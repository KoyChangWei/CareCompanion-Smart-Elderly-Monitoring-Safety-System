<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include 'dbconnect.php';

// Get parameters from GET request
$humidity = isset($_GET['humidity']) ? $_GET['humidity'] : null;
$alert_type = isset($_GET['alert_type']) ? $_GET['alert_type'] : null; // 'HIGH' or 'LOW'
$threshold_value = isset($_GET['threshold_value']) ? $_GET['threshold_value'] : null;

if ($humidity !== null && $alert_type !== null && $threshold_value !== null) {
    try {
        // Insert humidity alert into hum_alert_tbl (create if needed)
        $sql = "INSERT INTO hum_alert_tbl (humidity, alert_type, threshold_value, timestamp) VALUES (?, ?, ?, NOW())";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("dsd", $humidity, $alert_type, $threshold_value);
        
        if ($stmt->execute()) {
            echo "Humidity alert logged successfully - Humidity: " . $humidity . "% " . $alert_type . " threshold: " . $threshold_value . "%";
        } else {
            echo "Error: " . $stmt->error;
        }
        
        $stmt->close();
        
    } catch(Exception $e) {
        echo "Database error: " . $e->getMessage();
    }
} else {
    echo "Error: Missing humidity, alert_type (HIGH/LOW), or threshold_value data";
}

$conn->close();
?> 