// lib/features/splash/screens/splash_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Figma Frame1 geometry (414x896 artboard), scaled by screen size.
  static const double _logoWidthRatio = 84 / 414; // 0.203
  static const double _logoAspectRatio = 345 / 84; // 4.107
  static const double _logoTopRatio = 240 / 896; // logo top edge y=240
  static const double _taglineTopRatio = 642 / 896; // tagline top edge y=642
  static const double _loadingTopRatio = 700 / 896; // spinner below tagline

  // ponytail: temp dev hold so the splash stays on screen for review; set false for APK
  static const bool _devHoldSplash = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
          ),
        );

    _animationController.forward();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    if (_devHoldSplash) return; // ponytail: hold splash for review

    final authService = Provider.of<TokenAuthService>(context, listen: false);
    final isAuthenticated = await authService.checkAutoLogin();

    if (mounted) {
      if (isAuthenticated) {
        final mqtt = authService.mqttCredentials;
        final host = authService.discoveredIp;
        final commandToken = authService.commandToken;
        var mqttConnected = false;
        if (mqtt != null && host != null && commandToken != null && commandToken.isNotEmpty) {
          mqttConnected = await context.read<DirectMQTTService>().connectAuthenticated(
            host: host,
            port: mqtt['port'] as int? ?? 1884,
            username: mqtt['username'] as String? ?? '',
            password: mqtt['password'] as String? ?? '',
            commandToken: commandToken,
            tls: mqtt['tls'] == true,
            expiresAt: mqtt['expiresAt'] as String?,
          );
        }
        if (!mqttConnected) {
          // Do NOT wipe the session here — the token is still valid and the
          // MQTT failure is usually transient (board reboot, network blip).
          // Going to token-entry forces a full re-auth, which is what the
          // user perceives as "random logout". Instead, surface the retry
          // state on the home screen (DirectMQTTService.isConnected=false).
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/token-entry');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
      ),
    );

    final Size screenSize = MediaQuery.of(context).size;
    final double logoWidth = screenSize.width * _logoWidthRatio;
    final double logoHeight = logoWidth * _logoAspectRatio;
    final double logoTop = screenSize.height * _logoTopRatio;
    final double taglineTop = screenSize.height * _taglineTopRatio;
    final double loadingTop = screenSize.height * _loadingTopRatio;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: SHColors.splashBackgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Figma Frame1: logo top edge at y=240, centered horizontally.
              Positioned(
                top: logoTop,
                left: (screenSize.width - logoWidth) / 2,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SvgPicture.asset(
                      "assets/svg/okas-logo.svg",
                      width: logoWidth,
                      height: logoHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Tagline: top edge at y=642, centered horizontally.
              Positioned(
                top: taglineTop,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Control',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFFE2EDF0),
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: const [
                            TextSpan(
                              text: 'Your ',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            TextSpan(
                              text: 'World',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Loading indicator below the tagline.
              Positioned(
                top: loadingTop,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Column(
                    children: [
                      CircularProgressIndicator(color: Colors.white54),
                      SizedBox(height: 16),
                      Text(
                        'Loading..',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
