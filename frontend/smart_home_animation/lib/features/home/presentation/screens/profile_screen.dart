// screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/features/home/presentation/screens/guest_management_screen.dart';
import 'package:smart_home_animation/services/house_name_service.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';

class HouseNameToggleTile extends StatelessWidget {
  const HouseNameToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final service = HouseNameService.instance;
          return TextButton.icon(
            onPressed: () {
              final next = !service.showHouseName;
              service.setShowHouseName(next);
              setState(() {});
            },
            icon: Icon(
              service.showHouseName
                  ? Icons.home_outlined
                  : Icons.home_work_outlined,
              size: 18,
              color: service.showHouseName
                  ? SHColors.primary
                  : SHColors.mutedText,
            ),
            label: Text(
              service.showHouseName ? 'Hide house name' : 'Show house name',
              style: const TextStyle(color: SHColors.textColor),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<TokenAuthService>();

    return Column(
      children: [
        // Profile header: house name + logout always available.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      auth.isAdmin ? 'House Owner' : 'Guest',
                      style: const TextStyle(
                        color: SHColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Logout — always available regardless of role.
              TextButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(
                  Icons.logout,
                  size: 18,
                  color: SHColors.rose,
                ),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: SHColors.rose),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        if (auth.isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showChangePasswordDialog(context),
                icon: const Icon(
                  Icons.lock_reset,
                  size: 18,
                  color: SHColors.primary,
                ),
                label: const Text(
                  'Change Password',
                  style: TextStyle(color: SHColors.textColor),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: SizedBox(
            width: double.infinity,
            child: HouseNameToggleTile(),
          ),
        ),
        Expanded(
          child: !auth.isAdmin
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Guest access management is available only for the admin user.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SHColors.mutedText),
                    ),
                  ),
                )
              : const GuestManagementScreen(showAppBar: false),
        ),
      ],
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var saving = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: SHColors.elevatedCardColor,
          title: const Text(
            'Change Password',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'New password',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final current = currentController.text;
                      final next = newController.text;
                      final confirm = confirmController.text;
                      if (next != confirm) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('New passwords do not match.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await context
                            .read<TokenAuthService>()
                            .changePassword(
                              currentPassword: current,
                              newPassword: next,
                            );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: SHColors.primary,
              ),
              child: Text(saving ? 'Saving…' : 'Update'),
            ),
          ],
        ),
      ),
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. Use it next time you sign in.'),
          backgroundColor: SHColors.green,
        ),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SHColors.elevatedCardColor,
        title: const Text(
          'Log out?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You will need to enter your access token again to reconnect.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: SHColors.rose),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<TokenAuthService>().logout();
      // Also drop the MQTT connection so the token entry screen starts clean.
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/token-entry',
        (route) => false,
      );
    }
  }
}
