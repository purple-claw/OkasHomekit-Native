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
        resetBoardState();
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

    // Retained mirror + disk copy of the app's scenes; broker clears or app wipes, we still have them.
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
        global.appScenes = pld;
        saveAppScenes();
    };

    // A fresh config upload (makFile.php) swaps the load list AND the rooms:
    // rooms are part of the uploaded config now (Data/rooms.json written by
    // PHP), so they survive the reset. App scenes, the per-load status cache,
    // and the broker's retained state are still wiped, then re-seeded from
    // the new files — no window where a stale list and a fresh config mix.
    const resetBoardState = () => {
        const marker = path.join(__dirname, '..', 'Data', '.configReset');
        if (!fs.existsSync(marker)) return;
        try {
            fs.unlinkSync(marker);
            dbg.Inf('MQTT: Config reset marker found - wiping previous app scenes/status.');

            global.appScenes = [];
            saveAppScenes();
            // Rooms now live in the config; reload what makFile.php wrote.
            loadRooms();

            if (mqttClnt && isMqttCntd) {
                // Republish the configured rooms (not an empty home) and
                // clear the retained scene/status topics.
                mqttPub(TPCS.PUB.ST_ROOMS, { rooms: global.rooms }, true);
                mqttPub(TPCS.PUB.APP_SCENES, [], true);
                clearRetainedStatusTopics();
            }
            dbg.Inf('MQTT: Board state reset complete - ready for fresh configuration.');
        } catch (e) {
            dbg.Err('MQTT: Config reset failed - ' + e.message);
        }
    };

    // Nuke EVERY retained status/{ldId} — old configs may have left orphans; enumerate status/#, then clear each.
    const clearRetainedStatusTopics = () => {
        const collected = new Set();
        let done = false;
        const finish = () => {
            if (done) return;
            done = true;
            try { mqttClnt.unsubscribe('status/#'); } catch (e) { /* ignore */ }
            dbg.Inf('MQTT: Cleared ' + collected.size + ' stale status topics.');
        };
        mqttClnt.on('message', collector);
        mqttClnt.subscribe('status/#', { qos: 0 }, (err) => {
            if (err) {
                mqttClnt.removeListener('message', collector);
                finish();
                return;
            }
            // Retained messages race SUBACK; give the event loop one turn to deliver.
            setTimeout(() => {
                mqttClnt.removeListener('message', collector);
                collected.forEach((t) => {
                    mqttClnt.publish(t, Buffer.alloc(0), { qos: 1, retain: true });
                });
                finish();
            }, 500);
        });
        function collector(tp, msg) {
            if (tp.startsWith('status/')) collected.add(tp);
        }
    };

    global.mqttGetRooms = (pld) => {
        // Retain rooms/set so new subscribers see the list now; a late reply would wipe a fresh create.
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
        // Keep the retained rooms cache fresh; new subscribers hate empty lists.
        mqttPub(TPCS.PUB.ST_ROOMS, { rooms: global.rooms }, true);
    };

    global.mqttAddRoom = (pld) => {
        if (!pld || !pld.name) {
            dbg.Err('MQTT: Invalid room data');
            return;
        }
        // Merge partials over the existing room; don't nuke fields the client didn't send.
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
        // Retain it, or a subscriber joining between delete+add never sees the room.
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

    // Coalesce absolute-dim writes: KNX dimmers drop writes mid-settle and restart the ramp — one latest write per settle window, or slider drags strobe the light.
    const dimTmr = {};
    const dimPending = {};

    // Shared flush for coalesced writes; RGB re-sends Hue/Sat after, or the colour drifts.
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
                    // Relay first, then brightness: ON snaps to 100%, OFF drops to 0%.
                    const swtRes = await Swt(lNm, val);
                    if (!swtRes.ok) return swtRes;
                    if (val) {
                        // Route the relatch through the coalescer too; the old pairing re-wrote 100% on every tick.
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
                    // Settling relays drop dim writes and power on at 100% — hence the coalescer.
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
                // Tuning an OFF load must start it straight through the relay (no 100% relatch) — the app no longer pairs swt with cTp.
                if (!knxLod[lNm].Val.Sta) {
                    const onRes = await Swt(lNm, 1);
                    if (!onRes.ok) return onRes;
                    // Let the relay settle, then restore brightness through the coalescer — raw power-on 100% is not a feature.
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
        },
        'mov': {
            types: ['Curtain'],
            act: async (lNm, val) => { return await Mov(lNm, val); }
        },
        'stp': {
            types: ['Curtain'],
            act: async (lNm) => { return await Stp(lNm); }
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
                // Runs on connect AND on every reconnect — subscriptions must survive broker holidays.
                mqttClnt.subscribe(sbTpcs, { qos: 1 }, (err) => {
                    if (err) {
                        dbg.Err('MQTT: Subscription Error - ' + err.message);
                        settle(false);
                    } else {
                        dbg.Inf('MQTT: Subscribed to - ' + sbTpcs.join(', '));
                        // Re-seed the retained scenes from disk; broker amnesia is not a data-loss excuse.
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
                // Log a real drop only; an absent broker shouting every 5s is noise.
                if (wasCntd) {
                    dbg.Inf('MQTT: Disconnected from Broker...');
                    wasCntd = false;
                }
                settle(false);
            });
        });
    };

    mqttRoute = (tp, msg) => {
        // Empty payload = a retained-message clear (Buffer.alloc(0)) — never a
        // command. status/# belongs to the mobile app; Node only touches those
        // topics for retention cleanup, so both are ignored here.
        if (msg.length === 0 || tp.startsWith('status/')) return;
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
        dbg.Dbg('MQTT: Message on [' + tp + '] ' + o2S(logPayload));

        // Shared broker account, so every state-revealing or KNX-writing op needs auth; revoked guests get bounced.
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
        // Room mutation is admin-only; guests may look and poke loads, not redecorate.
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
                dbg.Dbg('MQTT: Published to [' + tp + ']' + (retain ? ' (retained)' : ''));
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
            dbg.Dbg('MQTT: Published ' + lds.length + ' loads to loads/setLoads');
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
        // Refresh the retained topic right away; devices that never echo would leave subscribers staring at lies.
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
                    tPs: vals.Pos || 0,
                    hasPos: !!(knxLod[lNm].GA && knxLod[lNm].GA.Pos)
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