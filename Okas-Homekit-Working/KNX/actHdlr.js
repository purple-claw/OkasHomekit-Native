// HomeKit / mobile commands -> KNX writes via the Python bridge; API shape unchanged.

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
            if (val === 0 && ['Dimmer', 'RGB', 'Tunable'].includes(knxLod[lNm].Typ)) {
                knxLod[lNm].Val.Bri = 0;
                knxLod[lNm].Val.Bvi = 0;
            }
            if (knxLod[lNm].Typ === 'HVAC') {
                if (val === 0) {
                    // For HVAC, turning off also clears the mode to 0 (OFF).
                    knxLod[lNm].Val.Tmc = 0;
                    knxLod[lNm].Val.Tmv = 0;
                } else if (knxLod[lNm].Val.Tmc === 0) {
                    // Powering HVAC on without a mode leaves the relay latched and nothing running — re-apply the last mode.
                    const resumeMode = knxLod[lNm].Val.Tmc || 1; // 1 = COOL
                    dbg.Inf(`HVAC toggle-on without mode - resuming ${resumeMode}`);
                    await knxCmd(lNm, 'Tmc', resumeMode);
                    knxLod[lNm].Val.Tmc = resumeMode;
                    knxLod[lNm].Val.Tmv = resumeMode;
                }
            }
            dbg.Inf(`Turn-${val ? 'On' : 'Off'} sent to ${lNm}.`);
            // Push to HomeKit + MQTT now; many KNX devices can't be bothered to echo status.
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
            // Kelvin->mired for HomeKit; cache it too, in case the bus stays silent.
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
            // Real 0..255 pass-through; the old 1-5 "auto-detect" turned a 5% slider into 255 bus.
            let fnSpd = Math.min(255, Math.max(0, Number(val) || 0));
            // Fan coils don't latch on speed writes; manage the edge here (speed>0 => on).
            if (fnSpd > 0 && !knxLod[lNm].Val.Sta) {
                const onRes = await Swt(lNm, 1);
                if (!onRes.ok) return onRes;
            } else if (fnSpd <= 0 && knxLod[lNm].Val.Sta) {
                const offRes = await Swt(lNm, 0);
                if (!offRes.ok) return offRes;
            }
            let res = knxCmd(lNm, 'Fsc', fnSpd);
            if (!res.ok) {
                dbg.Err(`Unable to send Fan Speed command to ${lNm}: ${res.err}.`);
                return res;
            }
            // Store in both Fsv and Fsc for consistency with status reporting
            knxLod[lNm].Val.Fsv = fnSpd;
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
            // Mode strings -> HomeKit enum numbers, so the bus matches what iOS wrote back (DRY stays COOL).
            if (typeof val === 'string') {
                const modeMap = { 'cool': 2, 'heat': 1, 'auto': 3, 'dry': 2 };
                val = modeMap[val.toLowerCase()] ?? 2;
            }
            // HomeKit modes 0=OFF,1=COOL,2=HEAT,3=AUTO; OFF also kills the HVAC switch.
            if (val === 0) {
                dbg.Inf(`HVAC OFF mode - turning off ${lNm}`);
                await Swt(lNm, 0);
                // Update state
                knxLod[lNm].Val.Tmc = 0;
                knxLod[lNm].Val.Tmv = 0;
            } else {
                // A mode implies "the AC is on"; otherwise you changed the mode of a corpse.
                const wasOff = !knxLod[lNm].Val.Sta;
                if (wasOff) {
                    dbg.Inf(`HVAC mode ${val} - turning on ${lNm} relay`);
                    await Swt(lNm, 1);
                }
                let res = knxCmd(lNm, 'Tmc', val);
                if (!res.ok) {
                    dbg.Err(`Unable to send Temperature Mode command to ${lNm}: ${res.err}.`);
                    return res;
                }
                knxLod[lNm].Val.Tmc = val;
                knxLod[lNm].Val.Tmv = val;
                let mode = ["OFF", "HEAT", "COOL", "AUTO"][val];
                dbg.Inf(`Temperature Mode-${mode} sent to ${lNm}.`);
            }
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
        // Caller's value wins; the cached Scn is 0 until triggered, and anything sent as 0 fails DPT17.001.
        if (val === undefined || val === null) {
            val = knxLod[lNm].Val.Scn;
        }
        dbg.Inf(`Scene Trigger: ${lNm} called with value: ${val}`);
        try {
            // DPT17.001 is 1-based; send as-is — subtracting again double-decodes into out-of-range.
            const busVal = Number(val);
            if (!Number.isFinite(busVal) || busVal < 1 || busVal > 64) {
                dbg.Err(`Scene ${lNm}: value ${val} out of range (1-64).`);
                return { ok: false, err: `Scene number out of range (1-64): ${val}` };
            }
            let res = knxCmd(lNm, 'Scn', busVal);
            if (!res.ok) {
                dbg.Err(`Unable to send Trigger Scene ${lNm} command: ${res.err}.`);
                return res;
            }
            knxLod[lNm].Val.Scn = busVal;
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
        // KNX 1.008: 1 = Up/Open, 0 = Down/Close.
        try {
            let res = knxCmd(lNm, 'Mov', val);
            if (!res.ok) return res;
            knxLod[lNm].Val.Mov = val;
            knxLod[lNm].Val.Mvi = val;
            dbg.Inf(`Curtain ${val ? 'Open' : 'Close'} sent to ${lNm}.`);
            if (typeof global.mqttRptSts === 'function') {
                global.mqttRptSts(lNm);
            }
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send Curtain Movement command to ${lNm} : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

    Stp = async (lNm) => {
        try {
            let res = knxCmd(lNm, 'Stp', 1);
            if (!res.ok) return res;
            dbg.Inf(`Curtain Stop sent to ${lNm}.`);
            if (typeof global.mqttRptSts === 'function') {
                global.mqttRptSts(lNm);
            }
            return { ok: true };
        } catch (e) {
            dbg.Err(`Unable to send Curtain Stop command to ${lNm} : ${e}.`);
            return { ok: false, err: e.message };
        }
    };

    Pos = async (lNm, val) => {
        try {
            if (!knxLod[lNm].GA.Pos) {
                return { ok: false, err: 'No position control (Pos) configured for this curtain' };
            }
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
