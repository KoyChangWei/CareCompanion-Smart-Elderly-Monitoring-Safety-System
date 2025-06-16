<?php
include 'dbconnect.php';

// Get parameters from GET request
$status = isset($_GET['status']) ? $_GET['status'] : null;

if ($status !== null) {
    // Update relay status in relay_tbl (assuming there's only one relay record)
    // If no record exists, insert one; otherwise update the existing record
    
    // First check if a relay record exists
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
        $sql = "UPDATE relay_tbl SET relay_status = ?, timestamp = NOW() WHERE relay_id = (SELECT relay_id FROM (SELECT relay_id FROM relay_tbl ORDER BY relay_id LIMIT 1) as temp)";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $status);
    }
    
    if ($stmt->execute()) {
        echo "Relay status updated successfully to: " . $status;
    } else {
        echo "Error: " . $stmt->error;
    }
    
    $stmt->close();
} else {
    echo "Error: Missing relay status data";
}

$conn->close();
?> 