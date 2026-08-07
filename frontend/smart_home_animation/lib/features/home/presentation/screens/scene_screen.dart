// screens/scene_screen.dart
// Scene management: Global Scenes + Room-Based Scenes, with a creation
// flow (previously scene creation was not available where expected).
// ignore_for_file: unused_element, prefer_final_fields

import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/theme/aurora_background.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';

class SceneScreen extends StatefulWidget {
  const SceneScreen({super.key});

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<SceneCategory> _categories = [
    SceneCategory(name: 'All', icon: Icons.apps),
    SceneCategory(name: 'Global', icon: Icons.public),
    SceneCategory(name: 'Rooms', icon: Icons.meeting_room_outlined),
    SceneCategory(name: 'Favorites', icon: Icons.favorite),
  ];

  // 4 standard + 6 custom scenes, split by scope.
  List<SmartScene> _scenes = [];
  final List<SmartScene> _standardScenes = [
    SmartScene(
      id: 'std_morning',
      name: 'Morning',
      description: 'Gentle wake-up lighting',
      icon: Icons.wb_sunny_outlined,
      color: SHColors.amber,
      deviceCount: 4,
      isFavorite: false,
      scope: 'Global',
    ),
    SmartScene(
      id: 'std_evening',
      name: 'Evening',
      description: 'Warm dimmed ambience',
      icon: Icons.nightlight_outlined,
      color: SHColors.dimGrey,
      deviceCount: 3,
      isFavorite: false,
      scope: 'Global',
    ),
    SmartScene(
      id: 'std_movie',
      name: 'Movie',
      description: 'Cinema dim lighting',
      icon: Icons.movie_outlined,
      color: SHColors.blue,
      deviceCount: 5,
      isFavorite: false,
      scope: 'Global',
    ),
    SmartScene(
      id: 'std_away',
      name: 'Away',
      description: 'All loads off',
      icon: Icons.lock_outline,
      color: SHColors.rose,
      deviceCount: 6,
      isFavorite: false,
      scope: 'Global',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _scenes = List.of(_standardScenes);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  void _toggleFavorite(SmartScene scene) {
    setState(() {
      final index = _scenes.indexWhere((s) => s.id == scene.id);
      if (index != -1) {
        final s = _scenes[index];
        _scenes[index] = SmartScene(
          id: s.id,
          name: s.name,
          description: s.description,
          icon: s.icon,
          color: s.color,
          deviceCount: s.deviceCount,
          isFavorite: !s.isFavorite,
          timeOfDay: s.timeOfDay,
          scope: s.scope,
        );

        final isNowFavorite = _scenes[index].isFavorite;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNowFavorite
                  ? '${scene.name} added to favorites'
                  : '${scene.name} removed from favorites',
            ),
            backgroundColor: isNowFavorite ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  /// Opens the scene creation dialog. New scenes are added as custom
  /// Room-Based scenes by default (user picks the scope in the dialog).
  Future<void> _openCreateScene() async {
    final nameController = TextEditingController();
    var selectedIcon = Icons.auto_awesome;
    var selectedColor = SHColors.primary;
    var scope = 'Room';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: SHColors.elevatedCardColor,
          title: const Text(
            'Create Scene',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Scene name',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: SHColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Scope: Global or Room-based.
                Row(
                  children: [
                    const Text(
                      'Scope:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Global'),
                      selected: scope == 'Global',
                      onSelected: (_) =>
                          setDialogState(() => scope = 'Global'),
                      selectedColor: SHColors.primary,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Room'),
                      selected: scope == 'Room',
                      onSelected: (_) => setDialogState(() => scope = 'Room'),
                      selectedColor: SHColors.dimGrey,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Icon picker.
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _iconOption(ctx, setDialogState, Icons.wb_sunny_outlined,
                          (i) => selectedIcon = i, selectedIcon),
                      _iconOption(ctx, setDialogState, Icons.nightlight_outlined,
                          (i) => selectedIcon = i, selectedIcon),
                      _iconOption(ctx, setDialogState, Icons.movie_outlined,
                          (i) => selectedIcon = i, selectedIcon),
                      _iconOption(ctx, setDialogState, Icons.lock_outline,
                          (i) => selectedIcon = i, selectedIcon),
                      _iconOption(ctx, setDialogState, Icons.favorite_outline,
                          (i) => selectedIcon = i, selectedIcon),
                      _iconOption(ctx, setDialogState, Icons.auto_awesome,
                          (i) => selectedIcon = i, selectedIcon),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Color picker.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _colorDot(ctx, setDialogState, SHColors.primary,
                        (c) => selectedColor = c, selectedColor),
                    _colorDot(ctx, setDialogState, SHColors.amber,
                        (c) => selectedColor = c, selectedColor),
                    _colorDot(ctx, setDialogState, SHColors.dimGrey,
                        (c) => selectedColor = c, selectedColor),
                    _colorDot(ctx, setDialogState, SHColors.blue,
                        (c) => selectedColor = c, selectedColor),
                    _colorDot(ctx, setDialogState, SHColors.rose,
                        (c) => selectedColor = c, selectedColor),
                    _colorDot(ctx, setDialogState, SHColors.green,
                        (c) => selectedColor = c, selectedColor),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Scene name is required'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, {
                  'name': name,
                  'icon': selectedIcon,
                  'color': selectedColor,
                  'scope': scope,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SHColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _scenes.insert(
          0,
          SmartScene(
            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
            name: result['name'] as String,
            description:
                '${result['scope']} scene • created by you',
            icon: result['icon'] as IconData,
            color: result['color'] as Color,
            deviceCount: 0,
            isFavorite: false,
            scope: result['scope'] as String,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scene "${result['name']}" created!'),
          backgroundColor: SHColors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _iconOption(
    BuildContext ctx,
    StateSetter setDialogState,
    IconData icon,
    ValueChanged<IconData> onPick,
    IconData current,
  ) {
    final active = current == icon;
    return GestureDetector(
      onTap: () => setDialogState(() => onPick(icon)),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? SHColors.primary.withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? SHColors.primary : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Icon(icon, color: active ? SHColors.primary : Colors.white54),
      ),
    );
  }

  Widget _colorDot(
    BuildContext ctx,
    StateSetter setDialogState,
    Color color,
    ValueChanged<Color> onPick,
    Color current,
  ) {
    final active = current == color;
    return GestureDetector(
      onTap: () => setDialogState(() => onPick(color)),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: active
              ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)]
              : null,
        ),
      ),
    );
  }

  void _showPinDialog(String sceneName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Enter PIN for $sceneName',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This scene is protected',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter 4-digit PIN',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: SHColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$sceneName activated!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SHColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Header row: title + Add Scene (admin or all users can create
            // scenes — scenes are per-device customization).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Scenes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openCreateScene,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: SHColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Add Scene',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar with clear button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: SHColors.cardColor.withOpacity(0.56),
                  borderRadius: BorderRadius.circular(SHColors.radiusMd),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? SHColors.primary.withOpacity(0.5)
                        : Colors.white.withOpacity(0.12),
                  ),
                  boxShadow: SHColors.softShadow,
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search scenes...',
                    hintStyle: TextStyle(color: SHColors.hintColor),
                    prefixIcon: Icon(Icons.search, color: SHColors.hintColor),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: SHColors.hintColor),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Categories Tab Bar
            SizedBox(
              height: 80,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: BoxDecoration(
                  color: SHColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SHColors.primary.withOpacity(0.35)),
                ),
                dividerColor: Colors.transparent,
                labelColor: SHColors.primary,
                unselectedLabelColor: SHColors.hintColor,
                tabs: _categories.map((category) {
                  return Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(category.icon, size: 20),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Scenes Grid
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _categories.map((category) {
                  return _buildScenesGrid(category);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenesGrid(SceneCategory category) {
    // Filter scenes based on category and search query
    List<SmartScene> filteredScenes = _scenes;

    // Apply search filter first
    if (_searchQuery.isNotEmpty) {
      filteredScenes = filteredScenes.where((scene) {
        return scene.name.toLowerCase().contains(_searchQuery) ||
            scene.description.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply category filter
    if (category.name == 'All') {
      // All: show everything.
    } else if (category.name == 'Favorites') {
      filteredScenes = filteredScenes
          .where((scene) => scene.isFavorite)
          .toList();
    } else if (category.name == 'Global') {
      filteredScenes = filteredScenes
          .where((scene) => scene.scope == 'Global')
          .toList();
    } else if (category.name == 'Rooms') {
      filteredScenes = filteredScenes
          .where((scene) => scene.scope == 'Room')
          .toList();
    }

    if (filteredScenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 80,
              color: SHColors.hintColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No scenes match your search'
                  : 'No scenes found',
              style: TextStyle(
                fontSize: 18,
                color: SHColors.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try a different keyword',
                style: TextStyle(fontSize: 14, color: SHColors.hintColor),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Tap "Add Scene" to create one',
                style: TextStyle(fontSize: 14, color: SHColors.hintColor),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredScenes.length,
      itemBuilder: (context, index) {
        final scene = filteredScenes[index];
        return _buildSceneCard(scene);
      },
    );
  }

  Widget _buildSceneCard(SmartScene scene) {
    return GestureDetector(
      onTap: () => _showPinDialog(scene.name),
      onLongPress: () => _toggleFavorite(scene),
      child: Container(
        decoration: BoxDecoration(
          color: SHColors.cardColor.withOpacity(0.58),
          gradient: SHColors.cardGradient,
          borderRadius: BorderRadius.circular(SHColors.radiusLg),
          border: Border.all(
            color: scene.isFavorite
                ? SHColors.rose.withOpacity(0.5)
                : scene.color.withOpacity(0.3),
            width: scene.isFavorite ? 2 : 1,
          ),
          boxShadow: SHColors.softShadow,
        ),
        child: Stack(
          children: [
            // Favorite icon
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                scene.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: scene.isFavorite ? SHColors.rose : Colors.white54,
                size: 20,
              ),
            ),

            // Scope badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scene.scope == 'Global'
                      ? SHColors.primary.withOpacity(0.25)
                      : SHColors.dimGrey.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  scene.scope,
                  style: TextStyle(
                    fontSize: 10,
                    color: scene.scope == 'Global'
                        ? SHColors.primary
                        : SHColors.dimGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scene.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(scene.icon, color: scene.color, size: 32),
                  ),

                  const SizedBox(height: 12),

                  // Scene name
                  Text(
                    scene.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Description
                  Text(
                    scene.description,
                    style: TextStyle(fontSize: 11, color: SHColors.mutedText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Device count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scene.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${scene.deviceCount} devices',
                      style: TextStyle(
                        fontSize: 10,
                        color: scene.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Models
class SceneCategory {
  final String name;
  final IconData icon;

  SceneCategory({required this.name, required this.icon});
}

class SmartScene {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int deviceCount;
  final bool isFavorite;
  final String? timeOfDay;
  final String scope;

  SmartScene({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.deviceCount,
    required this.isFavorite,
    this.timeOfDay,
    this.scope = 'Global',
  });
}
