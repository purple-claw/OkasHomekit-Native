// Update the RoomSectionWidget to show room images
// lib/features/home/presentation/widgets/room_section_widget.dart

import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/core/shared/domain/entities/room.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/room_image.dart';
import 'package:ui_common/ui_common.dart';
import 'load_icon.dart';

class RoomSectionWidget extends StatelessWidget {
  final Room room;
  final Map<String, dynamic> savedRoomData;
  final VoidCallback onRoomTap;

  const RoomSectionWidget({
    super.key,
    required this.room,
    required this.savedRoomData,
    required this.onRoomTap,
  });

  @override
  Widget build(BuildContext context) {
    final accessories = savedRoomData['accessories'] as List<dynamic>? ?? [];
    final imagePath = savedRoomData['imagePath'] as String?;

    // Count different types of loads
    final switchCount = accessories.where((a) {
      final t = a['type']?.toString().toLowerCase() ?? '';
      return t == 'switch' || t == 'swt';
    }).length;
    final dimmerCount = accessories.where((a) {
      final t = a['type']?.toString().toLowerCase() ?? '';
      return t == 'dimmer' || t == 'dim';
    }).length;
    final tunableCount = accessories.where((a) {
      final t = a['type']?.toString().toLowerCase() ?? '';
      return t == 'tunable' || t == 'tun';
    }).length;
    final rgbCount = accessories.where((a) {
      final t = a['type']?.toString().toLowerCase() ?? '';
      return t == 'rgb';
    }).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SHColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRoomTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room Header with Image
                Row(
                  children: [
                    // Room Image or Placeholder
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: SHColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RoomImage(
                          imagePath: imagePath,
                          width: 60,
                          height: 60,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: context.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${accessories.length} devices',
                            style: context.bodySmall.copyWith(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: SHColors.primary,
                      size: 24,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Load Stats Section
                if (accessories.isNotEmpty) ...[
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 16),

                  // Load types grid
                  Row(
                    children: [
                      _buildLoadStat(
                        context,
                        'Switch',
                        switchCount,
                        loadIconAssetPath('swt'),
                        Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _buildLoadStat(
                        context,
                        'Dimmer',
                        dimmerCount,
                        loadIconAssetPath('dim'),
                        Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      _buildLoadStat(
                        context,
                        'Tunable',
                        tunableCount,
                        loadIconAssetPath('tun'),
                        Colors.purple,
                      ),
                      const SizedBox(width: 16),
                      _buildLoadStat(
                        context,
                        'RGB',
                        rgbCount,
                        loadIconAssetPath('rgb'),
                        Colors.blue,
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No loads added yet',
                        style: context.bodySmall.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadStat(
    BuildContext context,
    String label,
    int count,
    String iconAsset,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Image.asset(
              iconAsset,
              width: 20,
              height: 20,
              color: color,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.lightbulb_outline, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: context.bodySmall.copyWith(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
