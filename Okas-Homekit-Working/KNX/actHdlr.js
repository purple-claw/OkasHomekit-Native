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
                    // Turning the HVAC back on without a mode set would leave
                    // the relay latched but no Cool/Heat/Auto command on the
                    // bus, so the unit never actually runs. Re-apply the last
                    // known mode (falling back to COOL) so the AC starts
                    // running immediately when toggled on via the Fanv2.On
                    // tile or the mobile app.
                    const resumeMode = knxLod[lNm].Val.Tmc || 1; // 1 = COOL
                    dbg.Inf(`HVAC toggle-on without mode - resuming ${resumeMode}`);
                    await knxCmd(lNm, 'Tmc', resumeMode);
                    knxLod[lNm].Val.Tmc = resumeMode;
                    knxLod[lNm].Val.Tmv = resumeMode;
                }
            }
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
            // Straight 0..255 pass-through. The old "1-5 scale" auto-detect
            // corrupted real low speeds: dragging a slider to 1-5% produced
            // 153-255 on the bus (1-5 mapped to /5*255), so the fan snapped
            // high whenever the user aimed low.
            let fnSpd = Math.min(255, Math.max(0, Number(val) || 0));
            // Speed writes do not latch the relay on KNX fan coils. Manage
            // the edge here (speed>0 => on, 0 => off) so the app can send
            // fSp alone — the same pattern as bri for dimmers — instead of
            // re-sending swt on every slider tick.
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
            // Convert string mode to numeric if needed. Values follow the
            // HomeKit TargetHeatingCoolingState enum so the bus representation
            // matches what HomeKit writes back: 0=OFF, 1=HEAT, 2=COOL, 3=AUTO.
            // (DRY has no HomeKit equivalent, so we keep the bus at COOL.)
            if (typeof val === 'string') {
                const modeMap = { 'cool': 2, 'heat': 1, 'auto': 3, 'dry': 2 };
                val = modeMap[val.toLowerCase()] ?? 2;
            }
            // HomeKit TargetHeatingCoolingState: 0=OFF, 1=COOL, 2=HEAT, 3=AUTO
            // When OFF is selected, also turn off the HVAC switch
            if (val === 0) {
                dbg.Inf(`HVAC OFF mode - turning off ${lNm}`);
                await Swt(lNm, 0);
                // Update state
                knxLod[lNm].Val.Tmc = 0;
                knxLod[lNm].Val.Tmv = 0;
            } else {
                // Picking a Cool/Heat/Auto mode implicitly means "turn the AC
                // on". Without this Swt(lNm, 1) call the Tmc write would
                // change the bus mode but leave the relay off, so the AC
                // never actually starts — HomeKit shows the mode change but
                // the unit stays off (and the mobile app sees isOn=false).
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
        // Use the value the caller (mobile app / HomeKit) passed in.
        // Previously this line overwrote it with the cached Val.Scn which
        // is 0 for every scene that was never triggered — so every scene
        // write sent 0 to DPT17.001 and failed serialization. Fall back
        // to the cached value only when the caller didn't supply one.
        if (val === undefined || val === null) {
            val = knxLod[lNm].Val.Scn;
        }
        dbg.Inf(`Scene Trigger: ${lNm} called with value: ${val}`);
        try {
            // xknx DPTSceneNumber (17.001) accepts 1-based scene numbers
            // (1-64) and encodes the raw bus byte as value-1 internally.
            // Send the 1-based value straight through — do NOT subtract 1
            // here (that double-decoding produced an out-of-range write).
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
