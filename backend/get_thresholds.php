<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include 'dbconnect.php';

try {
    // Get the threshold settings for threshold_id = 1 (main threshold configuration)
    $sql = "SELECT high_temp_threshold, low_temp_threshold, high_hum_threshold, low_hum_threshold, timestamp 
            FROM temp_hum_threshold_tbl 
            WHERE threshold_id = 1 
            LIMIT 1";
    $stmt = $conn->prepare($sql);
    $stmt->execute();
    
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    if ($row) {
        echo json_encode([
            'high_temp_threshold' => $row['high_temp_threshold'],
            'low_temp_threshold' => $row['low_temp_threshold'],
            'high_hum_threshold' => $row['high_hum_threshold'],
            'low_hum_threshold' => $row['low_hum_threshold'],
            'timestamp' => $row['timestamp']
        ]);
    } else {
        // Default thresholds if no data in database
        echo json_encode([
            'high_temp_threshold' => '28.0',
            'low_temp_threshold' => '18.0',
            'high_hum_threshold' => '70.0',
            'low_hum_threshold' => '30.0',
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    $stmt->close();
    
} catch(Exception $e) {
    // Return default thresholds on error
    echo json_encode([
        'error' => 'Database error: ' . $e->getMessage(),
        'high_temp_threshold' => '28.0',
        'low_temp_threshold' => '18.0',
        'high_hum_threshold' => '70.0',
        'low_hum_threshold' => '30.0',
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}

$conn->close();
?> 