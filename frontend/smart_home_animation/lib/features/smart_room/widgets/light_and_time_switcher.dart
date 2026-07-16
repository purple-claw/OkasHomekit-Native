// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_state.dart';

import '../../../core/core.dart';

class LightsAndTimerSwitchers extends StatelessWidget {
  const LightsAndTimerSwitchers({
    required this.room,
    required this.roomDeviceStates,
    required this.onDeviceToggle,
    super.key,
  });

  final SmartRoom room;
  final Map<String, DeviceState> roomDeviceStates;
  final Function(String deviceId, bool value) onDeviceToggle;

  @override
  Widget build(BuildContext context) {
    return SHCard(
      childrenPadding: const EdgeInsets.all(12),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lights'),
            const SizedBox(height: 8),
            SHSwitcher(
              value: room.lights.isOn,
              onChanged: (value) {},
              icon: const Icon(SHIcons.lightBulbOutline),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const Row(children: [Text('Timer'), Spacer(), BlueLightDot()]),
            const SizedBox(height: 8),
            // Timer Section
            _buildTimerSection(),

            // SHSwitcher(
            //   icon: room.timer.isOn
            //       ? const Icon(SHIcons.timer)
            //       : const Icon(SHIcons.timerOff),
            //   value: room.timer.isOn,
            //   onChanged: (value) {},
            // ),
          ],
        ),
      ],
    );
  }
}

Widget _buildTimerSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Text(
            'TIMER',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Spacer(),
          BlueLightDot(),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTimerButton(minutes: 15),
          _buildTimerButton(minutes: 30),
          _buildTimerButton(minutes: 60),
          _buildTimerButton(minutes: 60),
        ],
      ),
    ],
  );
}

Widget _buildTimerButton({required int minutes}) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 2,
      ), // Small margin for spacing
      child: Material(
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            // Handle timer button tap
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, size: 20, color: Colors.blue),
                const SizedBox(height: 4),
                Text(
                  '${minutes}m',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
