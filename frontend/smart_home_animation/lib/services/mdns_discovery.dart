// lib/services/mdns_discovery.dart
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:smart_home_animation/api/constants.dart';

class MDNSDiscovery {
  static const String serviceType = '_okas._tcp.local.';
  static const String homeKitServiceType = '_hap._tcp.local.';
  static const String hostname = 'okas-homekit.local.';
  static int get _apiPort => Constants.apiScheme == 'https' ? 443 : 80;

  final List<Map<String, dynamic>> _devices = [];

  List<Map<String, dynamic>> get devices => _devices;

  String? _discoveredIp;
  Timer? _discoveryTimer;
  final List<dynamic> _listeners = [];

  String? get discoveredIp => _discoveredIp;

  static const List<String> commonIPs = [
    '192.168.1.152', // Your board IP (UPDATED)
    '192.168.1.120',
    '192.168.1.119',
    '192.168.1.187',
    '192.168.1.100',
    '192.168.1.169',
    '192.168.1.164',
    '192.168.1.150',
    '192.168.1.200',
    '192.168.1.108',
    '192.168.1.199',
  ];

  void addListener(dynamic listener) {
    _listeners.add(listener);
  }

  void removeListener(dynamic listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners(String ip) {
    for (var listener in _listeners) {
      try {
        if (listener is Function(String)) {
          listener(ip);
        }
      } catch (e) {
        print('Error calling listener: $e');
      }
    }
  }

  void startBackgroundDiscovery() {
    discoverOKASDevice();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      discoverOKASDevice();
    });
    print('🔄 Started background mDNS discovery');
  }

  void stopBackgroundDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    print('⏹️ Stopped background mDNS discovery');
  }

  Future<bool> checkBoardAccessible(String ip) async {
    try {
      final url = Uri(
        scheme: Constants.apiScheme,
        host: ip,
        port: _apiPort,
        path: '/api/health',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> discoverOKASDevice() async {
    _devices.clear();

    print('🔍 Starting OKAS board discovery...');

    final hostResult = await _discoverHostname();
    if (hostResult != null) return hostResult;

    final serviceResult = await _discoverServices();
    if (serviceResult != null) return serviceResult;

    // Check known IPs
    for (final ip in commonIPs) {
      print('  🔍 Testing: $ip');
      final isAccessible = await checkBoardAccessible(ip);
      if (isAccessible) {
        final deviceInfo = {
          'name': 'OKAS Device',
          'host': ip,
          'port': _apiPort,
          'type': 'okas',
          'lastSeen': DateTime.now().toIso8601String(),
          'status': 'online',
        };
        _devices.add(deviceInfo);
        _discoveredIp = ip;
        Constants.updateBaseUrl(ip);
        Constants.setCurrentIp(ip);
        Constants.setApiPort(_apiPort);
        _notifyListeners(ip);
        print('✅ Found OKAS board at: $ip');
        return _devices;
      }
    }

    print('❌ No OKAS board found on the network');
    return _devices;
  }

  Future<List<Map<String, dynamic>>?> _discoverHostname() async {
    final cleanHostname = hostname.endsWith('.')
        ? hostname.substring(0, hostname.length - 1)
        : hostname;

    for (final candidate in [cleanHostname, hostname]) {
      final ip = await _resolveHostToIpv4(candidate);
      if (ip == null) continue;
      print('  🔍 Testing hostname $candidate resolved to: $ip');
      if (await checkBoardAccessible(ip)) {
        return _registerDevice(
          name: 'OKAS HomeKit',
          host: ip,
          macAddress: null,
          source: 'hostname',
        );
      }
    }
    return null;
  }

  Future<String?> _resolveSystemHostname(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 2));
      for (final address in addresses) {
        if (address.type == InternetAddressType.IPv4) return address.address;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _resolveMdnsHostname(String host) async {
    final queryHost = host.endsWith('.') ? host : '$host.';
    try {
      final client = MDnsClient();
      await client.start();
      await for (final IPAddressResourceRecord record
          in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(queryHost),
          )) {
        client.stop();
        return record.address.address;
      }
      client.stop();
    } catch (e) {
      print('mDNS hostname resolution error: $e');
    }
    return null;
  }

  Future<String?> _resolveHostToIpv4(String host) async {
    if (Constants.isValidIp(host)) return host;
    final systemIp = await _resolveSystemHostname(host);
    if (systemIp != null) return systemIp;
    return _resolveMdnsHostname(host);
  }

  Future<List<Map<String, dynamic>>?> _discoverServices() async {
    try {
      final MDnsClient client = MDnsClient();
      await client.start();

      print('🔍 Checking mDNS for OKAS devices...');

      for (final type in [serviceType, homeKitServiceType]) {
        await for (final PtrResourceRecord ptr
            in client.lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(type),
            )) {
          print('Found service: ${ptr.domainName}');

          await for (final SrvResourceRecord srv
              in client.lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
              )) {
            final target = srv.target.endsWith('.')
                ? srv.target.substring(0, srv.target.length - 1)
                : srv.target;
            final ip = await _resolveHostToIpv4(target);
            if (ip == null) continue;
            print('  🔍 Testing mDNS found: $ip');
            final isAccessible = await checkBoardAccessible(ip);

            if (isAccessible) {
              // Query TXT records to extract MAC address and other metadata.
              String? macAddress;
              try {
                await for (final TxtResourceRecord txt
                    in client.lookup<TxtResourceRecord>(
                      ResourceRecordQuery.text(ptr.domainName),
                    )) {
                  print('  📋 mDNS TXT: ${txt.text}');
                  final text = txt.text.trim();
                  if (text.startsWith('mac=') || text.startsWith('hwaddr=') || text.startsWith('id=')) {
                    macAddress = text.split('=').skip(1).join('=').trim();
                  }
                }
              } catch (_) {
                // TXT records may not be available on all services.
              }

              final devices = _registerDevice(
                name: ptr.domainName,
                host: ip,
                macAddress: macAddress,
                source: type,
              );
              print('✅ Found OKAS board via mDNS at: $ip');
              client.stop();
              return devices;
            }
          }
        }
      }

      client.stop();
    } catch (e) {
      print('mDNS discovery error: $e');
    }
    return null;
  }

  List<Map<String, dynamic>> _registerDevice({
    required String name,
    required String host,
    required String source,
    String? macAddress,
  }) {
    if (macAddress != null && macAddress.isNotEmpty) {
      Constants.setMacAddress(macAddress);
      print('  📍 Board MAC: $macAddress');
    }
    final deviceInfo = {
      'name': name,
      'host': host,
      'port': _apiPort,
      'type': 'okas',
      'source': source,
      'mac': macAddress,
      'lastSeen': DateTime.now().toIso8601String(),
      'status': 'online',
    };
    _devices.add(deviceInfo);
    _discoveredIp = host;
    Constants.updateBaseUrl(host);
    Constants.setCurrentIp(host);
    Constants.setApiPort(_apiPort);
    _notifyListeners(host);
    return _devices;
  }

  void dispose() {
    stopBackgroundDiscovery();
  }
}
