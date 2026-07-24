global.fs = require("fs");
global.lDatFile = "./Data/loadData.json";
global.PINcode = "";
require("./log2file");
require("./Data/iData");
require("./initLoads");
require("./KNX/knxBridge");   // MQTT link to the Python xknx bridge (KNX/knx_bridge.py)
require("./HkB/HkB");
require("./KNX/actHdlr");
require("./KNX/repHdlr");
require("./Mqtt/mqttClnt");
const { startAuthService, stopAuthService } = require("./Auth/authService");

// KNX bus I/O now lives in the Python process (KNX/knx_bridge.py). This Node
// service runs HomeKit + the mobile MQTT API + authentication and reaches the
// bus over MQTT:
//   commands  -> okas/knx/cmd   (JS -> Python)
//   feedback  <- okas/knx/state (Python -> JS)
//   link state<- okas/knx/conn  (Python -> JS -> global isCon)

async function initialize() {
    dbg.Inf("Starting OKAS HomeKit service...");
    if (!(await chkFile())) { dbg.Err("Data file check failed. Aborting."); return; }
    if (!(await makLdArr())) { dbg.Err("Failed to process load data. Aborting."); return; }
    // Start the authentication service before anything else — it publishes the
    // owner token to loadData.json that HomeKit and the web UI depend on.
    try {
        startAuthService();
        dbg.Inf("OKAS-Secure Service started.");
    } catch (error) {
        dbg.Err(`OKAS-Secure service did not start: ${error.message}`);
    }
    if (!(await prepLoads())) { dbg.Err("Failed to prepare KNX loads. Aborting."); return; }
    else { dbg.Inf("Prepared KNX Loads."); }

    // Build & publish HomeKit first — it is the critical path (iOS Home app) and
    // hkbAcc must be populated before any KNX feedback is processed.
    dbg.Inf("Preparing HomeKit loads");
    if (!(await bldAcc())) { dbg.Err("Failed to build HomeKit accessories. Aborting."); return; }
    else { dbg.Inf("Prepared HomeKit Loads."); }

    // Connect the KNX bridge (to the Python xknx process via MQTT).
    dbg.Inf("Connecting KNX bridge...");
    if (!(await cntKnxBridge())) {
        dbg.Wrn("KNX bridge not ready yet. Will auto-retry in background.");
    } else {
        dbg.Inf("KNX bridge connected.");
    }

    // Connect the mobile-app MQTT API (auxiliary — never blocks HomeKit).
    dbg.Inf("Connecting MQTT Client...");
    if (!(await cntMqtt())) {
        dbg.Wrn("MQTT connection failed. Will auto-retry in background.");
    } else {
        dbg.Inf("MQTT Client connected and subscribed.");
    }
    dbg.Inf("Okas HomeKit service started successfully.");
}

// Keep the service alive: a stray async error (e.g. a KNX/MQTT callback) must be
// logged, not allowed to exit the process into a systemd restart loop.
process.on('unhandledRejection', (reason) => {
    try { dbg.Err(`Unhandled Rejection: ${(reason && reason.stack) ? reason.stack : reason}`); }
    catch (_) { console.error('Unhandled Rejection:', reason); }
});
process.on('uncaughtException', (err) => {
    try { dbg.Err(`Uncaught Exception: ${(err && err.stack) ? err.stack : err}`); }
    catch (_) { console.error('Uncaught Exception:', err); }
});

initialize();

async function processEnd() {
    await stopAuthService();
    dbg.Inf('Stopping MQTT Service.');
    await discntMqtt();
    dbg.Inf('Stopping KNX bridge.');
    await discntKnxBridge();
    dbg.Inf('Stopping HomeKit Service.');
    try {
        if (bridge && bridge.published) {
            await bridge.unpublish();
            dbg.Inf("HomeKit Service gracefully Shutdown.");
        } else { dbg.Inf("HomeKit Service NOT active."); }
    } catch (error) { dbg.Err(`Error Shutting down HomeKit Service: ${error}`); }
    finally {
        logStream.end();
        dbg.Inf('Shutting down all other Services.');
        process.exit(0);
    }
}

process.on('SIGINT', processEnd);
process.on('SIGTERM', processEnd);
