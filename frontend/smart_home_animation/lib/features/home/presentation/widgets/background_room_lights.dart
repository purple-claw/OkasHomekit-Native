// ignore_for_file: deprecated_member_use, unused_local_variable

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';

import '../../../../core/core.dart';
import '../../../../services/device_provider.dart';

class BackgroundRoomCard extends StatelessWidget {
  const BackgroundRoomCard({
    required this.room,
    required this.translation,
    super.key,
  });

  final SmartRoom room;
  final double translation;

  // Helper method to find device safely
  Device? _findDevice(List<Device> devices, DeviceType type) {
    try {
      return devices.firstWhere((d) => d.type == type);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = Provider.of<DeviceProvider>(context);

    // Get devices for this room
    final roomDevices = deviceProvider.getDevicesByRoom(room.id);

    // Find specific devices using helper method
    final lightDevice = _findDevice(roomDevices, DeviceType.light);
    final acDevice = _findDevice(roomDevices, DeviceType.airConditioner);
    // final speakerDevice = _findDevice(roomDevices, DeviceType.speaker);

    // Get states
    final lightState = lightDevice != null
        ? deviceProvider.getDeviceState(lightDevice.id)
        : null;
    final acState = acDevice != null
        ? deviceProvider.getDeviceState(acDevice.id)
        : null;
    // final speakerState = speakerDevice != null
    //     ? deviceProvider.getDeviceState(speakerDevice.id)
    //     : null;

    // Get temperature and humidity from sensors
    final tempSensor = room.temperatureSensor;
    final humiditySensor = room.humiditySensor;

    // Use device properties
    final lightsOn = lightState?.isOn ?? lightDevice?.isOn ?? room.lights.isOn;
    final acOn = acState?.isOn ?? acDevice?.isOn ?? room.airCondition.isOn;
    // final speakerOn =
    //     speakerState?.isOn ?? speakerDevice?.isOn ?? room.musicInfo.isOn;

    return Transform(
      transform: Matrix4.translationValues(0, 80 * translation, 0),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF2C2C2E),
          borderRadius: BorderRadius.all(Radius.circular(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(-7, 7),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoomInfoRow(
              icon: const Icon(Icons.thermostat),
              label: const Text('Temperature'),
              data: '${room.temperature}°',
            ),
            const SizedBox(height: 4),
            _RoomInfoRow(
              icon: const Icon(Icons.water_drop),
              label: const Text('Air Humidity'),
              data: '${room.airHumidity}%',
            ),
            const SizedBox(height: 4),
            // const _RoomInfoRow(
            //   icon: Icon(Icons.timer),
            //   label: Text('Timer'),
            //   data: null,
            // ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white30, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DeviceIconSwitcher(
                    onTap: (value) async {
                      if (lightDevice != null) {
                        await deviceProvider.toggleDevice(
                          lightDevice.id,
                          value,
                        );
                      }
                    },
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Lights'),
                    value: lightsOn,
                    isLoading: false,
                  ),
                  _DeviceIconSwitcher(
                    onTap: (value) async {
                      if (acDevice != null) {
                        await deviceProvider.toggleDevice(acDevice.id, value);
                      }
                    },
                    icon: const Icon(Icons.ac_unit),
                    label: const Text('Air-conditioning'),
                    value: acOn,
                    isLoading: false,
                  ),
                  // _DeviceIconSwitcher(
                  //   onTap: (value) async {
                  //     if (speakerDevice != null) {
                  //       await deviceProvider.toggleDevice(
                  //         speakerDevice.id,
                  //         value,
                  //       );
                  //     }
                  //   },
                  //   icon: const Icon(Icons.music_note),
                  //   label: const Text('Music'),
                  //   value: speakerOn,
                  //   isLoading: false,
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceIconSwitcher extends StatelessWidget {
  const _DeviceIconSwitcher({
    required this.onTap,
    required this.label,
    required this.icon,
    required this.value,
    this.isLoading = false,
  });

  final Text label;
  final Icon icon;
  final bool value;
  final bool isLoading;
  final ValueChanged<bool> onTap;

  @override
  Widget build(BuildContext context) {
    final color = value ? Colors.blue : Colors.white70;

    if (isLoading) {
      return Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(color: color),
            child: label,
          ),
          Text(
            value ? 'ON' : 'OFF',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: () => onTap(!value),
      child: Column(
        children: [
          IconTheme(
            data: IconThemeData(color: color, size: 24),
            child: icon,
          ),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(color: color),
            child: label,
          ),
          Text(
            value ? 'ON' : 'OFF',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomInfoRow extends StatelessWidget {
  const _RoomInfoRow({
    required this.icon,
    required this.label,
    required this.data,
  });

  final Icon icon;
  final Text label;
  final String? data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconTheme(
            data: Theme.of(context).iconTheme.copyWith(size: 18),
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: data == null ? Colors.white70 : Colors.white,
              ),
              child: label,
            ),
          ),
          if (data != null)
            Text(
              data!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'OFF',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
