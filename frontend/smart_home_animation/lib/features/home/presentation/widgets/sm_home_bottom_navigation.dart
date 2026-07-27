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
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTabTapped,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: SHColors.primary,
        unselectedItemColor: Colors.white54,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        items: [
          BottomNavigationBarItem(
            icon: _buildIcon('assets/icons/home.png', 24),
            activeIcon: _buildIcon(
              'assets/icons/home.png',
              24,
              color: SHColors.primary,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('assets/icons/loads.png', 24),
            activeIcon: _buildIcon(
              'assets/icons/loads.png',
              24,
              color: SHColors.primary,
            ),
            label: 'Loads',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('assets/icons/room.png', 24),
            activeIcon: _buildIcon(
              'assets/icons/room.png',
              24,
              color: SHColors.primary,
            ),
            label: 'Rooms',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('assets/icons/scene.png', 24),
            activeIcon: _buildIcon(
              'assets/icons/scene.png',
              24,
              color: SHColors.primary,
            ),
            label: 'Scenes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 24),
            activeIcon: Icon(Icons.person, size: 24),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // For PNG/JPG images
  Widget _buildIcon(String path, double size, {Color? color}) {
    // Handle missing icons gracefully
    try {
      return Image.asset(path, width: size, height: size, color: color);
    } catch (e) {
      // Fallback to appropriate icon based on path
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
    }
  }

  // For SVG images (if using flutter_svg)
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
