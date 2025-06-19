<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include 'dbconnect.php';

// Get parameters from GET request (for testing)
$action = isset($_GET['action']) ? $_GET['action'] : 'get';

if ($action == 'set_default') {
    try {
        // Insert default threshold settings
        $sql = "INSERT INTO temp_hum_threshold_tbl (high_temp_threshold, low_temp_threshold, high_hum_threshold, low_hum_threshold, timestamp) VALUES (28.0, 18.0, 70.0, 30.0, NOW())";
        $stmt = $conn->prepare($sql);
        
        if ($stmt->execute()) {
            echo json_encode([
                'success' => true,
                'message' => 'Default thresholds set successfully',
                'thresholds' => [
                    'high_temp' => 28.0,
                    'low_temp' => 18.0,
                    'high_hum' => 70.0,
                    'low_hum' => 30.0
                ]
            ]);
        } else {
            echo json_encode(['success' => false, 'error' => $stmt->error]);
        }
        
        $stmt->close();
        
    } catch(Exception $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
} else {
    // Default action: get current thresholds
    try {
        $sql = "SELECT high_temp_threshold, low_temp_threshold, high_hum_threshold, low_hum_threshold, timestamp 
                FROM temp_hum_threshold_tbl 
                ORDER BY timestamp DESC 
                LIMIT 1";
        $stmt = $conn->prepare($sql);
        $stmt->execute();
        
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        
        if ($row) {
            echo json_encode([
                'success' => true,
                'thresholds' => $row
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'message' => 'No thresholds found in database'
            ]);
        }
        
        $stmt->close();
        
    } catch(Exception $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

$conn->close();
?> 