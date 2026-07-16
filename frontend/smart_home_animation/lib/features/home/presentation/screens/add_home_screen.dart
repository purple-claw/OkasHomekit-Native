// lib/screens/add_home_screen.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/safe_image.dart';

class AddHomeScreen extends StatefulWidget {
  const AddHomeScreen({super.key});

  @override
  State<AddHomeScreen> createState() => _AddHomeScreenState();
}

class _AddHomeScreenState extends State<AddHomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedWallpaper;

  final List<String> _wallpapers = [
    'assets/wallpapers/home1.jpg',
    'assets/wallpapers/home2.jpg',
    'assets/wallpapers/home3.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Home'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(onPressed: () => _saveHome(), child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Home Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Home Name',
                hintText: 'e.g., Holiday House',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty == true ? 'Please enter home name' : null,
            ),
            const SizedBox(height: 16),

            // Home Wallpaper
            const Text('Home Wallpaper', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Take photo
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo...'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showWallpaperPicker(),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose from Existing'),
                  ),
                ),
              ],
            ),
            if (_selectedWallpaper != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SafeImage(
                  imageUrl: _selectedWallpaper!,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showWallpaperPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Wallpaper', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _wallpapers.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedWallpaper = _wallpapers[index]);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: AssetImage(_wallpapers[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveHome() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'name': _nameController.text,
        'wallpaper': _selectedWallpaper,
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
