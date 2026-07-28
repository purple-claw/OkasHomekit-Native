// lib/features/home/presentation/screens/home_screen.dart
// ignore_for_file: unused_field, unused_element, unused_local_variable, unused_import

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/room.dart';
import 'package:smart_home_animation/features/home/presentation/screens/add_room_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/lounge_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/profile_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/rooms_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/scene_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/room_loads_screen.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/page_indicators.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/smart_room_page_view.dart';
import 'package:smart_home_animation/services/device_provider_wrapper.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/room_service.dart' hide Room;
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

  // Listener registered with DirectMQTTService so the Active Loads counts
  // and per-room counts recompute whenever the underlying MQTT state changes
  // (new loads discovered, status update, command ack). Without this the
  // counts only updated on pull-to-refresh.
  VoidCallback? _okasServiceListener;

  // Current room load counts
  int _currentRoomSwitchCount = 0;
  int _currentRoomDimmerCount = 0;
  int _currentRoomTunableCount = 0;
  int _currentRoomRgbCount = 0;

  @override
  void initState() {
    super.initState();
    controller.addListener(pageListener);
    // Recompute the Active Loads cards whenever the underlying MQTT
    // service reports new state (load list, status update, cmd ack).
    // Without this listener the counts only refresh on pull-to-refresh,
    // so newly-discovered loads never appear and the per-room counts
    // stay stale as the user navigates between rooms.
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    _okasServiceListener = () {
      if (!mounted) return;
      _calculateTotalLoadCounts();
      _updateCurrentRoomLoads(_currentRoomIndex);
    };
    okasService.addListener(_okasServiceListener!);
    // Listen to RoomService so newly added rooms show up immediately on
    // the Home screen without waiting for a manual refresh.
    _roomServiceListener = () {
      if (!mounted) return;
      _loadRoomsFromService();
    };
    RoomService.instance.addListener(_roomServiceListener!);
    _loadAllRooms();
  }

  VoidCallback? _roomServiceListener;

  @override
  void dispose() {
    if (_okasServiceListener != null) {
      try {
        Provider.of<DirectMQTTService>(
          context,
          listen: false,
        ).removeListener(_okasServiceListener!);
      } catch (_) {
        /* context may be unmounted */
      }
    }
    if (_roomServiceListener != null) {
      RoomService.instance.removeListener(_roomServiceListener!);
    }
    controller.removeListener(pageListener);
    controller.dispose();
    pageNotifier.dispose();
    roomSelectorNotifier.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadAllRooms() async {
    await _loadSavedRooms();
    _loadRoomsFromService();
    _calculateTotalLoadCounts();
    _updateCurrentRoomLoads(0);
  }

  Future<void> _loadSavedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsJson = prefs.getStringList('home_saved_rooms') ?? [];
    setState(() {
      _savedRooms = roomsJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
    });
  }

  void _loadRoomsFromService() {
    final serviceRooms = RoomService.instance.rooms;
    final uniqueRooms = <String, Room>{};
    for (final r in serviceRooms) {
      uniqueRooms[r.id] = Room(
        id: r.id,
        name: r.name,
        wallpaperUrl: r.imagePath,
        devices: [],
        createdAt: r.createdAt,
      );
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
                  title: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/svg/okas-logo.svg',
                        width: 72,
                        height: 22,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'HomeKit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              (okasService.isConnected
                                      ? SHColors.green
                                      : SHColors.rose)
                                  .withOpacity(0.42),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            okasService.isConnected
                                ? Icons.wifi
                                : Icons.wifi_off,
                            color: okasService.isConnected
                                ? SHColors.green
                                : SHColors.rose,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            okasService.isConnected ? 'Connected' : 'Offline',
                            style: const TextStyle(
                              color: SHColors.textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
                        ? 'Rooms'
                        : _selectedIndex == 3
                        ? 'Scenes'
                        : 'Profile',
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
              RoomsTab(),
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
          : 'Waiting for connection...';
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
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome back",
                      style: TextStyle(
                        color: SHColors.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Smart Home",
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ],
                ),
              ),
              _buildAddRoomButton(),
            ],
          ),

          const SizedBox(height: 22),
          if (_rooms.isNotEmpty) _buildRoomCard(),
          if (_rooms.isEmpty) _buildEmptyState(),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Loads',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_rooms.isNotEmpty)
                Text(
                  'Room ${_currentRoomIndex + 1}/${_rooms.length}',
                  style: TextStyle(
                    color: SHColors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
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
                  _totalSwitchCount,
                  Image.asset(
                    'assets/icons/switch.png',
                    width: 24,
                    height: 24,
                    color: SHColors.green,
                  ),
                  SHColors.green,
                ),
                const SizedBox(width: 12),
                _buildActiveLoadCard(
                  'Dimmer',
                  _totalDimmerCount,
                  Image.asset(
                    'assets/icons/dimmer.png',
                    width: 24,
                    height: 24,
                    color: SHColors.amber,
                  ),
                  SHColors.amber,
                ),
                const SizedBox(width: 12),
                _buildActiveLoadCard(
                  'Tunable',
                  _totalTunableCount,
                  Image.asset(
                    'assets/icons/tunable.png',
                    width: 24,
                    height: 24,
                    color: SHColors.violet,
                  ),
                  SHColors.violet,
                ),
                const SizedBox(width: 12),
                _buildActiveLoadCard(
                  'RGB',
                  _totalRgbCount,
                  Image.asset(
                    'assets/icons/rgb.png',
                    width: 24,
                    height: 24,
                    color: SHColors.blue,
                  ),
                  SHColors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            'Your Rooms',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _rooms.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final room = _rooms[index];
              return _buildHorizontalRoomCard(context, room);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalRoomCard(BuildContext context, Room room) {
    final serviceRoom = RoomService.instance.getRoomById(room.id);
    final imagePath = serviceRoom?.imagePath ?? room.wallpaperUrl;

    return GestureDetector(
      onTap: () {
        if (serviceRoom != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomLoadsScreen(room: serviceRoom),
            ),
          );
        }
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SHColors.radiusLg),
          gradient: SHColors.cardGradient,
          border: Border.all(color: Colors.white.withOpacity(0.14), width: 1),
          boxShadow: SHColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SHColors.radiusLg),
              ),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child:
                    imagePath != null &&
                        imagePath.isNotEmpty &&
                        File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.cover)
                    : Container(
                        color: Colors.black26,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Image.asset(
                            'assets/icons/room.png',
                            color: SHColors.primary,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.meeting_room,
                              size: 48,
                              color: SHColors.hintColor,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(serviceRoom?.loadIds.length ?? 0)} loads',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLoadCard(
    String title,
    int count,
    Widget icon,
    Color color,
  ) {
    return Container(
      width: 88,
      decoration: BoxDecoration(
        color: SHColors.cardColor.withOpacity(0.58),
        borderRadius: BorderRadius.circular(SHColors.radiusMd),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: SHColors.softShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: icon,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
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
          Icon(Icons.home_work_outlined, size: 64, color: SHColors.hintColor),
          const SizedBox(height: 16),
          const Text(
            'No rooms added yet',
            style: TextStyle(color: SHColors.mutedText),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + button to add a room',
            style: TextStyle(color: SHColors.hintColor),
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
          color: SHColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
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
