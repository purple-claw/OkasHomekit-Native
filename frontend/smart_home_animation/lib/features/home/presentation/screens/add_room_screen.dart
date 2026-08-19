// lib/features/home/presentation/screens/add_room_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/room_image_sync_service.dart';
import '../widgets/load_icon.dart';

class AddRoomScreen extends StatefulWidget {
  final Map<String, dynamic>? roomToEdit;

  const AddRoomScreen({super.key, this.roomToEdit});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selectedLoadIds = {};
  String? _roomImagePath;
  bool _isImageLoading = false;
  List<Map<String, dynamic>> _availableLoads = [];
  bool get _isEditing => widget.roomToEdit != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableLoads();
      if (_isEditing) {
        _loadExistingRoom();
      }
    });
  }

  void _loadExistingRoom() {
    final room = widget.roomToEdit!;
    _nameController.text = room['name']?.toString() ?? '';
    _roomImagePath = room['imagePath']?.toString();
    final loads = room['loads'] as List<dynamic>? ?? [];
    setState(() {
      _selectedLoadIds.addAll(loads.map((e) => e.toString()));
    });
  }

  void _loadAvailableLoads() {
    final mqttService = Provider.of<DirectMQTTService>(context, listen: false);
    mqttService.addListener(_onLoadsUpdated);
    _onLoadsUpdated();
  }

  void _onLoadsUpdated() {
    final mqttService = Provider.of<DirectMQTTService>(context, listen: false);
    setState(() {
      _availableLoads = mqttService.getLoadsList();
    });
  }

  @override
  void dispose() {
    try {
      final mqttService = Provider.of<DirectMQTTService>(
        context,
        listen: false,
      );
      mqttService.removeListener(_onLoadsUpdated);
    } catch (e) {
      // Widget may be unmounted
    }
    _nameController.dispose();
    super.dispose();
  }

  Future<String?> _compressAndSaveImage(String originalPath) async {
    try {
      final originalImage = File(originalPath);
      final imageBytes = await originalImage.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Cap the long edge at 1600px which is plenty for a phone display at
      // @3x (the source-of-truth 220dp room card tops out around 660px).
      // Down-scaling below 1000px is what causes the pixelation users see
      // when the source is a high-res camera shot.
      const maxEdge = 1600;
      img.Image resizedImage;
      if (image.width >= image.height && image.width > maxEdge) {
        resizedImage = img.copyResize(image, width: maxEdge);
      } else if (image.height > maxEdge) {
        resizedImage = img.copyResize(image, height: maxEdge);
      } else {
        // Source is already small enough — do not downscale.
        resizedImage = image;
      }

      final compressedBytes = img.encodeJpg(resizedImage, quality: 92);
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'room_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File('${appDir.path}/$fileName');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile.path;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return originalPath;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isImageLoading = true);

      final picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: source,
        // No maxWidth/maxHeight so the picker hands back the full-resolution
        // source — the resize step in _compressAndSaveImage is the single
        // place where we normalise the image, and it keeps aspect ratio.
        imageQuality: 100,
      );

      if (pickedImage != null) {
        final compressedPath = await _compressAndSaveImage(pickedImage.path);
        if (!mounted) return;
        setState(() {
          _roomImagePath = compressedPath;
          _isImageLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room image added successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        setState(() => _isImageLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImageLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Room Image',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImagePickerOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildImagePickerOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SHColors.primary.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: SHColors.primary, size: 40),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() => _roomImagePath = null);
  }

  void _toggleLoadSelection(String loadId) {
    setState(() {
      if (_selectedLoadIds.contains(loadId)) {
        _selectedLoadIds.remove(loadId);
      } else {
        _selectedLoadIds.add(loadId);
      }
    });
  }

  Future<void> _saveRoom() async {
    final roomName = _nameController.text.trim();

    if (roomName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a room name')));
      return;
    }

    final String roomId;
    if (_isEditing && widget.roomToEdit != null) {
      roomId =
          widget.roomToEdit!['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
    } else {
      roomId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    // If a local image was picked, upload it to the board first so every
    // device on the network can see it (the board URL replaces the local
    // path and syncs via MQTT rooms/set).
    final syncedImagePath = await RoomImageSyncService.instance
        .syncImageToBoard(_roomImagePath);

    final roomData = {
      'id': roomId,
      'name': roomName,
      'imagePath': syncedImagePath,
      'loads': _selectedLoadIds.toList(),
      'createdAt': _isEditing
          ? widget.roomToEdit!['createdAt'] ?? DateTime.now().toIso8601String()
          : DateTime.now().toIso8601String(),
    };

    // Push the new room straight to the board. We deliberately do NOT
    // add it to the local RoomService cache here — the board's `rooms/set`
    // reply (retained on the broker so it arrives immediately on a fresh
    // subscription) is the single source of truth and populates the
    // local list via replaceRooms. Adding locally and then having the
    // board's reply overwrite it was the root cause of the "deleted
    // rooms reappear when I create a new room" bug: a previous version
    // of the local cache would briefly reappear if the rooms/set response
    // raced the local add. Skipping the local add eliminates the race.
    if (!mounted) return;
    final mqttService = Provider.of<DirectMQTTService>(context, listen: false);
    mqttService.publish('rooms/add', json.encode(roomData));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Room "$roomName" updated!'
                : 'Room "$roomName" saved with ${_selectedLoadIds.length} loads!',
          ),
          backgroundColor: SHColors.primary,
        ),
      );
      Navigator.pop(context, roomData);
    }
  }

  void _cancel() {
    Navigator.pop(context);
  }

  String _getLoadTypeIcon(String type) {
    return loadIconAssetPath(type);
  }

  Color _getLoadTypeColor(String type) {
    switch (type) {
      case 'swt':
        return Colors.green;
      case 'dim':
        return Colors.orange;
      case 'rgb':
        return Colors.purple;
      case 'tun':
        return Colors.amber;
      case 'hvc':
        return Colors.cyan;
      case 'fan':
        return Colors.teal;
      case 'cur':
        return Colors.green;
      case 'scn':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            _isEditing ? 'Edit Room' : 'Add New Room',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: _cancel,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room Image Section
                    const Text(
                      'Room Image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: SHColors.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: _isImageLoading
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 8),
                                    Text(
                                      'Processing image...',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              )
                            : _roomImagePath != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(_roomImagePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.7),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          onPressed: _showImagePickerOptions,
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black54,
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          onPressed: _removeImage,
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black54,
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: SHColors.primary.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tap to add room image',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Enter Room Name Section
                    const Text(
                      'Enter Room Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: SHColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g., Living Room, Bedroom',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Available Loads Section
                    const Text(
                      'Select Loads for this Room',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_availableLoads.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No loads found. Configure KNX loads first.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _availableLoads.length,
                        itemBuilder: (context, index) {
                          final load = _availableLoads[index];
                          final loadId = (load['id'] ?? index + 1).toString();
                          final loadName =
                              load['name'] ?? load['nm'] ?? 'Load ${index + 1}';
                          final loadType =
                              (load['type'] ?? load['typ'] ?? 'swt').toString();
                          final isSelected = _selectedLoadIds.contains(loadId);

                          return GestureDetector(
                            onTap: () => _toggleLoadSelection(loadId),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _getLoadTypeColor(
                                        loadType,
                                      ).withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? _getLoadTypeColor(loadType)
                                      : Colors.white.withValues(alpha: 0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getLoadTypeColor(
                                        loadType,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Image.asset(
                                      _getLoadTypeIcon(loadType),
                                      width: 20,
                                      height: 20,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.lightbulb_outline,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loadName,
                                          style: TextStyle(
                                            color: isSelected
                                                ? _getLoadTypeColor(loadType)
                                                : Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          loadType.toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: _getLoadTypeColor(loadType),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveRoom,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: SHColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _selectedLoadIds.isEmpty
                            ? 'Save Room'
                            : 'Save (${_selectedLoadIds.length} loads)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
