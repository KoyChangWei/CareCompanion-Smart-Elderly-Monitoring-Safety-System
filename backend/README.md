# Backend Setup for User Authentication

This directory contains the PHP backend files for user authentication that work with the new `user_tbl` table structure.

## Table Structure

The `user_tbl` table has the following columns:
- `user_id` (int, auto-increment, primary key)
- `username` (varchar(50), unique)
- `password` (varchar(255), hashed)
- `timestamp` (timestamp, default current timestamp)

## Files

1. **login.php** - Handles user login authentication
2. **register.php** - Handles user registration
3. **create_user_table.sql** - SQL script to create the user_tbl table
4. **README.md** - This file

## Setup Instructions

### 1. Database Setup

1. Run the SQL script to create the table:
   ```sql
   -- Copy and run the contents of create_user_table.sql in your MySQL database
   ```

2. The database connection is handled by the existing `dbconnect.php` file which contains:
   ```php
   $servername = "localhost";
   $username   = "threenqs_koy_chang_wei";
   $password   = "6gspmd70(**O";
   $dbname     = "threenqs_carecompanion";
   ```
   
   Both `login.php` and `register.php` use `include_once("dbconnect.php")` for database connectivity.

### 2. Server Setup

1. Upload these PHP files to your web server (where your carecompanion.threelittlecar.com domain points)
2. Make sure the files are accessible at:
   - `http://carecompanion.threelittlecar.com/login.php`
   - `http://carecompanion.threelittlecar.com/register.php`

### 3. Testing

You can test the endpoints using curl or Postman:

**Register a new user:**
```bash
curl -X POST http://carecompanion.threelittlecar.com/register.php \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=password123"
```

**Login:**
```bash
curl -X POST http://carecompanion.threelittlecar.com/login.php \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=password123"
```

## Security Features

- Passwords are hashed using PHP's `password_hash()` function
- SQL injection protection using prepared statements
- Input validation for username and password requirements
- Duplicate username prevention
- CORS headers for cross-origin requests

## Flutter App Changes

The Flutter app has been updated to:
- Use `username` instead of `email` for authentication
- Send requests to the correct endpoints
- Handle the new response format
- Work with the new table structure

## Test User

A test user is included in the SQL script:
- Username: `testuser`
- Password: `password123`

You can use this for initial testing of the login functionality. 