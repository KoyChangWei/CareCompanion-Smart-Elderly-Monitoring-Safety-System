// PIR Motion Detection with Duration Filtering
// This code ensures motion is detected for at least 10 seconds before reporting

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// Pin definitions
#define PIR_PIN 2  // PIR sensor pin
#define LED_PIN 13 // Built-in LED for visual feedback

// Motion detection variables
bool pirState = LOW;
bool lastPirState = LOW;
unsigned long motionStartTime = 0;
unsigned long lastMotionReport = 0;
bool motionActive = false;
bool motionReported = false;

// Timing constants
const unsigned long MOTION_DURATION_THRESHOLD = 10000; // 10 seconds in milliseconds
const unsigned long MOTION_REPORT_INTERVAL = 30000;    // Report every 30 seconds during continuous motion
const unsigned long NO_MOTION_TIMEOUT = 5000;          // 5 seconds of no motion to reset

// WiFi and server configuration
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* serverURL = "http://your-server.com/api/pir";

void setup() {
  Serial.begin(115200);
  
  // Initialize pins
  pinMode(PIR_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("WiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  
  Serial.println("PIR Motion Detection with Duration Filtering Started");
  Serial.println("Motion must last 10+ seconds to be reported as activity");
}

void loop() {
  // Read PIR sensor
  pirState = digitalRead(PIR_PIN);
  unsigned long currentTime = millis();
  
  // Handle motion state changes
  if (pirState == HIGH && lastPirState == LOW) {
    // Motion just started
    motionStartTime = currentTime;
    motionActive = true;
    motionReported = false;
    digitalWrite(LED_PIN, HIGH); // Turn on LED for visual feedback
    Serial.println("Motion detected - starting timer...");
    
  } else if (pirState == LOW && lastPirState == HIGH) {
    // Motion just stopped
    digitalWrite(LED_PIN, LOW); // Turn off LED
    
    if (motionActive) {
      unsigned long motionDuration = currentTime - motionStartTime;
      Serial.print("Motion stopped. Duration: ");
      Serial.print(motionDuration);
      Serial.println(" ms");
      
      // If motion was long enough and reported, send "motion ended" status
      if (motionReported) {
        reportMotionEnd();
      }
    }
    
    // Reset motion tracking
    motionActive = false;
    motionReported = false;
    
  } else if (pirState == HIGH && motionActive) {
    // Motion is ongoing - check if it's been long enough
    unsigned long motionDuration = currentTime - motionStartTime;
    
    if (motionDuration >= MOTION_DURATION_THRESHOLD && !motionReported) {
      // Motion has lasted 10+ seconds - report it as activity
      Serial.print("Sustained motion detected! Duration: ");
      Serial.print(motionDuration);
      Serial.println(" ms - Reporting as activity");
      
      reportActivity();
      motionReported = true;
      lastMotionReport = currentTime;
      
    } else if (motionReported && (currentTime - lastMotionReport >= MOTION_REPORT_INTERVAL)) {
      // Send periodic updates during long motion periods
      Serial.println("Continuous motion - sending update");
      reportContinuousMotion();
      lastMotionReport = currentTime;
    }
  }
  
  // Store current state for next iteration
  lastPirState = pirState;
  
  // Small delay to prevent excessive polling
  delay(100);
}

void reportActivity() {
  Serial.println("📊 Reporting sustained motion activity to server...");
  
  // Create JSON payload
  StaticJsonDocument<200> doc;
  doc["sensor_type"] = "PIR";
  doc["status"] = "DETECTED";
  doc["activity_type"] = "SUSTAINED_MOTION";
  doc["duration_seconds"] = (millis() - motionStartTime) / 1000;
  doc["timestamp"] = millis();
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  // Send to server
  sendToServer(jsonString);
}

void reportContinuousMotion() {
  Serial.println("📊 Reporting continuous motion to server...");
  
  // Create JSON payload
  StaticJsonDocument<200> doc;
  doc["sensor_type"] = "PIR";
  doc["status"] = "CONTINUOUS";
  doc["activity_type"] = "ONGOING_MOTION";
  doc["duration_seconds"] = (millis() - motionStartTime) / 1000;
  doc["timestamp"] = millis();
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  // Send to server
  sendToServer(jsonString);
}

void reportMotionEnd() {
  Serial.println("📊 Reporting motion end to server...");
  
  unsigned long totalDuration = millis() - motionStartTime;
  
  // Create JSON payload
  StaticJsonDocument<200> doc;
  doc["sensor_type"] = "PIR";
  doc["status"] = "NO_MOTION";
  doc["activity_type"] = "MOTION_ENDED";
  doc["total_duration_seconds"] = totalDuration / 1000;
  doc["timestamp"] = millis();
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  // Send to server
  sendToServer(jsonString);
}

void sendToServer(String jsonData) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverURL);
    http.addHeader("Content-Type", "application/json");
    
    int httpResponseCode = http.POST(jsonData);
    
    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.print("✅ Server response: ");
      Serial.println(response);
    } else {
      Serial.print("❌ HTTP Error: ");
      Serial.println(httpResponseCode);
    }
    
    http.end();
  } else {
    Serial.println("❌ WiFi not connected - cannot send data");
  }
} 