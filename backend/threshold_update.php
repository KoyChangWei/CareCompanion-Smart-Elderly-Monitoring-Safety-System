<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

include 'dbconnect.php';

// Get parameters from GET request
$high_temp_threshold = isset($_GET['high_temp_threshold']) ? floatval($_GET['high_temp_threshold']) : null;
$low_temp_threshold = isset($_GET['low_temp_threshold']) ? floatval($_GET['low_temp_threshold']) : null;
$high_hum_threshold = isset($_GET['high_hum_threshold']) ? floatval($_GET['high_hum_threshold']) : null;
$low_hum_threshold = isset($_GET['low_hum_threshold']) ? floatval($_GET['low_hum_threshold']) : null;

if ($high_temp_threshold !== null && $low_temp_threshold !== null && 
    $high_hum_threshold !== null && $low_hum_threshold !== null) {
    
    // Validate threshold ranges
    if ($high_temp_threshold <= $low_temp_threshold) {
        echo json_encode(array("success" => false, "message" => "High temperature threshold must be greater than low temperature threshold"));
        exit;
    }
    
    if ($high_hum_threshold <= $low_hum_threshold) {
        echo json_encode(array("success" => false, "message" => "High humidity threshold must be greater than low humidity threshold"));
        exit;
    }
    
    try {
        // UPDATE existing threshold record with threshold_id = 1 (don't insert new records)
        $sql = "UPDATE temp_hum_threshold_tbl SET 
                high_temp_threshold = ?, 
                low_temp_threshold = ?, 
                high_hum_threshold = ?, 
                low_hum_threshold = ?, 
                timestamp = NOW() 
                WHERE threshold_id = 1";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("dddd", $high_temp_threshold, $low_temp_threshold, $high_hum_threshold, $low_hum_threshold);
        
        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                echo json_encode(array(
                    "success" => true, 
                    "message" => "Thresholds updated successfully",
                    "data" => array(
                        "high_temp_threshold" => $high_temp_threshold,
                        "low_temp_threshold" => $low_temp_threshold,
                        "high_hum_threshold" => $high_hum_threshold,
                        "low_hum_threshold" => $low_hum_threshold
                    )
                ));
            } else {
                // If no rows were affected, threshold_id = 1 doesn't exist, so insert it
                $insert_sql = "INSERT INTO temp_hum_threshold_tbl (threshold_id, high_temp_threshold, low_temp_threshold, high_hum_threshold, low_hum_threshold, timestamp) VALUES (1, ?, ?, ?, ?, NOW())";
                $insert_stmt = $conn->prepare($insert_sql);
                $insert_stmt->bind_param("dddd", $high_temp_threshold, $low_temp_threshold, $high_hum_threshold, $low_hum_threshold);
                
                if ($insert_stmt->execute()) {
                    echo json_encode(array(
                        "success" => true, 
                        "message" => "Initial thresholds created successfully",
                        "data" => array(
                            "high_temp_threshold" => $high_temp_threshold,
                            "low_temp_threshold" => $low_temp_threshold,
                            "high_hum_threshold" => $high_hum_threshold,
                            "low_hum_threshold" => $low_hum_threshold
                        )
                    ));
                } else {
                    echo json_encode(array("success" => false, "message" => "Error creating initial thresholds: " . $insert_stmt->error));
                }
                $insert_stmt->close();
            }
        } else {
            echo json_encode(array("success" => false, "message" => "Error updating thresholds: " . $stmt->error));
        }
        
        $stmt->close();
        
    } catch(Exception $e) {
        echo json_encode(array("success" => false, "message" => "Database error: " . $e->getMessage()));
    }
} else {
    echo json_encode(array(
        "success" => false, 
        "message" => "Missing threshold data. Required: high_temp_threshold, low_temp_threshold, high_hum_threshold, low_hum_threshold"
    ));
}

$conn->close();
?> 