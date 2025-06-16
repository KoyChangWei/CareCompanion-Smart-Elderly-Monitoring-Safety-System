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
    // Get DHT history for specified number of days
    $sql = "SELECT dht_temp as temperature, dht_humdity as humidity, timestamp 
            FROM dht_tbl 
            WHERE timestamp >= DATE_SUB(NOW(), INTERVAL ? DAY)
            ORDER BY timestamp ASC";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $days);
    $stmt->execute();
    
    $result = $stmt->get_result();
    $results = $result->fetch_all(MYSQLI_ASSOC);
    
    echo json_encode([
        'status' => 'success',
        'data' => $results,
        'count' => count($results),
        'period_days' => $days
    ]);
    
    $stmt->close();
    
} catch(Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Database error: ' . $e->getMessage(),
        'data' => []
    ]);
}

$conn->close();
?> 