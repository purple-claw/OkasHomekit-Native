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

// ---- LRU line cap -----------------------------------------------------------
// Measured on the board: 10k lines ≈ 1.2MB ≈ ~290ms web refresh; trim rewrite ≈ 16ms.
// Hitting the limit drops the oldest 10% (amortized: one rewrite per ~1000 writes).
const LOG_LINE_LIMIT = 10000;
const LOG_TRIM_KEEP = 9000;
let logLineCount = 0;
let trimBusy = false;
const trimQueue = []; // lines arriving mid-trim; flushed after

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

// LRU trim: keep the newest LOG_TRIM_KEEP lines. Truncates the SAME inode
// (never renames) so the open append stream stays valid — same doctrine as
// delFile.php. Appends made while the trim ran are re-queued and flushed after.
trimLog = (fPth) => {
    if (trimBusy) return;
    trimBusy = true;
    fs.readFile(fPth, 'utf8', (err, data) => {
        if (err) { trimBusy = false; return console.error('Log trim read failed:', err.message); }
        let lines = data.split('\n');
        if (lines.length && lines[lines.length - 1] === '') lines.pop();
        const kept = lines.slice(-LOG_TRIM_KEEP);
        kept.push('');
        fs.writeFile(fPth, kept.join('\n'), 'utf8', (werr) => {
            trimBusy = false;
            if (werr) return console.error('Log trim write failed:', werr.message);
            logLineCount = LOG_TRIM_KEEP;
            console.log(`Log LRU: trimmed ${fPth} to ${LOG_TRIM_KEEP} lines`);
            while (trimQueue.length && isStream(logStream)) {
                logStream.write(trimQueue.shift() + '\n', 'utf8');
                logLineCount++;
            }
        });
    });
}

countLines = (fPth) => {
    try {
        const data = fs.readFileSync(fPth, 'utf8');
        const lines = data.split('\n');
        return lines.length && lines[lines.length - 1] === '' ? lines.length - 1 : lines.length;
    } catch (e) {
        return 0;
    }
}

makStream = (fNm) => {
    const fPth = path.join(logDir, fNm);
    logStream = fs.createWriteStream(fPth, { flags: 'a' });
    try {
        const dirStat = fs.statSync(logDir);
        fs.chownSync(fPth, process.getuid(), dirStat.gid);
        fs.chmodSync(fPth, 0o664);
    } catch (e) {
        console.log('Log file permission fix failed:', e);
    }
    //delete fPth;
    logFile = fNm;
    logLineCount = countLines(fPth);
    if (logLineCount >= LOG_LINE_LIMIT) {
        console.log(`Log ${fNm} opens at ${logLineCount} lines (limit ${LOG_LINE_LIMIT}) - trimming`);
        trimLog(fPth);
    }
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
        // Mid-trim arrivals are queued, not dropped - the trim rewrites a
        // snapshot and would otherwise swallow them.
        if (trimBusy) { trimQueue.push(oTxt); return; }
        logStream.write(oTxt + '\n', 'utf8', (e) => {
            if (e) console.error('Failed to append log:', e);
        });
        logLineCount++;
        if (logLineCount >= LOG_LINE_LIMIT) trimLog(path.join(logDir, logFile));
        //delete typ, txt, oTxt, ts;
    });
}

(module.exports = () => {
    // Opt-in debug (OKAS_DEBUG=1); a busy bus shouldn't write a novel into the log.
    const dbgOn = String(process.env.OKAS_DEBUG || '').trim().toLowerCase() === '1';
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
        "Dbg": (t) => {
            if (dbgOn) put2File("Debug", t);
        },
    }
})();
