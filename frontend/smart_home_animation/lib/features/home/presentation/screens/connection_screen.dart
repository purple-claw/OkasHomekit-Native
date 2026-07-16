// // lib/features/home/presentation/screens/connection_screen.dart
// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:multicast_dns/multicast_dns.dart';
// import 'package:provider/provider.dart';
// import 'package:smart_home_animation/services/direct_mqtt_service.dart';
// import 'package:wifi_iot/wifi_iot.dart';

// class ConnectionScreen extends StatefulWidget {
//   const ConnectionScreen({super.key});

//   @override
//   State<ConnectionScreen> createState() => _ConnectionScreenState();
// }

// class _ConnectionScreenState extends State<ConnectionScreen> {
//   final TextEditingController _ipController = TextEditingController();
//   final TextEditingController _usernameController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   bool _isConnecting = false;
//   bool _isDiscovering = false;
//   String? _currentSSID;
//   bool _isOnWifi = false;
//   String? _errorMessage;
//   List<Map<String, dynamic>> _discoveredDevices = [];

//   // mDNS service types
//   static const String serviceType = '_okas._tcp.local.';
//   static const String hostname = 'http://okas-homekit.local.';

//   @override
//   void initState() {
//     super.initState();
//     _checkNetworkStatus();
//     _startMDNSDiscovery();
//   }

//   Future<void> _checkNetworkStatus() async {
//     try {
//       final isWifi = await WiFiForIoTPlugin.isConnected();
//       final ssid = await WiFiForIoTPlugin.getSSID();
//       setState(() {
//         _isOnWifi = isWifi;
//         _currentSSID = ssid;
//       });
//     } catch (e) {
//       print('Error checking Wi-Fi: $e');
//     }
//   }

//   Future<void> _startMDNSDiscovery() async {
//     setState(() {
//       _isDiscovering = true;
//       _discoveredDevices.clear();
//     });

//     try {
//       final devices = await _discoverOKASDevice();
//       setState(() {
//         _discoveredDevices = devices;
//         _isDiscovering = false;
//       });

//       if (devices.isNotEmpty) {
//         _ipController.text = devices.first['host'];
//       }
//     } catch (e) {
//       print('mDNS discovery error: $e');
//       setState(() {
//         _isDiscovering = false;
//       });
//     }
//   }

//   Future<List<Map<String, dynamic>>> _discoverOKASDevice() async {
//     final List<Map<String, dynamic>> devices = [];

//     try {
//       final client = MDnsClient();
//       await client.start();

//       print('🔍 Discovering OKAS devices via mDNS...');

//       await for (final PtrResourceRecord ptr
//           in client.lookup<PtrResourceRecord>(
//             ResourceRecordQuery.serverPointer(serviceType),
//           )) {
//         print('Found service: ${ptr.domainName}');

//         await for (final SrvResourceRecord srv
//             in client.lookup<SrvResourceRecord>(
//               ResourceRecordQuery.service(ptr.domainName),
//             )) {
//           final deviceInfo = {
//             'name': ptr.domainName,
//             'host': srv.target,
//             'port': srv.port,
//             'type': 'okas',
//             'lastSeen': DateTime.now().toIso8601String(),
//           };

//           print('✅ Discovered OKAS device:');
//           print('   Host: ${srv.target}');
//           print('   Port: ${srv.port}');

//           devices.add(deviceInfo);
//         }
//       }

//       client.stop();
//       print('Found ${devices.length} OKAS device(s)');
//     } catch (e) {
//       print('mDNS discovery error: $e');
//     }

//     return devices;
//   }

//   Future<void> _connect() async {
//     // Get the IP address from the text field
//     final ip = _ipController.text.trim();
//     final username = _usernameController.text.trim();
//     final password = _passwordController.text.trim();

//     if (ip.isEmpty) {
//       setState(() {
//         _errorMessage = 'Please enter IP address or select discovered device';
//       });
//       return;
//     }

//     setState(() {
//       _isConnecting = true;
//       _errorMessage = null;
//     });

//     final mqttService = Provider.of<DirectMQTTService>(context, listen: false);

//     // Use the IP from the text field - this is the correct variable
//     final connected = await mqttService.connect(
//       host: ip, // Use 'host' parameter instead of 'OKAS_HOST'
//       port: 1884,
//       username: username.isEmpty ? 'okasapi' : username,
//       password: password.isEmpty ? 'okas1234' : password,
//     );

//     if (connected && mounted) {
//       Navigator.pushReplacementNamed(context, '/home');
//     } else {
//       setState(() {
//         _errorMessage = 'Failed to connect to OKAS device at $ip:1884';
//         _isConnecting = false;
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _ipController.dispose();
//     _usernameController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Connect to OKAS'),
//         backgroundColor: Colors.transparent,
//       ),
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Theme.of(context).primaryColor,
//               Theme.of(context).primaryColor.withOpacity(0.7),
//             ],
//           ),
//         ),
//         child: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.all(24.0),
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   // Network Status Card
//                   Card(
//                     elevation: 4,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         children: [
//                           Row(
//                             children: [
//                               Icon(
//                                 _isOnWifi ? Icons.wifi : Icons.wifi_off,
//                                 color: _isOnWifi ? Colors.green : Colors.orange,
//                                 size: 32,
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       _isOnWifi
//                                           ? 'Connected to Wi-Fi'
//                                           : 'Not on Wi-Fi',
//                                       style: const TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                     if (_isOnWifi && _currentSSID != null)
//                                       Text(
//                                         'Network: $_currentSSID',
//                                         style: TextStyle(
//                                           fontSize: 14,
//                                           color: Colors.grey[600],
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                           if (!_isOnWifi)
//                             const Padding(
//                               padding: EdgeInsets.only(top: 12),
//                               child: Text(
//                                 'Please connect to your home Wi-Fi network for device discovery',
//                                 style: TextStyle(fontSize: 14),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 24),

//                   // mDNS Discovery Section
//                   Card(
//                     elevation: 4,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               const Icon(Icons.search, color: Colors.blue),
//                               const SizedBox(width: 8),
//                               const Text(
//                                 'Discover Devices',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const Spacer(),
//                               if (_isDiscovering)
//                                 const SizedBox(
//                                   width: 20,
//                                   height: 20,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                   ),
//                                 )
//                               else
//                                 IconButton(
//                                   icon: const Icon(Icons.refresh),
//                                   onPressed: _startMDNSDiscovery,
//                                   tooltip: 'Refresh discovery',
//                                 ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           if (_discoveredDevices.isNotEmpty)
//                             ..._discoveredDevices.map(
//                               (device) => ListTile(
//                                 leading: const Icon(Icons.devices),
//                                 title: Text(device['name'] ?? 'OKAS Device'),
//                                 subtitle: Text(
//                                   'IP: ${device['host']}:${device['port']}',
//                                 ),
//                                 trailing: const Icon(Icons.chevron_right),
//                                 onTap: () {
//                                   setState(() {
//                                     _ipController.text = device['host'];
//                                   });
//                                 },
//                               ),
//                             ),
//                           if (_discoveredDevices.isEmpty && !_isDiscovering)
//                             const Padding(
//                               padding: EdgeInsets.all(8.0),
//                               child: Text(
//                                 'No OKAS devices found. Enter IP manually.',
//                                 style: TextStyle(color: Colors.grey),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 24),

//                   // Connection Form
//                   Card(
//                     elevation: 4,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.all(20),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'OKAS Gateway Connection',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'Enter the IP address and authentication credentials',
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                           const SizedBox(height: 20),

//                           // IP Address Field
//                           TextField(
//                             controller: _ipController,
//                             decoration: InputDecoration(
//                               labelText: 'IP Address',
//                               hintText:
//                                   '192.168.1.169 or http://okas-homekit.local',
//                               prefixIcon: const Icon(Icons.settings_ethernet),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                           ),

//                           const SizedBox(height: 16),

//                           // Username Field
//                           TextField(
//                             controller: _usernameController,
//                             decoration: InputDecoration(
//                               labelText: 'Username',
//                               hintText: 'okasapi',
//                               prefixIcon: const Icon(Icons.person),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                           ),

//                           const SizedBox(height: 16),

//                           // Password Field
//                           TextField(
//                             controller: _passwordController,
//                             obscureText: true,
//                             decoration: InputDecoration(
//                               labelText: 'Password',
//                               hintText: 'Enter password',
//                               prefixIcon: const Icon(Icons.lock),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                           ),

//                           const SizedBox(height: 8),
//                           Text(
//                             'Default credentials: okasapi / okas1234',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey[500],
//                             ),
//                           ),

//                           if (_errorMessage != null)
//                             Padding(
//                               padding: const EdgeInsets.only(top: 8),
//                               child: Text(
//                                 _errorMessage!,
//                                 style: const TextStyle(color: Colors.red),
//                               ),
//                             ),

//                           const SizedBox(height: 24),

//                           // Connect Button
//                           ElevatedButton(
//                             onPressed: _isConnecting ? null : _connect,
//                             style: ElevatedButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(vertical: 16),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                             child: _isConnecting
//                                 ? const SizedBox(
//                                     height: 20,
//                                     width: 20,
//                                     child: CircularProgressIndicator(
//                                       strokeWidth: 2,
//                                       valueColor: AlwaysStoppedAnimation<Color>(
//                                         Colors.white,
//                                       ),
//                                     ),
//                                   )
//                                 : const Text(
//                                     'Connect to OKAS Gateway',
//                                     style: TextStyle(fontSize: 16),
//                                   ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
