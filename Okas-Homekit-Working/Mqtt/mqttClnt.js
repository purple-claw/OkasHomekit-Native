const { loadDirectory } = require('hap-nodejs');
const mqtt = require('mqtt');
require("../log2file");
require("../Data/iData");
require("../KNX/actHdlr");

(module.exports = () => {
    const BRKURI = 'mqtt://localhost:1883';
    const CLNTID = 'okas-local' + Math.random().toString(16).substring(2, 8);

    global.TPCS = {
        SUB: {
            GT_LDS:  'loads/getLoads',
            SND_CMD: 'command/sndCmd',
            MOB_ACK: 'status/mobAck',
            GT_ROOMS: 'rooms/get',
            ADD_ROOM: 'rooms/add',
            DEL_ROOM: 'rooms/delete',
            WATCHDOG_CMD: 'okas/watchdog/cmd',
            APP_SCENES: 'app/scenes'
        },
        PUB: {
            ST_LDS:  'loads/setLoads',
            CMD_ACK: 'command/cmdAck',
            ST_ROOMS: 'rooms/set',
            WATCHDOG_STATUS: 'okas/watchdog/status',
            APP_SCENES: 'app/scenes'
        }
    };

    global.TYP_ABR = {
        'Switch':  'swt',
        'Dimmer':  'dim',
        'RGB':     'rgb',
        'Tunable': 'tun',
        'HVAC':    'hvc',
        'Fan':     'fan',
        'Curtain': 'cur',
        'Scene':   'scn'
    };

    global.ldIdx = {};
    global.bldLdIdx = () => {
        ldIdx = {};
        ldArr.forEach((v, i) => {
            if (i === 0) return;
            ldIdx[v.Nm] = i;
        });
        dbg.Inf('MQTT: Load index built — ' + Object.keys(ldIdx).length + ' loads mapped.');
        reconcileRoomsWithLoads();
    };

    // Room management - persistent storage
    const fs = require('fs');
    const path = require('path');
    const ROOMS_FILE = path.join(__dirname, '..', 'Data', 'rooms.json');

    global.rooms = [];
    const loadRooms = () => {
        try {
            if (fs.existsSync(ROOMS_FILE)) {
                global.rooms = JSON.parse(fs.readFileSync(ROOMS_FILE, 'utf8'));
                dbg.Inf('MQTT: Loaded ' + global.rooms.length + ' rooms.');
            }
        } catch (e) {
            dbg.Err('MQTT: Failed to load rooms: ' + e.message);
            global.rooms = [];
        }
    };
    loadRooms();

    const saveRooms = () => {
        try {
            fs.writeFileSync(ROOMS_FILE, JSON.stringify(global.rooms, null, 2));
            dbg.Inf('MQTT: Saved ' + global.rooms.length + ' rooms.');
        } catch (e) {
            dbg.Err('MQTT: Failed to save rooms: ' + e.message);
        }
    };

    // App scenes (app 'app/scenes') - persistent mirror of the mobile app's
    // scene list. The app publishes it retained; the backend keeps a disk
    // copy so a cleared broker or app storage never loses the scenes.
    const SCENES_FILE = path.join(__dirname, '..', 'Data', 'appScenes.json');

    global.appScenes = [];
    const loadAppScenes = () => {
        try {
            if (fs.existsSync(SCENES_FILE)) {
                global.appScenes = JSON.parse(fs.readFileSync(SCENES_FILE, 'utf8'));
                dbg.Inf('MQTT: Loaded ' + global.appScenes.length + ' app scenes.');
            }
        } catch (e) {
            dbg.Err('MQTT: Failed to load app scenes: ' + e.message);
            global.appScenes = [];
        }
    };
    loadAppScenes();

    const saveAppScenes = () => {
        try {
            fs.writeFileSync(SCENES_FILE, JSON.stringify(global.appScenes, null, 2));
            dbg.Inf('MQTT: Saved ' + global.appScenes.length + ' app scenes.');
        } catch (e) {
            dbg.Err('MQTT: Failed to save app scenes: ' + e.message);
        }
    };

    global.mqttSetAppScenes = (pld) => {
        if (!Array.isArray(pld)) {
            dbg.Err('MQTT: Invalid app scenes payload');
            return;
        }
        // The app mirrors its scene list to the board (retained), but that
        // copy may be stale after a config upload — the app still holds
        // scenes referencing load ids that no longer exist. The broker also
        // delivers this retained message back to the board on subscribe
        // (the board subscribes to app/scenes), so pruning must happen here
        // on EVERY accepted payload, not just at startup, or a stale list
        // overwrites the reconciled one.
        global.appScenes = pruneStaleSceneLoads(pld);
        saveAppScenes();
    };

    // Shared prune for app scenes: drop entries whose loadId does not map
    // to the current loadData.json config. Applied when the board accepts
    // an app/scenes payload AND during startup reconciliation.
    const pruneStaleSceneLoads = (scenes) => {
        if (!ldArr || !Array.isArray(ldArr) || ldArr.length < 2) return scenes;
        const validIds = new Set();
        for (let i = 1; i < ldArr.length; i++) validIds.add(String(i));
        let changed = false;
        const pruned = scenes.map((scene) => {
            if (!scene || !Array.isArray(scene.loads)) return scene;
            const kept = scene.loads.filter((s) => s && validIds.has(String(s.loadId)));
            if (kept.length !== scene.loads.length) {
                dbg.Wrn('MQTT: Scene "' + scene.name + '" had ' + scene.loads.length +
                    ' loads, pruned to ' + kept.length + ' (config changed).');
                changed = true;
                return { ...scene, loads: kept };
            }
            return scene;
        });
        if (changed) dbg.Inf('MQTT: App scene list reconciled with current load configuration.');
        return pruned;
    };

    // Rooms and app scenes reference loads by their positional id in
    // loadData.json (loads: ["4","5"] = entries 4 and 5 of ldArr). When a
    // new configuration is uploaded (makFile.php rewrites loadData.json and
    // restarts the service) those ids can point at loads that no longer
    // exist — e.g. a room referencing ids 9-21 after the new config only
    // defines 8 loads. Without this, the room list survives but every room
    // silently loses its loads (or worse, controls the WRONG load when the
    // index shifts). Prune invalid ids and republish the retained rooms/set
    // so the app immediately sees the corrected membership.
    const reconcileRoomsWithLoads = () => {
        // ldArr[0] is the project header, so valid load ids are 1..len-1.
        // If the config has not loaded yet (or failed), do NOT prune —
        // wiping every room's loads would be worse than leaving stale ids.
        if (!ldArr || !Array.isArray(ldArr) || ldArr.length < 2) {
            dbg.Wrn('MQTT: Skipping room reconciliation - load config not ready.');
            return;
        }
        const validIds = new Set();
        for (let i = 1; i < ldArr.length; i++) validIds.add(String(i));
        let changed = false;

        (global.rooms || []).forEach((room) => {
            if (!room || !Array.isArray(room.loads)) return;
            const pruned = room.loads.filter((id) => validIds.has(String(id)));
            if (pruned.length !== room.loads.length) {
                dbg.Wrn('MQTT: Room "' + room.name + '" had ' + room.loads.length +
                    ' loads, pruned to ' + pruned.length + ' (config changed).');
                room.loads = pruned;
                changed = true;
            }
        });

        // App scenes carry the same positional load ids — prune those too
        // so a stale scene cannot be replayed against the wrong load.
        const prunedScenes = pruneStaleSceneLoads(global.appScenes || []);
        if (prunedScenes !== global.appScenes) {
            global.appScenes = prunedScenes;
            changed = true;
        }

        if (changed) {
            saveRooms();
            saveAppScenes();
            // Push the corrected list to the broker so the mobile app's
            // replaceRooms() updates immediately (retained for new clients).
            mqttPub(TPCS.PUB.ST_ROOMS, { rooms: global.rooms }, true);
            dbg.Inf('MQTT: Rooms reconciled with current load configuration.');
        }
    };

    global.mqttGetRooms = (pld) => {
        // rooms/set is published with retain=true so that a brand-new
        // mobile app that subscribes receives the last-known room list
        // immediately without first sending rooms/get. Without this the
        // new client had to wait for a round-trip — and any room create
        // during that window would be wiped by the late rooms/set reply.
        mqttPub(TPCS.PUB.ST_ROOMS, { rooms: global.rooms }, true);
    };

    global.mqttDeleteRoom = (pld) => {
        if (!pld || !pld.id) {
            dbg.Err('MQTT: Invalid room delete payload');
            return;
        }
        const idx = global.rooms.findIndex(r => r.id === pld.id);
        if (idx >= 0) {
            const removed = global.rooms.splice(idx, 1)[0];
            dbg.Inf('MQTT: Deleted room: ' + removed.name);
            saveRooms();
        } else {
            dbg.Wrn('MQTT: Delete room - id not found: ' + pld.id);
        }
        // Update the retained rooms/set cache so new subscribers get the
        // latest list immediately and no orphan rooms linger.
        mqttPub(TPCS.PUB.ST_ROOMS, { rooms: global.rooms }, true);
    };

    global.mqttAddRoom = (pld) => {
        if (!pld || !pld.name) {
            dbg.Err('MQTT: Invalid room data');
            return;
        }
        // Merge partial updates (e.g. a favorite-only toggle) over any
        // existing room instead of replacing it wholesale, so fields the
        // client did not send (imagePath, createdAt, loads) are preserved.
        const existingIdx = global.rooms.findIndex(r => r.id === (pld.id || ''));
        const existing = existingIdx >= 0 ? global.rooms[existingIdx] : null;
        const room = {
            id: pld.id || Date.now().toString(),
            name: pld.name,
            imagePath: pld.imagePath !== undefined ? pld.imagePath : (existing ? existing.imagePath : null),
            loads: pld.loads !== undefined ? pld.loads : (existing ? existing.loads : []),
            createdAt: pld.createdAt || (existing ? existing.createdAt : new Date().toISOString()),
            isFavorite: pld.isFavorite !== undefined
                ? (pld.isFavorite === true || pld.isFavorite === 'true')
                : (existing ? existing.isFavorite === true : false)
        };
        if (existingIdx >= 0) {
            global.rooms[existingIdx] = room;
            dbg.Inf('MQTT: Updated room: ' + room.name);
        } else {
            global.rooms.push(room);
            dbg.Inf('MQTT: Added room: ' + room.name);
        }
        saveRooms();
        // Retain so a brand-new subscriber gets the updated list instantly
        // — without retain, a new app session that subscribes between
        // delete+add windows would not see the new room.
        mqttPub(TPCS.PUB.ST_ROOMS, { rooms: global.rooms }, true);
    };

    const getLdNm = (id) => {
        if (id < 1 || id >= ldArr.length) return null;
        return ldArr[id].Nm;
    };

    global.stsTpc = (lNm) => {
        let idx = ldIdx[lNm];
        if (idx === undefined) {
            dbg.Wrn('MQTT: No index for load "' + lNm + '"');
            return null;
        }
        return 'status/' + idx;
    };

    // Per-load dim-write coalescing: KNX dimmers drop absolute-dim writes
    // that land while the relay is still settling, and restart their ramp on
    // every mid-ramp write. A fast slider drag therefore oscillated the light
    // (0<->100) because each tick hit the bus. Only ONE write per settle
    // window reaches the bus — always the latest requested value.
    const dimTmr = {};
    const dimPending = {};

    // Shared flush for coalesced dim writes (slider drags AND the 100%
    // relatch the swt act triggers). RGB also re-sends Hue/Sat after the
    // final write so the colour doesn't drift on the dimmer.
    const scheduleDimFlush = (lNm) => {
        if (dimTmr[lNm]) return;
        dimTmr[lNm] = setTimeout(async () => {
            dimTmr[lNm] = null;
            const target = dimPending[lNm];
            dimPending[lNm] = undefined;
            const res = await Bri(lNm, target);
            if (res.ok && knxLod[lNm].Typ === 'RGB') {
                await Hue(lNm, knxLod[lNm].Val.Hue);
                await Sat(lNm, knxLod[lNm].Val.Sat);
            }
        }, 400);
    };

    const PAR_MAP = {
        'swt': {
            types: ['Switch', 'Dimmer', 'RGB', 'Tunable', 'HVAC', 'Fan'],
            act: async (lNm, val) => {
                if (['Dimmer', 'RGB', 'Tunable'].includes(knxLod[lNm].Typ)) {
                    // Latch the relay first, then drive brightness so the UI
                    // slider follows: ON snaps to 100%, OFF drops to 0%.
                    const swtRes = await Swt(lNm, val);
                    if (!swtRes.ok) return swtRes;
                    if (val) {
                        // Route the relatch through the coalescer too: the app
                        // used to pair swt:true with every bri tick, and each
                        // swt would otherwise re-write 100% to the bus.
                        knxLod[lNm].Val.Bri = 100;
                        knxLod[lNm].Val.Bvi = 100;
                        dimPending[lNm] = 100;
                        scheduleDimFlush(lNm);
                        return swtRes;
                    }
                    return swtRes;
                } else {
                    return await Swt(lNm, val);
                }
            }
        },
        'bri': {
            types: ['Dimmer', 'RGB', 'Tunable'],
            act: async (lNm, val) => {
                val = Number(val) || 0;
                if (val > 0 && !knxLod[lNm].Val.Sta) {
                    const onRes = await Swt(lNm, 1);
                    if (!onRes.ok) return onRes;
                    // KNX dimmers drop a dim write that lands while the relay
                    // is still settling and power on at 100% instead.
                    await new Promise((r) => setTimeout(r, 400));
                } else if (val <= 0 && knxLod[lNm].Val.Sta) {
                    const offRes = await Swt(lNm, 0);
                    if (!offRes.ok) return offRes;
                }
                // Optimistic: status reports show the drag target right away.
                knxLod[lNm].Val.Bri = val;
                knxLod[lNm].Val.Bvi = val;
                dimPending[lNm] = val;
                scheduleDimFlush(lNm);
                return { ok: true };
            }
        },
        'hue': {
            types: ['RGB'],
            act: async (lNm, val) => { return await Hue(lNm, val); }
        },
        'sat': {
            types: ['RGB'],
            act: async (lNm, val) => { return await Sat(lNm, val); }
        },
        'cTp': {
            types: ['Tunable'],
            act: async (lNm, val) => {
                // Tuning an OFF load must start it, but throu the relay
                // directly (no 100% relatch) — the app no longer pairs swt
                // with cTp, so without this a kelvin drag on an off light
                // wrote colour temp to an actuator that ignores it.
                if (!knxLod[lNm].Val.Sta) {
                    const onRes = await Swt(lNm, 1);
                    if (!onRes.ok) return onRes;
                    // Let the relay settle, then restore brightness through
                    // the coalescer so the light powers to 100% instead of
                    // sitting at the actuator's raw power-on level.
                    await new Promise((r) => setTimeout(r, 400));
                    dimPending[lNm] = knxLod[lNm].Val.Bri || 100;
                    scheduleDimFlush(lNm);
                }
                return await Tun(lNm, val);
            }
        },
        'spt': {
            types: ['HVAC'],
            act: async (lNm, val) => { return await Tsp(lNm, val); }
        },
        'fSp': {
            types: ['HVAC', 'Fan'],
            act: async (lNm, val) => { return await Fsp(lNm, val); }
        },
        'mod': {
            types: ['HVAC'],
            act: async (lNm, val) => { return await Tmd(lNm, val); }
        },
        'scn': {
            types: ['Scene'],
            act: async (lNm, val) => { return await Scn(lNm, val); }
        },
        'pos': {
            types: ['Curtain'],
            act: async (lNm, val) => { return await Pos(lNm, val); }
        }
    };

    let mqttClnt = null;
    global.isMqttCntd = false;
    let lstErrLog = 0;
    let wasCntd = false;

    global.cntMqtt = async () => {
        return new Promise((resolve) => {
            let settled = false;
            let startupTmr = null;
            // MQTT is auxiliary. It must never block or crash HomeKit startup
            const settle = (v) => {
                if (settled) return;
                settled = true;
                if (startupTmr) clearTimeout(startupTmr);
                resolve(v);
            };

            dbg.Inf('MQTT: Connecting to Broker...');
            mqttClnt = mqtt.connect(BRKURI, {
                clientId: CLNTID,
                clean: true,
                reconnectPeriod: 5000,
                connectTimeout: 10000
            });

            startupTmr = setTimeout(() => {
                dbg.Wrn('MQTT: Broker not reachable yet - continuing startup, will keep retrying in background.');
                settle(false);
            }, 8000);

            mqttClnt.on('connect', () => {
                isMqttCntd = true;
                wasCntd = true;
                dbg.Inf('MQTT: Connected to Broker...');
                bldLdIdx();
                const sbTpcs = Object.values(TPCS.SUB);
                // Runs on first connect AND every auto-reconnect, so subscriptions
                // are always restored after the broker returns.
                mqttClnt.subscribe(sbTpcs, { qos: 1 }, (err) => {
                    if (err) {
                        dbg.Err('MQTT: Subscription Error - ' + err.message);
                        settle(false);
                    } else {
                        dbg.Inf('MQTT: Subscribed to - ' + sbTpcs.join(', '));
                        // Re-seed the broker's retained app/scenes cache from
                        // disk, so scenes survive a broker persistence loss.
                        if (global.appScenes && global.appScenes.length) {
                            mqttPub(TPCS.PUB.APP_SCENES, global.appScenes, true);
                        }
                        settle(true);
                    }
                });
            });

            mqttClnt.on('message', (tp, msg) => {
                mqttRoute(tp, msg);
            });

            mqttClnt.on('error', (err) => {
                isMqttCntd = false;
                // Throttle: an unreachable broker emits an error on every retry (every 5s).
                const now = Date.now();
                if (now - lstErrLog > 60000) {
                    let m = (err && err.message) ? err.message : '';
                    if (!m || err.name === 'AggregateError') {
                        m = 'broker unreachable at ' + BRKURI + ' (is a broker running?) - retrying in background.';
                    }
                    dbg.Wrn('MQTT: ' + m);
                    lstErrLog = now;
                }
                settle(false);
            });

            mqttClnt.on('close', () => {
                isMqttCntd = false;
                // Only log a real drop from a connected state, not every retry
                // while the broker is simply absent (avoids 5s log spam).
                if (wasCntd) {
                    dbg.Inf('MQTT: Disconnected from Broker...');
                    wasCntd = false;
                }
                settle(false);
            });
        });
    };

    mqttRoute = (tp, msg) => {
        let pld;
        try {
            pld = JSON.parse(msg.toString());
        } catch (e) {
            dbg.Err('MQTT: Invalid JSON on Topic ' + tp + ' - ' + e.message);
            return;
        }
        // Tokens are bearer credentials. Never write them to the board log.
        const logPayload = { ...pld };
        delete logPayload.authToken;
        delete logPayload.token;
        delete logPayload.commandToken;
        dbg.Inf('MQTT: Message on [' + tp + '] ' + o2S(logPayload));

        // The Mosquitto account remains shared for backwards compatibility.
        // Authorization is therefore mandatory for every operation that can
        // reveal loads or change a KNX value. A revoked/expired guest is
        // rejected even if it still has a live MQTT connection.
        if ([TPCS.SUB.GT_LDS, TPCS.SUB.SND_CMD].includes(tp)) {
            const principal = typeof global.authorizeMqttPayload === 'function'
                ? global.authorizeMqttPayload(pld)
                : null;
            if (!principal) {
                mqttPub(TPCS.PUB.CMD_ACK, {
                    sts: 'error',
                    err: 'Unauthorized, expired, or revoked token.',
                    ts: Date.now()
                });
                dbg.Wrn('MQTT: Rejected unauthorized request on ' + tp);
                return;
            }
        }
        // Room mutation (add/delete) is admin-only. Guests may view the
        // room list (rooms/get) and control loads, but must not be able to
        // restructure the home. `authorizeMqttPayload` returns the
        // principal; only role === 'admin' may pass here.
        if ([TPCS.SUB.ADD_ROOM, TPCS.SUB.DEL_ROOM].includes(tp)) {
            const principal = typeof global.authorizeMqttPayload === 'function'
                ? global.authorizeMqttPayload(pld)
                : null;
            if (!principal || principal.role !== 'admin') {
                mqttPub(TPCS.PUB.CMD_ACK, {
                    sts: 'error',
                    err: 'Only the owner can manage rooms.',
                    ts: Date.now()
                });
                dbg.Wrn('MQTT: Rejected non-admin room mutation on ' + tp);
                return;
            }
        }
        switch (tp) {
            case TPCS.SUB.GT_LDS:
                mqttGtLds(pld);
                break;
            case TPCS.SUB.SND_CMD:
                mqttHdlCmd(pld);
                break;
            case TPCS.SUB.MOB_ACK:
                mqttRcvSts(pld);
                break;
            case TPCS.SUB.GT_ROOMS:
                mqttGetRooms(pld);
                break;
            case TPCS.SUB.ADD_ROOM:
                mqttAddRoom(pld);
                break;
            case TPCS.SUB.DEL_ROOM:
                mqttDeleteRoom(pld);
                break;
            case TPCS.SUB.APP_SCENES:
                mqttSetAppScenes(pld);
                break;
            case TPCS.SUB.WATCHDOG_CMD:
                // Handle watchdog commands: {cmd: 'restart', reason: '...'}
                if (pld.cmd === 'restart') {
                    dbg.Inf('Watchdog: Remote restart requested - ' + (pld.reason || 'unknown'));
                    // Publish to local watchdog topic or trigger via shell
                    const { exec } = require('child_process');
                    // Restart services in sequence
                    exec('systemctl restart OhKnxKnx.service', (err) => {
                        if (err) dbg.Err('Watchdog: Failed to restart OhKnxKnx - ' + err.message);
                        setTimeout(() => {
                            exec('systemctl restart HkBStartUp.service', (err2) => {
                                if (err2) dbg.Err('Watchdog: Failed to restart HkBStartUp - ' + err2.message);
                                else dbg.Inf('Watchdog: Services restarted successfully');
                            });
                        }, 3000);
                    });
                }
                mqttPub(TPCS.PUB.WATCHDOG_STATUS, { status: 'ok', timestamp: new Date().toISOString() });
                break;
            default:
                dbg.Wrn('MQTT: Unhandled Topic - ' + tp);
        }
    };

    global.mqttPub = (tp, pld, retain = false) => {
        if (!mqttClnt || !isMqttCntd) {
            dbg.Wrn('MQTT: Cannot Publish - Not Connected.');
            return false;
        }
        const msg = o2S(pld);
        mqttClnt.publish(tp, msg, { qos: 1, retain: retain }, (err) => {
            if (err) {
                dbg.Err('MQTT: Publish Failed on [' + tp + '] - ' + err.message);
            } else {
                dbg.Inf('MQTT: Published to [' + tp + ']' + (retain ? ' (retained)' : ''));
            }
        });
        return true;
    };

    global.discntMqtt = () => {
        return new Promise((resolve) => {
            if (mqttClnt) {
                mqttClnt.end(false, () => {
                    dbg.Inf('MQTT: Disconnected gracefully..');
                    isMqttCntd = false;
                    resolve(true);
                });
            } else {
                resolve(true);
            }
        });
    };

    mqttGtLds = (pld) => {
        dbg.Inf('MQTT: GetLoads -> Building Loads List..');
        try {
            let lds = [];
            ldArr.forEach((v, i) => {
                if (i === 0) return;
                lds.push({
                    nm: v.Nm,
                    typ: TYP_ABR[v.Typ] || v.Typ,
                    sta: gtLdSt(v.Nm)
                });
            });
            mqttPub(TPCS.PUB.ST_LDS, {
                lds: lds,
                ts: Date.now()
            }, true);
            dbg.Inf('MQTT: Published ' + lds.length + ' loads to loads/setLoads');
        } catch (e) {
            dbg.Err('MQTT: Error Building Load List - ' + e.message);
        }
    };

    global.mqttGtLds = mqttGtLds;

    mqttHdlCmd = async (pld) => {
        dbg.Inf('MQTT: Processing Command');
        if (!pld || pld.ldId === undefined || !pld.cmd || typeof pld.cmd !== 'object') {
            mqttPub(TPCS.PUB.CMD_ACK, {
                sts: 'error',
                err: 'Invalid Payload. Required: { ldId, cmd: { par: val } }',
                ts: Date.now()
            });
            dbg.Err('MQTT: Invalid Command Payload Received.');
            return;
        };

        let ldId = pld.ldId;
        let lNm = getLdNm(ldId);
        if (!lNm || !knxLod[lNm]) {
            mqttPub(TPCS.PUB.CMD_ACK, {
                ldId: ldId,
                sts: 'error',
                err: 'Load id ' + ldId + ' not found.',
                ts: Date.now()
            });
            dbg.Err('MQTT: Load Not Found - id ' + ldId);
            return;
        }

        let ldTyp = knxLod[lNm].Typ;
        let typAbr = TYP_ABR[ldTyp] || ldTyp;
        if (pld.typ && pld.typ !== typAbr) {
            mqttPub(TPCS.PUB.CMD_ACK, {
                ldId: ldId,
                typ: typAbr,
                sts: 'error',
                err: 'Type mismatch. Sent "' + pld.typ + '", actual "' + typAbr + '".',
                ts: Date.now()
            });
            dbg.Err('MQTT: Type mismatch for load id ' + ldId);
            return;
        }

        mqttPub(TPCS.PUB.CMD_ACK, {
            ldId: ldId,
            typ: typAbr,
            cmd: pld.cmd,
            sts: 'received',
            ts: Date.now()
        });

        let scs = true;
        let eMsg = '';
        let pars = Object.keys(pld.cmd);
        try {
            for (let i = 0; i < pars.length; i++) {
                let par = pars[i];
                let val = pld.cmd[par];
                let map = PAR_MAP[par];
                if (!map) {
                    scs = false;
                    eMsg = 'Unknown parameter: ' + par;
                    break;
                }
                if (!map.types.includes(ldTyp)) {
                    scs = false;
                    eMsg = '"' + par + '" not supported for type: ' + typAbr;
                    break;
                }

                let res = await map.act(lNm, val);
                if (!res.ok) {
                    scs = false;
                    eMsg = par + ': ' + res.err;
                    break;
                }
                dbg.Inf('MQTT: Executed ' + par + '=' + val + ' on ' + lNm);
            }
        } catch (e) {
            scs = false;
            eMsg = 'Execution error: ' + e.message;
            dbg.Err('MQTT: Command execution error - ' + e.message);
        }

        let stsMsg = {
            ldId: ldId,
            typ: typAbr,
            cmd: pld.cmd,
            sts: scs ? 'executed' : 'failed',
            ts: Date.now()
        };
        if (scs) {
            let cSt = gtLdSt(lNm);
            if (pld.cmd && typeof pld.cmd.swt === 'boolean' &&
                ['Dimmer', 'RGB', 'Tunable'].includes(ldTyp)) {
                cSt.bri = pld.cmd.swt ? 100 : 0;
            }
            stsMsg.cSt = cSt;
        } else {
            stsMsg.err = eMsg;
        }
        mqttPub(TPCS.PUB.CMD_ACK, stsMsg);
        // Refresh the retained per-load topic immediately so subscribers
        // (mobile app, dashboards) see the new state without waiting for
        // bus feedback. KNX devices that don't echo status would otherwise
        // leave status/{ldId} stale.
        if (scs && typeof global.mqttRptSts === 'function') {
            global.mqttRptSts(lNm);
        }
        dbg.Inf('MQTT: Command ' + (scs ? 'executed' : 'FAILED') + ' -> id:' + ldId + ' ' + o2S(pld.cmd));
    };

    global.gtLdSt = (lNm) => {
        let vals = knxLod[lNm]?.Val;
        let typ = knxLod[lNm]?.Typ;
        if (!vals) return {};
        switch (typ) {
            case 'Switch':
                return { on: vals.Sta ? true : false };
            case 'Dimmer':
                return {
                    on: vals.Sta ? true : false,
                    bri: vals.Sta ? (vals.Bvi || 0) : 0
                };
            case 'RGB':
                return {
                    on: vals.Sta ? true : false,
                    bri: vals.Sta ? (vals.Bvi || 0) : 0,
                    hue: vals.Hue || 0,
                    sat: vals.Sat || 0
                };
            case 'Tunable':
                return {
                    on: vals.Sta ? true : false,
                    bri: vals.Sta ? (vals.Bvi || 0) : 0,
                    cTp: vals.Tuv || 0
                };
            case 'HVAC':
                return {
                    on: vals.Sta ? true : false,
                    rTp: vals.Trm || 0,
                    spt: vals.Tsp || 0,
                    fSp: vals.Fsv || 0,
                    mod: vals.Tmv || 0
                };
            case 'Fan':
                return {
                    on: vals.Sta ? true : false,
                    fSp: vals.Fsv || 0
                };
            case 'Curtain':
                return {
                    cPs: vals.Pvi || 0,
                    tPs: vals.Pos || 0
                };
            case 'Scene':
                return { scn: vals.Scn || 0 };
            default:
                return {};
        }
    };

    mqttRcvSts = (pld) => {
        try {
            if (!pld) {
                dbg.Wrn('MQTT: Empty Status acknowledgement Recvd.');
                return;
            }
            let ldId = pld.ldId || 'unknown';
            let cmd = pld.cmd || 'unknown';
            let sts = pld.sts || 'unknown';
            dbg.Inf('MQTT: Cycle complete -> id:' + ldId + ' [' + sts + ']');
            global.lastMblAck = {
                ldId: ldId,
                cmd: cmd,
                sts: sts,
                ts: Date.now()
            };
        } catch (e) {
            dbg.Err('MQTT: Error processing status Acknowledgement - ' + e.message);
        }
    };
})();