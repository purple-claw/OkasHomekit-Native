(module.exports = () => {
    kIP = "";
    kPort = 3671;
    isTun = true;
    gwTyp = null;
    kHwID = '15.15.232';
    kCom = {};
    isCon = false;
    kCon = async () => {
        dbg.Inf(`Connecting to KNX/${gwTyp}: [IP Addr: ${kIP}, Port: ${kPort}]`);
        return new Promise((r) => {
            try {
                kCom = new knx.Connection({
                    ipAddr: kIP,
                    ipPort: kPort,
                    physAddr: kHwID,
                    manualConnect: true,
                    forceTunneling: isTun,
                    setLogLevel: 'trace',
                    handlers: {
                        connected: () => {
                            dbg.Inf(`KNX/${gwTyp} Connected.`);
                            isCon = true;
                            r(true);
                        },
                        event: async (e, s, d, vl) => {
                            let vArr = [];
                            Object.keys(vl).forEach((v) => {
                                vArr.push(vl[v]);
                            });
                            // dbg.Inf(`event: ${e}, src: ${s}, dest: ${d}, value: ${vArr.join('|')}`);
                            if (rxArr.length <= 0 && (rxIdle == true)) {
                                rxArr.push([d, vl]);
                                knxRep();
                            } else {
                                rxArr.push([d, vl]);
                            }
                            // //delete vArr;
                        },
                        error: (c) => {
                            dbg.Err(`Connection Status: ${c}`);
                            r(false);
                        },
                        disconnected: () => {
                            dbg.Wrn(`KNX/${gwTyp} Disconnected.`);
                            isCon = false;
                        }
                    }
                });
                r(true);
            } catch (e) {
                r(false);
            }
            kCom = kCom;
        });
    };
})();