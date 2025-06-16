<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include 'dbconnect.php';

// Handle OPTIONS request for CORS
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

try {
    // Get status parameter
    if (!isset($_GET['status'])) {
        echo json_encode([
            'error' => 'Missing status parameter',
            'success' => false
        ]);
        exit;
    }
    
    $status = strtoupper($_GET['status']);
    
    // Validate status
    if ($status !== 'ON' && $status !== 'OFF') {
        echo json_encode([
            'error' => 'Invalid status. Use ON or OFF',
            'success' => false
        ]);
        exit;
    }
    
    // Check if a relay record exists
    $checkSql = "SELECT COUNT(*) as count FROM relay_tbl";
    $result = $conn->query($checkSql);
    $row = $result->fetch_assoc();
    
    if ($row['count'] == 0) {
        // No record exists, insert the first one
        $sql = "INSERT INTO relay_tbl (relay_status, timestamp) VALUES (?, NOW())";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $status);
    } else {
        // Record exists, update it
        $sql = "UPDATE relay_tbl SET relay_status = ?, timestamp = NOW()";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $status);
    }
    
    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => "Relay turned $status successfully",
            'status' => $status,
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    } else {
        echo json_encode([
            'error' => 'Failed to update relay status',
            'success' => false
        ]);
    }
    
    $stmt->close();
    
} catch(Exception $e) {
    echo json_encode([
        'error' => 'Database error: ' . $e->getMessage(),
        'success' => false
    ]);
}

$conn->close();
?> 