// lib/features/home/presentation/widgets/sm_home_bottom_navigation.dart
// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';

class SmHomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabTapped;

  const SmHomeBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: SHColors.black.withOpacity(0.82),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: SHColors.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTabTapped,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: SHColors.primary,
            unselectedItemColor: SHColors.hintColor,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: [
              BottomNavigationBarItem(
                icon: _buildIcon(
                  'assets/icons/home.png',
                  22,
                  color: SHColors.hintColor,
                ),
                activeIcon: _activeIcon('assets/icons/home.png'),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: _buildIcon(
                  'assets/icons/loads.png',
                  22,
                  color: SHColors.hintColor,
                ),
                activeIcon: _activeIcon('assets/icons/loads.png'),
                label: 'Loads',
              ),
              BottomNavigationBarItem(
                icon: _buildIcon(
                  'assets/icons/room.png',
                  22,
                  color: SHColors.hintColor,
                ),
                activeIcon: _activeIcon('assets/icons/room.png'),
                label: 'Rooms',
              ),
              BottomNavigationBarItem(
                icon: _buildIcon(
                  'assets/icons/scene.png',
                  22,
                  color: SHColors.hintColor,
                ),
                activeIcon: _activeIcon('assets/icons/scene.png'),
                label: 'Scenes',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline, size: 22),
                activeIcon: _activeIcon(null, icon: Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeIcon(String? path, {IconData? icon}) {
    return Container(
      width: 36,
      height: 30,
      decoration: BoxDecoration(
        color: SHColors.primary.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SHColors.primary.withOpacity(0.28)),
      ),
      child: Center(
        child: path == null
            ? Icon(icon, color: SHColors.primary, size: 22)
            : _buildIcon(path, 22, color: SHColors.primary),
      ),
    );
  }

  Widget _buildIcon(String path, double size, {Color? color}) {
    return Image.asset(
      path,
      width: size,
      height: size,
      color: color,
      errorBuilder: (_, __, ___) {
        if (path.contains('room')) {
          return Icon(Icons.meeting_room, size: size, color: color);
        } else if (path.contains('home')) {
          return Icon(Icons.home, size: size, color: color);
        } else if (path.contains('loads')) {
          return Icon(Icons.lightbulb_outline, size: size, color: color);
        } else if (path.contains('scene')) {
          return Icon(Icons.auto_awesome, size: size, color: color);
        }
        return Icon(Icons.circle, size: size, color: color);
      },
    );
  }

  Widget _buildSvgIcon(String path, double size, {Color? color}) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    );
  }
}
