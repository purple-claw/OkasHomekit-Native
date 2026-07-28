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
            WATCHDOG_CMD: 'okas/watchdog/cmd'
        },
        PUB: {
            ST_LDS:  'loads/setLoads',
            CMD_ACK: 'command/cmdAck',
            ST_ROOMS: 'rooms/set',
            WATCHDOG_STATUS: 'okas/watchdog/status'
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

    global.mqttGetRooms = (pld) => {
        mqttPub(TPCS.PUB.ST_ROOMS, { rooms: global.rooms });
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
        mqttPub(TPCS.PUB.ST_ROOMS, { rooms: global.rooms });
    };

    global.mqttAddRoom = (pld) => {
        if (!pld || !pld.name) {
            dbg.Err('MQTT: Invalid room data');
            return;
        }
        const room = {
            id: pld.id || Date.now().toString(),
            name: pld.name,
            imagePath: pld.imagePath || null,
            loads: pld.loads || [],
            createdAt: pld.createdAt || new Date().toISOString()
        };
        // Check if room exists, update if so
        const existingIdx = global.rooms.findIndex(r => r.id === room.id);
        if (existingIdx >= 0) {
            global.rooms[existingIdx] = room;
            dbg.Inf('MQTT: Updated room: ' + room.name);
        } else {
            global.rooms.push(room);
            dbg.Inf('MQTT: Added room: ' + room.name);
        }
        saveRooms();
        mqttPub(TPCS.PUB.ST_ROOMS, { rooms: global.rooms });
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

    const PAR_MAP = {
        'swt': {
            types: ['Switch', 'Dimmer', 'RGB', 'Tunable', 'HVAC', 'Fan'],
            act: async (lNm, val) => {
                if (['Dimmer', 'RGB', 'Tunable'].includes(knxLod[lNm].Typ)) {
                    // Always write the Swt GA first so the dimmer relay latches
                    // ON/OFF on the bus and Val.Sta tracks reality. Then, if we
                    // are turning on, reapply the last-known brightness (or 100%
                    // on first-on) so the lamp actually lights up.
                    const swtRes = await Swt(lNm, val);
                    if (!swtRes.ok) return swtRes;
                    if (val) {
                        const vl = knxLod[lNm].Val.Bri > 0 ? knxLod[lNm].Val.Bri : 100;
                        return await Bri(lNm, vl);
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
                let res = await Bri(lNm, val);
                if (res.ok && knxLod[lNm].Typ === 'RGB') {
                    await Hue(lNm, knxLod[lNm].Val.Hue);
                    await Sat(lNm, knxLod[lNm].Val.Sat);
                }
                return res;
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
            act: async (lNm, val) => { return await Tun(lNm, val); }
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
            // MQTT is auxiliary. It must never block or crash HomeKit startup:
            // resolve exactly once, and keep the client retrying in the background
            // (reconnectPeriod) so it recovers on its own when the broker comes up.
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
            stsMsg.cSt = gtLdSt(lNm);
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
                    bri: vals.Bvi || 0
                };
            case 'RGB':
                return {
                    on: vals.Sta ? true : false,
                    bri: vals.Bvi || 0,
                    hue: vals.Hue || 0,
                    sat: vals.Sat || 0
                };
            case 'Tunable':
                return {
                    on: vals.Sta ? true : false,
                    bri: vals.Bvi || 0,
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