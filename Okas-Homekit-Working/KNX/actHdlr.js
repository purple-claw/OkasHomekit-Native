// KNX action handlers — HomeKit / mobile commands -> KNX write commands.
//
// Previously these wrote directly to `knx` Datapoint objects. Now they publish
// to the Python xknx bridge via knxCmd() (KNX/knxBridge.js). Signatures and the
// { ok, err } return shape are unchanged, so HkB.js and Mqtt/mqttClnt.js keep
// working without modification. Cached values in knxLod[lNm].Val are still
// updated optimistically; the authoritative state arrives back as bus feedback.

require('./knxBridge');

(module.exports = () => {
    let rgbTmr = null;

    sndRGB = (lNm, p, v) => {
        return new Promise((resolve) => {
            if (rgbTmr) clearTimeout(rgbTmr);
            knxLod[lNm].Val[p] = v;
            rgbTmr = setTimeout(async () => {
                try {
                    let rgb = await hsv2RGB(
                        knxLod[lNm].Val.Hue, knxLod[lNm].Val.Sat, knxLod[lNm].Val.Bri
                    );
                    let res = knxCmd(lNm, 'Clc', rgb);
                    if (!res.ok) {
                        dbg.Err(`Unable to send RGB command to ${lNm}: ${res.err}.`);
                        rgbTmr = null;
                        resolve(res);
                        return;
                    }
                    dbg.Inf(`${o2S(rgb)} sent to ${lNm}.`);
                    // Push RGB state to HomeKit immediately
                    const hkSvc = hkbAcc[lNm] && hkbAcc[lNm][0];
                    if (hkSvc) {
                        try {
                            hkSvc.updateCharacteristic(Characteristic.Hue, knxLod[lNm].Val.Hue);
                            hkSvc.updateCharacteristic(Characteristic.Saturation, knxLod[lNm].Val.Sat);
                            hkSvc.updateCharacteristic(Characteristic.Brightness, knxLod[lNm].Val.Bri);
                        } catch (e) {
                            dbg.Inf(`Unable to update HomeKit RGB for ${lNm}: ${o2S(e)}`);
                        }
                    }
                    if (typeof global.mqttRptSts === 'function') {
                        global.mqttRptSts(lNm);
                    }
                    rgbTmr = null;
                    resolve({ ok: true });
                } catch (e) {
                    dbg.Err(`Unable to send RGB command to ${lNm} : ${e}.`);
                    rgbTmr = null;
                    resolve({ ok: false, err: e.message });
                }
            }, 100);
        });
    };

    Swt = async (lNm, val) => {
        val = knxLod[lNm].Typ == 'Fan' ? val == 1 : val;
        try {
            let res = knxCmd(lNm, 'Swt', val);
            if (!res.ok) {
                dbg.Err(`Unable to send 'On/Off' command to ${lNm}: ${res.err}.`);
                return res;
            }
            knxLod[lNm].Val.Swt = val;
            knxLod[lNm].Val.Sta = val;
            dbg.Inf(`Turn-${val ? 'On' : 'Off'} sent to ${lNm}.`);
            // Push state to HomeKit + MQTT immediately so the Home app and
            // mobile app see it without waiting for bus feedback (many KNX
            // devices do not echo status telegrams).
            const hkSvc = hkbAcc[lNm] && hkbAcc[lNm][0];
            if (hkSvc) {
                try {
                    hkSvc.updateCharacteristic(Characteristic.On, val);
                } catch (e) {
                    dbg.Inf(`Unable to update HomeKit On for ${lNm}: ${o2S(e)}`);
                }
            }
            if (typeof global.mqttRptSts === 'function') {
                global.mqttRptSts(lNm);
            }
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send 'On/Off' command to ${lNm} : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

    Bri = async (lNm, val) => {
        try {
            let res = knxCmd(lNm, 'Bri', val);
            if (!res.ok) {
                dbg.Err(`Unable to send Brightness command to ${lNm}: ${res.err}.`);
                return res;
            }
            knxLod[lNm].Val.Bri = val;
            knxLod[lNm].Val.Bvi = val;
            dbg.Inf(`Brightness-${val}% sent to ${lNm}.`);
            // Push brightness to HomeKit + MQTT immediately
            const hkSvc = hkbAcc[lNm] && hkbAcc[lNm][0];
            if (hkSvc) {
                try {
                    hkSvc.updateCharacteristic(Characteristic.Brightness, val);
                } catch (e) {
                    dbg.Inf(`Unable to update HomeKit Brightness for ${lNm}: ${o2S(e)}`);
                }
            }
            if (typeof global.mqttRptSts === 'function') {
                global.mqttRptSts(lNm);
            }
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send Brightness command to ${lNm} : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

    Hue = async (lNm, val) => {
        return await sndRGB(lNm, 'Hue', val);
    };

    Sat = async (lNm, val) => {
        return await sndRGB(lNm, 'Sat', val);
    };

    Tun = async (lNm, val) => {
        try {
            let res = knxCmd(lNm, 'Tuc', val);
            if (!res.ok) {
                dbg.Err(`Unable to send Color Temperature command to ${lNm}: ${res.err}.`);
                return res;
            }
            knxLod[lNm].Val.Tuc = val;
            dbg.Inf(`Color Temperature-${val}K sent to ${lNm}.`);
            // Convert Kelvin to Mired for HomeKit and push immediately.
            // Also update knxLod.Tuv so the get callback returns the right
            // value even if no bus feedback arrives.
            const safeKel = Number(val) > 0 ? Number(val) : 2000;
            const miredVal = Math.floor(1000000 / safeKel);
            knxLod[lNm].Val.Tuv = miredVal;
            const hkSvc = hkbAcc[lNm] && hkbAcc[lNm][0];
            if (hkSvc) {
                try {
                    hkSvc.updateCharacteristic(Characteristic.ColorTemperature, miredVal);
                } catch (e) {
                    dbg.Inf(`Unable to update HomeKit CCT for ${lNm}: ${o2S(e)}`);
                }
            }
            if (typeof global.mqttRptSts === 'function') {
                global.mqttRptSts(lNm);
            }
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send Color Temperature command to ${lNm} : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

    Tsp = async (lNm, val) => {
        try {
            let res = knxCmd(lNm, 'Tsp', val);
            if (!res.ok) {
                dbg.Err(`Unable to send Setpoint Temperature command to ${lNm}: ${res.err}.`);
                return res;
            }
            knxLod[lNm].Val.Tsp = val;
            dbg.Inf(`Setpoint Temperature-${val}°C sent to ${lNm}.`);
            // Push target temperature to HomeKit + MQTT immediately
            const hkSvc = hkbAcc[lNm] && hkbAcc[lNm][0];
            if (hkSvc) {
                try {
                    hkSvc.updateCharacteristic(Characteristic.TargetTemperature, val);
                } catch (e) {
                    dbg.Inf(`Unable to update HomeKit target temp for ${lNm}: ${o2S(e)}`);
                }
            }
            if (typeof global.mqttRptSts === 'function') {
                global.mqttRptSts(lNm);
            }
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send Setpoint Temperature command to ${lNm} : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

    Fsp = async (lNm, val) => {
        try {
            const fnSpd = Math.min(255, Math.max(0, Math.round(Number(val))));
            let res = knxCmd(lNm, 'Fsc', fnSpd);
            if (!res.ok) {
                dbg.Err(`Unable to send Fan Speed command to ${lNm}: ${res.err}.`);
                return res;
            }
            knxLod[lNm].Val.Fsc = fnSpd;
            dbg.Inf(`Fan Speed-${fnSpd} sent to ${lNm}.`);
            // Push fan speed to HomeKit + MQTT immediately
            const hkSvc = hkbAcc[lNm] && hkbAcc[lNm][0];
            if (hkSvc) {
                try {
                    hkSvc.updateCharacteristic(Characteristic.RotationSpeed, fnSpd);
                } catch (e) {
                    dbg.Inf(`Unable to update HomeKit fan speed for ${lNm}: ${o2S(e)}`);
                }
            }
            if (typeof global.mqttRptSts === 'function') {
                global.mqttRptSts(lNm);
            }
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send Fan Speed command to ${lNm} : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

    Tmd = async (lNm, val) => {
        try {
            let res = knxCmd(lNm, 'Tmc', val);
            if (!res.ok) {
                dbg.Err(`Unable to send Temperature Mode command to ${lNm}: ${res.err}.`);
                return res;
            }
            knxLod[lNm].Val.Tmc = val;
            let mode = ["OFF", "HEAT", "COOL", "AUTO"][val];
            dbg.Inf(`Temperature Mode-${mode} sent to ${lNm}.`);
            // Push mode to HomeKit + MQTT immediately
            const hkSvc = hkbAcc[lNm] && hkbAcc[lNm][0];
            if (hkSvc) {
                try {
                    hkSvc.updateCharacteristic(Characteristic.TargetHeatingCoolingState, val);
                } catch (e) {
                    dbg.Inf(`Unable to update HomeKit mode for ${lNm}: ${o2S(e)}`);
                }
            }
            if (typeof global.mqttRptSts === 'function') {
                global.mqttRptSts(lNm);
            }
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send Temperature Mode command to ${lNm} : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

    Scn = async (lNm, val) => {
        val = knxLod[lNm].Val.Scn;
        dbg.Inf(`Scene Trigger: ${lNm} called with value: ${val}`);
        try {
            // Python encodes DPT17.001 as (scene number - 1) on the wire, matching
            // the previous behaviour. Send the 1-based scene number.
            let res = knxCmd(lNm, 'Scn', val);
            if (!res.ok) {
                dbg.Err(`Unable to send Trigger Scene ${lNm} command: ${res.err}.`);
                return res;
            }
            dbg.Inf(`Trigger Scene-${val} sent to ${lNm}.`);
            let hkSvc = hkbAcc[lNm][0];
            hkSvc.updateCharacteristic(Characteristic.On, false);
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send Trigger Scene ${lNm} command : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

    Mov = async (lNm, val) => {
        return { ok: false, err: 'Curtain movement not Yet supported.' };
    };

    Pos = async (lNm, val) => {
        try {
            let res = knxCmd(lNm, 'Pos', val);
            if (!res.ok) {
                dbg.Err(`Unable to send Curtain Position command to ${lNm}: ${res.err}.`);
                return res;
            }
            knxLod[lNm].Val.Pos = val;
            dbg.Inf(`Position-${val} sent to ${lNm}.`);
            // Push target position to HomeKit + MQTT immediately
            const hkSvc = hkbAcc[lNm] && hkbAcc[lNm][0];
            if (hkSvc) {
                try {
                    hkSvc.updateCharacteristic(Characteristic.TargetPosition, val);
                } catch (e) {
                    dbg.Inf(`Unable to update HomeKit position for ${lNm}: ${o2S(e)}`);
                }
            }
            if (typeof global.mqttRptSts === 'function') {
                global.mqttRptSts(lNm);
            }
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send Curtain Position command to ${lNm} : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

})();
