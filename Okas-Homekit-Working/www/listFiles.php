<?php
$dir = 'Logs/';
try {
    $files = array_filter(scandir($dir), fn($f) => pathinfo($f, PATHINFO_EXTENSION) === 'log');
    
    $months = [
        'JAN' => 1, 'FEB' => 2, 'MAR' => 3, 'APR' => 4, 'MAY' => 5, 'JUN' => 6,
        'JUL' => 7, 'AUG' => 8, 'SEP' => 9, 'OCT' => 10, 'NOV' => 11, 'DEC' => 12
    ];

    usort($files, function($a, $b) use ($months) {
        $monthA = strtoupper(substr($a, 0, 3));
        $yearA = substr($a, 3, 4);
        
        $monthB = strtoupper(substr($b, 0, 3));
        $yearB = substr($b, 3, 4);
        
        $dateA = $yearA * 100 + ($months[$monthA] ?? 0);
        $dateB = $yearB * 100 + ($months[$monthB] ?? 0);
        
        return $dateB - $dateA; // Descending order
    });

} catch (Exception $e) {
    echo (["No Files to show."]);
}
if ($files == []) {
    echo json_encode(array_values(["No Files."]));
} else {
    echo json_encode(array_values($files));
}