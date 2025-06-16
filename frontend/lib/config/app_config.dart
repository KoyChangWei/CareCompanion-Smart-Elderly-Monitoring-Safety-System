class MyConfig {
  // Server configuration - Update this with your actual server URL
  static const String server = 'http://carecompanion.threelittlecar.com/';
  
  
  // API endpoints
  static const String getLatestDhtEndpoint = 'get_latest_dht.php';
  static const String getLatestPirEndpoint = 'get_latest_pir.php';
  static const String getLatestVibrationEndpoint = 'get_latest_vibration.php';
  static const String getRelayStatusEndpoint = 'get_relay_status.php';
  static const String relayControlEndpoint = 'relay_control.php';
  static const String getDhtHistoryEndpoint = 'get_dht_history.php';
  static const String getActivityHistoryEndpoint = 'get_activity_history.php';
  
  // App settings
  static const int dataRefreshIntervalSeconds = 5;
  static const int relayCheckIntervalSeconds = 3;
  static const int httpTimeoutSeconds = 10;
  static const int maxHistoryRecords = 100;
  
  // Threshold default values (hardcoded since no database table exists)
  static const double defaultTempHigh = 28.0;
  static const double defaultTempLow = 18.0;
  static const double defaultHumidityHigh = 70.0;
  static const double defaultHumidityLow = 30.0;
  
  // Chart settings
  static const int defaultChartDays = 7;
  static const int maxChartDays = 30;
  
  // Timezone settings
  static const String timeZone = 'Asia/Kuala_Lumpur'; // Malaysia Time (GMT+8)
  static const int timeZoneOffsetHours = 8;
  
  // Helper methods
  static String getFullUrl(String endpoint) {
    return '$server$endpoint';
  }
  
  static Duration get dataRefreshInterval => 
      Duration(seconds: dataRefreshIntervalSeconds);
  
  static Duration get relayCheckInterval => 
      Duration(seconds: relayCheckIntervalSeconds);
  
  static Duration get httpTimeout => 
      Duration(seconds: httpTimeoutSeconds);
  
  // Get current Malaysia time
  static DateTime get malaysiaTime => 
      DateTime.now().toUtc().add(Duration(hours: timeZoneOffsetHours));
  
  // Convert UTC time to Malaysia time
  static DateTime toMalaysiaTime(DateTime utcTime) =>
      utcTime.toUtc().add(Duration(hours: timeZoneOffsetHours));
  
  // Convert Malaysia time to UTC
  static DateTime toUtcTime(DateTime malaysiaTime) =>
      malaysiaTime.subtract(Duration(hours: timeZoneOffsetHours));
} 