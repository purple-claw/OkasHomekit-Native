// lib/features/home/presentation/screens/rooms_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/room_image.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/room_service.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';
import 'package:smart_home_animation/features/home/presentation/screens/add_room_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/room_loads_screen.dart';
import '../widgets/load_icon.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/glass_panel.dart';

class RoomsTab extends StatefulWidget {
  const RoomsTab();

  @override
  State<RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<RoomsTab> {
  @override
  void initState() {
    super.initState();
    RoomService.instance.addListener(_onRoomsChanged);
    RoomService.instance.loadRooms();
  }

  void _onRoomsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RoomService.instance.removeListener(_onRoomsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = RoomService.instance.rooms;
    final mqttService = Provider.of<DirectMQTTService>(context);
    final loads = mqttService.getLoadsList();
    // Guests can view rooms but only the owner can add/edit/delete them.
    final isAdmin = context.watch<TokenAuthService>().isAdmin;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: rooms.isEmpty ? _buildEmptyState() : _buildRoomsList(rooms, loads),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _navigateToAddRoom(context),
              backgroundColor: SHColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    final isAdmin = context.watch<TokenAuthService>().isAdmin;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.meeting_room_outlined,
            size: 80,
            color: SHColors.hintColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No Rooms Yet',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAdmin
                ? 'Create rooms to organize your loads'
                : 'Rooms will appear here when the owner creates them',
            style: TextStyle(color: SHColors.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (isAdmin)
            ElevatedButton.icon(
              onPressed: () => _navigateToAddRoom(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Room'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SHColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomsList(List<Room> rooms, List<Map<String, dynamic>> loads) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _buildRoomCard(room, loads);
      },
    );
  }

  Widget _buildRoomCard(Room room, List<Map<String, dynamic>> loads) {
    // Get loads for this room
    final roomLoads = room.loadIds
        .map((id) {
          try {
            return loads.firstWhere((l) => l['id'].toString() == id);
          } catch (e) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    return GestureDetector(
      onTap: () => _openRoomLoads(room, roomLoads),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SHColors.radiusLg),
          gradient: SHColors.cardGradient,
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          boxShadow: SHColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Figma spec: image-led room cards with dark gradient overlay
            // sitting under the room name so white text remains legible.
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(SHColors.radiusLg),
                  ),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: RoomImage(
                      imagePath: room.imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (room.imagePath != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(SHColors.radiusLg),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.65),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 10,
                  child: Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Admin-only edit/delete menu — room management is
                      // restricted to the owner (guests only view/control).
                      if (context.watch<TokenAuthService>().isAdmin)
                        GestureDetector(
                          onTap: () => _showEditDeleteDialog(room),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ),
                        ),
                      if (context.watch<TokenAuthService>().isAdmin)
                        const SizedBox(width: 6),
                      // Favorite star toggle — sets this room as the
                      // favorite room across all devices via the board.
                      GestureDetector(
                        onTap: () {
                          final mqtt = Provider.of<DirectMQTTService>(
                            context,
                            listen: false,
                          );
                          final next = !room.isFavorite;
                          RoomService.instance.setFavorite(room.id, next);
                          mqtt.setFavoriteRoom(room.id, next);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: room.isFavorite
                                  ? SHColors.amber.withOpacity(0.9)
                                  : Colors.white.withOpacity(0.18),
                            ),
                          ),
                          child: Icon(
                            room.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: room.isFavorite
                                ? SHColors.amber
                                : Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: Text(
                          '${roomLoads.length} loads',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Figma spec: load-type chips row.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: roomLoads.map((load) {
                      final type = load['type']?.toString() ?? 'swt';
                      return Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _getLoadTypeColor(type).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getLoadTypeColor(type).withOpacity(0.35),
                          ),
                        ),
                        child: Image.asset(
                          _getLoadTypeIconAsset(
                            type,
                            isOn: load['isOn'] == true,
                          ),
                          width: 18,
                          height: 18,
                          color: _getLoadTypeColor(type),
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.lightbulb_outline, size: 16),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddRoom(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddRoomScreen()),
    );
  }

  /// Opens the same room-loads page the home screen uses, so every room
  /// entry point shares the identical "Your Room" interface.
  void _openRoomLoads(Room room, List<Map<String, dynamic>> roomLoads) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomLoadsScreen(room: room)),
    );
  }

  void _showEditDeleteDialog(Room room) {
    showDialog(
      context: context,
      builder: (context) => FrostedAlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(room.name, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text(
                'Edit Room',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddRoomScreen(
                      roomToEdit: {
                        'id': room.id,
                        'name': room.name,
                        'imagePath': room.imagePath,
                        'loads': room.loadIds,
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Room',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteRoom(room);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRoom(Room room) {
    final mqttService = Provider.of<DirectMQTTService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => FrostedAlertDialog(
        backgroundColor: Colors.grey[900],
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

  String _getLoadTypeIconAsset(String type, {bool isOn = false}) {
    return loadIconAssetPath(type, isOn: isOn);
  }

  Color _getLoadTypeColor(String type) {
    switch (type) {
      case 'swt':
        return SHColors.green;
      case 'dim':
        return SHColors.amber;
      case 'rgb':
        return SHColors.blue;
      case 'tun':
        return SHColors.dimGrey;
      case 'hvc':
        return SHColors.cyan300;
      case 'fan':
        return SHColors.teal500;
      case 'cur':
        return SHColors.green;
      case 'scn':
        return SHColors.rose;
      default:
        return SHColors.hintColor;
    }
  }
}
