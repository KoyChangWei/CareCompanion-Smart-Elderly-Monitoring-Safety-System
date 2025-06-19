<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include 'dbconnect.php';

// Get parameters from GET request
$temperature = isset($_GET['temperature']) ? $_GET['temperature'] : null;
$alert_type = isset($_GET['alert_type']) ? $_GET['alert_type'] : null; // 'HIGH' or 'LOW'
$threshold_value = isset($_GET['threshold_value']) ? $_GET['threshold_value'] : null;

if ($temperature !== null && $alert_type !== null && $threshold_value !== null) {
    try {
        // Insert temperature alert into temp_alert_tbl (create if needed)
        $sql = "INSERT INTO temp_alert_tbl (temperature, alert_type, threshold_value, timestamp) VALUES (?, ?, ?, NOW())";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("dsd", $temperature, $alert_type, $threshold_value);
        
        if ($stmt->execute()) {
            echo "Temperature alert logged successfully - Temp: " . $temperature . "°C " . $alert_type . " threshold: " . $threshold_value . "°C";
        } else {
            echo "Error: " . $stmt->error;
        }
        
        $stmt->close();
        
    } catch(Exception $e) {
        echo "Database error: " . $e->getMessage();
    }
} else {
    echo "Error: Missing temperature, alert_type (HIGH/LOW), or threshold_value data";
}

$conn->close();
?> 