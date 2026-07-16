// lib/core/app/app.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/theme/sh_theme.dart';
import 'package:smart_home_animation/features/home/presentation/screens/home_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/pin_auth_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/scene_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/splash_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/token_entry_screen.dart';
import 'package:smart_home_animation/features/home/presentation/screens/guest_management_screen.dart';
import 'package:ui_common/ui_common.dart';

class SmartHomeApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  final String initialRoute;

  const SmartHomeApp({
    super.key,
    this.initialRoute = '/splash',
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'SmartHome Animation',
          theme: SHTheme.dark,
          initialRoute: initialRoute,
          routes: {
            '/splash': (context) => SplashScreen(),
            '/token-entry': (context) => const TokenEntryScreen(),
            '/home': (context) => const HomeScreen(),
            '/pin': (context) => PinAuthScreen(),
            '/scenes': (context) => const SceneScreen(),
            '/guests': (context) => const GuestManagementScreen(),
          },
        );
      },
    );
  }
}
