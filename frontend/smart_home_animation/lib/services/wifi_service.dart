// lib/services/wifi_service.dart
import 'package:wifi_iot/wifi_iot.dart';

class WifiService {
  static Future<bool> isConnectedToWifi() async {
    try {
      // Check if connected to Wi-Fi
      bool isConnected = await WiFiForIoTPlugin.isConnected();
      if (!isConnected) return false;

      // Get current SSID
      String? ssid = await WiFiForIoTPlugin.getSSID();
      return ssid != null && ssid.isNotEmpty;
    } catch (e) {
      print('Error checking Wi-Fi: $e');
      return false;
    }
  }

  static Future<String?> getCurrentSSID() async {
    try {
      return await WiFiForIoTPlugin.getSSID();
    } catch (e) {
      print('Error getting SSID: $e');
      return null;
    }
  }

  static Future<String?> getCurrentIP() async {
    try {
      return await WiFiForIoTPlugin.getIP();
    } catch (e) {
      print('Error getting IP: $e');
      return null;
    }
  }
}
