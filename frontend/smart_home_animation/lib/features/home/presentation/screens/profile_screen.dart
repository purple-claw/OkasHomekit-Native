// screens/profile_screen.dart
//
// Profile Management screen. Layout follows the Figma frame: centered
// identity header (avatar, owner name, email, Logout pill), then GENERAL
// and GUEST MANAGEMENT sections of frosted-glass cards. Owner name and
// email come from the board's Auth API (session principal).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/glass_panel.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/features/home/presentation/screens/guest_management_screen.dart';
import 'package:smart_home_animation/services/house_name_service.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<TokenAuthService>();
    final admin = auth.isAdmin;
    final ownerName = auth.displayName ?? HouseNameService.instance.ownerName;
    final email = auth.adminEmail ?? '';
    final initial = ownerName.isNotEmpty
        ? ownerName[0].toUpperCase()
        : (HouseNameService.instance.houseName.isNotEmpty
              ? HouseNameService.instance.houseName[0].toUpperCase()
              : 'O');

    return Column(
      children: [
        const SizedBox(height: 24),
        // Centered identity header (avatar, name, email, logout).
        // Outer 96px ring per the Figma frame, teal 78px inner disc.
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0x24686F7D), // rgba(104,111,125,0.14)
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF4FE3F2),
                    SHColors.primary,
                    Color(0xFF007380),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          admin ? ownerName : 'Guest',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            email,
            style: const TextStyle(
              color: SHColors.figmaOrange,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Frosted logout pill (neutral glass, red icon + text).
        Center(
          child: SizedBox(
            width: 97,
            child: GlassPanel(
              radius: SHColors.pillRadius,
              blur: 7,
              fillColor: Colors.white.withValues(alpha: 0.04),
              onTap: () => _confirmLogout(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 16, color: SHColors.figmaRed),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: SHColors.figmaRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (admin) ...[
          // GENERAL section.
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'GENERAL',
                style: TextStyle(
                  color: SHColors.figmaGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: GlassPanel(
              radius: 14,
              blur: 6,
              onTap: () => _showChangePasswordDialog(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 17),
                child: Row(
                  children: [
                    Text(
                      'Change Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: SHColors.figmaGray,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: GlassPanel(
              radius: 14,
              blur: 6,
              onTap: () => _showHelpDialog(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 17),
                child: Row(
                  children: [
                    Text(
                      'Help & Support',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: SHColors.figmaGray,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // GUEST MANAGEMENT section.
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'GUEST MANAGEMENT',
                style: TextStyle(
                  color: SHColors.figmaGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
        Expanded(
          child: !admin
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Guest management is available only for the House Owner.',
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
        builder: (ctx, setDialogState) => FrostedAlertDialog(
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
                        await context.read<TokenAuthService>().changePassword(
                          currentPassword: current,
                          newPassword: next,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('$e')));
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

  Future<void> _showHelpDialog(BuildContext context) async {
    final email = context.read<TokenAuthService>().adminEmail ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
        backgroundColor: SHColors.elevatedCardColor,
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          email.isEmpty
              ? 'Contact your installer for assistance with OKAS Homekit.'
              : 'Having Trouble? Contact Your OKAS Distributor / Programmer for Technical Support.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
        backgroundColor: SHColors.elevatedCardColor,
        title: const Text('Log out?', style: TextStyle(color: Colors.white)),
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
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/token-entry', (route) => false);
    }
  }
}
