<?php
/**
 * uploadEts.php — receive an ETS .knxproj, run the board converter in an
 * isolated temp dir, return a KNXdata-shaped draft {prjNm, loads[], rooms[]}
 * for the configuration page's review step. The watch-service and manual
 * load flow are untouched.
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') { http_response_code(200); exit(); }

function fail(string $msg, int $code = 400): void {
    http_response_code($code);
    echo json_encode(['ok' => false, 'err' => $msg]);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST only.');
if (!isset($_FILES['etsfile'])) fail('No file received (check upload size limits).');

$f = $_FILES['etsfile'];
if ($f['error'] !== UPLOAD_ERR_OK) {
    $msgs = [
        UPLOAD_ERR_INI_SIZE   => 'File exceeds server upload limit (raise upload_max_filesize).',
        UPLOAD_ERR_FORM_SIZE  => 'File exceeds form limit.',
        UPLOAD_ERR_PARTIAL    => 'Upload was partial - please retry.',
        UPLOAD_ERR_NO_TMP_DIR => 'Server temp dir missing.',
        UPLOAD_ERR_CANT_WRITE => 'Server failed to write upload.',
    ];
    fail($msgs[$f['error']] ?? 'Upload error code ' . $f['error']);
}
if ($f['size'] > 64 * 1024 * 1024) fail('File larger than 64MB.');
if (strtolower(pathinfo($f['name'], PATHINFO_EXTENSION)) !== 'knxproj') {
    fail('Please select a .knxproj ETS project file.');
}

set_time_limit(180);

$convDir = '/home/OhKnx/OkasConverter';
foreach (['Aexp.py', 'OkasConverter.py'] as $lib) {
    if (!is_readable("$convDir/$lib")) fail("Converter library missing: $lib", 500);
}

$tmpBase = sys_get_temp_dir();
// GC workdirs older than 1h from aborted requests
foreach (glob($tmpBase . '/okas_ets_*', GLOB_ONLYDIR) ?: [] as $old) {
    if (@filemtime($old) < time() - 3600) exec('rm -rf ' . escapeshellarg($old));
}

$work = "$tmpBase/okas_ets_" . uniqid();
if (!mkdir($work, 0700, true)) fail('Cannot create working directory.', 500);

$dest = "$work/project.knxproj";
if (!move_uploaded_file($f['tmp_name'], $dest)) { exec('rm -rf '.escapeshellarg($work)); fail('Failed to store upload.', 500); }
foreach (['Aexp.py', 'OkasConverter.py'] as $lib) {
    if (!copy("$convDir/$lib", "$work/$lib")) { exec('rm -rf '.escapeshellarg($work)); fail('Failed to stage converter.', 500); }
}

$out = [];
$rc = -1;
// HOME is redirected into the workdir: Aexp's import-time Drv logger writes
// ~/Documents/... which www-data cannot create elsewhere; it dies with the workdir.
exec('cd ' . escapeshellarg($work) . ' && HOME=' . escapeshellarg($work) . ' python3 OkasConverter.py 2>&1', $out, $rc);
$logTail = implode("\n", array_slice($out, -12));

if ($rc !== 0 || !file_exists("$work/KNXdata.json") || !file_exists("$work/okas_tuned.json")) {
    exec('rm -rf ' . escapeshellarg($work));
    fail("Conversion failed:\n" . ($logTail ?: "python exited $rc"), 422);
}

$draft = json_decode(file_get_contents("$work/KNXdata.json"), true);
$tuned = json_decode(file_get_contents("$work/okas_tuned.json"), true);
exec('rm -rf ' . escapeshellarg($work));

if (!is_array($draft) || !isset($draft['loads']) || !isset($draft['rooms'])) {
    fail('Converter produced invalid output.', 500);
}
// never leak board credentials through the draft meta row
unset($draft['mac'], $draft['ip'], $draft['pinCode'], $draft['authToken']);

echo json_encode(
    ['ok' => true,
     'draft' => ['prjNm' => $draft['prjNm'] ?? '', 'loads' => $draft['loads'], 'rooms' => $draft['rooms']],
     'stats' => $tuned['stats'] ?? null],
    JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
);
