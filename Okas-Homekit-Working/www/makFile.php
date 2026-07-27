<?php
function s2O($str)
{
    return json_decode($str);
}
function o2S($obj)
{
    return json_encode($obj, JSON_UNESCAPED_SLASHES);
}

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Handle preflight request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}


$inDat = file_get_contents("php://input");
$file = "../Data/loadData.json";
$lT2gT = [
    "Switch" => ["Swt", "Sta"],
    "Dimmer" => ["Swt", "Sta", "Dim", "Bri", "Bvi"],
    "RGB" => ["Swt", "Sta", "Dim", "Bri", "Bvi", "Clc", "Clv"],
    "Tunable" => ["Swt", "Sta", "Dim", "Bri", "Bvi", "Tuc", "Tuv"],
    "HVAC" => ["Swt", "Sta", "Trm", "Tsp", "Fsc", "Fsv", "Tmc", "Tmv"],
    "Scene" => ["Scn"],
    "Fan" => ["Swt", "Sta", "Fsc", "Fsv"],
    "Curtain" => ["Mov", "Mvi", "Stp", "Pos", "Pvi"],
];
$inDat = s2O($inDat);
$ldData = [];
$ldData[0] = (object)[];

function getMACnIP()
{
    if (PHP_OS_FAMILY === 'Windows') {
        $output = shell_exec("getmac");
        $line = trim(shell_exec('ipconfig | findstr /R "IPv4"'));
        preg_match('/\d+\.\d+\.\d+\.\d+/', $line, $m);
        $ip = $m[0] ?? "255.255.255.255";
        if (preg_match('/([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})/', $output, $matches)) {
            return [str_replace("-", ":", $matches[0]), $ip];
        } else {
            return ['66:42:62:62:64:84', $ip];
        }
    } elseif (PHP_OS_FAMILY === 'Linux') {
        // Auto-detect the first active non-loopback interface
        $iface = trim(shell_exec("ip -o link show up | awk -F': ' '{print $2}' | grep -v lo | head -1"));
        $macFile = "/sys/class/net/{$iface}/address";
        $mac = file_exists($macFile) ? trim(file_get_contents($macFile)) : '66:42:62:62:64:84';
        $ip = trim(shell_exec("ip -4 addr show " . escapeshellarg($iface) . " | grep -oP '(?<=inet\s)\d+(\.\d+){3}'"));
        return [str_replace("-", ":", $mac), $ip ?: '0.0.0.0'];
    }
    return '66:42:62:62:64:84';
}

$pPC = "";
$autnToken = "";

if (file_exists($file)) {
    $fDat = file_get_contents($file);
    $fDat = s2O($fDat);
    if ($fDat !== null) {
        if (isset($fDat[0]->pinCode)) {
            $pPC = $fDat[0]->pinCode;
        }
        if (isset($fDat[0]->authToken)) {
            $autnToken = $fDat[0]->authToken;
        }
    }
}

if ($inDat) {
    $rslt = false;
    if (count(($inDat->loads)) > 0) {
        foreach ($inDat->loads as $id => $val) {
            if (count($val->gAdd)) {
                $ldData[$id + 1] = (object)["Nm" => $val->ldNm, "Typ" => $val->ldTyp, "GA" => (object)[]];
                switch ($val->ldTyp) {
                    case 'Scene':
                        $ldData[$id + 1]->Scn = (int)$val->Scn;
                        break;
                    case 'Fan':
                        $ldData[$id + 1]->Smx = (int)$val->Smx;
                        $ldData[$id + 1]->Fst = (int)$val->Fst;
                        break;
                    case 'HVAC':
                        $ldData[$id + 1]->Tmn = (int)$val->Tmn;
                        $ldData[$id + 1]->Tmx = (int)$val->Tmx;
                        $ldData[$id + 1]->Smx = (int)$val->Smx;
                        $ldData[$id + 1]->Fst = (int)$val->Fst;
                        break;
                    case 'Tunable':
                        $ldData[$id + 1]->Kmn = (int)$val->Kmn;
                        $ldData[$id + 1]->Kmx = (int)$val->Kmx;
                        break;
                }
                foreach ($val->gAdd as $gI => $gA) {
                    $kVal = $lT2gT[$val->ldTyp][$gI];
                    $ldData[$id + 1]->GA->$kVal = $gA;
                }
                $rslt = true;
            }
        }
        $ldData[0] = (object)[];
        $ldData[0]->prjNm = $inDat->prjNm;
        $MACnIP = getMACnIP();
        $ldData[0]->mac = $MACnIP[0];
        $ldData[0]->ip = $MACnIP[1];
        $ldData[0]->gwIP = $inDat->knxIp;
        $ldData[0]->gwPort = $inDat->knxPort;
        $ldData[0]->pinCode = $pPC;
        $ldData[0]->authToken = $autnToken;
        echo $rslt;
        $oData = o2S($ldData);
        file_put_contents($file, $oData);
        sleep(2);
        // Restart KNX bridge first (must reconnect to new gateway), then HomeKit service
        exec("sudo /usr/bin/systemctl restart OhKnxKnx.service");
        sleep(3);
        exec("sudo /usr/bin/systemctl restart HkBStartUp.service");
        unset($rslt, $kVal);
    }
};
