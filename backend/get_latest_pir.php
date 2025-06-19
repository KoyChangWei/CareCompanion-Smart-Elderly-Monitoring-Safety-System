<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include 'dbconnect.php';

try {
    // Get the latest PIR reading with duration
    $sql = "SELECT PIR_status as status, act_time as duration, timestamp 
            FROM PIR_tbl 
            ORDER BY timestamp DESC 
            LIMIT 1";
    $stmt = $conn->prepare($sql);
    $stmt->execute();
    
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    if ($row) {
        $rawDuration = intval($row['duration']);
        
        // Decode the actual motion duration from encoded value
        // Arduino encodes: actual_seconds + (risk_level * 1000)
        $actualDuration = $rawDuration % 1000; // Extract actual motion seconds
        
        // Determine fall risk level from encoding
        $fallRiskLevel = 'NORMAL';
        if ($rawDuration >= 5000) {
            $fallRiskLevel = 'CRITICAL';
        } else if ($rawDuration >= 4000) {
            $fallRiskLevel = 'HIGH_RISK';
        } else if ($rawDuration >= 3000) {
            $fallRiskLevel = 'MODERATE_RISK';
        } else if ($rawDuration >= 2000) {
            $fallRiskLevel = 'LOW_RISK';
        } else if ($rawDuration >= 1000) {
            $fallRiskLevel = 'SAFE';
        }
        
        echo json_encode([
            'status' => $row['status'],
            'duration' => $actualDuration, // Use decoded actual duration
            'fall_risk_level' => $fallRiskLevel, // Add fall risk information
            'raw_duration' => $rawDuration, // Keep original for debugging
            'timestamp' => $row['timestamp']
        ]);
    } else {
        echo json_encode([
            'status' => 'NO_MOTION',
            'duration' => 0,
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    $stmt->close();
    
} catch(Exception $e) {
    echo json_encode([
        'error' => 'Database error: ' . $e->getMessage(),
        'status' => 'NO_MOTION',
        'duration' => 0,
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}

$conn->close();
?> 