<?php
$filepath = "Logs/loadData.json";

if (file_exists($filepath)) {
    echo htmlspecialchars(file_get_contents($filepath));
} else {
    http_response_code(404);
    echo "File not found.";
}
