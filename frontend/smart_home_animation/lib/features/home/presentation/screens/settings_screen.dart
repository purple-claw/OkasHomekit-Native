// lib/screens/settings_screen.dart
// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/services/mqtt_command_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mqttService = Provider.of<MQTTService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          // Edit Home View
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Home View'),
            subtitle: const Text('Reorder Sections'),
            onTap: () {
              _showReorderDialog(context);
            },
          ),
          const Divider(),

          // Down Lights section (from image)
          _buildIssueTile('Down Lights', 'No Response', Colors.red),
          _buildIssueTile('Strip Light', 'No Response', Colors.red),
          _buildIssueTile('Focus Light', 'No Response', Colors.red),
          _buildIssueTile('test', 'No Response', Colors.red),
          _buildIssueTile('Curtain', 'No Response', Colors.red),

          const Divider(),

          // Home Hubs & Bridges
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Home Hubs & Bridges'),
            onTap: () {
              _showHubsDialog(context);
            },
          ),

          // Scenes
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Scenes'),
            subtitle: const Text('Show Suggested Scenes'),
            onTap: () {
              _showScenesDialog(context);
            },
          ),

          // Home Wallpaper
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: const Text('Home Wallpaper'),
            onTap: () {
              _showWallpaperDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIssueTile(String title, String subtitle, Color color) {
    return ListTile(
      leading: Icon(Icons.warning, color: color),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }

  void _showReorderDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Reorder Sections', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.drag_handle),
              title: Text('Big HT'),
            ),
            const ListTile(
              leading: Icon(Icons.drag_handle),
              title: Text('Display Area'),
            ),
            const ListTile(
              leading: Icon(Icons.drag_handle),
              title: Text('Loads'),
            ),
            const ListTile(
              leading: Icon(Icons.drag_handle),
              title: Text('Small HT'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHubsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Home Hubs & Bridges'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.hub),
              title: Text('OKAS Bridge'),
              subtitle: Text('Connected'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showScenesDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Suggested Scenes', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.home),
              title: Text('Arrive Home'),
            ),
            const ListTile(
              leading: Icon(Icons.wb_sunny),
              title: Text('Good Morning'),
            ),
            const ListTile(
              leading: Icon(Icons.nightlight),
              title: Text('Good Night'),
            ),
            const ListTile(
              leading: Icon(Icons.logout),
              title: Text('Leave Home'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWallpaperDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Wallpaper', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo...'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose from Existing'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
