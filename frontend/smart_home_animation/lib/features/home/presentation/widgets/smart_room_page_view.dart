// smart_room_page_view.dart
import 'package:flutter/material.dart';

import '../../../../core/shared/domain/entities/smart_room.dart';
import '../../../../core/shared/presentation/widgets/room_card.dart';
import '../../../smart_room/screens/room_details_screen.dart';

class SmartRoomsPageView extends StatefulWidget {
  const SmartRoomsPageView({
    super.key,
    required this.rooms, // Add rooms parameter
    required this.pageNotifier,
    required this.roomSelectorNotifier,
    required this.controller,
  });

  final List<SmartRoom> rooms;
  final ValueNotifier<double> pageNotifier;
  final ValueNotifier<int> roomSelectorNotifier;
  final PageController controller;

  @override
  State<SmartRoomsPageView> createState() => _SmartRoomsPageViewState();
}

class _SmartRoomsPageViewState extends State<SmartRoomsPageView> {
  @override
  Widget build(BuildContext context) {
    if (widget.rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No rooms found. Please add rooms using the + button.'),
          ],
        ),
      );
    }

    return ValueListenableBuilder<double>(
      valueListenable: widget.pageNotifier,
      builder: (_, page, __) => ValueListenableBuilder(
        valueListenable: widget.roomSelectorNotifier,
        builder: (_, selected, __) => PageView.builder(
          clipBehavior: Clip.none,
          itemCount: widget.rooms.length,
          controller: widget.controller,
          itemBuilder: (_, index) {
            final percent = page - index;
            final isSelected = selected == index;
            final room = widget.rooms[index];
            return AnimatedContainer(
              duration: kThemeAnimationDuration,
              curve: Curves.fastOutSlowIn,
              transform: _getOutTranslate(percent, selected, index),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RoomCard(
                percent: percent,
                expand: isSelected,
                room: room,
                onSwipeUp: () => widget.roomSelectorNotifier.value = index,
                onSwipeDown: () => widget.roomSelectorNotifier.value = -1,
                onTap: () async {
                  if (isSelected) {
                    await Navigator.push(
                      context,
                      PageRouteBuilder<void>(
                        transitionDuration: const Duration(milliseconds: 800),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 800,
                        ),
                        pageBuilder: (_, animation, __) => FadeTransition(
                          opacity: animation,
                          child: RoomDetailScreen(room: room),
                        ),
                      ),
                    );
                    widget.roomSelectorNotifier.value = -1;
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  double _getOffsetX(double percent) => percent.isNegative ? 30.0 : -30.0;

  Matrix4 _getOutTranslate(double percent, int selected, int index) {
    final x = selected != index && selected != -1 ? _getOffsetX(percent) : 0.0;
    return Matrix4.translationValues(x, 0, 0);
  }
}
