(module.exports = () => {
    o2S = JSON.stringify;
    s2O = JSON.parse;
    global.hkbAcc = {};
    global.knxLod = {};
    global.ldArr = [];
    global.ga2Ld = {};
    global.bridge = "";

    // Kelvin->mired, once — two files re-implementing this was two too many.
    global.cctRange = (acy) => {
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
            kMin, kMax,
            mrdMn: Math.floor(1000000 / kMax),
            mrdMx: Math.floor(1000000 / kMin)
        };
    };

    dptObj = {
        "Swt": "DPT1.001",
        "Sta": "DPT1.001",
        "Dim": "DPT3.007",
        "Bri": "DPT5.001",
        "Bvi": "DPT5.001",
        "Clc": "DPT232.600",
        "Clv": "DPT232.600",
        "Tuc": "DPT7.600",
        "Tuv": "DPT7.600",
        "Trm": "DPT9.001",
        "Tsp": "DPT9.001",
        "Fsc": "DPT5.010",
        "Fsv": "DPT5.010",
        "Thc": "DPT1.100",
        "Tmc": "DPT20.102",
        "Tmv": "DPT20.102",
        "Scn": "DPT17.001",
        "Mov": "DPT1.008",
        "Mvi": "DPT1.008",
        "Stp": "DPT1.010",
        "Pos": "DPT5.001",
        "Pvi": "DPT5.001",
        "Tim": "DPT10.001",
    }
    lT2Cat = {
        "Switch": [{
            "Cat": "Lgt",
            "Chr": [1],
            "Typ": [
                "Swt",
                "Sta"
            ]
        }],
        "Dimmer": [{
            "Cat": "Lgt",
            "Chr": [1, 3],
            "Typ": [
                "Swt",
                "Sta",
                "Dim",
                "Bri",
                "Bvi"
            ]
        }],
        "RGB": [{
            "Cat": "Lgt",
            "Chr": [1, 3, 5, 6],
            "Typ": [
                "Swt",
                "Sta",
                "Dim",
                "Bri",
                "Bvi",
                "Clc",
                "Clv",
            ]
        }],
        "Tunable": [{
            "Cat": "Lgt",
            "Chr": [1, 3, 4],
            "Typ": [
                "Swt",
                "Sta",
                "Dim",
                "Bri",
                "Bvi",
                "Tuc",
                "Tuv",
            ]
        }],
        "HVAC": [{
            "Cat": "AC",
            "Chr": [12, 13, 14], // Removed 8(Rotation Speed) 
            "Typ": [
                "Swt",
                "Sta",
                "Trm",
                "Tsp",
                "Fsc",
                "Fsv",
                "Tmc",
                "Tmv",
                "Thc",
            ]
        }],
        "Scene": [{
            "Cat": "Switch",
            "Chr": [17],
            "Typ": ["Swt"]
        }],
        "Fan": [{
            "Cat": "Fan",
            "Chr": [1, 8],
            "Typ": [
                "Swt",
                "Sta",
                "Fsc",
                "Fsv"
            ]
        }],
        "Curtain": [{
            "Cat": "Cur",
            "Chr": [9, 11],
            "Typ": [
                "Mov",
                "Mvi",
                "Stp",
                "Pos",
                "Pvi"
            ]
        }]
    }

    hsv2RGB = async (h, s, v) => {
        s /= 100;
        v /= 100;
        let c = v * s;
        let x = c * (1 - Math.abs(((h / 60) % 2) - 1));
        let m = v - c;
        let [r, g, b] = [0, 0, 0];
        if (0 <= h && h < 60) { [r, g, b] = [c, x, 0]; }
        else if (h < 120) { [r, g, b] = [x, c, 0]; }
        else if (h < 180) { [r, g, b] = [0, c, x]; }
        else if (h < 240) { [r, g, b] = [0, x, c]; }
        else if (h < 300) { [r, g, b] = [x, 0, c]; }
        else if (h < 360) { [r, g, b] = [c, 0, x]; }
        r = Math.round((r + m) * 255);
        g = Math.round((g + m) * 255);
        b = Math.round((b + m) * 255);
        return { red: r, green: g, blue: b };
    }

    rgb2HSV = async (r, g, b) => {
        r /= 255;
        g /= 255;
        b /= 255;
        const max = Math.max(r, g, b);
        const min = Math.min(r, g, b);
        const delta = max - min;
        let h = 0;
        if (delta !== 0) {
            if (max === r) {
                h = ((g - b) / delta) % 6;
            } else if (max === g) {
                h = (b - r) / delta + 2;
            } else {
                h = (r - g) / delta + 4;
            }
            h *= 60;
            if (h < 0) h += 360;
        }
        const s = max === 0 ? 0 : (delta / max) * 100;
        const v = max * 100;
        return [Math.round(h), Math.round(s), Math.round(v)];
    }

    chkFile = async () => {
        return new Promise((resolve) => {
            fs.access(lDatFile, fs.constants.F_OK, (err) => {
                if (err) {
                    dbg.Err(`Data File does NOT exist. Aborting process & Waiting for File. ${err}`);
                    ldArr = [];
                    resolve(false);
                } else {
                    dbg.Inf('Data File exists. Verifying file Content.');
                    fs.readFile(lDatFile, 'utf8', (err, data) => {
                        if (err) {
                            dbg.Err(`Error reading file: ${err}`);
                            ldArr = [];
                            resolve(false);
                        } else {
                            try {
                                ldArr = s2O(data);
                                if ((Array.isArray(ldArr)) && ldArr.length > 1) {
                                    dbg.Inf('Content exists in Data File.');
                                    resolve(true);
                                } else {
                                    dbg.Err('There is NO Content in Data File. Waiting for File content.');
                                    ldArr = [];
                                    resolve(false);
                                }
                            } catch (parseErr) {
                                dbg.Err(`Error parsing Content: ${parseErr}`);
                                ldArr = [];
                                resolve(false);
                            }
                        }
                    });
                }
            });
        });
    }

    Array.prototype.has = function (str) {
        return this.indexOf(str) >= 0;
    }

    String.prototype.toInt = function (t) {
        t = t || 10;
        return parseInt(this, t);
    }

    makLdArr = async () => {
        return new Promise((r) => {
            ldArr.forEach((v, i) => {
                if (i === 0) {
                    return;
                };
                for (k in v.GA) {
                    ga2Ld[v.GA[k]] = [v.Nm, k, dptObj[k]];
                    // ga2Ld['0/0/0'] ['Load', 'Swt', 'DPT0.000']  #NP
                }
            });
            if ((Object.keys(ga2Ld)).length >= 1) {
                r(true);
            } else {
                r(false);
            }
        });
    }
})();