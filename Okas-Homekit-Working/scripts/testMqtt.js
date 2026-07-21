global.fs = require("fs");
global.lDatFile = "./Data/loadData.json";
global.PINcode = "";

require("../log2file");
require("../Data/iData");
require("../Mqtt/mqttClnt");

async function setupMockData() {
    dbg.Inf("=== MQTT TEST MODE ===");
    dbg.Inf("Setting up mock load data (no KNX required)...");

    if (!(await chkFile())) {
        dbg.Err("Cannot read loadData.json. Aborting test.");
        process.exit(1);
    }

    if (!(await makLdArr())) {
        dbg.Err("Cannot process load data. Aborting test.");
        process.exit(1);
    }

    dbg.Inf("Loaded " + (ldArr.length - 1) + " loads from loadData.json");

    ldArr.forEach((v, i) => {
        if (i === 0) return;  // Skip project settings

        knxLod[v.Nm] = {};
        knxLod[v.Nm].Typ = v.Typ;
        knxLod[v.Nm].Val = {};

        // Set default mock values based on type
        switch (v.Typ) {
            case 'Switch':
                knxLod[v.Nm].Val.Sta = false;
                knxLod[v.Nm].Val.Swt = false;
                dbg.Inf("  Mock: " + v.Nm + " [Switch] → OFF");
                break;

            case 'Dimmer':
                knxLod[v.Nm].Val.Sta = true;
                knxLod[v.Nm].Val.Swt = true;
                knxLod[v.Nm].Val.Bri = 75;
                knxLod[v.Nm].Val.Bvi = 75;
                dbg.Inf("  Mock: " + v.Nm + " [Dimmer] → ON, 75%");
                break;

            case 'RGB':
                knxLod[v.Nm].Val.Sta = true;
                knxLod[v.Nm].Val.Swt = true;
                knxLod[v.Nm].Val.Bri = 100;
                knxLod[v.Nm].Val.Bvi = 100;
                knxLod[v.Nm].Val.Hue = 220;
                knxLod[v.Nm].Val.Sat = 85;
                dbg.Inf("  Mock: " + v.Nm + " [RGB] → ON, 100%, H:220 S:85");
                break;

            case 'Tunable':
                knxLod[v.Nm].Val.Sta = true;
                knxLod[v.Nm].Val.Swt = true;
                knxLod[v.Nm].Val.Bri = 60;
                knxLod[v.Nm].Val.Bvi = 60;
                knxLod[v.Nm].Val.Tuv = 350;
                dbg.Inf("  Mock: " + v.Nm + " [Tunable] → ON, 60%, 350 mired");
                break;

            case 'HVAC':
                knxLod[v.Nm].Val.Sta = true;
                knxLod[v.Nm].Val.Swt = true;
                knxLod[v.Nm].Val.Trm = 24.5;
                knxLod[v.Nm].Val.Tsp = 22.0;
                knxLod[v.Nm].Val.Fsv = 2;
                knxLod[v.Nm].Val.Tmv = 2;
                dbg.Inf("  Mock: " + v.Nm + " [HVAC] → ON, Room:24.5, SP:22, Fan:2, COOL");
                break;

            case 'Fan':
                knxLod[v.Nm].Val.Sta = true;
                knxLod[v.Nm].Val.Swt = true;
                knxLod[v.Nm].Val.Fsv = 3;
                dbg.Inf("  Mock: " + v.Nm + " [Fan] → ON, Speed:3");
                break;

            case 'Curtain':
                knxLod[v.Nm].Val.Pvi = 50;
                knxLod[v.Nm].Val.Pos = 50;
                dbg.Inf("  Mock: " + v.Nm + " [Curtain] → Position:50%");
                break;

            case 'Scene':
                knxLod[v.Nm].Val.Scn = v.Scn || 1;
                dbg.Inf("  Mock: " + v.Nm + " [Scene] → Scene:" + (v.Scn || 1));
                break;

            default:
                knxLod[v.Nm].Val.Sta = false;
                dbg.Inf("  Mock: " + v.Nm + " [" + v.Typ + "] → default OFF");
        }
    });

    dbg.Inf("Mock data ready. " + Object.keys(knxLod).length + " loads configured.");
    for (let lNm in knxLod) {
        dbg.Inf("DEBUG knxLod[" + lNm + "].Typ = " + knxLod[lNm].Typ);
        dbg.Inf("DEBUG knxLod[" + lNm + "].Val = " + o2S(knxLod[lNm].Val));
    }
}

async function runTest() {
    await setupMockData();

    dbg.Inf("Connecting MQTT client to broker...");
    if (!(await cntMqtt())) {
        dbg.Err("MQTT connection failed. Is Mosquitto running?");
        process.exit(1);
    }
    dbg.Inf("MQTT client connected and subscribed.");

    dbg.Inf("Publishing initial load states...");
    let loadList = [];
    ldArr.forEach((v, i) => {
        if (i === 0) return;
        loadList.push({
            name: v.Nm,
            type: v.Typ,
            state: gtLdSt(v.Nm)
        });
    });

    mqttPub(TPCS.PUB.ST_LDS, {
        type: 'loadList',
        count: loadList.length,
        loads: loadList,
        timestamp: Date.now()
    }, true);

    dbg.Inf("");
    dbg.Inf("══════════════════════════════════════════════════");
    dbg.Inf("  TEST SERVER RUNNING — Ready for MQTT testing!");
    dbg.Inf("══════════════════════════════════════════════════");
    dbg.Inf("");
    dbg.Inf("  Open NEW terminals and try these commands:");
    dbg.Inf("");
    dbg.Inf("  TEST 1 - Subscribe to all topics:");
    dbg.Inf("    mosquitto_sub -h localhost -p 1883 -t '#' -v");
    dbg.Inf("");
    dbg.Inf("  TEST 2 - Request load list:");
    dbg.Inf("    mosquitto_pub -h localhost -p 1883 -t 'loads/getLoads' -m '{}'");
    dbg.Inf("");
    dbg.Inf("  TEST 3 - Send a command:");
    dbg.Inf('    mosquitto_pub -h localhost -p 1883 -t \'command/sndCmd\' -m \'{"load":"Track Light","command":"setOn","value":true}\'');
    dbg.Inf("");
    dbg.Inf("  TEST 4 - Send status ack:");
    dbg.Inf('    mosquitto_pub -h localhost -p 1883 -t \'status/recvStatus\' -m \'{"load":"Track Light","command":"setOn","status":"acknowledged"}\'');
    dbg.Inf("");
    dbg.Inf("  Press Ctrl+C to stop the test server.");
    dbg.Inf("══════════════════════════════════════════════════");
}

runTest();

async function testEnd() {
    dbg.Inf("Stopping MQTT test server...");
    await discntMqtt();
    logStream.end();
    process.exit(0);
}

process.on('SIGINT', testEnd);
process.on('SIGTERM', testEnd);