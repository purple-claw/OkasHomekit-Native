// lib/features/home/presentation/screens/home_screen.dart
// ignore_for_file: unused_field, unused_element, unused_local_variable, unused_import

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/room.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/room_image.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/glass_panel.dart';
import 'package:smart_home_animation/features/home/presentation/screens/add_room_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/lounge_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/profile_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/scene_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/room_loads_screen.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/page_indicators.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/smart_room_page_view.dart';
import 'package:smart_home_animation/services/device_provider_wrapper.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/house_name_service.dart';
import 'package:smart_home_animation/services/room_service.dart' hide Room;
import 'package:smart_home_animation/services/scene_favorites_service.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';
import 'package:smart_home_animation/services/weather_service.dart';
import 'package:ui_common/ui_common.dart' hide DeviceType;

import '../widgets/lighted_background.dart';
import '../widgets/sm_home_bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = PageController(viewportFraction: 0.68);
  int _selectedIndex = 0;
  int _currentRoomIndex = 0;

  List<Room> _rooms = [];
  VoidCallback? _sceneFavoritesListener;

  @override
  void initState() {
    super.initState();
    controller.addListener(pageListener);
    _sceneFavoritesListener = () {
      if (!mounted) return;
      setState(() {});
    };
    SceneFavoritesService.instance.addListener(_sceneFavoritesListener!);
    SceneFavoritesService.instance.load();
    WeatherService.instance.load();
    // Listen to RoomService so newly added rooms show up immediately on
    // the Home screen without waiting for a manual refresh.
    _roomServiceListener = () {
      if (!mounted) return;
      _loadRoomsFromService();
    };
    RoomService.instance.addListener(_roomServiceListener!);
    _loadAllRooms();
    // House name: refresh from the board and reflect the show/hide pref.
    HouseNameService.instance.init().then((_) {
      if (mounted) setState(() {});
      HouseNameService.instance.refreshFromBoard().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  VoidCallback? _roomServiceListener;

  @override
  void dispose() {
    if (_sceneFavoritesListener != null) {
      SceneFavoritesService.instance.removeListener(_sceneFavoritesListener!);
    }
    if (_roomServiceListener != null) {
      RoomService.instance.removeListener(_roomServiceListener!);
    }
    controller.removeListener(pageListener);
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadAllRooms() async {
    await RoomService.instance.loadRooms();
    _loadRoomsFromService();
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
        isFavorite: r.isFavorite,
      );
    }
    setState(() {
      _rooms = uniqueRooms.values.toList();
    });
  }

  void _addRoom(dynamic roomData) {
    _loadAllRooms();
  }

  void pageListener() {
    final page = controller.page ?? 0;
    final newIndex = page.round();
    if (newIndex != _currentRoomIndex && newIndex < _rooms.length) {
      _currentRoomIndex = newIndex;
      setState(() {});
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
              ? null
              : AppBar(
                  backgroundColor: Colors.black.withValues(alpha: 0.12),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    _selectedIndex == 1
                        ? 'Loads'
                        : _selectedIndex == 2
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
              const SceneScreen(showHeader: false),
              // NOT const: rebuilds when HouseNameService refreshes from
              // the board (owner/project names).
              ProfileScreen(),
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
      return const _MqttLoadingSkeleton();
    }

    return SafeArea(
      top: true,
      bottom: false,
      child: SingleChildScrollView(
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
                      Text(
                        // Greet the owner by their display name (set by the
                        // programmer on the web User Management page).
                        context.watch<TokenAuthService>().displayName != null
                            ? 'Hi, ${context.watch<TokenAuthService>().displayName}'
                            : 'Welcome back',
                        style: TextStyle(
                          color: SHColors.mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // House name from the board when the option is enabled;
                        // falls back to the generic brand title.
                        HouseNameService.instance.showHouseName
                            ? HouseNameService.instance.houseName
                            : "Smart Home",
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

            _buildFavoritesSection(),
            const SizedBox(height: 20),
            _buildWeatherSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesSection() {
    final favorites = <_FavoriteAccess>[
      ..._rooms
          .where((room) => room.isFavorite)
          .map(
            (room) => _FavoriteAccess(
              id: room.id,
              label: room.name,
              typeLabel: 'Room',
              icon: Icons.meeting_room_rounded,
              accent: SHColors.primary,
              imagePath: room.wallpaperUrl,
              onTap: () {
                final serviceRoom = RoomService.instance.getRoomById(room.id);
                if (serviceRoom == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoomLoadsScreen(room: serviceRoom),
                  ),
                );
              },
            ),
          ),
      ...SceneFavoritesService.instance.favorites.map(
        (scene) => _FavoriteAccess(
          id: scene.id,
          label: scene.name,
          typeLabel: 'Scene',
          icon: scene.icon,
          accent: scene.color,
          onTap: () => setState(() => _selectedIndex = 2),
        ),
      ),
    ].take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Favorites',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${favorites.length}/4',
              style: const TextStyle(
                color: SHColors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 136,
          child: Row(
            children: List.generate(4, (index) {
              final favorite = index < favorites.length
                  ? favorites[index]
                  : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 3 ? 0 : 8),
                  child: _FavoriteAccessCard(favorite: favorite),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherSection() {
    final weather = WeatherService.instance;
    return AnimatedBuilder(
      animation: weather,
      builder: (context, _) {
        final snapshot = weather.snapshot;
        final stateKey = snapshot == null
            ? 'weather-${weather.isLoading}-${weather.error}'
            : 'weather-${snapshot.observedAt.toIso8601String()}';
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _WeatherGlassCard(
            key: ValueKey(stateKey),
            snapshot: snapshot,
            isLoading: weather.isLoading,
            error: weather.error,
            onRetry: () => weather.load(force: true),
          ),
        );
      },
    );
  }

  Widget _buildRoomCard() {
    final rooms = [..._rooms]
      ..sort((a, b) {
        final favoriteOrder = (b.isFavorite ? 1 : 0) - (a.isFavorite ? 1 : 0);
        return favoriteOrder;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 10),
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
          height: 326,
          child: PageView.builder(
            controller: controller,
            clipBehavior: Clip.none,
            padEnds: true,
            physics: const BouncingScrollPhysics(),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              return _buildHorizontalRoomCard(context, rooms[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalRoomCard(BuildContext context, Room room, int index) {
    final serviceRoom = RoomService.instance.getRoomById(room.id);
    final imagePath = serviceRoom?.imagePath ?? room.wallpaperUrl;

    return AnimatedBuilder(
      animation: controller,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: _RoomShowcaseCard(
          key: ValueKey(room.id),
          index: index,
          imagePath: imagePath,
          roomName: room.name,
          loadCount: serviceRoom?.loadIds.length ?? 0,
          isFavorite: room.isFavorite,
          onFavoriteToggle: () {
            final next = !room.isFavorite;
            RoomService.instance.setFavorite(room.id, next);
            Provider.of<DirectMQTTService>(
              context,
              listen: false,
            ).setFavoriteRoom(room.id, next);
          },
          onTap: serviceRoom == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomLoadsScreen(room: serviceRoom),
                    ),
                  );
                },
          onLongPress: Provider.of<TokenAuthService>(context, listen: false)
                  .isAdmin
              ? () => _showRoomActionsDialog(context, room)
              : null,
        ),
      ),
      builder: (context, child) {
        final page = controller.hasClients && controller.page != null
            ? controller.page!
            : _currentRoomIndex.toDouble();
        final distance = (page - index).abs().clamp(0.0, 1.0).toDouble();
        final scale = 1 - (distance * 0.14);

        return Transform.scale(
          alignment: Alignment.center,
          scale: scale,
          child: child,
        );
      },
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

  /// Long-press action menu for a home-screen room card.
  void _showRoomActionsDialog(BuildContext context, Room room) {
    final serviceRoom = RoomService.instance.getRoomById(room.id);
    showDialog(
      context: context,
      builder: (dialogContext) => FrostedAlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        contentPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          room.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, size: 22, color: Colors.white),
              title: const Text(
                'Edit Room',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddRoomScreen(
                      roomToEdit: {
                        'id': room.id,
                        'name': room.name,
                        'imagePath':
                            serviceRoom?.imagePath ?? room.wallpaperUrl,
                        'loads': serviceRoom?.loadIds ??
                            room.devices.map((d) => d.id).toList(),
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                room.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 22,
                color: room.isFavorite ? SHColors.amber : Colors.white,
              ),
              title: Text(
                room.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(dialogContext);
                final next = !room.isFavorite;
                RoomService.instance.setFavorite(room.id, next);
                Provider.of<DirectMQTTService>(
                  context,
                  listen: false,
                ).setFavoriteRoom(room.id, next);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, size: 22, color: Colors.red),
              title: const Text(
                'Delete Room',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(dialogContext);
                _confirmDeleteRoom(context, room);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRoom(BuildContext context, Room room) {
    final mqttService = Provider.of<DirectMQTTService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => FrostedAlertDialog(
        title: const Text(
          'Delete Room?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${room.name}"?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              RoomService.instance.deleteRoom(room.id);
              mqttService.deleteRoom(room.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

class _MqttLoadingSkeleton extends StatefulWidget {
  const _MqttLoadingSkeleton();

  @override
  State<_MqttLoadingSkeleton> createState() => _MqttLoadingSkeletonState();
}

class _MqttLoadingSkeletonState extends State<_MqttLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _bone({double? width, required double height, double radius = 16}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SHColors.cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
    );
  }

  Widget _buildSkeletonContent() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                    _bone(width: 128, height: 16, radius: 8),
                    const SizedBox(height: 12),
                    _bone(width: 218, height: 38, radius: 10),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _bone(width: 132, height: 54, radius: 28),
            ],
          ),
          const SizedBox(height: 34),
          _bone(width: 152, height: 24, radius: 8),
          const SizedBox(height: 12),
          SizedBox(
            height: 326,
            child: Row(
              children: [
                SizedBox(width: 52, child: _bone(height: 286, radius: 18)),
                const SizedBox(width: 12),
                Expanded(child: _bone(height: 326, radius: 18)),
                const SizedBox(width: 12),
                SizedBox(width: 52, child: _bone(height: 286, radius: 18)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _bone(width: 132, height: 24, radius: 8),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              4,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 3 ? 0 : 10),
                  child: _bone(height: 154, radius: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerPosition = (_shimmerController.value * 2) - 1;

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-2 + shimmerPosition * 2, 0),
              end: Alignment(-0.4 + shimmerPosition * 2, 0),
              colors: const [
                SHColors.cardColor,
                SHColors.elevatedCardColor,
                SHColors.cardColor,
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: _buildSkeletonContent(),
    );
  }
}

class _RoomShowcaseCard extends StatefulWidget {
  const _RoomShowcaseCard({
    super.key,
    required this.index,
    required this.imagePath,
    required this.roomName,
    required this.loadCount,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onTap,
    required this.onLongPress,
  });

  final int index;
  final String? imagePath;
  final String roomName;
  final int loadCount;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<_RoomShowcaseCard> createState() => _RoomShowcaseCardState();
}

class _RoomShowcaseCardState extends State<_RoomShowcaseCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (mounted && _isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = widget.onTap != null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (widget.index * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, animationValue, child) {
        return Opacity(
          opacity: animationValue,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - animationValue)),
            child: child,
          ),
        );
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Semantics(
          button: canOpen,
          label: '${widget.roomName} room',
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onTapDown: canOpen ? (_) => _setPressed(true) : null,
            onTapCancel: canOpen ? () => _setPressed(false) : null,
            onTapUp: canOpen ? (_) => _setPressed(false) : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RoomImage(imagePath: widget.imagePath),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.02),
                                Colors.black.withValues(alpha: 0.06),
                                Colors.black.withValues(alpha: 0.68),
                              ],
                              stops: const [0, 0.46, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Semantics(
                            button: true,
                            label: widget.isFavorite
                                ? 'Remove ${widget.roomName} from favorites'
                                : 'Add ${widget.roomName} to favorites',
                            child: GestureDetector(
                              onTap: widget.onFavoriteToggle,
                              child: _RoomGlassIcon(
                                icon: widget.isFavorite
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: widget.isFavorite
                                    ? SHColors.amber
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(18),
                            ),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 14,
                                sigmaY: 14,
                              ),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  13,
                                  12,
                                  14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.07),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.roomName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${widget.loadCount} loads',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.68,
                                              ),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _RoomGlassIcon(
                                      icon: Icons.chevron_right_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomGlassIcon extends StatelessWidget {
  const _RoomGlassIcon({
    required this.icon,
    required this.color,
    this.size = 18,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

class _FavoriteAccess {
  const _FavoriteAccess({
    required this.id,
    required this.label,
    required this.typeLabel,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.imagePath,
  });

  final String id;
  final String label;
  final String typeLabel;
  final IconData icon;
  final Color accent;
  final String? imagePath;
  final VoidCallback onTap;
}

class _FavoriteAccessCard extends StatefulWidget {
  const _FavoriteAccessCard({required this.favorite});

  final _FavoriteAccess? favorite;

  @override
  State<_FavoriteAccessCard> createState() => _FavoriteAccessCardState();
}

class _FavoriteAccessCardState extends State<_FavoriteAccessCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final favorite = widget.favorite;
    final accent = favorite?.accent ?? SHColors.hintColor;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        key: ValueKey(favorite?.id ?? 'empty'),
        onTap: favorite?.onTap,
        onTapDown: favorite == null ? null : (_) => _setPressed(true),
        onTapCancel: favorite == null ? null : () => _setPressed(false),
        onTapUp: favorite == null ? null : (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: favorite == null
                  ? null
                  : [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: favorite == null
                        ? Colors.white.withValues(alpha: 0.045)
                        : Colors.white.withValues(alpha: 0.075),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (favorite?.imagePath != null)
                        RoomImage(imagePath: favorite!.imagePath),
                      if (favorite != null)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.08),
                                Colors.black.withValues(alpha: 0.64),
                              ],
                            ),
                          ),
                        ),
                      if (favorite == null)
                        const Center(
                          child: Icon(
                            Icons.star_border_rounded,
                            color: SHColors.hintColor,
                            size: 28,
                          ),
                        )
                      else ...[
                        Positioned(
                          top: 9,
                          left: 9,
                          child: _FavoritePill(
                            label: favorite.typeLabel,
                            color: accent,
                          ),
                        ),
                        Positioned(
                          top: 9,
                          right: 9,
                          child: Icon(favorite.icon, color: accent, size: 18),
                        ),
                        Positioned(
                          left: 10,
                          right: 8,
                          bottom: 10,
                          child: Text(
                            favorite.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritePill extends StatelessWidget {
  const _FavoritePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _WeatherGlassCard extends StatelessWidget {
  const _WeatherGlassCard({
    super.key,
    required this.snapshot,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final WeatherSnapshot? snapshot;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.105),
                  Colors.white.withValues(alpha: 0.045),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: snapshot == null
                  ? _buildStatus()
                  : _buildWeather(snapshot!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    return Row(
      children: [
        Icon(
          isLoading ? Icons.cloud_sync_rounded : Icons.cloud_off_rounded,
          color: Colors.white.withValues(alpha: 0.72),
          size: 34,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            isLoading ? 'Checking the sky...' : error ?? 'Weather unavailable',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (!isLoading)
          IconButton(
            onPressed: onRetry,
            tooltip: 'Refresh weather',
            icon: const Icon(Icons.refresh_rounded),
            color: Colors.white70,
          ),
      ],
    );
  }

  Widget _buildWeather(WeatherSnapshot weather) {
    final accent =
        weather.weatherCode == 0 ||
            weather.weatherCode == 1 ||
            weather.weatherCode == 2
        ? const Color(0xFFFFD166)
        : const Color(0xFF9AD9FF);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: Colors.white.withValues(alpha: 0.72),
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      weather.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                weather.condition,
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
                '${_formatTime(weather.boardTime)}  •  Wind ${weather.windSpeedKmh.round()} km/h',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(weather.icon, color: accent, size: 48),
        const SizedBox(width: 4),
        Text(
          '${weather.temperatureCelsius.round()}°',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w300,
            height: 1,
          ),
        ),
      ],
    );
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
