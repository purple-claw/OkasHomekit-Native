// screens/scene_screen.dart
// ignore_for_file: unused_element, prefer_final_fields

import 'package:flutter/material.dart';
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
    SceneCategory(name: 'Favorites', icon: Icons.favorite),
    SceneCategory(name: 'Morning', icon: Icons.wb_sunny),
    SceneCategory(name: 'Evening', icon: Icons.nightlight),
    SceneCategory(name: 'Sleep', icon: Icons.bed),
    SceneCategory(name: 'Away', icon: Icons.lock_outline),
  ];

  List<SmartScene> _scenes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _searchController.addListener(_onSearchChanged);
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
        _scenes[index] = SmartScene(
          id: _scenes[index].id,
          name: _scenes[index].name,
          description: _scenes[index].description,
          icon: _scenes[index].icon,
          color: _scenes[index].color,
          deviceCount: _scenes[index].deviceCount,
          isFavorite: !_scenes[index].isFavorite,
          timeOfDay: _scenes[index].timeOfDay,
        );

        // Show feedback
        final isNowFavorite = _scenes[index].isFavorite;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNowFavorite
                  ? '${scene.name} added to favorites ❤️'
                  : '${scene.name} removed from favorites',
            ),
            backgroundColor: isNowFavorite ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    });
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
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Colors.white54,
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
    return Container(
      decoration: const BoxDecoration(gradient: SHColors.backgroundColor),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Search Bar with clear button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? SHColors.primary.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search scenes...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400]),
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
                ),
                dividerColor: Colors.transparent,
                labelColor: SHColors.primary,
                unselectedLabelColor: Colors.grey,
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
    if (category.name != 'All') {
      if (category.name == 'Favorites') {
        filteredScenes = filteredScenes
            .where((scene) => scene.isFavorite)
            .toList();
      } else {
        filteredScenes = filteredScenes
            .where(
              (scene) =>
                  scene.name.contains(category.name) ||
                  scene.description.contains(category.name),
            )
            .toList();
      }
    }

    if (filteredScenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No scenes match your search'
                  : 'No scenes found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try a different keyword',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Try a different category',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
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
      // onTap: () => _showPinDialog(scene.name),
      onLongPress: () => _toggleFavorite(scene),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scene.color.withOpacity(0.2),
              scene.color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scene.isFavorite
                ? Colors.red.withOpacity(0.5)
                : scene.color.withOpacity(0.3),
            width: scene.isFavorite ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Favorite icon
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                scene.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: scene.isFavorite ? Colors.red : Colors.white54,
                size: 20,
              ),
            ),

            // Time indicator (if available)
            if (scene.timeOfDay != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    scene.timeOfDay!,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ),

            // Long press indicator
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_outline,
                      color: Colors.white54,
                      size: 10,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Long press to favorite',
                      style: TextStyle(fontSize: 8, color: Colors.white54),
                    ),
                  ],
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
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Description
                  Text(
                    scene.description,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
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

  SmartScene({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.deviceCount,
    required this.isFavorite,
    this.timeOfDay,
  });
}
