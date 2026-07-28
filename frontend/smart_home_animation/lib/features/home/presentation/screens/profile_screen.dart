// screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/features/home/presentation/screens/guest_management_screen.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<TokenAuthService>();

    if (!auth.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Guest access management is available only for the admin user.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SHColors.mutedText),
          ),
        ),
      );
    }

    return const GuestManagementScreen(showAppBar: false);
  }
}
