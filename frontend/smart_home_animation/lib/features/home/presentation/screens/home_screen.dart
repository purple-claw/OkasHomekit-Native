// lib/features/home/presentation/screens/home_screen.dart
// ignore_for_file: unused_field, unused_element, unused_local_variable, unused_import

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/room.dart';
import 'package:smart_home_animation/features/home/presentation/screens/add_room_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/lounge_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/profile_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/scene_screen.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/page_indicators.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/smart_room_page_view.dart';
import 'package:smart_home_animation/services/device_provider_wrapper.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';
import 'package:ui_common/ui_common.dart' hide DeviceType;

import '../widgets/lighted_background.dart';
import '../widgets/sm_home_bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = PageController(viewportFraction: 0.8);
  final ValueNotifier<double> pageNotifier = ValueNotifier(0);
  final ValueNotifier<int> roomSelectorNotifier = ValueNotifier(-1);
  int _selectedIndex = 0;
  int _currentRoomIndex = 0;

  List<Room> _rooms = [];
  List<Map<String, dynamic>> _savedRooms = [];

  final RefreshController _refreshController = RefreshController();

  // Load counts for Active Loads section
  int _totalSwitchCount = 0;
  int _totalDimmerCount = 0;
  int _totalTunableCount = 0;
  int _totalRgbCount = 0;

  // Current room load counts
  int _currentRoomSwitchCount = 0;
  int _currentRoomDimmerCount = 0;
  int _currentRoomTunableCount = 0;
  int _currentRoomRgbCount = 0;

  @override
  void initState() {
    super.initState();
    controller.addListener(pageListener);
    _loadAllRooms();
  }

  Future<void> _loadAllRooms() async {
    await _loadSavedRooms();
    _loadRoomsFromService();
    _calculateTotalLoadCounts();
    _updateCurrentRoomLoads(0);
  }

  Future<void> _loadSavedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsJson = prefs.getStringList('saved_rooms') ?? [];
    setState(() {
      _savedRooms = roomsJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
    });
  }

  void _loadRoomsFromService() {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    final List<Room> allRooms = [];

    final mqttRooms = okasService.rooms.entries.map((entry) {
      final roomData = entry.value;
      return Room(
        id: roomData['id'] ?? entry.key,
        name: entry.key,
        devices: [],
        createdAt: DateTime.now(),
      );
    }).toList();
    allRooms.addAll(mqttRooms);

    for (var savedRoom in _savedRooms) {
      allRooms.add(
        Room(
          id: savedRoom['id'],
          name: savedRoom['name'],
          devices: [],
          createdAt: DateTime.parse(savedRoom['createdAt']),
        ),
      );
    }

    final uniqueRooms = <String, Room>{};
    for (var room in allRooms) {
      uniqueRooms[room.id] = room;
    }

    setState(() {
      _rooms = uniqueRooms.values.toList();
    });
  }

  void _calculateTotalLoadCounts() {
    int switchCount = 0;
    int dimmerCount = 0;
    int tunableCount = 0;
    int rgbCount = 0;

    for (var savedRoom in _savedRooms) {
      final accessories = savedRoom['accessories'] as List<dynamic>? ?? [];
      for (var accessory in accessories) {
        final type = accessory['type'] as String? ?? '';
        switch (type) {
          case 'Switch':
            switchCount++;
            break;
          case 'Dimmer':
            dimmerCount++;
            break;
          case 'Tunable':
            tunableCount++;
            break;
          case 'RGB':
            rgbCount++;
            break;
        }
      }
    }

    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    final allDevices = okasService.devices.values.toList();
    for (var device in allDevices) {
      final type = device['type'] as String? ?? '';
      switch (type) {
        case 'swt':
          switchCount++;
          break;
        case 'dim':
          dimmerCount++;
          break;
        case 'tun':
          tunableCount++;
          break;
        case 'rgb':
          rgbCount++;
          break;
      }
    }

    setState(() {
      _totalSwitchCount = switchCount;
      _totalDimmerCount = dimmerCount;
      _totalTunableCount = tunableCount;
      _totalRgbCount = rgbCount;
    });
  }

  void _updateCurrentRoomLoads(int roomIndex) {
    if (roomIndex < 0 || roomIndex >= _rooms.length) {
      setState(() {
        _currentRoomSwitchCount = 0;
        _currentRoomDimmerCount = 0;
        _currentRoomTunableCount = 0;
        _currentRoomRgbCount = 0;
      });
      return;
    }

    final room = _rooms[roomIndex];
    final savedRoomData = _savedRooms.firstWhere(
      (saved) => saved['id'] == room.id,
      orElse: () => {},
    );

    final accessories = savedRoomData['accessories'] as List<dynamic>? ?? [];

    int switchCount = 0;
    int dimmerCount = 0;
    int tunableCount = 0;
    int rgbCount = 0;

    for (var accessory in accessories) {
      final type = accessory['type'] as String? ?? '';
      switch (type) {
        case 'Switch':
          switchCount++;
          break;
        case 'Dimmer':
          dimmerCount++;
          break;
        case 'Tunable':
          tunableCount++;
          break;
        case 'RGB':
          rgbCount++;
          break;
      }
    }

    setState(() {
      _currentRoomSwitchCount = switchCount;
      _currentRoomDimmerCount = dimmerCount;
      _currentRoomTunableCount = tunableCount;
      _currentRoomRgbCount = rgbCount;
    });
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    await _loadAllRooms();
    _calculateTotalLoadCounts();
    _updateCurrentRoomLoads(_currentRoomIndex);
    _refreshController.refreshCompleted();
    if (mounted) setState(() {});
  }

  void _addRoom(dynamic roomData) {
    _loadAllRooms();
    _calculateTotalLoadCounts();
    _updateCurrentRoomLoads(_currentRoomIndex);
  }

  @override
  void dispose() {
    controller
      ..removeListener(pageListener)
      ..dispose();
    pageNotifier.dispose();
    roomSelectorNotifier.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void pageListener() {
    final page = controller.page ?? 0;
    pageNotifier.value = page;

    // Update current room index when page changes
    final newIndex = page.round();
    if (newIndex != _currentRoomIndex && newIndex < _rooms.length) {
      _currentRoomIndex = newIndex;
      _updateCurrentRoomLoads(newIndex);
    }
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final okasService = Provider.of<DirectMQTTService>(context);

    return ChangeNotifierProvider(
      create: (_) => DeviceProviderWrapper(okasService),
      child: LightedBackgound(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _selectedIndex == 0
              ? AppBar(
                  title: const Text(
                    'Smart Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      child: Row(
                        children: [
                          Icon(
                            okasService.isConnected
                                ? Icons.wifi
                                : Icons.wifi_off,
                            color: okasService.isConnected
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            okasService.isConnected ? 'Connected' : 'Offline',
                            style: TextStyle(
                              color: okasService.isConnected
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    _selectedIndex == 1
                        ? 'Loads'
                        : _selectedIndex == 2
                        ? 'Scenes'
                        : 'Guest Access',
                    style: context.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  centerTitle: true,
                ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeTab(),
              const LoungeScreen(),
              const SceneScreen(),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: SmHomeBottomNavigationBar(
            currentIndex: _selectedIndex,
            onTabTapped: _onBottomNavTapped,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final okasService = Provider.of<DirectMQTTService>(context);

    if (!okasService.isConnected) {
      final lastAttempt = okasService.brokerAttempts.isNotEmpty
          ? okasService.brokerAttempts.last
          : 'Waiting for MQTT connection...';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Connecting to OKAS device...'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                okasService.lastError ?? lastAttempt,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await context.read<TokenAuthService>().logout();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/token-entry');
              },
              child: const Text('Re-authenticate'),
            ),
          ],
        ),
      );
    }

    final userName = " ";

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Welcome home,",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                "$userName!",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: _buildAddRoomButton()),

          if (_rooms.isNotEmpty) _buildRoomCard(),
          if (_rooms.isEmpty) _buildEmptyState(),

          const SizedBox(height: 24),

          // Active Loads Section - Now shows current room's loads
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Loads',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_rooms.isNotEmpty)
                Text(
                  'Room ${_currentRoomIndex + 1}/${_rooms.length}',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildActiveLoadCard(
                  'Switch',
                  _currentRoomSwitchCount,
                  Image.asset(
                    'assets/icons/switch.png',
                    width: 24,
                    height: 24,
                    color: Colors.green,
                  ),
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _buildActiveLoadCard(
                  'Dimmer',
                  _currentRoomDimmerCount,
                  Image.asset(
                    'assets/icons/dimmer.png',
                    width: 24,
                    height: 24,
                    color: Colors.orange,
                  ),
                  Colors.orange,
                ),
                const SizedBox(width: 12),
                _buildActiveLoadCard(
                  'Tunable',
                  _currentRoomTunableCount,
                  Image.asset(
                    'assets/icons/tunable.png',
                    width: 24,
                    height: 24,
                    color: Colors.purple,
                  ),
                  Colors.purple,
                ),
                const SizedBox(width: 12),
                _buildActiveLoadCard(
                  'RGB',
                  _currentRoomRgbCount,
                  Image.asset(
                    'assets/icons/rgb.png',
                    width: 24,
                    height: 24,
                    color: Colors.blue,
                  ),
                  Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard() {
    final smartRooms = _rooms.map((room) {
      final savedRoom = _savedRooms.firstWhere(
        (saved) => saved['id'] == room.id,
        orElse: () => {},
      );

      final accessories = savedRoom['accessories'] as List<dynamic>? ?? [];

      final devices = accessories.map((accessory) {
        MQTTDeviceType mqttType;
        switch (accessory['type']) {
          case 'Switch':
            mqttType = MQTTDeviceType.swt;
            break;
          case 'Dimmer':
            mqttType = MQTTDeviceType.dim;
            break;
          case 'RGB':
            mqttType = MQTTDeviceType.rgb;
            break;
          case 'Tunable':
            mqttType = MQTTDeviceType.tun;
            break;
          case 'HVAC':
            mqttType = MQTTDeviceType.hvc;
            break;
          case 'Scene':
            mqttType = MQTTDeviceType.scn;
            break;
          case 'Fan':
            mqttType = MQTTDeviceType.fan;
            break;
          case 'Curtain':
            mqttType = MQTTDeviceType.cur;
            break;
          default:
            mqttType = MQTTDeviceType.swt;
        }

        return Device(
          id: accessory['id'],
          name: accessory['name'],
          type: DeviceType.light,
          roomId: room.id,
          room: room.name,
          icon: Icons.lightbulb_outline,
          color: Colors.amber,
          isOn: accessory['isOn'] ?? false,
          mqttType: mqttType,
          sensortype: accessory['type'].toLowerCase(),
          lastSeen: DateTime.now(),
          isOnline: true,
        );
      }).toList();

      return SmartRoom(
        id: room.id,
        name: room.name,
        imageUrl: '',
        temperature: 22.0,
        airHumidity: 45.0,
        lights: SmartDevice(isOn: false, value: 0),
        airCondition: SmartDevice(isOn: false, value: 0),
        timer: SmartDevice(isOn: false, value: 0),
        musicInfo: MusicInfo(isOn: false, currentSong: Song.defaultSong),
        devices: devices,
        sensors: [],
        automationRules: [],
      );
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 24),
        SizedBox(
          height: 380,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // SmartRoomsPageView(
              //   rooms: smartRooms,
              //   pageNotifier: pageNotifier,
              //   roomSelectorNotifier: roomSelectorNotifier,
              //   controller: controller,
              // ),
              Positioned.fill(
                top: null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PageIndicators(
                      roomSelectorNotifier: roomSelectorNotifier,
                      pageNotifier: pageNotifier,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveLoadCard(
    String title,
    int count,
    Widget icon,
    Color color,
  ) {
    return Container(
      width: 85,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: icon,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.home_work_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No rooms added yet',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + button to add a room',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRoomButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddRoomScreen()),
        );
        if (result != null) {
          _addRoom(result);
          if (mounted) setState(() {});
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: SHColors.primary.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, color: SHColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              "Add Room",
              style: TextStyle(
                color: SHColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
