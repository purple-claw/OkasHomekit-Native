// lib/features/home/presentation/screens/rooms_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/room_service.dart';
import 'package:smart_home_animation/features/home/presentation/screens/add_room_screen.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: rooms.isEmpty ? _buildEmptyState() : _buildRoomsList(rooms, loads),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddRoom(context),
        backgroundColor: SHColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            'Create rooms to organize your loads',
            style: TextStyle(color: SHColors.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddRoom(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SHColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      onTap: () => _showRoomDetail(room, roomLoads),
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
                    child: room.imagePath != null &&
                            File(room.imagePath!).existsSync()
                        ? Image.file(
                            File(room.imagePath!),
                            fit: BoxFit.cover,
                            // Cache at the device pixel ratio so the image
                            // stays sharp when the card is rebuilt — without
                            // this Flutter re-decodes the file at every
                            // rebuild and the user sees a brief blur.
                            cacheWidth: 800,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) =>
                                _buildRoomPlaceholder(),
                          )
                        : _buildRoomPlaceholder(),
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
                  child: Container(
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
                          _getLoadTypeIconAsset(type),
                          width: 18,
                          height: 18,
                          color: _getLoadTypeColor(type),
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


  Widget _buildRoomPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Image.asset(
          'assets/icons/room.png',
          width: 48,
          height: 48,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.meeting_room, size: 48, color: SHColors.hintColor),
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

  void _showRoomDetail(Room room, List<Map<String, dynamic>> roomLoads) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SHColors.radiusXl),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: SHColors.elevatedCardColor,
              // Use the opaque sheet gradient here — this sheet floats above
              // the rooms list and would otherwise let the room cards bleed
              // through. Tiles and inline cards keep `cardGradient`.
              gradient: SHColors.sheetGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SHColors.radiusXl),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditDeleteDialog(room);
                        },
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                // Loads list
                Expanded(
                  child: roomLoads.isEmpty
                      ? Center(
                          child: Text(
                            'No loads in this room',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: roomLoads.length,
                          itemBuilder: (context, index) {
                            final load = roomLoads[index];
                            return _buildLoadTile(load);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadTile(Map<String, dynamic> load) {
    return Consumer<DirectMQTTService>(
      builder: (context, mqttService, child) {
        final loadId = load['id']?.toString() ?? '0';
        final currentLoad = mqttService.getLoadsList().firstWhere(
          (l) => l['id']?.toString() == loadId,
          orElse: () => load,
        );
        final name =
            currentLoad['name']?.toString() ??
            load['name']?.toString() ??
            'Unknown';
        final type =
            currentLoad['type']?.toString() ??
            load['type']?.toString() ??
            'swt';
        final isOn = currentLoad['isOn'] as bool? ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: SHColors.glassDecoration(radius: SHColors.radiusMd),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getLoadTypeColor(type).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  _getLoadTypeIconAsset(type),
                  width: 20,
                  height: 20,
                  color: _getLoadTypeColor(type),
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.lightbulb_outline, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      type.toUpperCase(),
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOn,
                onChanged: (value) {
                  mqttService.sendCommand(loadId, value ? 'ON' : 'OFF');
                },
                activeColor: _getLoadTypeColor(type),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDeleteDialog(Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
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

  String _getLoadTypeIconAsset(String type) {
    switch (type) {
      case 'swt':
        return 'assets/icons/switch.png';
      case 'dim':
        return 'assets/icons/dimmer.png';
      case 'rgb':
        return 'assets/icons/rgb.png';
      case 'tun':
        return 'assets/icons/tunable.png';
      case 'hvc':
        return 'assets/icons/hvac.png';
      case 'fan':
        return 'assets/icons/fan.png';
      case 'cur':
        return 'assets/icons/curtain.png';
      case 'scn':
        return 'assets/icons/scene.png';
      default:
        return 'assets/icons/light.png';
    }
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
        return SHColors.violet;
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
