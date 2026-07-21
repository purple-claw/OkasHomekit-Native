// KNX feedback handler — apply bus state to HomeKit.
//
// The Python xknx bridge decodes bus telegrams and forwards { ga, val } over
// MQTT (okas/knx/state). knxBridge.js hands each one to applyKnxState() here,
// which updates the matching HomeKit characteristic, refreshes the cached value,
// and echoes status to the mobile-app MQTT API. `val` is already a decoded
// primitive (bool / number / {red,green,blue}) — no buffer decoding needed.

require('../Mqtt/mqttClnt');

(module.exports = () => {

    const getCctRangeMiredByName = (loadName) => {
        const acy = (ldArr || []).find((v, i) => i > 0 && v.Nm === loadName) || {};
        let kMin = Number(acy.Kmn);
        let kMax = Number(acy.Kmx);
        if (!Number.isFinite(kMin) || kMin <= 0) kMin = 2000;
        if (!Number.isFinite(kMax) || kMax <= 0) kMax = 6500;
        if (kMax < kMin) {
            const temp = kMin;
            kMin = kMax;
            kMax = temp;
        }
        return {
            miredMin: Math.floor(1000000 / kMax),
            miredMax: Math.floor(1000000 / kMin)
        };
    };

    const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

    const mqttRptSts = (lNm) => {
        if (typeof isMqttCntd === 'undefined' || !isMqttCntd) return;
        try {
            let tpc = stsTpc(lNm);
            if (!tpc) return;
            let typAbr = TYP_ABR[knxLod[lNm]?.Typ] || 'unk';
            mqttPub(tpc, {
                typ: typAbr,
                sta: gtLdSt(lNm),
                ts: Date.now()
            }, true);
        } catch (e) {
            dbg.Err('MQTT: Error publishing KNX status - ' + e.message);
        }
    };

    // Feedback from the KNX bus (relayed by the Python bridge).
    global.applyKnxState = async (ga, val) => {
        try {
            if (ga === undefined || val === undefined || !(ga in ga2Ld)) return;
            let [lNm, lTp] = ga2Ld[ga];

            // Only status/feedback datapoints drive HomeKit updates.
            if (!['Sta', 'Bvi', 'Clv', 'Tuv', 'Trm', 'Fsv', 'Tmv', 'Mvi', 'Pvi'].includes(lTp)) {
                return;
            }

            let hkSvc = hkbAcc[lNm] && hkbAcc[lNm][0];
            if (!hkSvc) {
                dbg.Wrn(`KNX event for '${lNm}' ignored - HomeKit accessory not ready.`);
                return;
            }

            switch (lTp) {
                case 'Sta':
                    try {
                        hkSvc.updateCharacteristic(Characteristic.On, val);
                    } catch (e) {
                        dbg.Inf(`Unable to update Status, due to error: ${o2S(e)}`);
                    }
                    knxLod[lNm].Val[lTp] = val;
                    dbg.Inf(`${lNm} is Turned-${val ? 'On' : 'Off'}.`);
                    break;
                case 'Bvi':
                    hkSvc.updateCharacteristic(Characteristic.Brightness, val);
                    knxLod[lNm].Val[lTp] = val;
                    dbg.Inf(`${lNm}'s Brightness is set to ${val}%.`);
                    break;
                case 'Clv':
                    var cArr = await rgb2HSV(val.red, val.green, val.blue);
                    knxLod[lNm].Val.Hue = cArr[0];
                    knxLod[lNm].Val.Sat = cArr[1];
                    knxLod[lNm].Val.Bri = cArr[2];
                    hkSvc.updateCharacteristic(Characteristic.Hue, cArr[0]);
                    hkSvc.updateCharacteristic(Characteristic.Saturation, cArr[1]);
                    hkSvc.updateCharacteristic(Characteristic.Brightness, cArr[2]);
                    dbg.Inf(`${lNm}'s Color is set to ${o2S(val)}.`);
                    break;
                case 'Trm':
                    hkSvc.updateCharacteristic(Characteristic.CurrentTemperature, val);
                    knxLod[lNm].Val[lTp] = val;
                    dbg.Inf(`${lNm}'s Room Temperature is set to ${val}°C.`);
                    break;
                case 'Fsv':
                    hkSvc.updateCharacteristic(Characteristic.RotationSpeed, val);
                    knxLod[lNm].Val[lTp] = val;
                    dbg.Inf(`${lNm}'s Speed is set to ${val}.`);
                    break;
                case 'Tmv':
                    hkSvc.updateCharacteristic(Characteristic.CurrentHeatingCoolingState, val);
                    knxLod[lNm].Val[lTp] = val;
                    dbg.Inf(`${lNm}'s Mode is set to ${["OFF", "HEAT", "COOL", "AUTO"][val]}.`);
                    break;
                case 'Mvi':
                    break;
                case 'Pvi':
                    hkSvc.updateCharacteristic(Characteristic.CurrentPosition, val);
                    knxLod[lNm].Val[lTp] = val;
                    dbg.Inf(`${lNm}'s Position is set to ${val}%.`);
                    break;
                case 'Tuv':
                    dbg.Inf(`${lNm}'s Color Temperature is set to ${val} Kelvin.`);
                    val = Number(val);
                    if (!Number.isFinite(val) || val <= 0) {
                        dbg.Wrn(`${lNm} reported invalid Color Temperature '${val}'. Ignoring update.`);
                        break;
                    }
                    const cctRange = getCctRangeMiredByName(lNm);
                    val = clamp(Math.floor(1000000 / val), cctRange.miredMin, cctRange.miredMax);
                    hkSvc.updateCharacteristic(Characteristic.ColorTemperature, val);
                    knxLod[lNm].Val[lTp] = val;
                    break;
            }

            if (lTp !== 'Mvi') {
                mqttRptSts(lNm);
            }
        } catch (e) {
            // Never let a single bad event crash the service.
            dbg.Err(`applyKnxState error on GA ${ga}: ${(e && e.message) ? e.message : e}`);
        }
    };
})();
