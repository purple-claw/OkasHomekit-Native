'use strict';

const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const path = require('path');

const DATA_DIR = process.env.OKAS_AUTH_DATA_DIR || path.join(__dirname, '..', 'AuthData');
const STORE_PATH = path.join(DATA_DIR, 'authStore.json');
const LOAD_DATA_PATH = process.env.OKAS_LOAD_DATA_PATH || path.join(__dirname, '..', 'Data', 'loadData.json');
const API_HOST = process.env.OKAS_AUTH_HOST || '127.0.0.1';
const API_PORT = Number(process.env.OKAS_AUTH_PORT || 8080);
const MAX_GUEST_DURATION_MINUTES = 60 * 24 * 30;
const MIN_GUEST_DURATION_MINUTES = 5;
const COMMAND_SESSION_TTL_MS = 12 * 60 * 60 * 1000;
const TOKEN_LENGTH = 8;
const TOKEN_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function now() { return new Date().toISOString(); }
function tokenHash(token, salt) {
    return crypto.scryptSync(token, salt, 32, { N: 16384, r: 8, p: 1 }).toString('base64url');
}
function randomToken() {
    let result = '';
    while (result.length < TOKEN_LENGTH) {
        for (const value of crypto.randomBytes(32)) {
            if (value >= 224) continue;
            result += TOKEN_ALPHABET[value % TOKEN_ALPHABET.length];
            if (result.length === TOKEN_LENGTH) break;
        }
    }
    return result;
}
function macToken(mac) {
    const normalized = String(mac || '').toLowerCase().replace(/[^a-f0-9]/g, '');
    if (normalized.length !== 12) return null;
    const digest = crypto.createHash('sha256').update(`OKAS-MAC-AUTH-V1:${normalized}`).digest();
    let result = '';
    for (const value of digest) {
        if (value >= 224) continue;
        result += TOKEN_ALPHABET[value % TOKEN_ALPHABET.length];
        if (result.length === TOKEN_LENGTH) return result;
    }
    return null;
}
function safeEqual(a, b) {
    const aa = Buffer.from(a);
    const bb = Buffer.from(b);
    return aa.length === bb.length && crypto.timingSafeEqual(aa, bb);
}
function isExpired(principal, at = Date.now()) {
    return principal.expiresAt != null && Date.parse(principal.expiresAt) <= at;
}
function publicPrincipal(principal) {
    return {
        id: principal.id,
        role: principal.role,
        label: principal.label,
        createdAt: principal.createdAt,
        expiresAt: principal.expiresAt,
        revokedAt: principal.revokedAt || null,
    };
}

class AuthService {
    constructor({ logger = console } = {}) {
        this.logger = logger;
        this.store = null;
        this.server = null;
        this.loginAttempts = new Map();
        this.expiryTimer = null;
    }

    initialise() {
        fs.mkdirSync(DATA_DIR, { recursive: true, mode: 0o750 });
        const ownerToken = this.readOrCreateOwnerToken();
        this.store = this.readStore();
        if (!this.store) this.store = this.createStore(ownerToken);
        if (!this.store.signingKey) this.store.signingKey = crypto.randomBytes(32).toString('base64url');
        this.ensureOwnerPrincipal(ownerToken);
        this.expirePrincipals();
        this.saveStore();
        this.expiryTimer = setInterval(() => this.expirePrincipals(), 60 * 1000);
        this.expiryTimer.unref();
    }

    createStore(ownerToken) {
        return {
            version: 1,
            signingKey: crypto.randomBytes(32).toString('base64url'),
            principals: [this.makePrincipal({ role: 'admin', label: 'Owner', token: ownerToken })],
        };
    }

    ensureOwnerPrincipal(ownerToken) {
        let owner = this.store.principals.find((principal) => principal.role === 'admin');
        if (!owner) {
            owner = this.makePrincipal({ role: 'admin', label: 'Owner', token: ownerToken });
            this.store.principals.unshift(owner);
            return;
        }
        const currentHash = tokenHash(ownerToken, owner.tokenSalt);
        if (!safeEqual(currentHash, owner.tokenHash)) {
            const replacement = this.makePrincipal({ role: 'admin', label: owner.label || 'Owner', token: ownerToken });
            replacement.id = owner.id;
            replacement.createdAt = owner.createdAt || replacement.createdAt;
            this.store.principals[this.store.principals.indexOf(owner)] = replacement;
        }
    }

    readStore() {
        try {
            const parsed = JSON.parse(fs.readFileSync(STORE_PATH, 'utf8'));
            if (parsed && parsed.version === 1 && Array.isArray(parsed.principals)) return parsed;
        } catch (error) {
            if (error.code !== 'ENOENT') this.logger.error(`AUTH: Could not read auth store: ${error.message}`);
        }
        return null;
    }

    readOrCreateOwnerToken() {
        let data = [];
        try { data = JSON.parse(fs.readFileSync(LOAD_DATA_PATH, 'utf8')); } catch (_) { /* created during first setup */ }
        const existing = data[0] && data[0].authToken;
        const macDerivedToken = macToken(data[0] && data[0].mac);
        const ownerToken = macDerivedToken || (typeof existing === 'string' && /^[A-Z2-9]{8}$/.test(existing)
            ? existing
            : randomToken());
        if (!data[0]) data[0] = {};
        data[0].authToken = ownerToken;
        fs.writeFileSync(LOAD_DATA_PATH, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o640 });
        return ownerToken;
    }

    makePrincipal({ role, label, token, expiresAt = null }) {
        const salt = crypto.randomBytes(16).toString('base64url');
        const id = crypto.randomUUID();
        return {
            id,
            role,
            label,
            tokenSalt: salt,
            tokenHash: tokenHash(token, salt),
            createdAt: now(),
            expiresAt,
            revokedAt: null,
        };
    }

    saveStore() {
        const temporary = `${STORE_PATH}.tmp`;
        fs.writeFileSync(temporary, `${JSON.stringify(this.store, null, 2)}\n`, { mode: 0o600 });
        fs.renameSync(temporary, STORE_PATH);
        fs.chmodSync(STORE_PATH, 0o600);
    }

    getOwnerToken() {
        try {
            const data = JSON.parse(fs.readFileSync(LOAD_DATA_PATH, 'utf8'));
            return data[0] && data[0].authToken;
        } catch (_) { return null; }
    }

    findPrincipalByToken(token) {
        if (typeof token !== 'string' || !/^[A-Za-z0-9]{8,256}$/.test(token)) return null;
        for (const principal of this.store.principals) {
            const candidate = tokenHash(token, principal.tokenSalt);
            if (safeEqual(candidate, principal.tokenHash)) return principal;
        }
        return null;
    }

    validPrincipalForToken(token) {
        const principal = this.findPrincipalByToken(token);
        if (!principal || principal.revokedAt || isExpired(principal)) return null;
        return principal;
    }

    createGuest(adminToken, { label, durationMinutes, expiresAt, token }) {
        const admin = this.validPrincipalForToken(adminToken);
        if (!admin || admin.role !== 'admin') throw this.httpError(403, 'Admin authorization is required.');
        if (typeof token !== 'string' || !/^[A-Z2-9]{8}$/.test(token)) {
            throw this.httpError(400, 'The app must provide an 8-character guest token.');
        }
        const guestLabel = String(label || 'Guest').trim().slice(0, 80);
        const expiration = this.validateGuestExpiry(durationMinutes, expiresAt);
        const principal = this.makePrincipal({ role: 'guest', label: guestLabel || 'Guest', token, expiresAt: expiration });
        this.store.principals.push(principal);
        this.saveStore();
        return { guest: publicPrincipal(principal) };
    }

    validateGuestExpiry(durationMinutes, expiresAt) {
        if (expiresAt != null) {
            const parsed = Date.parse(expiresAt);
            if (!Number.isNaN(parsed) && parsed > Date.now() && parsed - Date.now() <= MAX_GUEST_DURATION_MINUTES * 60000) {
                return new Date(parsed).toISOString();
            }
        }
        const minutes = Number(durationMinutes);
        if (!Number.isInteger(minutes) || minutes < MIN_GUEST_DURATION_MINUTES || minutes > MAX_GUEST_DURATION_MINUTES) {
            throw this.httpError(400, `durationMinutes must be an integer between ${MIN_GUEST_DURATION_MINUTES} and ${MAX_GUEST_DURATION_MINUTES}.`);
        }
        return new Date(Date.now() + minutes * 60000).toISOString();
    }

    revokeGuest(adminToken, id) {
        const admin = this.validPrincipalForToken(adminToken);
        if (!admin || admin.role !== 'admin') throw this.httpError(403, 'Admin authorization is required.');
        const principal = this.store.principals.find((item) => item.id === id && item.role === 'guest');
        if (!principal) throw this.httpError(404, 'Guest not found.');
        if (!principal.revokedAt) {
            principal.revokedAt = now();
            this.saveStore();
        }
        return publicPrincipal(principal);
    }

    updateGuest(adminToken, id, { label, durationMinutes, expiresAt }) {
        const admin = this.validPrincipalForToken(adminToken);
        if (!admin || admin.role !== 'admin') throw this.httpError(403, 'Admin authorization is required.');
        const principal = this.store.principals.find((item) => item.id === id && item.role === 'guest');
        if (!principal) throw this.httpError(404, 'Guest not found.');
        if (principal.revokedAt) throw this.httpError(409, 'Revoked guests cannot be updated.');

        if (label != null) {
            const guestLabel = String(label || 'Guest').trim().slice(0, 80);
            principal.label = guestLabel || 'Guest';
        }
        if (durationMinutes != null || expiresAt != null) {
            principal.expiresAt = this.validateGuestExpiry(durationMinutes, expiresAt);
        }
        this.saveStore();
        return publicPrincipal(principal);
    }

    deleteGuest(adminToken, id) {
        const admin = this.validPrincipalForToken(adminToken);
        if (!admin || admin.role !== 'admin') throw this.httpError(403, 'Admin authorization is required.');
        const index = this.store.principals.findIndex((item) => item.id === id && item.role === 'guest');
        if (index === -1) throw this.httpError(404, 'Guest not found.');
        const [principal] = this.store.principals.splice(index, 1);
        this.saveStore();
        return publicPrincipal({ ...principal, revokedAt: principal.revokedAt || now() });
    }

    listGuests(adminToken) {
        const admin = this.validPrincipalForToken(adminToken);
        if (!admin || admin.role !== 'admin') throw this.httpError(403, 'Admin authorization is required.');
        this.expirePrincipals();
        return this.store.principals.filter((item) => item.role === 'guest').map(publicPrincipal);
    }

    exchange(token) {
        this.expirePrincipals();
        const principal = this.validPrincipalForToken(token);
        if (!principal) throw this.httpError(401, 'Invalid, expired, or revoked token.');
        return {
            success: true,
            principal: publicPrincipal(principal),
            commandToken: this.issueCommandToken(principal),
            mqtt: {
                host: null,
                port: Number(process.env.OKAS_MQTT_PORT || 1884),
                username: process.env.OKAS_MQTT_USERNAME || 'okasapi',
                password: process.env.OKAS_MQTT_PASSWORD || 'okas1234',
                expiresAt: principal.expiresAt,
                tls: process.env.OKAS_MQTT_TLS === 'true',
            },
        };
    }

    expirePrincipals() {
        if (!this.store) return;
        let changed = false;
        for (const principal of this.store.principals) {
            if (!principal.revokedAt && isExpired(principal)) {
                principal.revokedAt = now();
                changed = true;
            }
        }
        if (changed) {
            this.saveStore();
        }
    }

    authorizeMqttPayload(payload) {
        const sessionPrincipal = this.verifyCommandToken(payload && payload.commandToken);
        if (sessionPrincipal) return publicPrincipal(sessionPrincipal);
        const principal = this.validPrincipalForToken(payload && (payload.authToken || payload.token));
        return principal ? publicPrincipal(principal) : null;
    }

    issueCommandToken(principal) {
        const expiresAt = Math.min(
            Date.now() + COMMAND_SESSION_TTL_MS,
            principal.expiresAt ? Date.parse(principal.expiresAt) : Number.MAX_SAFE_INTEGER,
        );
        const payload = Buffer.from(JSON.stringify({ v: 1, sub: principal.id, exp: expiresAt })).toString('base64url');
        const signature = crypto.createHmac('sha256', this.store.signingKey).update(payload).digest('base64url');
        return `${payload}.${signature}`;
    }

    verifyCommandToken(commandToken) {
        if (typeof commandToken !== 'string' || commandToken.length > 1024) return null;
        const parts = commandToken.split('.');
        if (parts.length !== 2) return null;
        const expected = crypto.createHmac('sha256', this.store.signingKey).update(parts[0]).digest('base64url');
        if (!safeEqual(parts[1], expected)) return null;
        try {
            const session = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
            if (session.v !== 1 || typeof session.sub !== 'string' || !Number.isInteger(session.exp) || session.exp <= Date.now()) return null;
            const principal = this.store.principals.find((item) => item.id === session.sub);
            return principal && !principal.revokedAt && !isExpired(principal) ? principal : null;
        } catch (_) {
            return null;
        }
    }

    start() {
        if (this.server) return;
        this.server = http.createServer((request, response) => this.handle(request, response));
        this.server.listen(API_PORT, API_HOST, () => this.logger.log(`AUTH: API listening on ${API_HOST}:${API_PORT}`));
    }

    stop() {
        if (this.expiryTimer) clearInterval(this.expiryTimer);
        if (!this.server) return Promise.resolve();
        return new Promise((resolve) => this.server.close(resolve));
    }

    async handle(request, response) {
        try {
            if (request.method === 'OPTIONS') return this.respond(response, 204, null);
            const url = new URL(request.url, 'http://localhost');
            if (request.method === 'GET' && url.pathname === '/api/health') return this.respond(response, 200, { success: true });
            if (request.method === 'POST' && ['/api/auth/verify', '/api/auth/exchange'].includes(url.pathname)) {
                const forwardedFor = request.headers['x-forwarded-for'];
                const clientAddress = typeof forwardedFor === 'string'
                    ? forwardedFor.split(',')[0].trim()
                    : request.socket.remoteAddress || 'unknown';
                this.checkLoginRate(clientAddress);
            }
            const body = await this.readJson(request);
            const token = this.bearerToken(request) || body.token;
            if (request.method === 'POST' && url.pathname === '/api/auth/verify') {
                const principal = this.validPrincipalForToken(token);
                if (!principal) throw this.httpError(401, 'Invalid, expired, or revoked token.');
                return this.respond(response, 200, { success: true, principal: publicPrincipal(principal) });
            }
            if (request.method === 'POST' && url.pathname === '/api/auth/exchange') return this.respond(response, 200, this.exchange(token));
            if (request.method === 'GET' && url.pathname === '/api/auth/guests') return this.respond(response, 200, { success: true, guests: this.listGuests(token) });
            if (request.method === 'POST' && url.pathname === '/api/auth/guests') return this.respond(response, 201, { success: true, ...this.createGuest(token, body) });
            const revokeMatch = url.pathname.match(/^\/api\/auth\/guests\/([0-9a-f-]{36})\/revoke$/i);
            if (request.method === 'POST' && revokeMatch) return this.respond(response, 200, { success: true, guest: this.revokeGuest(token, revokeMatch[1]) });
            const guestMatch = url.pathname.match(/^\/api\/auth\/guests\/([0-9a-f-]{36})$/i);
            if ((request.method === 'PUT' || request.method === 'PATCH') && guestMatch) return this.respond(response, 200, { success: true, guest: this.updateGuest(token, guestMatch[1], body) });
            if (request.method === 'DELETE' && guestMatch) return this.respond(response, 200, { success: true, guest: this.deleteGuest(token, guestMatch[1]) });
            throw this.httpError(404, 'Not found.');
        } catch (error) {
            this.respond(response, error.statusCode || 500, { success: false, message: error.expose ? error.message : 'Internal server error.' });
        }
    }

    readJson(request) {
        return new Promise((resolve, reject) => {
            let raw = '';
            request.on('data', (chunk) => {
                raw += chunk;
                if (raw.length > 16 * 1024) reject(this.httpError(413, 'Request body too large.'));
            });
            request.on('end', () => {
                if (!raw) return resolve({});
                try { resolve(JSON.parse(raw)); } catch (_) { reject(this.httpError(400, 'Invalid JSON.')); }
            });
            request.on('error', reject);
        });
    }

    bearerToken(request) {
        const value = request.headers.authorization || '';
        return value.startsWith('Bearer ') ? value.slice(7).trim() : null;
    }

    checkLoginRate(address) {
        const current = Date.now();
        const entry = this.loginAttempts.get(address) || { startedAt: current, count: 0 };
        if (current - entry.startedAt >= 60 * 1000) {
            entry.startedAt = current;
            entry.count = 0;
        }
        entry.count += 1;
        this.loginAttempts.set(address, entry);
        if (entry.count > 10) throw this.httpError(429, 'Too many authentication attempts. Try again in one minute.');
    }

    respond(response, status, payload) {
        response.writeHead(status, {
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'no-store',
            'X-Content-Type-Options': 'nosniff',
        });
        response.end(payload == null ? '' : JSON.stringify(payload));
    }

    httpError(statusCode, message) {
        const error = new Error(message);
        error.statusCode = statusCode;
        error.expose = true;
        return error;
    }
}

let singleton;
function startAuthService() {
    if (!singleton) {
        singleton = new AuthService({ logger: { log: (message) => dbg.Inf(message), error: (message) => dbg.Err(message) } });
        singleton.initialise();
        singleton.start();
        global.getOwnerToken = () => singleton.getOwnerToken();
        global.authorizeMqttPayload = (payload) => singleton.authorizeMqttPayload(payload);
    }
    return singleton;
}

function stopAuthService() {
    return singleton ? singleton.stop() : Promise.resolve();
}

module.exports = { AuthService, startAuthService, stopAuthService };
