<?php
$filename = basename($_GET['file']);
$filepath = "Logs/$filename";

if (file_exists($filepath)) {
    echo htmlspecialchars(file_get_contents($filepath));
} else {
    http_response_code(404);
    echo "File not found.";
}
?>
