<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include 'dbconnect.php';

// Get days parameter (default to 7 days)
$days = isset($_GET['days']) ? intval($_GET['days']) : 7;

// Validate days parameter
if ($days < 1 || $days > 365) {
    $days = 7; // Default to 7 days if invalid
}

try {
    // Get PIR sensor history with duration
    $pirSql = "SELECT 'MOTION' as type, PIR_status as status, act_time as duration, timestamp 
               FROM PIR_tbl 
               WHERE timestamp >= DATE_SUB(NOW(), INTERVAL ? DAY)
               ORDER BY timestamp ASC";
    $pirStmt = $conn->prepare($pirSql);
    $pirStmt->bind_param("i", $days);
    $pirStmt->execute();
    $pirResult = $pirStmt->get_result();
    $pirResults = $pirResult->fetch_all(MYSQLI_ASSOC);
    
    // Get vibration sensor history
    $vsSql = "SELECT 'FALL' as type, vs_status as status, timestamp 
              FROM vs_tbl 
              WHERE timestamp >= DATE_SUB(NOW(), INTERVAL ? DAY)
              ORDER BY timestamp ASC";
    $vsStmt = $conn->prepare($vsSql);
    $vsStmt->bind_param("i", $days);
    $vsStmt->execute();
    $vsResult = $vsStmt->get_result();
    $vsResults = $vsResult->fetch_all(MYSQLI_ASSOC);
    
    // Combine and format results
    $combinedResults = [];
    
    // Process PIR results with duration (decode fall risk encoding)
    foreach ($pirResults as $pir) {
        $rawDuration = intval($pir['duration']);
        
        // Decode the actual motion duration from encoded value
        // Arduino encodes: actual_seconds + (risk_level * 1000)
        // 1000+ = SAFE, 2000+ = LOW_RISK, 3000+ = MODERATE_RISK, 4000+ = HIGH_RISK, 5000+ = CRITICAL
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
        
        $combinedResults[] = [
            'type' => $pir['type'],
            'detected' => ($pir['status'] === 'DETECTED'),
            'duration' => $actualDuration, // Use decoded actual duration
            'fall_risk_level' => $fallRiskLevel, // Add fall risk information
            'raw_duration' => $rawDuration, // Keep original for debugging
            'timestamp' => $pir['timestamp']
        ];
    }
    
    // Process vibration sensor results
    foreach ($vsResults as $vs) {
        $combinedResults[] = [
            'type' => $vs['type'],
            'detected' => ($vs['status'] === 'DETECTED'),
            'duration' => 0, // Falls don't have duration
            'timestamp' => $vs['timestamp']
        ];
    }
    
    // Sort by timestamp
    usort($combinedResults, function($a, $b) {
        return strtotime($a['timestamp']) - strtotime($b['timestamp']);
    });
    
    // Count motion sessions (NO_MOTION events with duration > 0) using decoded duration
    $motionSessions = 0;
    $totalMotionTime = 0;
    foreach ($pirResults as $pir) {
        $rawDuration = intval($pir['duration']);
        $actualDuration = $rawDuration % 1000; // Decode actual duration
        
        if ($pir['status'] === 'NO_MOTION' && $actualDuration > 0) {
            $motionSessions++;
            $totalMotionTime += $actualDuration; // Use decoded duration
        }
    }
    
    // Count fall detections only
    $fallCount = 0;
    foreach ($vsResults as $vs) {
        if ($vs['status'] === 'DETECTED') {
            $fallCount++;
        }
    }
    
    echo json_encode([
        'status' => 'success',
        'data' => $combinedResults,
        'count' => count($combinedResults),
        'period_days' => $days,
        'motion_sessions' => $motionSessions,
        'total_motion_time' => $totalMotionTime,
        'fall_count' => $fallCount
    ]);
    
    $pirStmt->close();
    $vsStmt->close();
    
} catch(Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Database error: ' . $e->getMessage(),
        'data' => []
    ]);
}

$conn->close();
?> 