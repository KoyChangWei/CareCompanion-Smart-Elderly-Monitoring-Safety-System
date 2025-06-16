<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include 'dbconnect.php';

try {
    // Get the latest vibration sensor reading
    $sql = "SELECT vs_status as status, timestamp 
            FROM vs_tbl 
            ORDER BY timestamp DESC 
            LIMIT 1";
    $stmt = $conn->prepare($sql);
    $stmt->execute();
    
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    if ($row) {
        echo json_encode([
            'status' => $row['status'],
            'timestamp' => $row['timestamp']
        ]);
    } else {
        echo json_encode([
            'status' => 'NO_VIBRATION',
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    $stmt->close();
    
} catch(Exception $e) {
    echo json_encode([
        'error' => 'Database error: ' . $e->getMessage(),
        'status' => 'NO_VIBRATION',
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}

$conn->close();
?> 