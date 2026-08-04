// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/app/app.dart';
import 'package:smart_home_animation/core/theme/sh_theme.dart';
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
        theme: SHTheme.dark,
        home: const SmartHomeApp(initialRoute: '/splash'),
      ),
    );
  }
}
