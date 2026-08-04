<?php
// Device-local helper for the programmer-only User Management page.
// Reads the owner access token from loadData.json SERVER-SIDE (the
// browser never sees it) and proxies the request to the auth service
// on 127.0.0.1:8080. Supported actions:
//   action=email    -> change the owner email
//   action=label    -> change the owner display name (home greeting)
//   action=password -> reset the owner password
// Only reachable from the device's own network (web config is local).

header('Content-Type: application/json');

function fail($message, $status = 400) {
    http_response_code($status);
    echo json_encode(['success' => false, 'message' => $message]);
    exit;
}

function ownerToken() {
    $dataFile = '/home/OhKnx/Data/loadData.json';
    if (!file_exists($dataFile)) fail('loadData.json not found.', 500);
    $data = json_decode(file_get_contents($dataFile), true);
    if (!is_array($data) || !isset($data[0]['authToken'])) fail('Owner token missing.', 500);
    return $data[0]['authToken'];
}

$action = isset($_POST['action']) ? $_POST['action'] : '';
$token = ownerToken();

switch ($action) {
    case 'email':
        $email = isset($_POST['email']) ? trim($_POST['email']) : '';
        if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            fail('A valid email is required.');
        }
        $payload = ['token' => $token, 'email' => $email];
        break;
    case 'label':
        $name = isset($_POST['label']) ? trim($_POST['label']) : '';
        if ($name === '' || strlen($name) > 80) {
            fail('Display name must be 1-80 characters.');
        }
        $payload = ['token' => $token, 'label' => $name];
        break;
    case 'password':
        $password = isset($_POST['newPassword']) ? $_POST['newPassword'] : '';
        if (strlen($password) < 8 || strlen($password) > 128) {
            fail('Password must be 8-128 characters.');
        }
        $payload = ['token' => $token, 'newPassword' => $password];
        break;
    default:
        fail('Unknown action.');
}

$endpoint = $action === 'email' ? '/api/auth/admin/email'
    : ($action === 'label' ? '/api/auth/admin/label' : '/api/auth/reset-password');
$context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => "Content-Type: application/json\r\n",
        'content' => json_encode($payload),
        'timeout' => 10,
        'ignore_errors' => true,
    ],
]);
$response = file_get_contents('http://127.0.0.1:8080' . $endpoint, false, $context);
if ($response === false) fail('Auth service unreachable.', 500);
$status = 200;
foreach ($http_response_header as $header) {
    if (preg_match('/^HTTP\/\S*\s+(\d{3})/', $header, $m)) $status = (int) $m[1];
}
http_response_code($status);
echo $response;
