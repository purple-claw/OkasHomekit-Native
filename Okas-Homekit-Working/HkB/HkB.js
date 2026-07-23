
require('./pinGen');
const fs = require('fs');
const path = require('path');


(module.exports = async () => {
    hap = require('hap-nodejs');
    Bridge = hap.Bridge;
    uuid = hap.uuid;
    Accessory = hap.Accessory;
    Service = hap.Service;
    Categories = hap.Categories;
    Characteristic = hap.Characteristic;
    Formats = hap.Formats;
    Units = hap.Units;
    Perms = hap.Perms;

    const prstPth = path.join(__dirname, '../persist');
    let clntCnctd = false;
    let cnWdg = null;
    const WD_TOUT = 90000; 

    const rmFldr = async () => {
        return new Promise((resolve) => {
            if (fs.existsSync(prstPth)) {
                fs.rmSync(prstPth, { recursive: true, force: true });
                dbg.Inf('Persist folder cleared - pairing data reset.');
            }
            resolve(true);
        });
    };

    const hsPrngs = () => { // Check if device has existing pairings
        try {
            const fls = fs.readdirSync(prstPth).filter(f => f.startsWith('AccessoryInfo'));
            for (const file of fls) {
                const data = JSON.parse(fs.readFileSync(path.join(prstPth, file), 'utf8'));
                if (data.pairedClients && Object.keys(data.pairedClients).length > 0) {
                    return true;
                }
            }
        } catch (e) {
            // No persist folder or files
        }
        return false;
    };

    const startcnWdg = () => {
        if (!hsPrngs()) {
            dbg.Inf('No existing pairings - ready for new pairing.');
            return;
        }
        dbg.Inf(`Existing pairing found. Keeping bridge published - waiting for clients to connect...`);
        cnWdg = setTimeout(async () => {
            if (!clntCnctd) {
                dbg.Inf('No client connected yet - bridge remains published for pairing. Clients can connect anytime.');
            }
        }, WD_TOUT);
    };

    // Function to save PIN code and auth token to loadData.json
    const saveAuthToConfig = async (pinCode, authToken) => {
        return new Promise((resolve, reject) => {
            try {
                const ldDtaPth = path.join(__dirname, '../Data/loadData.json');

                let loadData = [];
                if (fs.existsSync(ldDtaPth)) {
                    const fileContent = fs.readFileSync(ldDtaPth, 'utf8');
                    loadData = JSON.parse(fileContent);
                }

                if (loadData.length > 0 && loadData[0]) {
                    if (loadData[0].pinCode && loadData[0].pinCode !== pinCode) {
                        dbg.Inf('PIN code changed - clearing old pairing data...');
                        rmFldr();
                    }
                    loadData[0].pinCode = pinCode;
                    loadData[0].authToken = authToken;
                } else {
                    rmFldr();
                    loadData[0] = { pinCode, authToken };
                }

                fs.writeFileSync(ldDtaPth, JSON.stringify(loadData, null, 2));
                dbg.Inf(`Auth saved to loadData.json: PIN=${pinCode}, Token=${authToken}`);
                resolve(true);
            } catch (error) {
                dbg.Err(`Error saving auth data: ${error.message}`);
                reject(error);
            }
        });
    };

    const gtCctRngMird = (acy) => {
        let kMin = Number(acy.Kmn);
        let kMax = Number(acy.Kmx);
        if (!Number.isFinite(kMin) || kMin <= 0) kMin = 2000;
        if (!Number.isFinite(kMax) || kMax <= 0) kMax = 6500;
        if (kMax < kMin) {
            const temp = kMin;
            kMin = kMax;
            kMax = temp;
        }
        const mrdMn = Math.floor(1000000 / kMax);
        const mrdMx = Math.floor(1000000 / kMin);
        return { kMin, kMax, mrdMn, mrdMx };
    };

    const clmpNum = (value, min, max) => {
        if (!Number.isFinite(value)) return min;
        return Math.min(max, Math.max(min, value));
    };

    pubBRG = async () => { // Publish Bridge::
        return new Promise(async (r) => {
            PINcode = getPC((ldArr[0].prjNm).replace(/[^a-zA-Z0-9]/g, '').toUpperCase());
            PINcode = `${PINcode.slice(0, 3)}-${PINcode.slice(3, 5)}-${PINcode.slice(5)}`;
            let mac = ((ldArr[0].mac).replace(":", "").toUpperCase()).substr(-6);

            const AUTH_TOKEN = genAuthToken(ldArr[0].mac);
            ldArr[0].authToken = AUTH_TOKEN;

            bridge
                .getService(Service.AccessoryInformation)
                .setCharacteristic(Characteristic.Manufacturer, 'Vyom.ai')
                .setCharacteristic(Characteristic.Model, 'OKAS HomeKit')
                .setCharacteristic(Characteristic.FirmwareRevision, '1.0.0')
                .setCharacteristic(Characteristic.SerialNumber, (`OhKnx-${ldArr[0].mac}`));

            // Save PIN code and auth token to loadData.json
            saveAuthToConfig(PINcode, AUTH_TOKEN).then(() => {
                dbg.Inf('Auth data saved to loadData.json');
            }).catch((error) => {
                dbg.Err('Failed to save auth data:', error);
            });

            bridge.on('advertised', () => {
                dbg.Inf('HomeKit bridge advertised on network.');
            });

            bridge.on('paired', () => {
                dbg.Inf('HomeKit device successfully paired!');
                clntCnctd = true;
                if (cnWdg) {
                    clearTimeout(cnWdg);
                    cnWdg = null;
                }
            });

            bridge.on('unpaired', async () => {
                dbg.Inf('HomeKit device unpaired - auto-clearing pairing data...');
                clntCnctd = false;
                await rmFldr();
                dbg.Inf('Pairing data cleared. Ready for new pairing.');
            });

            bridge.on('characteristic-warning', () => {
                clntCnctd = true;
                if (cnWdg) {
                    clearTimeout(cnWdg);
                    cnWdg = null;
                }
            });

            bridge.publish({
                username: ldArr[0].mac,
                pincode: PINcode,
                port: 62648,
                category: Categories.BRIDGE,
            });
            
            dbg.Inf('Accessory is running... with PIN: ' + PINcode);
            
            // Start connection watchdog to detect stale pairings
            startcnWdg();
            
            r(true);
        });
    }

    bldAcc = async () => { // Build Accesories::
        bridge = new Bridge(ldArr[0].prjNm, uuid.generate('YesUsWe' + ldArr[0].prjNm)); // Create New Bridge.
        return new Promise(async (r) => {
            ldArr.forEach((acy, ai) => {
                if (ai == 0) {
                    return;
                };
                let aUUID = uuid.generate(ai + " " + acy.Nm);
                let Acc = new Accessory(acy.Nm, aUUID); // Create New Accessory
                acy.uid = aUUID;
                let isCar = false;
                hkbAcc[acy.Nm] = [];
                lT2Cat[acy.Typ].forEach((srv, si) => { // Add Services to Accessory
                    let Svc;
                    let sUID = (si + " " + acy.Nm);
                    switch (srv.Cat) {
                        case "Lgt":
                            Acc.addService(Service.Lightbulb, sUID);
                            Svc = Acc.getService(Service.Lightbulb);
                            break;
                        case "Switch":
                            Acc.addService(Service.Switch, sUID);
                            Svc = Acc.getService(Service.Switch);
                            break;
                        case "Cur":
                            Acc.addService(Service.WindowCovering, sUID);
                            Svc = Acc.getService(Service.WindowCovering);
                            break;
                        case "Fan":
                            Acc.addService(Service.Fan, sUID);
                            Svc = Acc.getService(Service.Fan);
                            break;
                        case "AC":
                            Acc.addService(Service.Thermostat, sUID);
                            Svc = Acc.getService(Service.Thermostat);
                            break;
                        case "Scn":
                            Acc.addService(Service.StatelessProgrammableSwitch, sUID);
                            Svc = Acc.getService(Service.StatelessProgrammableSwitch);
                            break;
                    }
                    if (!Svc) {
                        console.log('No Service Declared. Aborting Process!');
                        return;
                    };
                    srv.Chr.forEach((chr, ci) => { // Add Characteristics to Service(s)
                        isCar = false;
                        switch (chr) {
                            case 1: // On
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.On)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Sta;
                                        callback(null, rVal);
                                        //delete rVal;
                                        console.log(`Requested ${acy.Nm} Status value: ${knxLod[acy.Nm].Val.Sta}.`);
                                    })
                                    .on('set', (val, callback) => {
                                        if (['Dimmer', 'RGB', 'Tunable'].includes(acy.Typ)) {
                                            if (val) {
                                                let vl = knxLod[acy.Nm].Val.Bri > 0 ? knxLod[acy.Nm].Val.Bri : 100;
                                                Bri(acy.Nm, vl);
                                                //delete vl;
                                            } else {
                                                Swt(acy.Nm, val);
                                            };
                                        } else {
                                            Swt(acy.Nm, val);
                                        }
                                        callback(null);
                                    });
                                break;
                            case 2: // Active
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.Active)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Sta;
                                        callback(null, rVal);
                                        //delete rVal;
                                    })
                                    .on('set', (val, callback) => {
                                        Swt(acy.Nm, val);
                                        callback(null);
                                    });
                                break;
                            case 3: // Brightness
                                isCar = isCar || true;
                                Svc
                                    .addCharacteristic(Characteristic.Brightness)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Bvi;
                                        callback(null, rVal);
                                        //delete rVal;
                                        console.log(`Requested ${acy.Nm} Bri value: ${knxLod[acy.Nm].Val.Bvi}.`);
                                    })
                                    .on('set', (val, callback) => {
                                        Bri(acy.Nm, val);
                                        if (knxLod[acy.Nm].Val.Sta && acy.Typ == 'RGB') {
                                            Hue(acy.Nm, knxLod[acy.Nm].Val.Hue);
                                            Sat(acy.Nm, knxLod[acy.Nm].Val.Sat);
                                        }
                                        callback(null);
                                    });
                                break;
                            case 4: // Color Temperature
                                isCar = isCar || true;
                                const cctRng = gtCctRngMird(acy);
                                Svc
                                    .addCharacteristic(Characteristic.ColorTemperature)
                                    .setProps({
                                        minValue: cctRng.mrdMn,
                                        maxValue: cctRng.mrdMx,
                                    })
                                    .on('get', (callback) => {
                                        let rVal = Number(knxLod[acy.Nm].Val.Tuv);
                                        rVal = clmpNum(rVal, cctRng.mrdMn, cctRng.mrdMx);
                                        callback(null, rVal);
                                        //delete rVal;
                                        console.log(`Requested ${acy.Nm} CCT value: ${rVal}.`);
                                    })
                                    .on('set', (val, callback) => {
                                        const safeMired = clmpNum(Number(val), cctRng.mrdMn, cctRng.mrdMx);
                                        const kel = clmpNum(Math.floor(1000000 / safeMired), cctRng.kMin, cctRng.kMax);
                                        Tun(acy.Nm, kel);
                                        callback(null);
                                    });
                                break;
                            case 5: // Hue
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.Hue)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Hue;
                                        callback(null, rVal);
                                        console.log(`Requested ${acy.Nm} HUE value: ${rVal}.`);
                                        //delete rVal;
                                    })
                                    .on('set', (val, callback) => {
                                        console.log("HUE = " + val);
                                        Hue(acy.Nm, val);
                                        callback(null);
                                    });
                                break;
                            case 6: // Saturation
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.Saturation)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Sat || 100;
                                        callback(null, rVal);
                                        console.log(`Requested ${acy.Nm} SAT value: ${rVal}.`);
                                        //delete rVal;
                                    })
                                    .on('set', (val, callback) => {
                                        console.log("SAT = " + val);
                                        Sat(acy.Nm, val);
                                        callback(null);
                                    });
                                break;
                            case 8: // RotationSpeed
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.RotationSpeed)
                                    .setProps({
                                        minValue: 0,
                                        maxValue: acy.Smx,
                                        minStep: acy.Fst,
                                    })
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Fsv;
                                        callback(null, rVal);
                                        //delete rVal;
                                        console.log(`Requested ${acy.Nm} Rotation Spd value: ${knxLod[acy.Nm].Val.Fsv}.`);
                                    })
                                    .on('set', (val, callback) => {
                                        Fsp(acy.Nm, val);
                                        callback(null);
                                    });
                                break;
                            case 9: // Current & Target Position
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.CurrentPosition)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Pvi;
                                        callback(null, rVal);
                                        //delete rVal;
                                    });
                                Svc
                                    .getCharacteristic(Characteristic.TargetPosition)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Pos;
                                        callback(null, rVal);
                                        //delete rVal;
                                    })
                                    .on('set', (val, callback) => {
                                        Pos(acy.Nm, val);
                                        callback(null);
                                    });
                                break;
                            case 11: // PositionState
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.PositionState)
                                    .on('get', (callback) => {
                                        let rVal = "";
                                        if (knxLod[acy.Nm].Val.Pos > knxLod[acy.Nm].Val.Pvi) {
                                            rVal = Characteristic.PositionState.INCREASING;
                                        } else if (knxLod[acy.Nm].Val.Pos < knxLod[acy.Nm].Val.Pvi) {
                                            rVal = Characteristic.PositionState.DECREASING;
                                        } else {
                                            rVal = Characteristic.PositionState.STOPPED;
                                        }
                                        callback(null, rVal);
                                        //delete rVal;
                                    });
                                break;
                            case 12: // Current & Target Temperature
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.TargetTemperature) // Setpoint Temperature
                                    .setProps({
                                        minValue: acy.Tmn,
                                        maxValue: acy.Tmx,
                                        minStep: 0.5,
                                    })
                                    .on('get', (callback) => {
                                        let rVal = knxLod[acy.Nm].Val.Tsp <= acy.Tmn ? acy.Tmn : knxLod[acy.Nm].Val.Tsp;
                                        callback(null, rVal);
                                        //delete rVal;
                                    })
                                    .on('set', (val, callback) => {
                                        Tsp(acy.Nm, val);
                                        callback(null);
                                    });
                                Svc
                                    .getCharacteristic(Characteristic.CurrentTemperature) // Room Temperature
                                    .on('get', (callback) => {
                                        let rVal = knxLod[acy.Nm].Val.Trm <= acy.Tmn ? acy.Tmn : knxLod[acy.Nm].Val.Trm;
                                        callback(null, rVal);
                                        //delete rVal;
                                    });
                                break;
                            case 13: // Current & Target Heat|Cool State
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.CurrentHeatingCoolingState)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Tmv;
                                        callback(null, rVal);
                                        //delete rVal;
                                    });
                                Svc
                                    .getCharacteristic(Characteristic.TargetHeatingCoolingState)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Tmc;
                                        callback(null, rVal);
                                        //delete rVal;
                                    })
                                    .on('set', (val, callback) => {
                                        Tmd(acy.Nm, val);
                                        callback(null);
                                    });
                                break;
                            case 14: // Display Unit
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.TemperatureDisplayUnits)
                                    .on('get', (callback) => {
                                        const dUnt = Characteristic.TemperatureDisplayUnits.CELSIUS;
                                        callback(null, dUnt);
                                    })
                                    .on('set', (val, callback) => {
                                        setTimeout(() => {
                                            Svc.updateCharacteristic(Characteristic.TemperatureDisplayUnits, 0);
                                        }, 100);
                                        callback(null);
                                    });

                                const fSvc = new Service.Fanv2('Thermostat Fan');
                                fSvc
                                    .getCharacteristic(Characteristic.On)
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Sta;
                                        callback(null, rVal);
                                        //delete rVal;
                                    })
                                    .on('set', (val, callback) => {
                                        Swt(acy.Nm, val);
                                        callback(null);
                                    });
                                fSvc
                                    .getCharacteristic(Characteristic.RotationSpeed)
                                    .setProps({
                                        minValue: 0,
                                        maxValue: acy.Smx,
                                        minStep: acy.Fst,
                                    })
                                    .on('get', (callback) => {
                                        const rVal = knxLod[acy.Nm].Val.Fsv;
                                        callback(null, rVal);
                                        //delete rVal;
                                    })
                                    .on('set', (val, callback) => {
                                        Fsp(acy.Nm, val);
                                        callback(null);
                                    });
                                Svc.addLinkedService(fSvc);
                                Acc.addService(fSvc);
                                break;
                            case 15: // Cooling Threshold
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.CoolingThresholdTemperature)
                                    .setProps({
                                        minValue: acy.Tmn,
                                        maxValue: acy.Tmx,
                                        minStep: 0.5,
                                    })
                                    .on('get', (callback) => {
                                        callback(null, acy.Tmx);
                                    })
                                    .on('set', (val, callback) => {
                                        setTimeout(() => {
                                            Svc.updateCharacteristic(Characteristic.CoolingThresholdTemperature, acy.Tmx);
                                        }, 100);
                                        callback(null);
                                    });
                                break;
                            case 16: // Heating Threshold
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.HeatingThresholdTemperature)
                                    .setProps({
                                        minValue: acy.Tmn,
                                        maxValue: acy.Tmx,
                                        minStep: 0.5,
                                    })
                                    .on('get', (callback) => {
                                        callback(null, acy.Tmn);
                                    })
                                    .on('set', (val, callback) => {
                                        setTimeout(() => {
                                            Svc.updateCharacteristic(Characteristic.HeatingThresholdTemperature, acy.Tmn);
                                        }, 100);
                                        callback(null);
                                    });
                                break;
                            case 17: // On for Scene
                                isCar = isCar || true;
                                Svc
                                    .getCharacteristic(Characteristic.On)
                                    .on('get', (callback) => {
                                        callback(null, false);
                                    })
                                    .on('set', (val, callback) => {
                                        Scn(acy.Nm, val);
                                        callback(null);
                                    });
                                break; 
                            // case 17: // Scene | Trigger
                            //     isCar = isCar || true;
                            //     Svc
                            //         .getCharacteristic(Characteristic.ProgrammableSwitchEvent)
                            //         .on('change', (evt) => {
                            //             Scn(acy.Nm, evt.newValue);
                            //         });
                            //     break;
                        }
                    });
                    hkbAcc[acy.Nm].push(Svc);
                });
                if (isCar) {
                    bridge.addBridgedAccessory(Acc);
                } else {
                    console.log('Accessory ' + acy.Nm + ' not Built');
                }
            });
            r(await pubBRG());
        });
    }
})();