<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Include database connection
include_once("dbconnect.php");

// Get POST data
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $input_username = $_POST['username'] ?? '';
    $input_password = $_POST['password'] ?? '';
    
    // Validate input
    if (empty($input_username) || empty($input_password)) {
        echo json_encode(array("status" => "error", "message" => "Username and password are required"));
        exit;
    }
    
    // Prepare statement to prevent SQL injection
    $stmt = $conn->prepare("SELECT user_id, username, password FROM user_tbl WHERE username = ?");
    $stmt->bind_param("s", $input_username);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        
        // Verify password (assuming passwords are hashed with password_hash())
        if (password_verify($input_password, $row['password'])) {
            // Login successful
            echo json_encode(array(
                "status" => "success", 
                "message" => "Login successful",
                "user_id" => $row['user_id'],
                "username" => $row['username']
            ));
        } else {
            // Invalid password
            echo json_encode(array("status" => "error", "message" => "Invalid username or password"));
        }
    } else {
        // User not found
        echo json_encode(array("status" => "error", "message" => "Invalid username or password"));
    }
    
    $stmt->close();
} else {
    echo json_encode(array("status" => "error", "message" => "Only POST method allowed"));
}

$conn->close();
?>