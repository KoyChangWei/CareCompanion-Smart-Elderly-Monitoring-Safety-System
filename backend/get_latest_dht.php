<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include 'dbconnect.php';

try {
    // Get the latest DHT reading
    $sql = "SELECT dht_temp as temperature, dht_humdity as humidity, timestamp 
            FROM dht_tbl 
            ORDER BY timestamp DESC 
            LIMIT 1";
    $stmt = $conn->prepare($sql);
    $stmt->execute();
    
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    if ($row) {
        echo json_encode([
            'temperature' => $row['temperature'],
            'humidity' => $row['humidity'],
            'timestamp' => $row['timestamp']
        ]);
    } else {
        echo json_encode([
            'temperature' => '0.0',
            'humidity' => '0.0',
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    $stmt->close();
    
} catch(Exception $e) {
    echo json_encode([
        'error' => 'Database error: ' . $e->getMessage(),
        'temperature' => '0.0',
        'humidity' => '0.0',
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}

$conn->close();
?> 