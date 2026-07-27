import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/room_service.dart';
import '../widgets/load_grid_card.dart';
import '../widgets/figma_load_sheets.dart';

class RoomLoadsScreen extends StatefulWidget {
  const RoomLoadsScreen({required this.room, super.key});
  final Room room;

  @override
  State<RoomLoadsScreen> createState() => _RoomLoadsScreenState();
}

class _RoomLoadsScreenState extends State<RoomLoadsScreen> {
  String _selectedCategory = 'All';

  static const _categories = ['All', 'Lights', 'Dimmers', 'Tunable', 'RGB'];
  static const _categoryTypeCodes = {
    'All': <String>[],
    'Lights': ['swt'],
    'Dimmers': ['dim'],
    'Tunable': ['tun'],
    'RGB': ['rgb'],
  };

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<DirectMQTTService>(context);
    final allLoads = mqtt.loads.values.toList();
    final roomLoadIds = widget.room.loadIds;
    final roomLoads = allLoads.where((l) => roomLoadIds.contains(l['id']?.toString())).toList();

    return Container(
      decoration: const BoxDecoration(gradient: SHColors.backgroundColor),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.room.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final sel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? SHColors.primary : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? SHColors.primary : Colors.white24),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.white70,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildGrid(roomLoads)),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> allLoads) {
    List<Map<String, dynamic>> filtered = allLoads;
    if (_selectedCategory != 'All') {
      final codes = _categoryTypeCodes[_selectedCategory] ?? [];
      filtered = allLoads.where((l) => codes.contains(l['type'] ?? 'swt')).toList();
    }
    if (filtered.isEmpty) {
      return const Center(child: Text('No loads in this room', style: TextStyle(color: Colors.white54)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) => _makeCard(filtered[i]),
    );
  }

  Widget _makeCard(Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
    final id = load['id']?.toString() ?? '';
    final cur = mqtt.loads[id] ?? load;
    return LoadGridCard(
      load: cur,
      onTap: () => _showSheet(context, cur, cur['type'] ?? 'swt'),
      onToggle: (v) => mqtt.sendCommand(id, v ? 'ON' : 'OFF'),
    );
  }

  void _showSheet(BuildContext ctx, Map<String, dynamic> load, String type) {
    if (type == 'dim' || type == 'tun') {
      _showDimSheet(ctx, load, type);
    } else if (type == 'rgb') {
      _showRGBSheet(ctx, load);
    } else if (type == 'fan') {
      _showFanSheet(ctx, load);
    } else if (type == 'cur') {
      _showCurtainSheet(ctx, load);
    } else if (type == 'hvc') {
      _showHVACSheet(ctx, load);
    }
  }

  void _showDimSheet(BuildContext ctx, Map<String, dynamic> load, String type) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    double brightness = ((mqtt.loads[id]?['brightness'] ?? 50) as num).toDouble();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FigmaLoadSheet(
          title: type == 'tun' ? 'TUNNING' : 'BRIGHTNESS',
          isOn: (mqtt.loads[id]?['isOn'] ?? false),
          onToggle: (v) { mqtt.sendCommand(id, v ? 'ON' : 'OFF'); setSt(() {}); },
          body: BrightnessSlider(
            value: brightness,
            label: type == 'tun' ? 'COLOR TEMP' : 'BRIGHTNESS',
            onChanged: (v) { brightness = v; mqtt.sendBrightnessCommand(id, v.round()); setSt(() {}); },
          ),
        ),
      ),
    );
  }

  void _showRGBSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    final cur = mqtt.loads[id] ?? load;
    double r = (cur['red'] ?? 255).toDouble();
    double g = (cur['green'] ?? 255).toDouble();
    double b = (cur['blue'] ?? 255).toDouble();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FigmaLoadSheet(
          title: 'COLOR',
          isOn: (mqtt.loads[id]?['isOn'] ?? false),
          onToggle: (v) { mqtt.sendCommand(id, v ? 'ON' : 'OFF'); setSt(() {}); },
          body: Column(
            children: [
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(r.round(), g.round(), b.round(), 1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              _colorSlider('R', r, Colors.red, (v) {
                r = v;
                mqtt.sendRGBCommand(id, v.round(), g.round(), b.round());
                setSt(() {});
              }),
              _colorSlider('G', g, Colors.green, (v) {
                g = v;
                mqtt.sendRGBCommand(id, r.round(), v.round(), b.round());
                setSt(() {});
              }),
              _colorSlider('B', b, Colors.blue, (v) {
                b = v;
                mqtt.sendRGBCommand(id, r.round(), g.round(), v.round());
                setSt(() {});
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorSlider(String label, double val, Color c, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 30, child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.bold))),
        Expanded(child: Slider(value: val, min: 0, max: 255, activeColor: c, onChanged: onChanged)),
        SizedBox(width: 40, child: Text('${val.round()}', style: const TextStyle(color: Colors.white54))),
      ],
    );
  }

  void _showFanSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    double speed = ((mqtt.loads[id]?['fanSpeed'] ?? mqtt.loads[id]?['fSp'] ?? 0) as num).toDouble();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FigmaLoadSheet(
          title: 'FAN SPEED',
          isOn: (mqtt.loads[id]?['isOn'] ?? false),
          onToggle: (v) { mqtt.sendCommand(id, v ? 'ON' : 'OFF'); setSt(() {}); },
          body: BrightnessSlider(
            value: speed / 250 * 100,
            label: 'SPEED',
            onChanged: (v) {
              speed = v * 2.5;
              mqtt.sendFanSpeedCommand(id, speed.round());
              setSt(() {});
            },
          ),
        ),
      ),
    );
  }

  void _showCurtainSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    double pos = ((mqtt.loads[id]?['tPs'] ?? mqtt.loads[id]?['cPs'] ?? 0) as num).toDouble();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FigmaLoadSheet(
          title: 'MOVEMENT',
          isOn: pos > 0,
          onToggle: (v) { mqtt.sendCurtainPositionCommand(id, v ? 0 : 100); setSt(() {}); },
          body: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _curtainBtn('Open', 0, pos, (v) { mqtt.sendCurtainPositionCommand(id, v); setSt(() {}); }),
                  _curtainBtn('Stop', -1, pos, (v) { mqtt.sendCurtainPositionCommand(id, 50); setSt(() {}); }),
                  _curtainBtn('Close', 100, pos, (v) { mqtt.sendCurtainPositionCommand(id, v); setSt(() {}); }),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                pos == 0 ? 'Fully Open' : pos == 100 ? 'Fully Closed' : '${pos.round()}%',
                style: const TextStyle(color: SHColors.primary, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: pos,
                min: 0,
                max: 100,
                onChanged: (v) { mqtt.sendCurtainPositionCommand(id, v.round()); setSt(() {}); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _curtainBtn(String label, int target, double cur, ValueChanged<int> onTap) {
    final active = target != -1 && cur == target;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(target),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? SHColors.primary : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHVACSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    final cur = mqtt.loads[id] ?? load;
    double temp = (cur['temp'] ?? 25).toDouble();
    String mode = cur['hvacMode'] ?? 'Cool';
    final modes = ['Cool', 'Heat', 'Auto', 'Dry'];

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FigmaLoadSheet(
          title: 'TEMPERATURE',
          isOn: (cur['isOn'] ?? false),
          onToggle: (v) { mqtt.sendCommand(id, v ? 'ON' : 'OFF'); setSt(() {}); },
          body: Column(
            children: [
              Text(
                '${temp.round()}°C',
                style: const TextStyle(color: SHColors.primary, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: modes.map((m) {
                  final sel = mode == m;
                  return GestureDetector(
                    onTap: () { mqtt.sendHVACModeCommand(id, m); setSt(() {}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? SHColors.primary : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.white70,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Slider(
                value: temp,
                min: 16,
                max: 32,
                onChanged: (v) { mqtt.sendTemperatureCommand(id, v.round()); setSt(() {}); },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
