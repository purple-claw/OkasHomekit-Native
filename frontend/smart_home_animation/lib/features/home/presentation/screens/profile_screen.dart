// screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';
import 'package:ui_common/ui_common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<TokenAuthService>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        context.primaryColor,
                        context.primaryColor.withOpacity(0.5),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'John Doe',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'john.doe@example.com',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Settings Sections
          _buildSection(
            title: 'Account Settings',
            items: [
              _buildSettingItem(
                icon: Icons.person_outline,
                title: 'Personal Information',
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.lock_outline,
                title: 'Privacy & Security',
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () {},
              ),
            ],
          ),

          _buildSection(
            title: 'Smart Home Settings',
            items: [
              if (auth.isAdmin)
                _buildSettingItem(
                  icon: Icons.group_outlined,
                  title: 'Guest Access',
                  value: 'Manage guest tokens',
                  onTap: () => Navigator.pushNamed(context, '/guests'),
                ),
              _buildSettingItem(
                icon: Icons.devices_outlined,
                title: 'Connected Devices',
                value: '12 devices',
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.auto_awesome_outlined,
                title: 'Scenes & Automation',
                value: '8 scenes',
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.room_outlined,
                title: 'Rooms',
                value: '5 rooms',
                onTap: () {},
              ),
            ],
          ),

          _buildSection(
            title: 'Support',
            items: [
              _buildSettingItem(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.feedback_outlined,
                title: 'Send Feedback',
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.info_outline,
                title: 'About',
                value: 'Version 1.0.0',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Sign Out Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                _showSignOutDialog(context, auth);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SHTheme.dark.primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: items),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20),
      ),
      title: Text(title),
      trailing: value != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            )
          : const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  void _showSignOutDialog(BuildContext context, TokenAuthService auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await auth.logout();
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/pin');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
