// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/api/constants.dart';
import 'package:smart_home_animation/core/app/app.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TokenAuthService()),
        ChangeNotifierProvider(create: (_) => DirectMQTTService()),
      ],
      child: MaterialApp(
        title: 'OKAS Smart Home',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: SHColors.primary,
            secondary: SHColors.secondary,
            tertiary: SHColors.tertiary,
            background: SHColors.black,
            surface: SHColors.cardColor,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onBackground: Colors.white,
            onSurface: Colors.white,
            error: Colors.red,
          ),
          scaffoldBackgroundColor: Colors.transparent,
          fontFamily: 'sans-serif',
          useMaterial3: true,
        ),
        home: const SmartHomeApp(initialRoute: '/splash'),
      ),
    );
  }
}
