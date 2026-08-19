// lib/features/home/presentation/screens/room_scene_editor_screen.dart
// Create / edit an app-side scene for one room: pick a name + icon, choose
// which of the room's loads belong to the scene, and for each load pin the
// exact settings to replay on activation (with a one-tap "capture current
// state" shortcut that reads the live MQTT values).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/core/shared/domain/entities/room_scene.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/liquid_glass_scrim.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/figma_load_sheets.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/load_grid_card.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/room_scene_service.dart';

class RoomSceneEditorScreen extends StatefulWidget {
  const RoomSceneEditorScreen({
    required this.roomId,
    required this.roomLoads,
    this.existing,
    super.key,
  });

  final String roomId;
  final List<Map<String, dynamic>> roomLoads;
  final RoomScene? existing;

  @override
  State<RoomSceneEditorScreen> createState() => _RoomSceneEditorScreenState();
}

class _RoomSceneEditorScreenState extends State<RoomSceneEditorScreen> {
  late final TextEditingController _nameController;
  late String _iconId;
  final Map<String, SceneLoadSetting> _settings = {};
  final Set<String> _selectedLoadIds = {};

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _iconId = widget.existing?.iconId ??
        roomSceneIcons.keys.elementAt(
          DateTime.now().millisecondsSinceEpoch % roomSceneIcons.length,
        );
    for (final load in widget.roomLoads) {
      final id = load['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final existing = widget.existing?.loads
          .where((s) => s.loadId == id)
          .firstOrNull;
      // When editing an existing scene only its own loads start selected;
      // creating a scene starts with none.
      if (widget.existing != null && existing == null) continue;
      _selectedLoadIds.add(id);
      _settings[id] = existing ?? _defaultSetting(load);
    }
    if (!_isEdit) _selectedLoadIds.clear();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  static SceneLoadSetting _defaultSetting(Map<String, dynamic> load) {
    final type = load['type']?.toString() ?? 'swt';
    return SceneLoadSetting(loadId: load['id'].toString(), type: type);
  }

  void _randomizeIcon() {
    setState(() {
      final keys = roomSceneIcons.keys.toList();
      _iconId = keys[DateTime.now().millisecondsSinceEpoch % keys.length];
    });
  }

  Future<void> _editSetting(Map<String, dynamic> load) async {
    final id = load['id']?.toString() ?? '';
    final type = load['type']?.toString() ?? 'swt';
    var setting = _settings[id] ?? _defaultSetting(load);
    final name = load['name']?.toString() ?? 'Load';

    final snapshot = snapshotFor(context, load);

    void captureCurrent() {
      // Live values via the same field mapping the control sheets use.
      final s = SceneLoadSetting(
        loadId: id,
        type: type,
        isOn: snapshot.isOn,
        brightness: snapshot.brightness.round(),
        colorTempK: snapshot.colorTemp > 0
            ? (1000000 / snapshot.colorTemp).round()
            : null,
        red: snapshot.red.round(),
        green: snapshot.green.round(),
        blue: snapshot.blue.round(),
        hvacMode: snapshot.hvacMode,
        temp: snapshot.temperature.round(),
        fanSpeed: snapshot.fanSpeed.round(),
        curtainPos: snapshot.curtainPos.round(),
      );
      setState(() => _settings[id] = s);
    }

    showLiquidGlassModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => FigmaLoadSheet(
            title: name,
            isOn: setting.isOn,
            showToggle: type != 'cur',
            onToggle: (v) {
              setSheet(() {
                setting = setting.copyWith(isOn: v);
              });
              setState(() => _settings[id] = setting);
            },
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      captureCurrent();
                      setSheet(() {
                        setting = _settings[id]!;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SHColors.radiusMd),
                      ),
                    ),
                    icon: const Icon(
                      Icons.radar_rounded,
                      size: 18,
                      color: SHColors.primary,
                    ),
                    label: const Text(
                      'Capture current state',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                ..._controlsFor(type, setting, (updated) {
                  setSheet(() => setting = updated);
                  setState(() => _settings[id] = updated);
                }),
              ],
            ),
          ),
        ),
    );
  }

  List<Widget> _controlsFor(
    String type,
    SceneLoadSetting s,
    ValueChanged<SceneLoadSetting> onChanged,
  ) {
    switch (type) {
      case 'dim':
        return [
          BrightnessSlider(
            value: (s.brightness ?? 100).toDouble(),
            label: 'BRIGHTNESS',
            onChanged: (v) =>
                onChanged(s.copyWith(brightness: v.round(), isOn: v > 0)),
          ),
        ];
      case 'tun':
        return [
          const Text(
            'COLOR TEMPERATURE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${s.colorTempK ?? 4000}K',
            style: const TextStyle(
              color: SHColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FigmaSlider(
            value: (s.colorTempK ?? 4000).toDouble(),
            min: 2000,
            max: 6500,
            divisions: 45,
            onChanged: (v) => onChanged(s.copyWith(colorTempK: v.round())),
          ),
          const SizedBox(height: 18),
          BrightnessSlider(
            value: (s.brightness ?? 100).toDouble(),
            label: 'BRIGHTNESS',
            onChanged: (v) =>
                onChanged(s.copyWith(brightness: v.round(), isOn: v > 0)),
          ),
        ];
      case 'rgb':
        return [
          RgbGamutPicker(
            red: (s.red ?? 255).toDouble(),
            green: (s.green ?? 255).toDouble(),
            blue: (s.blue ?? 255).toDouble(),
            brightness: (s.brightness ?? 100).toDouble(),
            onChanged: (r, g, b) => onChanged(
              s.copyWith(red: r, green: g, blue: b, isOn: true),
            ),
            onBrightnessChanged: (v) => onChanged(
              s.copyWith(brightness: v.round(), isOn: v > 0),
            ),
          ),
        ];
      case 'hvc':
        return [
          FigmaSegmentedOptions<String>(
            options: const ['Cool', 'Heat', 'Auto', 'Dry'],
            selected: s.hvacMode ?? 'Cool',
            labelBuilder: (m) => m.toUpperCase(),
            onSelected: (m) => onChanged(s.copyWith(hvacMode: m, isOn: true)),
          ),
          const SizedBox(height: 20),
          const Text(
            'TEMPERATURE °C',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${s.temp ?? 24}°',
            style: const TextStyle(
              color: SHColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          FigmaSlider(
            value: (s.temp ?? 24).toDouble(),
            min: 16,
            max: 32,
            divisions: 16,
            onChanged: (v) => onChanged(s.copyWith(temp: v.round())),
          ),
          const SizedBox(height: 20),
          const Text(
            'FAN SPEED',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(s.fanSpeed ?? 0).round()}',
            style: const TextStyle(
              color: SHColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          FigmaSlider(
            value: (s.fanSpeed ?? 0).toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: (v) => onChanged(s.copyWith(fanSpeed: v.round())),
          ),
        ];
      case 'cur':
        return [
          CurtainVisualization(
            position: ((s.curtainPos ?? 0) / 100).clamp(0, 1),
          ),
          const SizedBox(height: 14),
          Text(
            s.curtainPos == null || s.curtainPos == 0
                ? 'Fully Open'
                : '${s.curtainPos}%',
            style: const TextStyle(
              color: SHColors.primary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          FigmaSlider(
            value: (s.curtainPos ?? 0).toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) => onChanged(s.copyWith(curtainPos: v.round())),
          ),
        ];
      default: // swt / scene: master switch only
        return [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Only on/off is available for this load.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ];
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final selectedSettings = _selectedLoadIds
        .map((id) => _settings[id])
        .whereType<SceneLoadSetting>()
        .toList();
    if (name.isEmpty || selectedSettings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedSettings.isEmpty
                ? 'Pick at least one load for the scene'
                : 'Give the scene a name',
          ),
          backgroundColor: SHColors.rose,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    final scene = RoomScene(
      id: _isEdit ? widget.existing!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: widget.roomId,
      name: name,
      iconId: _iconId,
      loads: selectedSettings,
      createdAt: _isEdit ? widget.existing!.createdAt : DateTime.now(),
    );
    final service = RoomSceneService.instance;
    if (_isEdit) {
      await service.updateScene(scene);
    } else {
      await service.addScene(scene);
    }
    if (mounted) Navigator.pop(context, scene);
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
    final allLoads = mqtt.loads.values.toList();
    final roomLoads = widget.roomLoads.isEmpty
        ? allLoads
        : widget.roomLoads;

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Scene' : 'New Scene',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete scene',
              icon: const Icon(Icons.delete_outline, color: SHColors.rose),
              onPressed: () async {
                await RoomSceneService.instance.deleteScene(widget.existing!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(color: SHColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Scene Name',
              labelStyle: const TextStyle(color: SHColors.mutedText),
              hintText: 'e.g. Movie Time, Dinner',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ICON',
                style: TextStyle(
                  color: SHColors.mutedText,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                onPressed: _randomizeIcon,
                icon: const Icon(Icons.shuffle_rounded, size: 18, color: SHColors.primary),
                label: const Text(
                  'Random',
                  style: TextStyle(color: SHColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: roomSceneIcons.entries.map((entry) {
              final selected = _iconId == entry.key;
              return GestureDetector(
                onTap: () => setState(() => _iconId = entry.key),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected
                        ? SHColors.primary.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? SHColors.primary
                          : Colors.white.withValues(alpha: 0.12),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Icon(
                    entry.value,
                    color: selected ? SHColors.primary : Colors.white70,
                    size: 26,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'LOADS IN THIS SCENE',
            style: TextStyle(
              color: SHColors.mutedText,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: roomLoads.map((load) {
              final id = load['id']?.toString() ?? '';
              final selected = _selectedLoadIds.contains(id);
              final name = load['name']?.toString() ?? 'Load';
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedLoadIds.remove(id);
                      _settings.remove(id);
                    } else {
                      _selectedLoadIds.add(id);
                      _settings[id] = _settings[id] ?? _defaultSetting(load);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? SHColors.primary.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? SHColors.primary.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: selected ? SHColors.primary : Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'SETTINGS',
            style: TextStyle(
              color: SHColors.mutedText,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          // Selected loads render as compact versions of the grid cards
          // (4 per row, ~30% smaller than the Room Loads grid cards) so
          // many loads fit on screen. FittedBox scales the card's fixed
          // internal layout down proportionally instead of overflowing.
          ...() {
            final selected = roomLoads.where((load) {
              return _selectedLoadIds.contains(load['id']?.toString());
            }).toList();
            if (selected.isEmpty) {
              return const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Select loads above to add them to this scene.',
                    style: TextStyle(color: SHColors.mutedText, fontSize: 13),
                  ),
                ),
              ];
            }
            return [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  // Base card is 100x170; tiles are ~30% smaller.
                  childAspectRatio: 100 / 170,
                ),
                itemCount: selected.length,
                itemBuilder: (ctx, index) {
                  final load = selected[index];
                  final id = load['id']?.toString() ?? '';
                  final setting = _settings[id];
                  final isCur = load['type']?.toString() == 'cur';
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 100,
                      height: 170,
                      child: LoadGridCard(
                        load: Map<String, dynamic>.from(load)
                          ..['isOn'] = isCur
                              ? (setting?.curtainPos ?? 0) > 0
                              : (setting?.isOn ?? false),
                        onTap: () => _editSetting(load),
                        onToggle: (v) {
                          setState(() {
                            final cur =
                                _settings[id] ?? _defaultSetting(load);
                            _settings[id] = isCur
                                ? cur.copyWith(curtainPos: v ? 100 : 0)
                                : cur.copyWith(isOn: v);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ];
          }(),
        ],
      ),
      ),
    );
  }
}