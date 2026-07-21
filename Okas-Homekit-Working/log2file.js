const fs = require('fs');
const path = require('path');
getTS = (cb) => {
    const dt = new Date();
    const day = dt.getDate().toString().padStart(2, '0');
    const fMnt = new Intl.DateTimeFormat('en-US', { month: 'short' });
    const month = fMnt.format(dt);
    const year = dt.getFullYear();
    const fTim = new Intl.DateTimeFormat('en-US', { timeStyle: 'medium', hour12: false });
    const time = fTim.format(dt);
    const mSec = dt.getMilliseconds().toString().padStart(3, '0');
    cb(`${day}.${month}.${year} ${time}:${mSec}`);
    //delete dt, day, fMnt, month, year, fTim, time, mSec;
}

let logDir = path.join(__dirname, "/www/Logs");
global.logStream = null;
let logFile = '';

lfNm = (date = new Date()) => {
    const month = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][date.getMonth()];
    const year = date.getFullYear();
    return `${month}${year}.log`;
}

isStream = (stm) => {
    return stm && !stm.destroyed && stm.writable;
}

delLogs = () => {
    const files = fs.readdirSync(logDir)
        .filter(f => f.match(/^[A-Z]{3}\d{4}\.log$/))
        .map(f => ({ name: f, time: fs.statSync(path.join(logDir, f)).mtime.getTime() }))
        .sort((a, b) => a.time - b.time);

    while (files.length > 6) {
        const file2Del = files.shift();
        fs.unlinkSync(path.join(logDir, file2Del.name));
        console.log(`Deleted old log file: ${file2Del.name}`);
    }
}

makStream = (fNm) => {
    const fPth = path.join(logDir, fNm);
    logStream = fs.createWriteStream(fPth, { flags: 'a' });
    //delete fPth;
    logFile = fNm;
    delLogs();
    console.log(`Logging to: ${fNm}`);
}

put2File = (typ, txt) => {
    const newFile = lfNm();
    if (!isStream(logStream)) {
        if (logFile === newFile) {
            console.log('Recreating stream for same log file...');
            makStream(newFile);
        } else {
            if (logStream) logStream.end();
            makStream(newFile);
        }
    }
    getTS((ts) => {
        let oTxt = `[${typ}] ${ts}>> ${txt}`;
        console.log(oTxt);
        logStream.write(oTxt + '\n', 'utf8', (e) => {
            if (e) console.error('Failed to append log:', e);
        });
        //delete typ, txt, oTxt, ts;
    });
}

(module.exports = () => {
    dbg = {
        "Inf": (t) => {
            put2File("Info", t);
        },
        "Err": (t) => {
            put2File("Error", t);
        },
        "Wrn": (t) => {
            put2File("Warn", t);
        },
    }
})();