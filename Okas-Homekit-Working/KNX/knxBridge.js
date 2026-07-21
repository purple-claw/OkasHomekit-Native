// KNX bridge (Node.js side) — the MQTT link to the Python xknx process.
//
// All KNX bus I/O lives in KNX/knx_bridge.py now. This module is how the
// HomeKit side reaches it:
//   * knxCmd()      publishes write commands  -> okas/knx/cmd   (JS -> Python)
//   * okas/knx/state feedback from the bus     -> applyKnxState  (Python -> JS)
//   * okas/knx/conn  KNX link status           -> global isCon   (Python -> JS)
//
// This is a separate MQTT client from Mqtt/mqttClnt.js (the mobile-app API);
// keeping the internal KNX channel isolated avoids coupling the two concerns.

const mqtt = require('mqtt');
require('../log2file');
require('../Data/iData');
require('./repHdlr');

(module.exports = () => {
    const BRKURI = 'mqtt://localhost:1883';
    const CLNTID = 'okas-hkb-' + Math.random().toString(16).substring(2, 8);

    global.KNX_TPCS = {
        CMD: 'okas/knx/cmd',    // JS -> Python : { ga, dpt, val, nm, dp }
        STATE: 'okas/knx/state',  // Python -> JS : { ga, val }
        CONN: 'okas/knx/conn',   // Python -> JS : { connected } (retained)
        SYNC: 'okas/knx/sync'    // JS -> Python : {} -> re-read all status GAs
    };

    // isCon mirrors the Python-reported KNX link state; actHdlr guards writes on it.
    global.isCon = false;

    let brdgClnt = null;
    let wasCntd = false;
    let lstErrLog = 0;

    // Publish a KNX write command to the Python bridge.
    //   dp:  datapoint key (e.g. 'Swt', 'Bri', 'Clc') — used to resolve GA + DPT.
    // Returns { ok, err } so the action handlers can report success synchronously.
    global.knxCmd = (lNm, dp, val) => {
        const load = knxLod[lNm];
        if (!load || !load.GA || !load.GA[dp]) {
            return { ok: false, err: `No group address for ${lNm}.${dp}` };
        }
        if (!isCon) {
            return { ok: false, err: 'KNX interface disconnected' };
        }
        if (!brdgClnt || !brdgClnt.connected) {
            return { ok: false, err: 'KNX bridge (MQTT) not connected' };
        }
        const pld = {
            ga: load.GA[dp],
            dpt: dptObj[dp],
            val: val,
            nm: lNm,
            dp: dp
        };
        brdgClnt.publish(KNX_TPCS.CMD, o2S(pld), { qos: 1 }, (err) => {
            if (err) dbg.Err(`KNX bridge: publish failed for ${lNm}.${dp} - ${err.message}`);
        });
        return { ok: true };
    };

    global.cntKnxBridge = async () => {
        return new Promise((resolve) => {
            let settled = false;
            let startupTmr = null;
            const settle = (v) => {
                if (settled) return;
                settled = true;
                if (startupTmr) clearTimeout(startupTmr);
                resolve(v);
            };

            dbg.Inf('KNX bridge: connecting to broker...');
            brdgClnt = mqtt.connect(BRKURI, {
                clientId: CLNTID,
                clean: true,
                reconnectPeriod: 5000,
                connectTimeout: 10000
            });

            // Don't let a missing broker block HomeKit startup — resolve once and
            // keep retrying in the background (reconnectPeriod).
            startupTmr = setTimeout(() => {
                dbg.Wrn('KNX bridge: broker not reachable yet - continuing, retrying in background.');
                settle(false);
            }, 8000);

            brdgClnt.on('connect', () => {
                wasCntd = true;
                dbg.Inf('KNX bridge: connected to broker.');
                const tpcs = [KNX_TPCS.STATE, KNX_TPCS.CONN];
                brdgClnt.subscribe(tpcs, { qos: 1 }, (err) => {
                    if (err) {
                        dbg.Err('KNX bridge: subscription error - ' + err.message);
                        settle(false);
                    } else {
                        dbg.Inf('KNX bridge: subscribed to - ' + tpcs.join(', '));
                        // Ask Python to re-read all status GAs so HomeKit gets fresh state.
                        brdgClnt.publish(KNX_TPCS.SYNC, '{}', { qos: 1 });
                        settle(true);
                    }
                });
            });

            brdgClnt.on('message', (tp, msg) => {
                let pld;
                try {
                    pld = s2O(msg.toString());
                } catch (e) {
                    dbg.Err('KNX bridge: invalid JSON on ' + tp + ' - ' + e.message);
                    return;
                }
                if (tp === KNX_TPCS.STATE) {
                    // Feedback from the bus -> update HomeKit + cached state.
                    applyKnxState(pld.ga, pld.val);
                } else if (tp === KNX_TPCS.CONN) {
                    const nowCon = !!(pld && pld.connected);
                    if (nowCon !== isCon) {
                        isCon = nowCon;
                        dbg.Inf('KNX bridge: KNX interface ' + (isCon ? 'CONNECTED' : 'DISCONNECTED') + '.');
                        // On (re)connect, pull fresh state from the bus.
                        if (isCon && brdgClnt && brdgClnt.connected) {
                            brdgClnt.publish(KNX_TPCS.SYNC, '{}', { qos: 1 });
                        }
                    }
                }
            });

            brdgClnt.on('error', (err) => {
                const now = Date.now();
                if (now - lstErrLog > 60000) {
                    let m = (err && err.message) ? err.message : '';
                    if (!m || err.name === 'AggregateError') {
                        m = 'broker unreachable at ' + BRKURI + ' - retrying in background.';
                    }
                    dbg.Wrn('KNX bridge: ' + m);
                    lstErrLog = now;
                }
                settle(false);
            });

            brdgClnt.on('close', () => {
                // The MQTT link to Python dropped; KNX writes can't reach the bus.
                isCon = false;
                if (wasCntd) {
                    dbg.Inf('KNX bridge: disconnected from broker.');
                    wasCntd = false;
                }
                settle(false);
            });
        });
    };

    global.discntKnxBridge = () => {
        return new Promise((resolve) => {
            if (brdgClnt) {
                brdgClnt.end(false, () => {
                    dbg.Inf('KNX bridge: disconnected gracefully.');
                    isCon = false;
                    resolve(true);
                });
            } else {
                resolve(true);
            }
        });
    };
})();
