// lib/features/home/presentation/screens/add_room_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selectedLoads = {};

  // Image selection
  String? _roomImagePath;
  bool _isImageLoading = false;

  // All load types with their details
  final List<LoadType> _loadTypes = [
    LoadType(
      name: 'Switch',
      defaultName: 'Light',
      icon: Icons.power_settings_new,
      color: Colors.green,
    ),
    LoadType(
      name: 'Dimmer',
      defaultName: 'Dimmer Light',
      icon: Icons.brightness_low,
      color: Colors.orange,
    ),
    LoadType(
      name: 'Tunable',
      defaultName: 'Tunable Light',
      icon: Icons.tune,
      color: Colors.purple,
    ),
    LoadType(
      name: 'RGB',
      defaultName: 'RGB Light',
      icon: Icons.palette,
      color: Colors.blue,
    ),
    LoadType(
      name: 'HVAC',
      defaultName: 'HVAC',
      icon: Icons.ac_unit,
      color: Colors.cyan,
    ),
    LoadType(
      name: 'Scene',
      defaultName: 'Scene',
      icon: Icons.auto_awesome,
      color: Colors.pink,
    ),
    LoadType(
      name: 'Fan',
      defaultName: 'Fan',
      icon: Icons.toys,
      color: Colors.teal,
    ),
    LoadType(
      name: 'Curtain',
      defaultName: 'Curtain',
      icon: Icons.curtains,
      color: Colors.brown,
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<String?> _compressAndSaveImage(String originalPath) async {
    try {
      // Read the original image
      final originalImage = File(originalPath);
      final imageBytes = await originalImage.readAsBytes();

      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Resize image to max width/height of 500px while maintaining aspect ratio
      final maxSize = 500;
      img.Image resizedImage;
      if (image.width > image.height) {
        resizedImage = img.copyResize(image, width: maxSize);
      } else {
        resizedImage = img.copyResize(image, height: maxSize);
      }

      // Compress JPEG with 70% quality
      final compressedBytes = img.encodeJpg(resizedImage, quality: 70);

      // Save compressed image to app's local directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'room_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File('${appDir.path}/$fileName');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile.path;
    } catch (e) {
      print('Error compressing image: $e');
      return originalPath; // Return original if compression fails
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isImageLoading = true;
      });

      final picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: source,
        maxWidth: 1200, // Slightly larger for better quality before compression
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        // Compress and save the image
        final compressedPath = await _compressAndSaveImage(pickedImage.path);

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
        setState(() {
          _isImageLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isImageLoading = false;
      });
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
          border: Border.all(color: SHColors.primary.withOpacity(0.5)),
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
    setState(() {
      _roomImagePath = null;
    });
  }

  void _toggleLoadSelection(String loadType) {
    setState(() {
      if (_selectedLoads.contains(loadType)) {
        _selectedLoads.remove(loadType);
      } else {
        _selectedLoads.add(loadType);
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

    if (_selectedLoads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one load type')),
      );
      return;
    }

    final okasService = Provider.of<DirectMQTTService>(context, listen: false);

    // Create accessories from selected loads
    final accessories = _selectedLoads.map((loadType) {
      final loadTypeObj = _loadTypes.firstWhere((l) => l.name == loadType);
      return {
        'id': DateTime.now().millisecondsSinceEpoch.toString() + loadType,
        'name': loadTypeObj.defaultName,
        'type': loadType,
        'isOn': false,
      };
    }).toList();

    // Create room data
    final roomId = DateTime.now().millisecondsSinceEpoch.toString();
    final roomData = {
      'id': roomId,
      'name': roomName,
      'accessories': accessories,
      'createdAt': DateTime.now().toIso8601String(),
      'imagePath': _roomImagePath, // Save the compressed image path
    };

    // Send to OKAS board via MQTT
    okasService.publish('rooms/add', json.encode(roomData));

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    final savedRoomsJson = prefs.getStringList('saved_rooms') ?? [];
    final savedRooms = savedRoomsJson
        .map((json) => jsonDecode(json) as Map<String, dynamic>)
        .toList();

    savedRooms.add(roomData);
    await prefs.setStringList(
      'saved_rooms',
      savedRooms.map((room) => jsonEncode(room)).toList(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Room "$roomName" saved successfully!'),
          backgroundColor: SHColors.primary,
        ),
      );
      Navigator.pop(context, roomData);
    }
  }

  void _cancel() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: SHColors.backgroundColor),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Add New Room',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: SHColors.primary.withOpacity(0.3),
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
                                          Colors.black.withOpacity(0.7),
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
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Tap to change',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
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
                                    color: SHColors.primary.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to add room image',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Camera or Gallery',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
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
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: SHColors.primary.withOpacity(0.3),
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

                    // Add Loads Section
                    const Text(
                      'Add Loads',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Horizontal Scrollable Load Types
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _loadTypes.length,
                        itemBuilder: (context, index) {
                          final loadType = _loadTypes[index];
                          final isSelected = _selectedLoads.contains(
                            loadType.name,
                          );
                          return _buildLoadCard(loadType, isSelected);
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Selected Loads Summary
                    if (_selectedLoads.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: SHColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.checklist,
                                  color: SHColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Selected Loads (${_selectedLoads.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedLoads.map((loadName) {
                                final loadType = _loadTypes.firstWhere(
                                  (l) => l.name == loadName,
                                );
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: loadType.color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: loadType.color.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        loadType.icon,
                                        color: loadType.color,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        loadName,
                                        style: TextStyle(
                                          color: loadType.color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Buttons - Cancel and Save
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
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
                        side: BorderSide(color: Colors.red.withOpacity(0.7)),
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
                      child: const Text(
                        'Save',
                        style: TextStyle(
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

  Widget _buildLoadCard(LoadType loadType, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleLoadSelection(loadType.name),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? loadType.color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? loadType.color : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(
                  loadType.icon,
                  color: isSelected ? loadType.color : Colors.white54,
                  size: 40,
                ),
                if (isSelected)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: loadType.color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loadType.name,
              style: TextStyle(
                color: isSelected ? loadType.color : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Load Type Model
class LoadType {
  final String name;
  final String defaultName;
  final IconData icon;
  final Color color;

  LoadType({
    required this.name,
    required this.defaultName,
    required this.icon,
    required this.color,
  });
}
