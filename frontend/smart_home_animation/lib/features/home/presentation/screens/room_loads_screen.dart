import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/core/shared/domain/entities/room_scene.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/liquid_glass_scrim.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/quick_select_strip.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/quick_select_service.dart';
import 'package:smart_home_animation/services/room_scene_service.dart';
import 'package:smart_home_animation/services/room_service.dart';
import 'package:smart_home_animation/services/scene_favorites_service.dart';
import '../widgets/load_grid_card.dart';
import '../widgets/figma_load_sheets.dart';
import 'room_scene_editor_screen.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/glass_panel.dart';

class RoomLoadsScreen extends StatefulWidget {
  const RoomLoadsScreen({required this.room, super.key});
  final Room room;

  @override
  State<RoomLoadsScreen> createState() => _RoomLoadsScreenState();
}

class _RoomLoadsScreenState extends State<RoomLoadsScreen> {
  String _selectedCategory = 'All';
  String _loadStructureSignature = '';
  // Carousel: one page per category so the user can swipe horizontally
  // between All / Lights / Climate / Curtain / Scene instead of tapping
  // each filter chip.
  final PageController _pageController = PageController();
  bool _pageProgrammaticScroll = false;
  // Load id currently highlighted after a Quick Select shortcut jump.
  String? _highlightedLoadId;

  // Grouped categories to reduce taps: "Lights" combines every lighting
  // type (on/off switches, dimmers, tunable whites, RGB), "Climate"
  // combines HVAC + fans, curtains and scenes stay as their own sections.
  static const _categories = [
    'All',
    'Lights',
    'Climate',
    'Curtain',
    'Scene',
  ];
  static const _categoryTypeCodes = {
    'All': <String>[],
    'Lights': ['swt', 'dim', 'tun', 'rgb'],
    'Climate': ['hvc', 'fan'],
    'Curtain': ['cur'],
    'Scene': ['scn'],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
      _loadStructureSignature = _structureSignature(mqtt);
      mqtt.addListener(_onDataChanged);
    });
    // Load the Quick Select strip for this room.
    QuickSelectService.instance.load().then((_) {
      if (mounted) setState(() {});
    });
    // Load persisted scenes for this room.
    RoomSceneService.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onDataChanged() {
    if (!mounted) return;
    final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
    final nextSignature = _structureSignature(mqtt);
    if (nextSignature == _loadStructureSignature) return;
    _loadStructureSignature = nextSignature;
    setState(() {});
  }

  String _structureSignature(DirectMQTTService mqtt) {
    return widget.room.loadIds
        .map((id) {
          final load = mqtt.loads[id];
          return '$id:${load?['type']}:${load?['name']}';
        })
        .join('|');
  }

  @override
  void dispose() {
    final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
    mqtt.removeListener(_onDataChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _openSceneEditor(List<Map<String, dynamic>> roomLoads, RoomScene? scene) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomSceneEditorScreen(
          roomId: widget.room.id,
          roomLoads: roomLoads,
          existing: scene,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
    final allLoads = mqtt.loads.values.toList();
    final roomLoadIds = widget.room.loadIds;
    final roomLoads = allLoads
        .where((l) => roomLoadIds.contains(l['id']?.toString()))
        .toList();

    return AuroraBackground(
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          actions: [
            // Room power: lit while ANY load in the room is on. Tapping it
            // turns every load in the room off.
            Selector<DirectMQTTService, bool>(
              selector: (context, mqtt) => mqtt.loads.values.any(
                (l) =>
                    widget.room.loadIds.contains(l['id']?.toString()) &&
                    l['isOn'] == true,
              ),
              builder: (context, anyOn, child) {
                final mqtt =
                    Provider.of<DirectMQTTService>(context, listen: false);
                final roomLoads = mqtt.loads.values
                    .where((l) =>
                        widget.room.loadIds.contains(l['id']?.toString()))
                    .toList();
                return IconButton(
                  tooltip: anyOn
                      ? 'Turn all loads in this room off'
                      : 'Turn all loads in this room on',
                  icon: Icon(
                    Icons.power_settings_new,
                    color: anyOn ? SHColors.green : SHColors.rose,
                  ),
                  onPressed: () {
                    showPowerConfirmDialog(
                      context,
                      message: anyOn
                          ? 'Turn off all loads in ${widget.room.name}?'
                          : 'Turn on all loads in ${widget.room.name}?',
                      action: () {
                        for (final l in roomLoads) {
                          if (anyOn ? l['isOn'] == true : true) {
                            mqtt.sendCommand(
                                l['id'].toString(), anyOn ? 'OFF' : 'ON');
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 12),
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
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        // Slide the carousel to the tapped category.
                        _pageProgrammaticScroll = true;
                        _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      // Frosted-glass chip: blurs the background behind the
                      // chip so it reads as glassmorphism.
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: 10,
                            sigmaY: 10,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? SHColors.primary.withValues(alpha: 0.85)
                                  : Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? SHColors.primary.withValues(alpha: 0.9)
                                    : Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: sel ? Colors.white : Colors.white70,
                                  fontWeight: sel
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
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
            // Carousel: swipe left/right across the category pages. The
            // selected chip stays in sync with the visible page.
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _categories.length,
                onPageChanged: (index) {
                  if (_pageProgrammaticScroll) {
                    _pageProgrammaticScroll = false;
                    return;
                  }
                  setState(() => _selectedCategory = _categories[index]);
                },
                itemBuilder: (ctx, index) {
                  final cat = _categories[index];
                  return Column(
                    children: [
                      Expanded(
                        child: AnimatedBuilder(
                          animation: RoomSceneService.instance,
                          builder: (context, _) => BackdropGroup(
                            child: _buildGrid(roomLoads, cat),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Quick Select strip: pinned loads for this room shown as
            // compact glass chips at the bottom of the screen. Tap a chip
            // to open that load's control sheet.
            _buildQuickSelectStrip(roomLoads),
          ],
        ),
      ),
    );
  }

  /// Bottom Quick Select strip — replicates the home screen's Favorites
  /// 4-card layout: frosted-glass tiles in a row. Tapping a tile is a
  /// SHORTCUT to the actual load card in the grid — it navigates to the
  /// load's category page and highlights the real card. It does NOT open
  /// a separate control sheet.
  Widget _buildQuickSelectStrip(List<Map<String, dynamic>> roomLoads) {
    final quickLoads = QuickSelectService.instance.forRoom(widget.room.id);
    if (quickLoads.isEmpty) return const SizedBox.shrink();

    return QuickSelectStrip(
      loads: quickLoads,
      onTapLoad: (ql) {
        // App scenes (appscene-<id>) aren't in mqtt.loads; jump straight
        // to the Scene category page by synthetic map.
        if (ql.id.startsWith('appscene-')) {
          _jumpToLoad({'id': ql.id, 'type': 'scn'});
          return;
        }
        final liveLoad = roomLoads
            .where((l) => l['id']?.toString() == ql.id)
            .firstOrNull;
        if (liveLoad == null) return;
        _jumpToLoad(liveLoad);
      },
      // Long-pressing the quick tile itself removes it from Quick Select.
      onLongPressLoad: (ql) async {
        await QuickSelectService.instance.removeFromRoom(
          roomId: widget.room.id,
          loadId: ql.id,
        );
        if (mounted) setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ql.name} removed from Quick Select'),
              backgroundColor: SHColors.rose,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
    );
  }

  /// Shortcut: find the load's category page, animate the carousel to it,
  /// and briefly highlight the actual load card in the grid.
  void _jumpToLoad(Map<String, dynamic> load) {
    final type = load['type']?.toString() ?? 'swt';
    // Find which category contains this load type.
    var targetIndex = 0; // 'All'
    for (var i = 1; i < _categories.length; i++) {
      final codes = _categoryTypeCodes[_categories[i]] ?? [];
      if (codes.contains(type)) {
        targetIndex = i;
        break;
      }
    }

    setState(() {
      _selectedCategory = _categories[targetIndex];
      _highlightedLoadId = load['id']?.toString() ?? '';
    });
    _pageProgrammaticScroll = true;
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    // Clear the highlight after a moment so the card settles back to normal.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightedLoadId != null) {
        setState(() => _highlightedLoadId = null);
      }
    });
  }

  Widget _buildGrid(List<Map<String, dynamic>> allLoads, String category) {
    List<Map<String, dynamic>> filtered = allLoads;
    if (category != 'All') {
      final codes = _categoryTypeCodes[category] ?? [];
      filtered = allLoads
          .where((l) => codes.contains(l['type'] ?? 'swt'))
          .toList();
    }
    // User-created app scenes live in the Scene category as cards exactly
    // like the board's `scn` loads. A "+" card (bare icon, same surface)
    // opens the editor for a new scene and always sits first.
    if (category == 'Scene') {
      filtered = [
        {
          'id': 'appscene-new',
          'type': 'scn',
          'name': '',
          'isOn': false,
          '__createScene': true,
        },
        ...filtered,
        ...RoomSceneService.instance.forRoom(widget.room.id).map((s) => {
              'id': 'appscene-${s.id}',
              'type': 'scn',
              'name': s.name,
              'isOn': false,
              '__scene': s,
            }),
      ];
    }
    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'No loads in this room',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      scrollCacheExtent: ScrollCacheExtent.pixels(720),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) => _makeCard(filtered[i], allLoads),
    );
  }

  Widget _makeCard(
    Map<String, dynamic> load,
    List<Map<String, dynamic>> allLoads,
  ) {
    final id = load['id']?.toString() ?? '';
    final scene = load['__scene'] as RoomScene?;
    final creatingScene = load['__createScene'] == true;
    if (scene != null) {
      final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
      final active = RoomSceneService.instance.isActive(scene.id);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SHColors.radiusLg + 2),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: SHColors.violet.withValues(alpha: 0.45),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: LoadGridCard(
          accent: SHColors.violet,
          load: Map<String, dynamic>.from(load)..['isOn'] = active,
          onTap: () => _openSceneEditor(allLoads, scene),
          onToggle: (_) => RoomSceneService.instance.toggleScene(mqtt, scene),
          // Double-tap = activate/deactivate; long-press = actions popup
          // (edit / quick select / delete).
          onDoubleTap: () => RoomSceneService.instance.toggleScene(mqtt, scene),
          onLongPress: () => _showSceneActions(allLoads, scene),
        ),
      );
    }
    if (creatingScene) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SHColors.radiusLg + 2),
        ),
        child: LoadGridCard(
          accent: SHColors.violet,
          icon: Icons.add_rounded,
          load: load,
          onTap: () => _openSceneEditor(allLoads, null),
          onToggle: (_) {},
        ),
      );
    }
    final isHighlighted = _highlightedLoadId == id;
    return Selector<DirectMQTTService, bool>(
      selector: (context, mqtt) => (mqtt.loads[id] ?? load)['isOn'] == true,
      builder: (context, isOn, child) {
        final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
        final cur = Map<String, dynamic>.from(mqtt.loads[id] ?? load)
          ..['isOn'] = isOn;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SHColors.radiusLg + 2),
            border: isHighlighted
                ? Border.all(
                    color: SHColors.primary,
                    width: 2.5,
                  )
                : null,
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: SHColors.primary.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: LoadGridCard(
            load: cur,
            onTap: () {
              // Switch loads toggle straight from the card — no control
              // sheet.
              if ((cur['type'] ?? 'swt') == 'swt') {
                mqtt.sendCommand(id, isOn ? 'OFF' : 'ON');
              } else {
                _showSheet(context, cur, cur['type'] ?? 'swt');
              }
            },
            onToggle: (v) => mqtt.sendCommand(id, v ? 'ON' : 'OFF'),
            onLongPress: () => _showQuickSelectDialog(cur),
          ),
        );
      },
    );
  }

  /// Long-press popup: pins the load to the room's Quick Select strip.
  /// Shows "Add to Quick Select" only — removing happens by long-pressing
  /// the load's tile inside the strip itself.
  void _showQuickSelectDialog(Map<String, dynamic> load) {
    final roomId = widget.room.id;
    final loadId = load['id']?.toString() ?? '';
    if (QuickSelectService.instance.isQuickSelected(roomId, loadId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already in Quick Select'),
          backgroundColor: SHColors.rose,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final name = load['name']?.toString() ?? 'Load';
    final type = load['type']?.toString() ?? 'swt';

    showDialog(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
        title: Text(
          name,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.add_rounded,
                size: 22,
                color: SHColors.green,
              ),
              title: const Text(
                'Add to Quick Select',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Pin this load to the room quick strip',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await QuickSelectService.instance.addToRoom(
                  roomId: roomId,
                  load: QuickSelectLoad(
                    id: loadId,
                    name: name,
                    type: type,
                    color: SHColors.deviceAccent(type),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Long-press popup on a scene card: Edit, Add to Quick Select, Favorites,
  /// Delete.
  void _showSceneActions(
    List<Map<String, dynamic>> allLoads,
    RoomScene scene,
  ) {
    final roomId = widget.room.id;
    final sceneLoadId = 'appscene-${scene.id}';
    final isFavorite = SceneFavoritesService.instance.favorites
        .any((favorite) => favorite.id == sceneLoadId);
    showDialog(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roomSceneIcon(scene.iconId), size: 20, color: SHColors.violet),
            const SizedBox(width: 8),
            Text(
              scene.name,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.edit_rounded,
                size: 22,
                color: SHColors.primary,
              ),
              title: const Text(
                'Edit Scene',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Change loads and their settings',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _openSceneEditor(allLoads, scene);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.add_rounded,
                size: 22,
                color: SHColors.green,
              ),
              title: const Text(
                'Add to Quick Select',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Pin this scene to the room quick strip',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                if (QuickSelectService.instance
                    .isQuickSelected(roomId, sceneLoadId)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Already in Quick Select'),
                      backgroundColor: SHColors.rose,
                      duration: Duration(seconds: 1),
                    ),
                  );
                  return;
                }
                await QuickSelectService.instance.addToRoom(
                  roomId: roomId,
                  load: QuickSelectLoad(
                    id: sceneLoadId,
                    name: scene.name,
                    type: 'scn',
                    color: SHColors.violet,
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
            ListTile(
              leading: Icon(
                isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 22,
                color: SHColors.amber,
              ),
              title: Text(
                isFavorite
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Show this scene on the home screen',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await SceneFavoritesService.instance.setFavorite(
                  id: sceneLoadId,
                  name: scene.name,
                  description: 'App scene',
                  icon: roomSceneIcon(scene.iconId),
                  color: SHColors.violet,
                  scope: 'App',
                  favorite: !isFavorite,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFavorite
                            ? '${scene.name} removed from Favorites'
                            : '${scene.name} added to Favorites',
                      ),
                      backgroundColor: SHColors.amber,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                size: 22,
                color: SHColors.rose,
              ),
              title: const Text(
                'Delete Scene',
                style: TextStyle(
                  color: SHColors.rose,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Remove this scene and its settings',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await RoomSceneService.instance.deleteScene(scene.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${scene.name} deleted'),
                      backgroundColor: SHColors.rose,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
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
    } else {
      // Plain switches / scenes: simple ON/OFF sheet — NO brightness
      // slider (that is only for dimmers / tunables).
      _showSwitchSheet(ctx, load);
    }
  }

  /// Simple ON/OFF sheet for plain switches and scenes. No brightness
  /// slider — the master toggle is the only control.
  void _showSwitchSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    final name = load['name']?.toString() ?? 'Device';
    final type = load['type']?.toString() ?? 'swt';
    final isScene = type == 'scn';

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: mqtt,
        builder: (ctx, _) {
          final cur = mqtt.loads[id] ?? load;
          final isOn = cur['isOn'] == true;
          return FigmaLoadSheet(
            title: isScene ? 'SCENE' : 'SWITCH',
            isOn: isOn,
            onToggle: (v) {
              mqtt.sendCommand(id, v ? 'ON' : 'OFF');
              setState(() {});
            },
            body: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: isOn
                        ? SHColors.green.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isOn
                          ? SHColors.green.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Center(
                    child: isScene
                        ? Image.asset(
                            'assets/icons/scene.png',
                            width: 44,
                            height: 44,
                            color: isOn ? SHColors.green : SHColors.hintColor,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.auto_awesome,
                              color: isOn
                                  ? SHColors.green
                                  : SHColors.hintColor,
                              size: 44,
                            ),
                          )
                        : Icon(
                            Icons.power_settings_new,
                            color:
                                isOn ? SHColors.green : SHColors.hintColor,
                            size: 44,
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOn
                      ? isScene
                          ? 'Scene will activate'
                          : 'Switch is ON'
                      : isScene
                      ? 'Tap toggle to activate scene'
                      : 'Switch is OFF',
                  style: TextStyle(
                    color: SHColors.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDimSheet(BuildContext ctx, Map<String, dynamic> load, String type) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    final double fallbackBrightness = ((mqtt.loads[id]?['brightness'] ?? 50) as num)
        .toDouble();

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      // ListenableBuilder: the sheet rebuilds on EVERY DirectMQTTService
      // notification — live status/+ echoes, cmdAck reconciliation and the
      // optimistic updates the send* commands apply. Without it the sheet
      // only ever rebuilt via the local setSt(), so bus feedback (wall
      // switch, HomeKit, scene, the 400ms bri settle) never re-rendered the
      // open sheet and the slider/switch stayed stale.
      builder: (ctx) => ListenableBuilder(
        listenable: mqtt,
        builder: (ctx, _) {
          final cur = mqtt.loads[id] ?? load;
          final curBrightness = ((cur['brightness'] ?? 0) as num).toDouble();
          // Follow the load's true switch state, not brightness > 0: the
          // board zeroes bri on OFF and briefly echoes bri:0 right after an
          // ON, so deriving the switch from bri alone made it look stuck.
          final curIsOn = cur['isOn'] == true;
          final sliderPct = curBrightness > 0
              ? curBrightness.clamp(0, 100).toDouble()
              : curIsOn
                  ? 100.0
                  : fallbackBrightness.clamp(0, 100).toDouble();

          // Tunable values come from the live load map on every rebuild.
          // The send* commands update the map optimistically, so the
          // picker tracks the finger AND follows bus feedback — no frozen
          // local copies.
          final rawCtpDynamic = cur['cTp'];
          final int rawCtp = rawCtpDynamic is int
              ? rawCtpDynamic
              : int.tryParse('$rawCtpDynamic') ?? 370;
          final int mired = rawCtp < 154
              ? 154
              : rawCtp > 500
              ? 500
              : rawCtp;
          final double tunKelvin =
              (1000000 / mired).clamp(2700, 6500).toDouble();
          final double tunBri =
              ((cur['brightness'] ?? 100) as num).toDouble().clamp(0, 100);

          return FigmaLoadSheet(
            title: type == 'tun' ? 'TUNING' : 'BRIGHTNESS',
            isOn: curIsOn,
            onToggle: (v) {
              mqtt.sendCommand(id, v ? 'ON' : 'OFF');
              setState(() {});
            },
            body: type == 'tun'
                ? TunablePicker(
                    kelvin: tunKelvin,
                    brightness: tunBri,
                    onKelvinChanged: (v) {
                      mqtt.sendColorTempCommand(id, v.round());
                    },
                    onBrightnessChanged: (v) {
                      mqtt.sendBrightnessCommand(id, v.round());
                    },
                  )
                : BrightnessSlider(
                    value: sliderPct,
                    label: curIsOn ? 'BRIGHTNESS' : 'TAP OR SLIDE TO TURN ON',
                    onChanged: (v) {
                      mqtt.sendBrightnessCommand(id, v.round());
                    },
                  ),
          );
        },
      ),
    );
  }

  void _showRGBSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    // The color picker is driven by drag-local r/g/b: the board only
    // stores HSV (hue/sat) for RGB loads, so the live map cannot feed the
    // picker's RGB channels. They are seeded once from the map and keep
    // tracking the finger; isOn/brightness are read live on every rebuild.
    final cur0 = mqtt.loads[id] ?? load;
    int r = ((cur0['red'] ?? 255) as num).round().clamp(0, 255);
    int g = ((cur0['green'] ?? 255) as num).round().clamp(0, 255);
    int b = ((cur0['blue'] ?? 255) as num).round().clamp(0, 255);

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: mqtt,
        builder: (ctx, _) {
          final cur = mqtt.loads[id] ?? load;
          final isOn = cur['isOn'] == true;
          // Brightness is its own channel (0-100), independent of the color.
          final int bri = ((cur['brightness'] ?? 100) as num)
              .round()
              .clamp(0, 100);
          return FigmaLoadSheet(
            title: 'RGB',
            isOn: isOn,
            onToggle: (v) {
              mqtt.sendCommand(id, v ? 'ON' : 'OFF');
              setState(() {});
            },
            body: RgbGamutPicker(
              red: r.toDouble(),
              green: g.toDouble(),
              blue: b.toDouble(),
              brightness: bri.toDouble(),
              onChanged: (nr, ng, nb) {
                r = nr;
                g = ng;
                b = nb;
                mqtt.sendRGBCommand(id, nr, ng, nb, brightness: bri);
              },
              onBrightnessChanged: (v) {
                mqtt.sendRGBCommand(id, r, g, b, brightness: v.round());
              },
            ),
          );
        },
      ),
    );
  }

  void _showFanSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    // The fan's "on" state is derived from speed > 0 so the slider position
    // and the master toggle stay perfectly in sync (0% -> OFF, >0% -> ON).
    double rawSpeed =
        ((mqtt.loads[id]?['fanSpeed'] ?? mqtt.loads[id]?['fSp'] ?? 0) as num)
            .toDouble();
    if (rawSpeed <= 0 && (mqtt.loads[id]?['isOn'] ?? false) == true) {
      rawSpeed =
          50; // fallback so a stale ON without a speed still shows a slider
    }

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: mqtt,
        builder: (ctx, _) {
          final liveLoad = mqtt.loads[id] ?? load;
          final liveSpeed =
              ((liveLoad['fanSpeed'] ?? liveLoad['fSp'] ?? 0) as num)
                  .toDouble();
          final liveIsOn =
              (liveSpeed > 0) || (liveLoad['isOn'] == true && liveSpeed > 0);
          final sliderPct = (liveSpeed > 0 ? liveSpeed : rawSpeed) / 250 * 100;
          return FigmaLoadSheet(
            title: 'FAN SPEED',
            isOn: liveIsOn,
            onToggle: (v) {
              // Toggling the master switch drives the bus command but the
              // underlying on/off is mirrored to fSp=0 (off) or fSp=128 (on)
              // so the slider remains the source of truth for the speed.
              mqtt.sendCommand(id, v ? 'ON' : 'OFF');
            },
            body: BrightnessSlider(
              value: sliderPct.clamp(0, 100).toDouble(),
              label: liveIsOn ? 'SPEED' : 'TAP OR SLIDE TO TURN ON',
              onChanged: (v) {
                mqtt.sendFanSpeedCommand(id, (v * 2.5).round().clamp(0, 250));
              },
            ),
          );
        },
      ),
    );
  }

  void _showCurtainSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: mqtt,
        builder: (ctx, _) {
          final cur = mqtt.loads[id] ?? load;
          final double pos = ((cur['tPs'] ?? cur['cPs'] ?? 0) as num)
              .toDouble();
          return FigmaLoadSheet(
            title: 'MOVEMENT',
            isOn: pos > 0,
            useRadialGradient: true,
            showToggle: false,
            onToggle: (v) {
              mqtt.sendCurtainPositionCommand(id, v ? 0 : 100);
            },
            body: Column(
              children: [
                CurtainVisualization(position: pos.clamp(0, 100) / 100),
                const SizedBox(height: 14),
                Text(
                  pos == 0
                      ? 'Fully Open'
                      : pos == 100
                      ? 'Fully Closed'
                      : '${pos.round()}%',
                  style: const TextStyle(
                    color: SHColors.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'CURTAIN MOVEMENT',
                  style: TextStyle(
                    color: SHColors.mutedText,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                FigmaSlider(
                  value: pos.clamp(0, 100),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (v) {
                    mqtt.sendCurtainPositionCommand(id, v.round());
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _curtainBtn('Open', 0, pos, (v) {
                      mqtt.sendCurtainPositionCommand(id, v);
                    }),
                    _curtainBtn('Stop', -1, pos, (v) {
                      mqtt.sendCurtainPositionCommand(id, 50);
                    }),
                    _curtainBtn('Close', 100, pos, (v) {
                      mqtt.sendCurtainPositionCommand(id, v);
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _curtainBtn(
    String label,
    int target,
    double cur,
    ValueChanged<int> onTap,
  ) {
    final active = target != -1 && cur == target;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(target),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? SHColors.primary : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(SHColors.radiusMd),
            border: Border.all(
              color: active ? SHColors.primary : Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : SHColors.mutedText,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
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
    double temp = ((cur['temp'] ?? 25) as num).toDouble();
    String mode = (cur['hvacMode'] ?? 'Cool').toString();
    final modes = const ['Cool', 'Heat', 'Auto', 'Dry'];
    // HVAC fan speed range. Defaults match the Figma spec (5 speeds);
    // overloads via Smx / Fst on the load config adapt the slider.
    final double fanMax = ((cur['fanSpeedMax'] ?? cur['Smx'] ?? 5) as num)
        .toDouble()
        .clamp(1, 5)
        .toDouble();
    final double fanStep = ((cur['fanSpeedStep'] ?? cur['Fst'] ?? 1) as num)
        .toDouble()
        .clamp(1, fanMax)
        .toDouble();

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: mqtt,
        builder: (ctx, _) {
          final live = mqtt.loads[id] ?? cur;
          final liveTemp = ((live['temp'] ?? temp) as num).toDouble();
          final liveMode = (live['hvacMode'] ?? mode).toString();
          final liveFan = ((live['fanSpeed'] ?? live['fSp'] ?? 0) as num)
              .toDouble();
          // Bus fan speed is 0..255; the Figma slider works in
          // 0..fanMax scale so users can pick discrete steps instead of
          // dragging across a 255-step range.
          final fanPct = fanMax > 0
              ? (liveFan * fanMax / 255).clamp(0, fanMax).toDouble()
              : 0.0;
          return FigmaLoadSheet(
            title: 'TEMPERATURE',
            isOn: (live['isOn'] ?? false),
            onToggle: (v) {
              mqtt.sendCommand(id, v ? 'ON' : 'OFF');
            },
            body: Column(
              children: [
                Text(
                  '${liveTemp.round()}°C',
                  style: const TextStyle(
                    color: SHColors.primary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ROOM TEMPERATURE',
                  style: TextStyle(
                    color: SHColors.mutedText,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                FigmaSegmentedOptions<String>(
                  options: modes,
                  selected: liveMode,
                  labelBuilder: (m) => m.toUpperCase(),
                  onSelected: (m) {
                    mqtt.sendHVACModeCommand(id, m);
                  },
                ),
                const SizedBox(height: 20),
                FigmaSlider(
                  value: liveTemp.clamp(16, 32),
                  min: 16,
                  max: 32,
                  divisions: 32,
                  onChanged: (v) {
                    mqtt.sendTemperatureCommand(id, v.round());
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  fanPct <= 0 ? 'TAP OR SLIDE TO TURN ON FAN' : 'FAN SPEED',
                  style: const TextStyle(
                    color: SHColors.mutedText,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${fanPct.round()} / ${fanMax.round()}',
                  style: const TextStyle(
                    color: SHColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                FigmaSlider(
                  value: fanPct,
                  min: 0,
                  max: fanMax,
                  divisions: (fanMax / fanStep).round(),
                  onChanged: (v) {
                    // Scale UI step (0..fanMax) to bus speed (0..255).
                    final busSpeed = fanMax > 0
                        ? (v / fanMax * 255).round().clamp(0, 255)
                        : 0;
                    mqtt.sendFanSpeedCommand(id, busSpeed);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
