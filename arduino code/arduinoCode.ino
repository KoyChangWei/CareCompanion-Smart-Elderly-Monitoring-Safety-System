/*
  CareCompanion - Fall, Motion & Air Comfort Monitor
  ESP32-based monitoring system for elderly care
  
  Features:
  - Fall detection using vibration sensor
  - Motion/presence detection using PIR sensor
  - Temperature and humidity monitoring using DHT11
  - OLED display for real-time information
  - Relay-controlled buzzer for emergency alerts
  - Database connectivity for data logging
  - App-controlled relay management (relay stays on until app turns it off)
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClient.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DHT.h>
#include <WebServer.h>

// WiFi credentials
const char* ssid = "Tung Sahur";        // Replace with your WiFi SSID
const char* password = "123456789";               // Replace with your WiFi password

// Database server URL
String serverName = "http://carecompanion.threelittlecar.com/";

// Web server for app communication
WebServer server(80);

// Pin Definitions
#define VIBRATION_PIN 26        // Vibration sensor (SW-420)
#define PIR_PIN 13              // PIR motion sensor
#define DHT_PIN 4               // DHT11 temperature/humidity sensor
#define RELAY_PIN 25            // Relay module for buzzer control
#define LED_PIN 2               // Built-in LED (GPIO 2) - lights up when relay is active
#define OLED_SDA 21             // OLED I2C SDA
#define OLED_SCL 22             // OLED I2C SCL

// OLED Display Configuration
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// DHT11 Configuration
#define DHT_TYPE DHT11
DHT dht(DHT_PIN, DHT_TYPE);

// System Variables
bool fallDetected = false;
bool motionDetected = false;
bool alertActive = false;
bool tempHumidityAlert = false;
bool previousMotionState = false;
bool previousRelayState = false;
bool relayTriggeredByFall = false;  // NEW: Track if relay was triggered by fall detection
bool vibrationCooldownActive = false;  // NEW: Track vibration sensor cooldown
unsigned long lastMotionTime = 0;
unsigned long lastVibrationTime = 0;
unsigned long lastVibrationDatabaseSend = 0;  // NEW: Track last database send
unsigned long lastDisplayUpdate = 0;
unsigned long alertStartTime = 0;
unsigned long lastTempHumidityCheck = 0;
unsigned long lastMotionCheck = 0;
unsigned long lastRelayCheck = 0;
unsigned long lastVibrationCheck = 0;

// Enhanced Motion Detection Variables
bool pirState = LOW;
bool lastPirState = LOW;
unsigned long motionStartTime = 0;
bool motionActive = false;
bool motionReported = false;
int motionDurationSeconds = 0;  // NEW: Store motion duration in seconds

// Threshold Settings
const float TEMP_THRESHOLD_HIGH = 28.0;    // High temperature threshold (°C)
const float TEMP_THRESHOLD_LOW = 18.0;     // Low temperature threshold (°C)
const float HUMIDITY_THRESHOLD_HIGH = 70.0; // High humidity threshold (%)
const float HUMIDITY_THRESHOLD_LOW = 30.0;  // Low humidity threshold (%)
const unsigned long INACTIVITY_THRESHOLD = 300000; // 5 minutes in milliseconds
const unsigned long DISPLAY_UPDATE_INTERVAL = 2000; // Update display every 2 seconds
const unsigned long VIBRATION_COOLDOWN = 5000; // NEW: 5-second cooldown between vibration detections

// Database timing intervals
const unsigned long DHT_SEND_INTERVAL = 15000;     // Send DHT data every 15 seconds
const unsigned long PIR_CHECK_INTERVAL = 1000;     // Check PIR sensor every 1 second for precision
const unsigned long RELAY_SEND_INTERVAL = 2000;    // Send relay data every 2 seconds (reduced from 5 seconds)
const unsigned long VS_SEND_INTERVAL = 5000;       // Send vibration data every 5 seconds if triggered

void setup() {
  // Initialize Serial Communication
  Serial.begin(115200);
  Serial.println("CareCompanion System Initializing...");
  
  // Initialize Pin Modes
  pinMode(VIBRATION_PIN, INPUT);
  pinMode(PIR_PIN, INPUT);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW); // Relay off initially
  digitalWrite(LED_PIN, LOW);   // LED off initially
  
  // Initialize I2C for OLED
  Wire.begin(OLED_SDA, OLED_SCL);
  
  // Initialize OLED Display
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("SSD1306 allocation failed");
    for(;;); // Don't proceed, loop forever
  }
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("CareCompanion");
  display.println("Initializing...");
  display.display();
  
  // Initialize DHT11 Sensor
  dht.begin();
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("Connecting WiFi...");
  display.display();
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println();
  Serial.println("WiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  
  // Setup web server for app communication
  setupWebServer();
  
  // System warm-up delay
  delay(3000);
  
  // Initial display setup
  displaySystemInfo();
  
  Serial.println("CareCompanion System Ready!");
  Serial.println("Monitoring: Falls, Motion (with duration tracking), Temperature & Humidity");
  Serial.println("Database: " + serverName);
  Serial.println("Web Server: " + WiFi.localIP().toString());
  Serial.println("========================================");
}

void loop() {
  // Handle web server requests from app
  server.handleClient();
  
  // Read vibration sensor in real-time (critical for fall detection)
  checkVibrationSensor();
  
  // Check PIR sensor every 1 second for precise motion detection
  if (millis() - lastMotionCheck >= PIR_CHECK_INTERVAL) {
    checkPIRSensor();
    lastMotionCheck = millis();
  }
  
  // Check environmental conditions every 15 seconds and send DHT data
  if (millis() - lastTempHumidityCheck >= DHT_SEND_INTERVAL) {
    checkEnvironmentalConditions();
    lastTempHumidityCheck = millis();
  }
  
  // Check relay status every 5 seconds and send if triggered
  if (millis() - lastRelayCheck >= RELAY_SEND_INTERVAL) {
    checkRelayStatus();
    lastRelayCheck = millis();
  }
  
  // Handle alerts (NO AUTOMATIC RELAY SHUTDOWN)
  manageAlerts();
  
  // Update display periodically
  if (millis() - lastDisplayUpdate >= DISPLAY_UPDATE_INTERVAL) {
    updateDisplay();
    lastDisplayUpdate = millis();
  }
  
  // Check for inactivity
  checkInactivity();
  
  delay(100); // Small delay to prevent overwhelming the system
}

void setupWebServer() {
  // CORS headers for all responses
  server.onNotFound([]() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
    server.send(404, "text/plain", "Not Found");
  });

  // Handle OPTIONS requests for CORS
  server.on("/relay_control.php", HTTP_OPTIONS, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
    server.send(200, "text/plain", "");
  });

  // App relay control endpoint
  server.on("/relay_control.php", HTTP_GET, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    
    if (server.hasArg("status")) {
      String status = server.arg("status");
      status.toUpperCase();
      
      if (status == "ON") {
        // Update database first, then immediately sync physical relay
        updateRelayData("ON");
        Serial.println("APP CONTROL: Relay ON command sent to database");
        // IMMEDIATE SYNC: Force immediate relay status check after app control
        checkRelayStatus();
        server.send(200, "text/plain", "Relay turned ON");
      } else if (status == "OFF") {
        // Update database first, then immediately sync physical relay
        updateRelayData("OFF");
        Serial.println("APP CONTROL: Relay OFF command sent to database");
        // IMMEDIATE SYNC: Force immediate relay status check after app control
        checkRelayStatus();
        server.send(200, "text/plain", "Relay turned OFF");
      } else {
        server.send(400, "text/plain", "Invalid status. Use ON or OFF");
      }
    } else {
      server.send(400, "text/plain", "Missing status parameter");
    }
  });

  // Get relay status endpoint
  server.on("/get_relay_status.php", HTTP_GET, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    bool relayState = digitalRead(RELAY_PIN);
    String status = relayState ? "ON" : "OFF";
    server.send(200, "application/json", "{\"status\":\"" + status + "\"}");
  });

  // Get latest sensor data endpoints
  server.on("/get_latest_dht.php", HTTP_GET, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    float temperature = dht.readTemperature();
    float humidity = dht.readHumidity();
    
    String json = "{";
    json += "\"temperature\":\"" + String(temperature, 1) + "\",";
    json += "\"humidity\":\"" + String(humidity, 1) + "\"";
    json += "}";
    
    server.send(200, "application/json", json);
  });

  server.on("/get_latest_pir.php", HTTP_GET, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    String status = motionDetected ? "DETECTED" : "NO_MOTION";
    String json = "{";
    json += "\"status\":\"" + status + "\",";
    json += "\"duration\":" + String(motionDurationSeconds);
    json += "}";
    server.send(200, "application/json", json);
  });

  server.on("/get_latest_vibration.php", HTTP_GET, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    String status = fallDetected ? "DETECTED" : "NO_VIBRATION";
    server.send(200, "application/json", "{\"status\":\"" + status + "\"}");
  });

  server.begin();
  Serial.println("Web server started for app communication");
}

void checkVibrationSensor() {
  int vibrationState = digitalRead(VIBRATION_PIN);
  unsigned long currentTime = millis();
  
  // Check if vibration cooldown period has ended
  if (vibrationCooldownActive && (currentTime - lastVibrationDatabaseSend >= VIBRATION_COOLDOWN)) {
    vibrationCooldownActive = false;
    fallDetected = false;
    Serial.println("VIBRATION COOLDOWN: Sensor ready for next detection");
    
    // Send "NO_VIBRATION" status to clear the detection in database
    sendVibrationData("NO_VIBRATION");
  }
  
  // Vibration sensor typically outputs HIGH when vibration is detected
  if (vibrationState == HIGH && !vibrationCooldownActive) {
    // Debounce vibration detection (avoid false positives)
    if (currentTime - lastVibrationTime > 1000) {
      fallDetected = true;
      vibrationCooldownActive = true;
      lastVibrationTime = currentTime;
      lastVibrationDatabaseSend = currentTime;
      
      Serial.println("EMERGENCY: Fall/Impact Detected! Triggering Relay Alert!");
      Serial.println("VIBRATION COOLDOWN: 5-second cooldown period started");
      
      // Immediately send fall detection to database
      sendVibrationData("DETECTED");
      
      triggerEmergencyAlert(); // Triggers relay and sets relayTriggeredByFall = true
      
      // IMMEDIATE DATABASE SYNC: Force immediate relay status check after fall detection
      Serial.println("IMMEDIATE SYNC: Checking relay status after fall detection");
      checkRelayStatus();
    }
  }
}

void checkPIRSensor() {
  // Motion detection with duration tracking
  pirState = digitalRead(PIR_PIN);
  unsigned long currentTime = millis();
  
  // Handle motion state changes
  if (pirState == HIGH && lastPirState == LOW) {
    // Motion just started
    motionStartTime = currentTime;
    motionActive = true;
    motionDetected = true;
    Serial.println("Motion started - tracking duration...");
    
    // Send motion start to database immediately
    sendPIRData("DETECTED", 0); // 0 duration for start
    
  } else if (pirState == LOW && lastPirState == HIGH) {
    // Motion just stopped - calculate duration
    if (motionActive) {
      unsigned long motionDuration = currentTime - motionStartTime;
      motionDurationSeconds = motionDuration / 1000; // Convert to seconds
      
      Serial.print("Motion ended - Duration: ");
      Serial.print(motionDurationSeconds);
      Serial.println(" seconds");
      
      // Send motion end with duration to database
      sendPIRData("NO_MOTION", motionDurationSeconds);
      
      motionDetected = false;
      previousMotionState = false;
    }
    
    // Reset motion tracking
    motionActive = false;
    motionStartTime = 0;
    
  } else if (pirState == HIGH && motionActive) {
    // Motion is ongoing - update lastMotionTime
    lastMotionTime = currentTime;
    
    // Calculate current duration for display
    unsigned long currentDuration = currentTime - motionStartTime;
    motionDurationSeconds = currentDuration / 1000;
  }
  
  // Store current state for next iteration
  lastPirState = pirState;
}

void checkEnvironmentalConditions() {
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  
  // Check if readings are valid
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("DHT Sensor Error: Failed to read data");
    return;
  }
  
  // Print current readings
  Serial.print("Environment Status - Temperature: ");
  Serial.print(temperature, 1);
  Serial.print("°C, Humidity: ");
  Serial.print(humidity, 1);
  Serial.print("%");
  
  bool environmentAlert = false;
  
  // Check temperature thresholds (alerts only, no relay)
  if (temperature > TEMP_THRESHOLD_HIGH) {
    environmentAlert = true;
    Serial.print(" [HIGH TEMP ALERT]");
  } else if (temperature < TEMP_THRESHOLD_LOW) {
    environmentAlert = true;
    Serial.print(" [LOW TEMP ALERT]");
  }
  
  // Check humidity thresholds (alerts only, no relay)
  if (humidity > HUMIDITY_THRESHOLD_HIGH) {
    environmentAlert = true;
    Serial.print(" [HIGH HUMIDITY ALERT]");
  } else if (humidity < HUMIDITY_THRESHOLD_LOW) {
    environmentAlert = true;
    Serial.print(" [LOW HUMIDITY ALERT]");
  }
  
  if (environmentAlert) {
    Serial.println(" - Please check elderly comfort!");
    tempHumidityAlert = true;
  } else {
    Serial.println(" - Normal conditions");
    tempHumidityAlert = false;
  }
  
  // Send DHT data to database every 15 seconds
  sendDHTData(temperature, humidity);
}

void checkInactivity() {
  if (lastMotionTime > 0) { // Only check if motion was detected at least once
    unsigned long timeSinceLastMotion = millis() - lastMotionTime;
    
    if (timeSinceLastMotion > INACTIVITY_THRESHOLD && !alertActive) {
      Serial.println("INACTIVITY ALERT: No motion for 5+ minutes! Please check on elderly person!");
      Serial.print("Time since last motion: ");
      Serial.print(timeSinceLastMotion / 60000);
      Serial.println(" minutes");
      // Motion alerts only - no relay trigger
    }
  }
}

void triggerEmergencyAlert() {
  alertActive = true;
  relayTriggeredByFall = true; // Mark that relay was triggered by fall detection
  alertStartTime = millis();
  digitalWrite(RELAY_PIN, HIGH); // Activate buzzer through relay
  digitalWrite(LED_PIN, HIGH);   // Turn on LED when relay is triggered
  
  Serial.println("EMERGENCY RELAY & LED ACTIVATED - Can only be turned off via app!");
  
  // Update database with relay ON status
  updateRelayData("ON");
  previousRelayState = true;
  
  // Display emergency message
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("EMERGENCY");
  display.setTextSize(1);
  display.println("Fall Detected!");
  display.println("Use App to Stop");
  display.display();
}

void manageAlerts() {
  // MODIFIED: No automatic relay shutdown
  // The relay stays on until manually turned off via the app
  if (alertActive && relayTriggeredByFall) {
    // Keep displaying emergency message and blinking LED, but don't auto-shutdown relay
    if (millis() % 1000 < 500) { // Blink effect every 500ms
      // LED blinks during emergency for visual indication
      digitalWrite(LED_PIN, HIGH);
      
      display.clearDisplay();
      display.setTextSize(2);
      display.setTextColor(SSD1306_WHITE);
      display.setCursor(0, 0);
      display.println("EMERGENCY");
      display.setTextSize(1);
      display.println("Fall Detected!");
      display.println("Use App to Stop");
      display.display();
    } else {
      // LED off during blink cycle
      digitalWrite(LED_PIN, LOW);
    }
  }
}

void updateDisplay() {
  // Don't update display during emergency (emergency display takes priority)
  if (alertActive && relayTriggeredByFall) {
    return;
  }
  
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  // Title (compact for 32px height)
  display.setCursor(0, 0);
  display.println("CareCompanion");
  
  // Environmental data (line 1)
  display.setCursor(0, 8);
  if (!isnan(temperature)) {
    display.print("T:");
    display.print(temperature, 1);
    display.print("C ");
  } else {
    display.print("T:Err ");
  }
  
  if (!isnan(humidity)) {
    display.print("H:");
    display.print(humidity, 1);
    display.print("%");
  } else {
    display.print("H:Err");
  }
  
  // Motion and alert status (line 2)
  display.setCursor(0, 16);
  if (motionActive) {
    // Show current motion duration
    display.print("Motion:");
    display.print(motionDurationSeconds);
    display.print("s");
  } else {
    display.print("Motion:");
    display.print(motionDetected ? "ACTIVE" : "NO");
  }
  
  // Environmental alert indicator
  if (tempHumidityAlert) {
    display.print(" ENV:ALERT");
  }
  
  // System status (line 3)
  display.setCursor(0, 24);
  display.print("Status: ");
  bool relayState = digitalRead(RELAY_PIN);
  if (relayState) {
    display.print("RELAY ON");
  } else if (tempHumidityAlert) {
    display.print("ENV WARNING");
  } else {
    display.print("OK");
  }
  
  display.display();
}

void displaySystemInfo() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("CareCompanion v2.0");
  display.println("Fall & Motion Monitor");
  display.println("Temp/Humidity Sensor");
  display.println("App-Controlled Relay");
  display.display();
  delay(3000);
  
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("IP: " + WiFi.localIP().toString());
  display.println("Database Connected");
  display.println("System Ready!");
  display.println("Monitoring Active...");
  display.display();
  delay(2000);
}

// Check relay status and sync with database
void checkRelayStatus() {
  // Get relay status from database
  String databaseStatus = getRelayStatusFromDatabase();
  
  if (databaseStatus != "") {
    bool shouldBeOn = (databaseStatus == "ON");
    bool currentRelayState = digitalRead(RELAY_PIN);
    
    // Sync physical relay and LED with database status
    if (shouldBeOn && !currentRelayState) {
      digitalWrite(RELAY_PIN, HIGH);
      digitalWrite(LED_PIN, HIGH);   // Turn on LED with relay
      previousRelayState = true;
      Serial.println("DATABASE SYNC: Relay & LED turned ON to match database");
    } else if (!shouldBeOn && currentRelayState) {
      digitalWrite(RELAY_PIN, LOW);
      digitalWrite(LED_PIN, LOW);    // Turn off LED with relay
      previousRelayState = false;
      alertActive = false; // Clear alert state when turned off
      fallDetected = false; // Clear fall detection state
      relayTriggeredByFall = false; // Reset fall trigger flag
      Serial.println("DATABASE SYNC: Relay & LED turned OFF to match database");
    }
  }
}

// Get relay status from database
String getRelayStatusFromDatabase() {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    
    String url = serverName + "get_relay_status.php";
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode == 200) {
      String response = http.getString();
      Serial.println("Relay Status Response: " + response);
      
      // Parse JSON response to extract status
      int statusStart = response.indexOf("\"status\":\"") + 10;
      int statusEnd = response.indexOf("\"", statusStart);
      
      if (statusStart > 9 && statusEnd > statusStart) {
        String status = response.substring(statusStart, statusEnd);
        http.end();
        return status;
      }
    } else {
      Serial.println("Relay Status HTTP Error: " + String(httpCode));
    }
    
    http.end();
  } else {
    Serial.println("WiFi not connected - cannot get relay status from database");
  }
  
  return ""; // Return empty string on error
}

// Send DHT data to database
void sendDHTData(float temperature, float humidity) {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    
    String url = serverName + "dht_insert.php?temp=" + String(temperature, 1) + "&humidity=" + String(humidity, 1);
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String response = http.getString();
      Serial.println("DHT Response: " + response);
    } else {
      Serial.println("DHT HTTP Error: " + String(httpCode));
    }
    
    http.end();
  } else {
    Serial.println("WiFi not connected - cannot send DHT data");
  }
}

// Send PIR data to database
void sendPIRData(String status, int durationSeconds) {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    
    String url = serverName + "pir_insert.php?status=" + status + "&duration=" + String(durationSeconds);
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String response = http.getString();
      Serial.println("PIR Response: " + response);
    } else {
      Serial.println("PIR HTTP Error: " + String(httpCode));
    }
    
    http.end();
  } else {
    Serial.println("WiFi not connected - cannot send PIR data");
  }
}

// Update Relay data in database
void updateRelayData(String status) {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    
    String url = serverName + "relay_update.php?status=" + status;
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String response = http.getString();
      Serial.println("Relay Update Response: " + response);
    } else {
      Serial.println("Relay Update HTTP Error: " + String(httpCode));
    }
    
    http.end();
  } else {
    Serial.println("WiFi not connected - cannot update Relay data");
  }
}

// Send Vibration sensor data to database
void sendVibrationData(String status) {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    
    String url = serverName + "vs_insert.php?status=" + status;
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String response = http.getString();
      Serial.println("Vibration Response: " + response);
    } else {
      Serial.println("Vibration HTTP Error: " + String(httpCode));
    }
    
    http.end();
  } else {
    Serial.println("WiFi not connected - cannot send Vibration data");
  }
}

