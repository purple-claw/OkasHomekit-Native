<?php
$filename = basename($_GET['file'] ?? '');
if ($filename === '' || !preg_match('/^[A-Za-z0-9._-]+$/', $filename)) {
    echo 'invalid file name';
    exit;
}

$filepath = "Logs/$filename";
if (!file_exists($filepath)) {
    echo 'not found';
    exit;
}

if (file_put_contents($filepath, '') === false) {
    echo 'permission denied';
    exit;
}

echo 'cleared';
?>