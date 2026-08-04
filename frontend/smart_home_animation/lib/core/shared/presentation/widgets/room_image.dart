// lib/core/shared/presentation/widgets/room_image.dart
//
// Renders a room image from either:
//   - a local file path (old device-local storage), or
//   - an HTTP(S) URL (the board's /uploads/ endpoint, synced to all
//     devices via MQTT).
//
// Using this widget everywhere a room image is shown keeps the display
// consistent across the Home tab, Rooms tab, and room detail sheets.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../theme/sh_colors.dart';

class RoomImage extends StatelessWidget {
  const RoomImage({
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    super.key,
  });

  final String? imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  bool get _isRemote =>
      imagePath != null &&
      (imagePath!.startsWith('http://') || imagePath!.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_isRemote) {
      child = Image.network(
        imagePath!,
        fit: fit,
        width: width,
        height: height,
        // Cache on the device so a second visit doesn't re-download and
        // the image survives a board IP change (the file stays local).
        cacheWidth: width != null ? (width! * MediaQuery.devicePixelRatioOf(context)).round() : null,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.black26,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    } else if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
      child = file.existsSync()
          ? Image.file(
              file,
              fit: fit,
              width: width,
              height: height,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder();
    } else {
      child = _placeholder();
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.black26,
      alignment: Alignment.center,
      child: const Icon(
        Icons.meeting_room_outlined,
        color: SHColors.hintColor,
        size: 32,
      ),
    );
  }
}
