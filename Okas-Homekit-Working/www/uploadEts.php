<?php
/**
 * uploadEts.php — single-script version (PURE)
 * Converter is separate process: pulsar.py → SINGLE KNXdata.json {prjNm,loads[],rooms[]}
 * No board details at conversion; makFile.php fills mac/ip/pin/gwIP at runtime.
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
$single = "$convDir/pulsar.py";
if (!is_readable($single)) fail("Converter missing: pulsar.py", 500);
$tmpBase = sys_get_temp_dir();
foreach (glob($tmpBase . '/okas_ets_*', GLOB_ONLYDIR) ?: [] as $old) {
    if (@filemtime($old) < time() - 3600) exec('rm -rf ' . escapeshellarg($old));
}
$work = "$tmpBase/okas_ets_" . uniqid();
if (!mkdir($work, 0700, true)) fail('Cannot create working directory.', 500);
$dest = "$work/project.knxproj";
if (!move_uploaded_file($f['tmp_name'], $dest)) { exec('rm -rf '.escapeshellarg($work)); fail('Failed to store upload.', 500); }
if (!copy($single, "$work/pulsar.py")) { exec('rm -rf '.escapeshellarg($work)); fail('Failed to stage converter.', 500); }
$out = [];
$rc = -1;
exec('cd ' . escapeshellarg($work) . ' && HOME=' . escapeshellarg($work) . ' python3 pulsar.py --knxproj project.knxproj --out-dir . 2>&1', $out, $rc);
$logTail = implode("\n", array_slice($out, -12));
if ($rc !== 0 || !file_exists("$work/KNXdata.json")) {
    exec('rm -rf ' . escapeshellarg($work));
    fail("Conversion failed:\n" . ($logTail ?: "python exited $rc"), 422);
}
$draft = json_decode(file_get_contents("$work/KNXdata.json"), true);
exec('rm -rf ' . escapeshellarg($work));
if (!is_array($draft) || !isset($draft['loads']) || !isset($draft['rooms'])) {
    fail('Converter produced invalid output.', 500);
}
echo json_encode(
    ['ok' => true,
     'draft' => ['prjNm' => $draft['prjNm'] ?? '', 'loads' => $draft['loads'], 'rooms' => $draft['rooms']],
     'stats' => ['loads' => count($draft['loads']), 'rooms' => count($draft['rooms'])]],
    JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
);
