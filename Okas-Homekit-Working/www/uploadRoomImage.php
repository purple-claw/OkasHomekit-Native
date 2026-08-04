<?php
/**
 * uploadRoomImage.php
 *
 * Room-image sync endpoint used by the mobile app so that a room image
 * picked on one device is available to every other device on the network.
 *
 * Accepts a multipart/form-data POST with a file field named "image".
 * The file is stored under /home/OhKnx/www/uploads/ (served statically by
 * the web server) and the JSON response returns the absolute URL to the
 * image. The mobile app stores that URL in the room's imagePath field and
 * the board syncs it to all devices via MQTT (rooms/set).
 *
 * Response: { success: true, url: "http://<host>/uploads/<file>", path: "/uploads/<file>" }
 * Error:    { success: false, message: "..." }
 */

header('Content-Type: application/json');

$uploadDir = __DIR__ . '/uploads';

if (!is_dir($uploadDir)) {
    if (!mkdir($uploadDir, 0755, true)) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Cannot create uploads directory']);
        exit();
    }
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'POST required']);
    exit();
}

if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
    $err = isset($_FILES['image']) ? $_FILES['image']['error'] : 'no file field';
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => "Upload failed ($err)"]);
    exit();
}

$tmp = $_FILES['image']['tmp_name'];
$size = $_FILES['image']['size'];

$maxBytes = 4 * 1024 * 1024; // 4 MB
if ($size > $maxBytes) {
    http_response_code(413);
    echo json_encode(['success' => false, 'message' => 'Image too large (max 4 MB)']);
    exit();
}

// Detect MIME from the actual file bytes (not the client header).
$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime = $finfo->file($tmp);
$allowed = [
    'image/jpeg' => 'jpg',
    'image/png'  => 'png',
    'image/webp' => 'webp',
    'image/gif'  => 'gif',
];
if (!isset($allowed[$mime])) {
    http_response_code(415);
    echo json_encode(['success' => false, 'message' => "Unsupported image type: $mime"]);
    exit();
}
$ext = $allowed[$mime];

$name = 'room_' . date('Ymd_His') . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
$dest = $uploadDir . '/' . $name;

if (!move_uploaded_file($tmp, $dest)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Failed to store image']);
    exit();
}

// Build an absolute URL from the request host so the mobile app can load it.
$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'] ?? 'localhost';
$url = "$scheme://$host/uploads/$name";

echo json_encode([
    'success' => true,
    'url'     => $url,
    'path'    => "/uploads/$name",
]);
