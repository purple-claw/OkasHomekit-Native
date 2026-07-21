<?php
// This endpoint intentionally exposes only the commissioning owner token used
// by deviceInfo.html. Guest tokens are never stored in, or served by, the web UI.
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

$file = '../Data/loadData.json';
if (!is_readable($file)) {
    http_response_code(404);
    echo json_encode(['error' => 'Board configuration is unavailable']);
    exit;
}

$data = json_decode(file_get_contents($file), true);
$token = $data[0]['authToken'] ?? null;
if (!is_string($token) || $token === '') {
    http_response_code(503);
    echo json_encode(['error' => 'Admin token is not generated yet']);
    exit;
}

echo json_encode(['token' => $token]);
