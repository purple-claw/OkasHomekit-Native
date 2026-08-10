import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/theme/aurora_background.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/load_icon.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/scene_favorites_service.dart';

class SceneScreen extends StatefulWidget {
  const SceneScreen({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _activeSceneIds = <String>{};
  final Map<String, Timer> _activationTimers = <String, Timer>{};

  VoidCallback? _favoritesListener;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _favoritesListener = () {
      if (mounted) setState(() {});
    };
    SceneFavoritesService.instance.addListener(_favoritesListener!);
    SceneFavoritesService.instance.load();
  }

  @override
  void dispose() {
    if (_favoritesListener != null) {
      SceneFavoritesService.instance.removeListener(_favoritesListener!);
    }
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    for (final timer in _activationTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final screen = _buildScreen(context);
    return widget.showHeader ? AuroraBackground(child: screen) : screen;
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showHeader
          ? AppBar(
              title: const Text(
                'Scenes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.black.withValues(alpha: 0.12),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _buildSearchField(),
            Expanded(
              child: _buildSceneList(context.watch<DirectMQTTService>()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.075),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search scenes',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white70,
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSceneList(DirectMQTTService mqtt) {
    if (!mqtt.isConnected) {
      return const _SceneMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Connecting to OKAS',
        subtitle: 'Configured scenes appear after board connection',
      );
    }

    final scenes = _scenesFromLoads(mqtt);
    final filtered = scenes.where((scene) {
      return _searchQuery.isEmpty ||
          scene.name.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return _SceneMessage(
        icon: _searchQuery.isEmpty
            ? Icons.auto_awesome_outlined
            : Icons.search_off_rounded,
        title: _searchQuery.isEmpty
            ? 'No scenes configured'
            : 'No scenes match search',
        subtitle: _searchQuery.isEmpty
            ? 'Programmer-uploaded Scene loads appear here'
            : 'Try another scene name',
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      // Same grid geometry as the Loads screen (LoadGridCard), so scene
      // cards render at exactly the same size as Scene Load cards.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _SceneGlassCard(
        scene: filtered[index],
        onTap: () => _activateScene(filtered[index]),
        onFavoriteTap: () => _toggleFavorite(filtered[index]),
      ),
    );
  }

  List<SmartScene> _scenesFromLoads(DirectMQTTService mqtt) {
    final favoriteIds = SceneFavoritesService.instance.favorites
        .map((favorite) => favorite.id)
        .toSet();

    return mqtt.loads.entries
        .where((entry) => _isSceneLoad(entry.value))
        .map((entry) {
          final load = entry.value;
          final id = (load['id'] ?? load['ldId'] ?? entry.key).toString();
          final name = (load['name'] ?? load['nm'] ?? 'Scene $id').toString();
          return SmartScene(
            id: id,
            name: name,
            icon: _iconForScene(id, name),
            color: SHColors.deviceAccent('Scene'),
            isFavorite: favoriteIds.contains(id),
            isActivated: _activeSceneIds.contains(id),
          );
        })
        .toList(growable: false);
  }

  static bool _isSceneLoad(Map<String, dynamic> load) {
    final type = load['type']?.toString().toLowerCase();
    return type == 'scn' || type == 'scene';
  }

  void _activateScene(SmartScene scene) {
    _activationTimers[scene.id]?.cancel();
    setState(() => _activeSceneIds.add(scene.id));
    context.read<DirectMQTTService>().sendCommand(scene.id, 'ON');
    _activationTimers[scene.id] = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _activeSceneIds.remove(scene.id));
      _activationTimers.remove(scene.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${scene.name} activated'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        backgroundColor: scene.color.withValues(alpha: 0.92),
      ),
    );
  }

  void _toggleFavorite(SmartScene scene) {
    SceneFavoritesService.instance.setFavorite(
      id: scene.id,
      name: scene.name,
      description: 'Board-configured scene',
      icon: scene.icon,
      color: scene.color,
      scope: 'Board',
      favorite: !scene.isFavorite,
    );
  }

  static int _stableIndex(String id, String name, int length) {
    var value = 17;
    for (final rune in '$id$name'.runes) {
      value = (value * 31 + rune) & 0x7fffffff;
    }
    return value % length;
  }

  static IconData _iconForScene(String id, String name) {
    const icons = [
      Icons.auto_awesome_rounded,
      Icons.wb_sunny_rounded,
      Icons.nightlight_round,
      Icons.movie_creation_rounded,
      Icons.music_note_rounded,
      Icons.local_dining_rounded,
      Icons.bedtime_rounded,
      Icons.celebration_rounded,
      Icons.lock_open_rounded,
      Icons.home_rounded,
    ];
    return icons[_stableIndex(id, name, icons.length)];
  }
}

class _SceneGlassCard extends StatelessWidget {
  const _SceneGlassCard({
    required this.scene,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final SmartScene scene;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final active = scene.isActivated;
    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SHColors.radiusLg),
          child: BackdropFilter.grouped(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SHColors.radiusLg),
                    border: Border.all(
                      color: active
                          ? scene.color.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.13),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(1.1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.018),
                    borderRadius: BorderRadius.circular(
                      SHColors.radiusLg - 1.1,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SHColors.radiusLg),
                        gradient: LinearGradient(
                          begin: const Alignment(-0.9, -1.1),
                          end: const Alignment(0.85, 0.65),
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.025),
                            Colors.black.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SHColors.radiusLg),
                        gradient: RadialGradient(
                          center: const Alignment(-0.85, -1.05),
                          radius: 1.25,
                          colors: [
                            Colors.white.withValues(alpha: 0.055),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: active ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            SHColors.radiusLg,
                          ),
                          gradient: RadialGradient(
                            center: const Alignment(0, 0),
                            radius: 1.1,
                            colors: [
                              scene.color.withValues(alpha: 0.25),
                              scene.color.withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: Center(
                          child: LoadIcon(
                            type: 'Scene',
                            isOn: active,
                            color: scene.color,
                            size: 45,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        scene.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'SCENE',
                        style: TextStyle(
                          color: SHColors.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: onTap,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: double.infinity,
                          height: 34,
                          decoration: BoxDecoration(
                            color: active
                                ? scene.color.withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: active
                                  ? scene.color.withValues(alpha: 0.42)
                                  : Colors.white.withValues(alpha: 0.14),
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: scene.color.withValues(
                                        alpha: 0.20,
                                      ),
                                      blurRadius: 12,
                                      spreadRadius: -3,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.power_settings_new,
                            color: active ? Colors.white : SHColors.hintColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: IconButton(
                    tooltip: scene.isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                    onPressed: onFavoriteTap,
                    icon: Icon(
                      scene.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: scene.isFavorite ? SHColors.amber : Colors.white54,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneMessage extends StatelessWidget {
  const _SceneMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.42), size: 58),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SmartScene {
  const SmartScene({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isFavorite,
    required this.isActivated,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isFavorite;
  final bool isActivated;
}
