<?php
$filepaths = "../Data/loadData.json";

header('Content-Type: application/json');

if (file_exists($filepaths)) {
    $content = file_get_contents($filepaths);
    // Validate if the content is valid JSON before outputting
    if (json_decode($content) !== null) {
        echo $content;
    } else {
        http_response_code(500);
        echo json_encode(["error" => "Invalid JSON in file"]);
    }
} else {
    http_response_code(404);
    echo json_encode(["error" => "File not found"]);
}