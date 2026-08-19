const crypto = require('crypto');
const AES_KEY = Buffer.from('OKAS_AUTH_2025_C', 'utf8');
const CTR_IV = Buffer.alloc(16);

(module.exports = () => {
    // HAP-R2 check digit (8th digit); wrong sum = "Unable to Add Accessory".
    //   sum = d1*3 + d2*1 + d3*3 + d4*1 + d5*3 + d6*1 + d7*3
    //   check = (10 - (sum % 10)) % 10
    const addCheckDigit = (pin) => {
        const digits = pin.split('').map(Number);
        const sum = digits[0] * 3 + digits[1] * 1 + digits[2] * 3 +
            digits[3] * 1 + digits[4] * 3 + digits[5] * 1 + digits[6] * 3;
        const check = (10 - (sum % 10)) % 10;
        return pin.slice(0, 7) + check;
    };

    getPC = input => {
        input += 'CE807A14D114EDBB7C2D1FA80BF016A3ACF780E4A0ABAFCD886CE2F04E7EE051';
        const hash = crypto
            .createHash('sha256')
            .update(input)
            .digest('hex');
        const num = parseInt(hash.slice(0, 16), 16);
        const result = num % 100000000;
        // Stamp the check digit or Apple's Home app spits the PIN back out.
        return addCheckDigit(result.toString().padStart(8, '0'));
    };

    const normMac = (mac) => Buffer.from(mac.toLowerCase().replace(/[^a-f0-9]/g, ''), 'hex');

    global.genAuthToken = (mac) => {
        // AuthService owns the token; if it already wrote loadData.json, take that.
        if (typeof global.getOwnerToken === 'function') {
            const ownerToken = global.getOwnerToken();
            if (ownerToken) return ownerToken;
        }
        // Fallback: AES-128-CTR MAC-derived token (used before AuthService starts).
        const raw = normMac(mac);
        const cipher = crypto.createCipheriv('aes-128-ctr', AES_KEY, CTR_IV);
        const enc = cipher.update(raw);
        cipher.final();
        return enc.toString('base64url');
    };

    global.decryptTokenToMac = (token) => {
        const enc = Buffer.from(token, 'base64url');
        const cipher = crypto.createCipheriv('aes-128-ctr', AES_KEY, CTR_IV);
        const dec = cipher.update(enc);
        cipher.final();
        return dec.toString('hex').match(/.{2}/g).join(':');
    };
})();
