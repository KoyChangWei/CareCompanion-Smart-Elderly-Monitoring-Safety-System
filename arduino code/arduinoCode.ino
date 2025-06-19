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
bool temperatureAlert = false;  // NEW: Separate temperature alert flag
bool humidityAlert = false;     // NEW: Separate humidity alert flag
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

// PIR Database Send Variables
unsigned long lastPIRDatabaseSend = 0;
int accumulatedMotionSeconds = 0;  // Total motion seconds in current 5-second window
bool motionDetectedInWindow = false;  // Track if any motion was detected in current 5-second window
String currentMotionStatus = "NO_MOTION";  // Current status to send to database

// Enhanced motion tracking for longer activities
unsigned long continuousMotionStartTime = 0;  // When current continuous motion session started
bool inContinuousMotion = false;  // Track if we're in a continuous motion session
int totalContinuousMotionSeconds = 0;  // Total seconds of current continuous motion session

// Fall risk assessment pattern analysis
int motionBurstsInWindow = 0;  // Number of motion start/stop cycles in 5-second window
int unsteadyMotionCount = 0;   // Short, erratic motions (< 2s) - potential unsteadiness
int transferMotionCount = 0;   // Medium motions (2-8s) - getting up/sitting (fall risk moments)
int normalMotionCount = 0;     // Longer motions (> 8s) - steady movement
unsigned long lastMotionEndTime = 0;  // When last motion ended
String fallRiskLevel = "SAFE";        // SAFE, LOW_RISK, MODERATE_RISK, HIGH_RISK, CRITICAL

// Threshold Settings
const float TEMP_THRESHOLD_HIGH = 28.0;    // High temperature threshold (°C)
const float TEMP_THRESHOLD_LOW = 18.0;     // Low temperature threshold (°C)
const float HUMIDITY_THRESHOLD_HIGH = 70.0; // High humidity threshold (%)
const float HUMIDITY_THRESHOLD_LOW = 30.0;  // Low humidity threshold (%)

// NEW: Dynamic threshold variables from database (High/Low ranges)
float dynamicHighTempThreshold = 28.0;    // Default high temp threshold
float dynamicLowTempThreshold = 18.0;     // Default low temp threshold
float dynamicHighHumThreshold = 70.0;     // Default high humidity threshold
float dynamicLowHumThreshold = 30.0;      // Default low humidity threshold
unsigned long lastThresholdFetch = 0;
const unsigned long THRESHOLD_FETCH_INTERVAL = 30000; // Fetch thresholds every 30 seconds
const unsigned long INACTIVITY_THRESHOLD = 300000; // 5 minutes in milliseconds
const unsigned long DISPLAY_UPDATE_INTERVAL = 2000; // Update display every 2 seconds
const unsigned long VIBRATION_COOLDOWN = 5000; // NEW: 5-second cooldown between vibration detections

// Database timing intervals
const unsigned long DHT_SEND_INTERVAL = 15000;     // Send DHT data every 15 seconds
const unsigned long PIR_CHECK_INTERVAL = 1000;     // Check PIR sensor every 1 second for precision
const unsigned long PIR_SEND_INTERVAL = 5000;      // Send PIR data every 5 seconds to prevent HTTP overload
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
  
  // Fetch initial thresholds from database
  Serial.println("Fetching initial thresholds from database...");
  fetchThresholdsFromDatabase();
  
  Serial.println("CareCompanion System Ready!");
  Serial.println("Monitoring: Falls, Motion (with duration tracking), Temperature & Humidity");
  Serial.println("Dynamic Thresholds: Temp=" + String(dynamicLowTempThreshold, 1) + "-" + String(dynamicHighTempThreshold, 1) + "°C, Hum=" + String(dynamicLowHumThreshold, 1) + "-" + String(dynamicHighHumThreshold, 1) + "%");
  Serial.println("Database: " + serverName);
  Serial.println("Web Server: " + WiFi.localIP().toString());
  Serial.println("========================================");
}

void loop() {
  // Handle web server requests from app
  server.handleClient();
  
  // Fetch dynamic thresholds from database every 30 seconds
  if (millis() - lastThresholdFetch >= THRESHOLD_FETCH_INTERVAL) {
    fetchThresholdsFromDatabase();
    lastThresholdFetch = millis();
  }
  
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
  
  // Send PIR data to database every 5 seconds
  if (millis() - lastPIRDatabaseSend >= PIR_SEND_INTERVAL) {
    sendPIRDataBatched();
    lastPIRDatabaseSend = millis();
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
    json += "\"humidity\":\"" + String(humidity, 1) + "\",";
    json += "\"highTempThreshold\":\"" + String(dynamicHighTempThreshold, 1) + "\",";
    json += "\"lowTempThreshold\":\"" + String(dynamicLowTempThreshold, 1) + "\",";
    json += "\"highHumThreshold\":\"" + String(dynamicHighHumThreshold, 1) + "\",";
    json += "\"lowHumThreshold\":\"" + String(dynamicLowHumThreshold, 1) + "\",";
    json += "\"tempAlert\":" + String(temperatureAlert ? "true" : "false") + ",";
    json += "\"humAlert\":" + String(humidityAlert ? "true" : "false");
    json += "}";
    
    server.send(200, "application/json", json);
  });

  // Get current thresholds endpoint
  server.on("/get_thresholds.php", HTTP_GET, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    String json = "{";
    json += "\"high_temp_threshold\":\"" + String(dynamicHighTempThreshold, 1) + "\",";
    json += "\"low_temp_threshold\":\"" + String(dynamicLowTempThreshold, 1) + "\",";
    json += "\"high_hum_threshold\":\"" + String(dynamicHighHumThreshold, 1) + "\",";
    json += "\"low_hum_threshold\":\"" + String(dynamicLowHumThreshold, 1) + "\"";
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
  // Motion detection with enhanced duration tracking for longer activities
  pirState = digitalRead(PIR_PIN);
  unsigned long currentTime = millis();
  
  // Handle motion state changes
  if (pirState == HIGH && lastPirState == LOW) {
    // Motion just started
    motionStartTime = currentTime;
    motionActive = true;
    motionDetected = true;
    motionDetectedInWindow = true;  // Mark that motion was detected in this 5-second window
    
    // Check if this is start of new continuous motion session
    if (!inContinuousMotion) {
      continuousMotionStartTime = currentTime;
      inContinuousMotion = true;
      totalContinuousMotionSeconds = 0;
      Serial.println("NEW CONTINUOUS MOTION SESSION started - tracking total duration...");
    } else {
      Serial.println("Motion resumed within continuous session...");
    }
    
  } else if (pirState == LOW && lastPirState == HIGH) {
    // Motion just stopped - calculate duration and add to accumulator
    if (motionActive && motionStartTime > 0) {
      unsigned long motionDuration = currentTime - motionStartTime;
      int durationSeconds = motionDuration / 1000; // Convert to seconds
      
      // Add to accumulated motion seconds for this 5-second window
      accumulatedMotionSeconds += durationSeconds;
      
      // Count motion bursts in this window
      motionBurstsInWindow++;
      
      // Classify motion for fall risk assessment
      if (durationSeconds < 2) {
        unsteadyMotionCount++;  // Short, erratic movements - potential unsteadiness/balance issues
      } else if (durationSeconds <= 8) {
        transferMotionCount++;  // Transfer movements (getting up/sitting) - high fall risk moments
      } else {
        normalMotionCount++;    // Steady, longer movements - safer mobility
      }
      
      // Update total continuous motion duration
      if (inContinuousMotion) {
        totalContinuousMotionSeconds += durationSeconds;
      }
      
      lastMotionEndTime = currentTime;
      
      Serial.print("Motion ended - Duration: ");
      Serial.print(durationSeconds);
      Serial.print("s [");
      if (durationSeconds < 2) Serial.print("UNSTEADY/BALANCE_ISSUE");
      else if (durationSeconds <= 8) Serial.print("TRANSFER/FALL_RISK");
      else Serial.print("STEADY/SAFE");
      Serial.print("] (Window: ");
      Serial.print(accumulatedMotionSeconds);
      Serial.print("s, Bursts: ");
      Serial.print(motionBurstsInWindow);
      Serial.print(", Session: ");
      Serial.print(totalContinuousMotionSeconds);
      Serial.println("s)");
      
      motionDetected = false;
      previousMotionState = false;
    }
    
    // Reset motion tracking
    motionActive = false;
    motionStartTime = 0;
    
  } else if (pirState == HIGH && motionActive) {
    // Motion is ongoing - update lastMotionTime and current duration for display
    lastMotionTime = currentTime;
    
    // Calculate current duration for display
    unsigned long currentDuration = currentTime - motionStartTime;
    motionDurationSeconds = currentDuration / 1000;
  }
  
  // Check if continuous motion session should end (no motion for 3+ seconds)
  if (inContinuousMotion && !motionActive && (currentTime - lastMotionTime > 3000)) {
    // End continuous motion session
    unsigned long totalSessionDuration = currentTime - continuousMotionStartTime;
    int totalSessionSeconds = totalSessionDuration / 1000;
    
    Serial.print("CONTINUOUS MOTION SESSION ENDED - Total duration: ");
    Serial.print(totalSessionSeconds);
    Serial.print(" seconds (Active motion: ");
    Serial.print(totalContinuousMotionSeconds);
    Serial.println(" seconds)");
    
    inContinuousMotion = false;
    continuousMotionStartTime = 0;
    totalContinuousMotionSeconds = 0;
  }
  
  // Assess fall risk based on motion patterns
  assessFallRisk(currentTime);
  
  // Update current motion status for database
  if (motionDetectedInWindow || motionActive) {
    currentMotionStatus = "DETECTED";
  } else {
    currentMotionStatus = "NO_MOTION";
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
  
  // Print current readings with dynamic thresholds
  Serial.print("Environment Status - Temperature: ");
  Serial.print(temperature, 1);
  Serial.print("°C (Range: ");
  Serial.print(dynamicLowTempThreshold, 1);
  Serial.print("-");
  Serial.print(dynamicHighTempThreshold, 1);
  Serial.print("°C), Humidity: ");
  Serial.print(humidity, 1);
  Serial.print("% (Range: ");
  Serial.print(dynamicLowHumThreshold, 1);
  Serial.print("-");
  Serial.print(dynamicHighHumThreshold, 1);
  Serial.print("%)");
  
  // Reset alert flags
  temperatureAlert = false;
  humidityAlert = false;
  String tempAlertType = "";
  String humAlertType = "";
  
  // Check temperature thresholds (both high and low)
  if (temperature > dynamicHighTempThreshold) {
    temperatureAlert = true;
    tempAlertType = "HIGH";
    Serial.print(" [TEMP HIGH ALERT: ");
    Serial.print(temperature - dynamicHighTempThreshold, 1);
    Serial.print("°C ABOVE HIGH THRESHOLD]");
    
    // Trigger high temperature alert
    triggerTemperatureAlert(temperature, "HIGH", dynamicHighTempThreshold);
  } else if (temperature < dynamicLowTempThreshold) {
    temperatureAlert = true;
    tempAlertType = "LOW";
    Serial.print(" [TEMP LOW ALERT: ");
    Serial.print(dynamicLowTempThreshold - temperature, 1);
    Serial.print("°C BELOW LOW THRESHOLD]");
    
    // Trigger low temperature alert
    triggerTemperatureAlert(temperature, "LOW", dynamicLowTempThreshold);
  }
  
  // Check humidity thresholds (both high and low)
  if (humidity > dynamicHighHumThreshold) {
    humidityAlert = true;
    humAlertType = "HIGH";
    Serial.print(" [HUMIDITY HIGH ALERT: ");
    Serial.print(humidity - dynamicHighHumThreshold, 1);
    Serial.print("% ABOVE HIGH THRESHOLD]");
    
    // Trigger high humidity alert
    triggerHumidityAlert(humidity, "HIGH", dynamicHighHumThreshold);
  } else if (humidity < dynamicLowHumThreshold) {
    humidityAlert = true;
    humAlertType = "LOW";
    Serial.print(" [HUMIDITY LOW ALERT: ");
    Serial.print(dynamicLowHumThreshold - humidity, 1);
    Serial.print("% BELOW LOW THRESHOLD]");
    
    // Trigger low humidity alert
    triggerHumidityAlert(humidity, "LOW", dynamicLowHumThreshold);
  }
  
  // Update combined alert flag
  tempHumidityAlert = (temperatureAlert || humidityAlert);
  
  if (tempHumidityAlert) {
    Serial.print(" - THRESHOLD EXCEEDED! ");
    if (temperatureAlert) Serial.print("TEMP " + tempAlertType + " ");
    if (humidityAlert) Serial.print("HUM " + humAlertType + " ");
    Serial.println("Please check elderly comfort!");
  } else {
    Serial.println(" - Normal conditions (within thresholds)");
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
  if (temperatureAlert && humidityAlert) {
    display.print(" T&H:ALERT");
  } else if (temperatureAlert) {
    display.print(" T:ALERT");
  } else if (humidityAlert) {
    display.print(" H:ALERT");
  }
  
  // System status (line 3)
  display.setCursor(0, 24);
  display.print("Status: ");
  bool relayState = digitalRead(RELAY_PIN);
  if (relayState) {
    display.print("RELAY ON");
  } else if (temperatureAlert) {
    display.print("TEMP ALERT");
  } else if (humidityAlert) {
    display.print("HUM ALERT");
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

// Send PIR data to database (batched every 5 seconds with enhanced data)
void sendPIRDataBatched() {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    
    // If motion is currently active, add current motion duration to accumulator
    int totalMotionSeconds = accumulatedMotionSeconds;
    if (motionActive && motionStartTime > 0) {
      unsigned long currentDuration = millis() - motionStartTime;
      totalMotionSeconds += (currentDuration / 1000);
    }
    
    // Calculate continuous session duration if active
    int continuousSessionDuration = 0;
    if (inContinuousMotion && continuousMotionStartTime > 0) {
      unsigned long sessionDuration = millis() - continuousMotionStartTime;
      continuousSessionDuration = sessionDuration / 1000;
    }
    
    // Determine what to send to database
    String statusToSend = currentMotionStatus;
    int durationToSend = totalMotionSeconds;  // Motion seconds in this 5-second window
    
    // Enhanced logging with fall risk assessment
    Serial.print("PIR FALL RISK ANALYSIS - Level: ");
    Serial.print(fallRiskLevel);
    Serial.print(", Window motion: ");
    Serial.print(durationToSend);
    Serial.print("s, Bursts: ");
    Serial.print(motionBurstsInWindow);
    Serial.print(" (Unsteady: ");
    Serial.print(unsteadyMotionCount);
    Serial.print(", Transfer: ");
    Serial.print(transferMotionCount);
    Serial.print(", Steady: ");
    Serial.print(normalMotionCount);
    Serial.print(")");
    
    if (inContinuousMotion) {
      Serial.print(", Continuous session: ");
      Serial.print(continuousSessionDuration);
      Serial.print("s total");
    }
    Serial.println();
    
    // Send to database (keeping current table structure but with fall risk encoding)
    // Encode fall risk level in duration: 
    // - Actual motion seconds + fall risk indicator
    int encodedDuration = durationToSend;
    if (durationToSend > 0) {
      // Add fall risk multiplier to preserve information while keeping table structure
      if (fallRiskLevel == "SAFE") encodedDuration = durationToSend + 1000;         // 1000+ = safe movement
      else if (fallRiskLevel == "LOW_RISK") encodedDuration = durationToSend + 2000; // 2000+ = low fall risk
      else if (fallRiskLevel == "MODERATE_RISK") encodedDuration = durationToSend + 3000; // 3000+ = moderate fall risk
      else if (fallRiskLevel == "HIGH_RISK") encodedDuration = durationToSend + 4000; // 4000+ = high fall risk  
      else if (fallRiskLevel == "CRITICAL") encodedDuration = durationToSend + 5000; // 5000+ = critical fall risk
    }
    
    String url = serverName + "pir_insert.php?status=" + statusToSend + "&duration=" + String(encodedDuration);
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String response = http.getString();
      if (inContinuousMotion) {
        Serial.print("PIR Session Response (Window: ");
        Serial.print(durationToSend);
        Serial.print("s, Session Total: ");
        Serial.print(continuousSessionDuration);
        Serial.print("s): ");
      } else {
        Serial.print("PIR Response (");
        Serial.print(statusToSend);
        Serial.print(", ");
        Serial.print(durationToSend);
        Serial.print("s): ");
      }
      Serial.println(response);
    } else {
      Serial.println("PIR HTTP Error: " + String(httpCode));
    }
    
    http.end();
    
    // Reset accumulator for next 5-second window (but keep continuous motion tracking active)
    accumulatedMotionSeconds = 0;
    motionDetectedInWindow = false;
    motionBurstsInWindow = 0;
    unsteadyMotionCount = 0;
    transferMotionCount = 0;
    normalMotionCount = 0;
    
    if (inContinuousMotion) {
      Serial.print("PIR window reset - Next 5s window, Session continues (");
      Serial.print(continuousSessionDuration);
      Serial.println("s total)");
    } else {
      Serial.println("PIR window reset - Ready for next activity analysis");
    }
    
  } else {
    Serial.println("WiFi not connected - cannot send PIR data");
  }
}

// Send PIR data to database (legacy function for compatibility)
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

// Fetch dynamic thresholds from database
void fetchThresholdsFromDatabase() {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    
    String url = serverName + "get_thresholds.php";
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode == 200) {
      String response = http.getString();
      Serial.println("Thresholds Response: " + response);
      
      // Parse JSON response to extract all threshold values
      int highTempStart = response.indexOf("\"high_temp_threshold\":\"") + 24;
      int highTempEnd = response.indexOf("\"", highTempStart);
      int lowTempStart = response.indexOf("\"low_temp_threshold\":\"") + 23;
      int lowTempEnd = response.indexOf("\"", lowTempStart);
      int highHumStart = response.indexOf("\"high_hum_threshold\":\"") + 23;
      int highHumEnd = response.indexOf("\"", highHumStart);
      int lowHumStart = response.indexOf("\"low_hum_threshold\":\"") + 22;
      int lowHumEnd = response.indexOf("\"", lowHumStart);
      
      if (highTempStart > 23 && highTempEnd > highTempStart && 
          lowTempStart > 22 && lowTempEnd > lowTempStart &&
          highHumStart > 22 && highHumEnd > highHumStart &&
          lowHumStart > 21 && lowHumEnd > lowHumStart) {
        
        float newHighTempThreshold = response.substring(highTempStart, highTempEnd).toFloat();
        float newLowTempThreshold = response.substring(lowTempStart, lowTempEnd).toFloat();
        float newHighHumThreshold = response.substring(highHumStart, highHumEnd).toFloat();
        float newLowHumThreshold = response.substring(lowHumStart, lowHumEnd).toFloat();
        
        // Update thresholds if they've changed
        if (newHighTempThreshold != dynamicHighTempThreshold || 
            newLowTempThreshold != dynamicLowTempThreshold ||
            newHighHumThreshold != dynamicHighHumThreshold || 
            newLowHumThreshold != dynamicLowHumThreshold) {
          
          dynamicHighTempThreshold = newHighTempThreshold;
          dynamicLowTempThreshold = newLowTempThreshold;
          dynamicHighHumThreshold = newHighHumThreshold;
          dynamicLowHumThreshold = newLowHumThreshold;
          
          Serial.println("Thresholds updated successfully:");
          Serial.print("  Temperature Range: ");
          Serial.print(dynamicLowTempThreshold, 1);
          Serial.print(" - ");
          Serial.print(dynamicHighTempThreshold, 1);
          Serial.println("°C");
          Serial.print("  Humidity Range: ");
          Serial.print(dynamicLowHumThreshold, 1);
          Serial.print(" - ");
          Serial.print(dynamicHighHumThreshold, 1);
          Serial.println("%");
        }
      } else {
        Serial.println("Error parsing threshold response - using current values");
      }
    } else {
      Serial.println("Thresholds HTTP Error: " + String(httpCode) + " - Using default thresholds");
    }
    
    http.end();
  } else {
    Serial.println("WiFi not connected - cannot fetch thresholds from database");
  }
}

// Trigger temperature alert (with high/low type)
void triggerTemperatureAlert(float temperature, String alertType, float thresholdValue) {
  Serial.print("TEMPERATURE ALERT TRIGGERED! Current: ");
  Serial.print(temperature, 1);
  Serial.print("°C " + alertType + " threshold: ");
  Serial.print(thresholdValue, 1);
  Serial.println("°C");
  
  // Send temperature alert to database/logging system
  sendTemperatureAlert(temperature, alertType, thresholdValue);
}

// Trigger humidity alert (with high/low type)
void triggerHumidityAlert(float humidity, String alertType, float thresholdValue) {
  Serial.print("HUMIDITY ALERT TRIGGERED! Current: ");
  Serial.print(humidity, 1);
  Serial.print("% " + alertType + " threshold: ");
  Serial.print(thresholdValue, 1);
  Serial.println("%");
  
  // Send humidity alert to database/logging system
  sendHumidityAlert(humidity, alertType, thresholdValue);
}

// Send temperature alert to database
void sendTemperatureAlert(float temperature, String alertType, float thresholdValue) {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    
    String url = serverName + "temp_alert_insert.php?temperature=" + String(temperature, 1) + 
                "&alert_type=" + alertType + "&threshold_value=" + String(thresholdValue, 1);
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String response = http.getString();
      Serial.println("Temperature Alert Response: " + response);
    } else {
      Serial.println("Temperature Alert HTTP Error: " + String(httpCode));
    }
    
    http.end();
  }
}

// Send humidity alert to database
void sendHumidityAlert(float humidity, String alertType, float thresholdValue) {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    
    String url = serverName + "hum_alert_insert.php?humidity=" + String(humidity, 1) + 
                "&alert_type=" + alertType + "&threshold_value=" + String(thresholdValue, 1);
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String response = http.getString();
      Serial.println("Humidity Alert Response: " + response);
    } else {
      Serial.println("Humidity Alert HTTP Error: " + String(httpCode));
    }
    
    http.end();
  }
}

// Assess fall risk based on motion patterns for elderly care
void assessFallRisk(unsigned long currentTime) {
  // Calculate time since last motion ended
  unsigned long timeSinceLastMotion = 0;
  if (lastMotionEndTime > 0) {
    timeSinceLastMotion = currentTime - lastMotionEndTime;
  }
  
  // Assess fall risk based on motion patterns
  if (accumulatedMotionSeconds == 0 && !motionActive) {
    // No motion in current window
    if (timeSinceLastMotion > 1800000) {  // No motion for 30+ minutes - potential emergency
      fallRiskLevel = "CRITICAL";  // May have fallen and unable to move
    } else if (timeSinceLastMotion > 600000) {  // No motion for 10+ minutes  
      fallRiskLevel = "HIGH_RISK"; // Unusually long inactivity - check needed
    } else {
      fallRiskLevel = "SAFE";      // Normal rest/sleep
    }
  } else {
    // Motion detected - assess fall risk based on pattern
    if (unsteadyMotionCount >= 3 && transferMotionCount == 0) {
      // Multiple short, erratic movements - balance issues, unsteadiness
      fallRiskLevel = "HIGH_RISK";
    } else if (motionBurstsInWindow >= 5) {
      // Very frequent start/stop motions - struggling, difficulty moving
      fallRiskLevel = "HIGH_RISK";
    } else if (transferMotionCount >= 2 && unsteadyMotionCount >= 1) {
      // Multiple transfer attempts with some unsteadiness - fall risk
      fallRiskLevel = "MODERATE_RISK";
    } else if (transferMotionCount >= 1) {
      // Transfer movements (getting up/sitting) - inherently risky for elderly
      fallRiskLevel = "LOW_RISK";
    } else if (unsteadyMotionCount >= 2) {
      // Some unsteady movements but not excessive
      fallRiskLevel = "LOW_RISK";
    } else if (normalMotionCount > 0 && unsteadyMotionCount == 0) {
      // Steady, controlled movement - good mobility
      fallRiskLevel = "SAFE";
    } else {
      // Default for unclear patterns
      fallRiskLevel = "LOW_RISK";
    }
  }
  
  // Enhanced logging for fall risk assessment
  if (accumulatedMotionSeconds > 0 || motionActive || fallRiskLevel != "SAFE") {
    Serial.print("FALL RISK ASSESSOR - Level: ");
    Serial.print(fallRiskLevel);
    Serial.print(" (Motion: ");
    Serial.print(accumulatedMotionSeconds);
    Serial.print("s, Bursts: ");
    Serial.print(motionBurstsInWindow);
    Serial.print(", Pattern: Unsteady:");
    Serial.print(unsteadyMotionCount);
    Serial.print(" Transfer:");
    Serial.print(transferMotionCount);
    Serial.print(" Steady:");
    Serial.print(normalMotionCount);
    Serial.print(", Inactive: ");
    Serial.print(timeSinceLastMotion / 1000);
    Serial.println("s)");
    
    // Alert for high risk situations
    if (fallRiskLevel == "HIGH_RISK" || fallRiskLevel == "CRITICAL") {
      Serial.println("⚠️  FALL RISK ALERT: Elderly person may need assistance!");
    } else if (fallRiskLevel == "MODERATE_RISK") {
      Serial.println("⚠️  CAUTION: Monitor elderly person closely");
    }
  }
}

