// lib/services/house_name_service.dart
//
// Provides the house/project name from the board (loadData.json prjNm)
// and the user preference for whether to show it on the home page.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_animation/api/constants.dart';

class HouseNameService {
  HouseNameService._();

  static final HouseNameService instance = HouseNameService._();

  static const _showPrefKey = 'okas_show_house_name';
  static const _nameKey = 'okas_house_name';

  String _houseName = 'Smart Home';
  bool _showHouseName = true;
  bool _loaded = false;

  String get houseName => _houseName;
  bool get showHouseName => _showHouseName;
  bool get loaded => _loaded;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _houseName = prefs.getString(_nameKey) ?? 'Smart Home';
      _showHouseName = prefs.getBool(_showPrefKey) ?? true;
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  /// Fetches the project name from the board and caches it.
  Future<void> refreshFromBoard() async {
    try {
      final ip = Constants.currentIp;
      if (ip.isEmpty) return;
      final uri = Uri(
        scheme: Constants.apiScheme,
        host: ip,
        port: Constants.apiPort,
        path: '/getConfig.php',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final name = data[0]['prjNm'] as String?;
          if (name != null && name.isNotEmpty) {
            _houseName = name;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_nameKey, name);
          }
        }
      }
    } catch (_) {
      // Board unreachable — keep the cached name.
    }
  }

  Future<void> setShowHouseName(bool show) async {
    _showHouseName = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showPrefKey, show);
  }
}
