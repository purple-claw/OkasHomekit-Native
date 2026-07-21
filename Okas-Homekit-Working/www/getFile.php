<?php
function o2S($obj)
{
    return json_encode($obj, JSON_UNESCAPED_SLASHES);
}
$dir = 'Logs/';
try {
    $files = array_filter(scandir($dir), fn($f) => pathinfo($f, PATHINFO_EXTENSION) === 'log');
} catch (Exception $e) {
    echo (["No Files to show."]);
}
if ($files == []) {
    echo json_encode(array_values(["No Files."]));
} else {
    echo json_encode(array_values($files));
}
