<?php
$filename = basename($_GET['file']);
$filepath = "Logs/$filename";

if (file_exists($filepath)) {
    unlink($filepath);
    echo "deleted";
} else {
    echo "not found";
}
?>
