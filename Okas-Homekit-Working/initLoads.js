
let isPrep = false;

// Build the in-memory load model (knxLod). No KNX Datapoint objects are
    // created here anymore — the Python xknx bridge owns all bus I/O. 

(module.exports = () => {
    prepLoads = async () => {
        return new Promise((r) => {
            ldArr.forEach((v, i) => {
                if (i === 0) return;
                knxLod[v.Nm] = {};
                knxLod[v.Nm].Typ = v.Typ;
                knxLod[v.Nm].GA = v.GA || {};
                knxLod[v.Nm].Val = {};
                for (k in v.GA) {
                    switch (k) {
                        case 'Swt':
                        case 'Bri':
                        case 'Clc':
                        case 'Tuc':
                        case 'Tsp': // Still to work on this::
                        case 'Fsc':
                        case 'Tmc':
                        case 'Scn':
                        case 'Mov':
                        case 'Stp':
                        case 'Pos':
                            knxLod[v.Nm].Val[k] = (k == 'Tsp') ? v.Tmn : 0;
                            isPrep = true;
                            break;
                        case 'Sta':
                        case 'Bvi':
                        case 'Clv':
                        case 'Tuv':
                        case 'Trm':
                        case 'Fsv':
                        case 'Tmv':
                        case 'Mvi':
                        case 'Pvi':
                            knxLod[v.Nm].Val[k] = (k == 'Tuv') ? 260 : (k == 'Trm') ? v.Tmn : 0;
                            isPrep = true;
                            break;
                    }
                };
                switch (v.Typ) {
                    case 'RGB':
                        knxLod[v.Nm].Val.Hue = 0;
                        knxLod[v.Nm].Val.Sat = 0;
                        break;
                    case 'Scene':
                        knxLod[v.Nm].Val.Scn = v.Scn;
                        break;
                };
            });
            if (isPrep) {
                r(true);
            } else {
                dbg.Wrn("Unable to prepare Loads. Verify your Load configuration.");
                r(false);
            }
        });
    }
})();
