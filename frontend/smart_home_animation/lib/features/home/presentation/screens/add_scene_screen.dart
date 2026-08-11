// lib/screens/add_scene_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/scene.dart';
import 'package:smart_home_animation/services/mqtt_command_service.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/glass_panel.dart';

class AddSceneScreen extends StatefulWidget {
  const AddSceneScreen({super.key});

  @override
  State<AddSceneScreen> createState() => _AddSceneScreenState();
}

class _AddSceneScreenState extends State<AddSceneScreen> {
  final _nameController = TextEditingController();
  final List<SceneAction> _actions = [];
  final List<String> _suggestedScenes = [
    'Arrive Home',
    'Good Morning',
    'Good Night',
    'Leave Home',
  ];

  void _showAddAccessories() {
    final mqttService = Provider.of<MQTTService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final devices = mqttService.devices.values.toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Add Accessories',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isSelected = _actions.any(
                        (a) => a.deviceId == device.id,
                      );

                      return ListTile(
                        title: Text(device.name),
                        subtitle: Text('Type: ${device.type}'),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _actions.removeWhere(
                                (a) => a.deviceId == device.id,
                              );
                            } else {
                              _showActionPicker(device, (action) {
                                setState(() => _actions.add(action));
                                Navigator.pop(context);
                              });
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showActionPicker(Device device, Function(SceneAction) onSelected) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              device.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Power actions
            ListTile(
              leading: const Icon(
                Icons.power_settings_new,
                color: Colors.green,
              ),
              title: const Text('Turn On'),
              onTap: () => onSelected(
                SceneAction(
                  deviceId: device.id,
                  deviceName: device.name,
                  action: 'Turn On',
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.power_off, color: Colors.red),
              title: const Text('Turn Off'),
              onTap: () => onSelected(
                SceneAction(
                  deviceId: device.id,
                  deviceName: device.name,
                  action: 'Turn Off',
                ),
              ),
            ),

            // Brightness actions
            if (device.type == 'dim' || device.type == 'rgb')
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Set Brightness'),
                trailing: const Text('70%'),
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => FrostedAlertDialog(
                    title: const Text('Set Brightness'),
                    content: StatefulBuilder(
                      builder: (context, setState) {
                        double brightness = 70;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: brightness,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              label: '${brightness.toInt()}%',
                              onChanged: (value) =>
                                  setState(() => brightness = value),
                            ),
                            Text('${brightness.toInt()}%'),
                          ],
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          onSelected(
                            SceneAction(
                              deviceId: device.id,
                              deviceName: device.name,
                              action: 'Set Brightness',
                              value: 70,
                            ),
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _saveScene() {
    if (_nameController.text.isEmpty) return;

    final scene = Scene(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      actions: _actions,
      isSuggested: false,
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, scene);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Scene'),
        backgroundColor: Colors.transparent,
        actions: [TextButton(onPressed: _saveScene, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scene Name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Scene Name',
              hintText: 'e.g., Movie Time, Dinner',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Suggested Scenes
          const Text(
            'Suggested Scenes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _suggestedScenes
                .map(
                  (name) => ActionChip(
                    label: Text(name),
                    onPressed: () {
                      _nameController.text = name;
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),

          // Accessories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Accessories',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showAddAccessories,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Actions List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _actions.length,
            itemBuilder: (context, index) {
              final action = _actions[index];
              return Card(
                child: ListTile(
                  title: Text(action.deviceName),
                  subtitle: Text(action.action),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _actions.removeAt(index)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
