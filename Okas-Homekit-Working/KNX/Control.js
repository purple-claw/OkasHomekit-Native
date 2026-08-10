// Verify if this file is still needed::

const readline = require('readline');
let lod = "";
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: 'Enter command > '
});

function putLd(ld) {
    lod = ld;
}

function hdlIP(c) {
    switch ((c.trim().toLowerCase())) {
        case 'on':
            console.log("Turning On Load");
            lod.write(true);
            break;
        case 'off':
            console.log("Turning Off Load");
            lod.write(false);
            break;
        default:
            console.log("Unknown action, Ignored.");
            break;
    }
}

function getIP() {
    rl.prompt();
    rl.on('line', (input) => {
        hdlIP(input);
        rl.prompt(); // Wait for next command
    });

    // On Ctrl+C or EOF
    rl.on('close', () => {
        console.log('\nCLI stopped.');
        // process.exit(0);
    });
}

module.exports = { putLd, getIP }