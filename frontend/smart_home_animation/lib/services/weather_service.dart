import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home_animation/api/constants.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureCelsius,
    required this.windSpeedKmh,
    required this.weatherCode,
    required this.locationLabel,
    required this.observedAt,
    required this.boardTime,
  });

  final double temperatureCelsius;
  final double windSpeedKmh;
  final int weatherCode;
  final String locationLabel;
  final DateTime observedAt;
  final DateTime boardTime;

  String get condition {
    switch (weatherCode) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'Light drizzle';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'Snow';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorms';
      default:
        return 'Current conditions';
    }
  }

  IconData get icon {
    switch (weatherCode) {
      case 0:
        return Icons.wb_sunny_rounded;
      case 1:
      case 2:
        return Icons.wb_cloudy_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return Icons.grain_rounded;
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return Icons.water_drop_rounded;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return Icons.ac_unit_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.cloud_rounded;
    }
  }
}

class WeatherService extends ChangeNotifier {
  WeatherService._();

  static final WeatherService instance = WeatherService._();

  static const _defaultLatitude = 51.5074;
  static const _defaultLongitude = -0.1278;
  static const _defaultLocation = 'London';

  WeatherSnapshot? _snapshot;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastLoadedAt;

  WeatherSnapshot? get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (!force &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            const Duration(minutes: 15)) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Board context is read first. The flexible parser supports firmware
      // versions that expose the values under different response envelopes.
      final boardContext = await _fetchBoardContext();
      final weather = await _fetchWeather(boardContext);
      _snapshot = weather;
      _lastLoadedAt = DateTime.now();
    } catch (_) {
      _error = 'Weather is temporarily unavailable';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<_BoardContext> _fetchBoardContext() async {
    final sources = <dynamic>[];
    final urls = <Uri>[];

    if (Constants.currentIp.isNotEmpty) {
      urls.add(Uri.parse(Constants.systemInfo));
      urls.add(Uri.parse(Constants.boardInfo));
      urls.add(
        Uri(
          scheme: Constants.apiScheme,
          host: Constants.currentIp,
          port: Constants.apiPort,
          path: '/getConfig.php',
        ),
      );
    }

    for (final uri in urls) {
      try {
        final response = await http
            .get(uri, headers: Constants.authHeaders)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        sources.add(jsonDecode(response.body));
      } catch (_) {
        // Try the next board endpoint, then use the known fallback location.
      }
    }

    final latitude =
        _numberFromSources(sources, {'latitude', 'lat'})?.clamp(-90, 90) ??
        _defaultLatitude;
    final longitude =
        _numberFromSources(sources, {
          'longitude',
          'lon',
          'lng',
        })?.clamp(-180, 180) ??
        _defaultLongitude;
    final location =
        _stringFromSources(sources, {'city', 'locality', 'place', 'timezone'}) ??
        _defaultLocation;
    final boardTime = _dateFromSources(sources) ?? DateTime.now().toLocal();

    return _BoardContext(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      location: location,
      boardTime: boardTime,
    );
  }

  Future<WeatherSnapshot> _fetchWeather(_BoardContext context) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': context.latitude.toStringAsFixed(4),
      'longitude': context.longitude.toStringAsFixed(4),
      'current_weather': 'true',
      'timezone': 'auto',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Open-Meteo returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current =
        (data['current_weather'] ?? data['current']) as Map<String, dynamic>?;
    if (current == null) throw const FormatException('Missing current weather');

    final temperature = _number(
      current['temperature'] ?? current['temperature_2m'],
    );
    final windSpeed = _number(
      current['windspeed'] ?? current['wind_speed_10m'],
    );
    final code = _number(current['weathercode'] ?? current['weather_code']);
    if (temperature == null || windSpeed == null || code == null) {
      throw const FormatException('Incomplete weather response');
    }

    return WeatherSnapshot(
      temperatureCelsius: temperature,
      windSpeedKmh: windSpeed,
      weatherCode: code.round(),
      locationLabel: context.location,
      observedAt: _parseDate(current['time']) ?? context.boardTime,
      boardTime: context.boardTime,
    );
  }

  static dynamic _valueForKeys(dynamic source, Set<String> keys) {
    if (source is Map) {
      for (final entry in source.entries) {
        final normalized = entry.key.toString().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
        if (keys.contains(normalized)) return entry.value;
      }
      for (final value in source.values) {
        final result = _valueForKeys(value, keys);
        if (result != null) return result;
      }
    } else if (source is List) {
      for (final value in source) {
        final result = _valueForKeys(value, keys);
        if (result != null) return result;
      }
    }
    return null;
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static double? _numberFromSources(List<dynamic> sources, Set<String> keys) {
    for (final source in sources) {
      final value = _number(_valueForKeys(source, keys));
      if (value != null) return value;
    }
    return null;
  }

  static String? _stringFromSources(List<dynamic> sources, Set<String> keys) {
    for (final source in sources) {
      final value = _valueForKeys(source, keys);
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static DateTime? _dateFromSources(List<dynamic> sources) {
    const keys = {'time', 'currenttime', 'datetime', 'timestamp', 'now'};
    for (final source in sources) {
      final date = _parseDate(_valueForKeys(source, keys));
      if (date != null) return date;
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is num) {
      final milliseconds = value.abs() > 100000000000
          ? value.toInt()
          : (value * 1000).round();
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();
    }
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toLocal();
  }
}

class _BoardContext {
  const _BoardContext({
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.boardTime,
  });

  final double latitude;
  final double longitude;
  final String location;
  final DateTime boardTime;
}
