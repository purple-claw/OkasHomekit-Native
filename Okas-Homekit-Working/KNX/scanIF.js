const dgram = require("dgram");

const PORT = 3671;
const SEARCH_REQUEST = Buffer.from("06100201000e0801ffffffff0e57", "hex");
const socket = dgram.createSocket({ type: "udp4", reuseAddr: true });

(module.exports = () => {
    socket.bind(PORT, () => {
        socket.addMembership("224.0.23.12");
    });
    let repArr = [];
    let seenIPs = new Set();
    getIF = async () => {
        socket.send(SEARCH_REQUEST, 0, SEARCH_REQUEST.length, PORT, "224.0.23.12", () => {
            dbg.Inf("Searching KNX/IP gateway on Network...");
        });

        socket.on("message", (msg, rinfo) => {
            if (seenIPs.has(rinfo.address)) {
                return;
            }
            seenIPs.add(rinfo.address);
            let oObj = {};
            if ((msg[2] + msg[3]) == 4) {
                dbg.Inf(`Response from ${rinfo.address}:${rinfo.port}`);
                oObj = {
                    ip: rinfo.address,
                    prt: rinfo.port
                };
                let tID = msg[18].toString(16).split('');
                oObj.hwID = (tID[0] + "." + tID[1] + "." + msg[19].toString(16));
                let mArr = [];
                for (let i = 32; i <= 37; i++) {
                    mArr.push(msg[i].toString(16).toUpperCase());
                }
                oObj.mac = mArr.join(':');
                oObj.svc = false;
                oObj.gw = false;
                try {
                    msg[74] == 4 ?
                        (oObj.svc = "TunnelUDP", oObj.gw = "IP Interface") :
                        msg[74] == 5 ?
                            (oObj.svc = "Multicast", oObj.gw = "IP Router") :
                            (oObj.svc = false, oObj.gw = false);
                } catch (e) {

                }
                repArr.push(oObj);
            }
        });
        return new Promise((resolve) => {
            setTimeout(() => {
                seenIPs.clear();
                let g2go = false;
                repArr.forEach((v) => {
                    if (ldArr[0].gwIP == v.ip) {
                        g2go = true;
                        kIP = v.ip;
                        kPort = v.prt;
                        isTun = v.svc == 'TunnelUDP';
                        gwTyp = v.gw;
                        // kHwID = v.hwID;
                    }
                });
                repArr = [];
                if (g2go) {
                    dbg.Inf(`KNX/${gwTyp} found on Network.`);
                    resolve(true);
                } else {
                    dbg.Wrn(`KNX/IP Gateway with IP Address: ${ldArr[0].gwIP} is not active on LAN.`);
                    resolve(false);
                }
                repArr = [];
            }, 5000);
        });
    }
})();