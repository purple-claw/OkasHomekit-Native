// ignore_for_file: deprecated_member_use, unused_element, unused_field, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:smart_home_animation/core/theme/sh_theme.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/glass_panel.dart';

class PinAuthScreen extends StatefulWidget {
  const PinAuthScreen({super.key});

  @override
  State<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends State<PinAuthScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final TextEditingController _pinController = TextEditingController();
  final int _pinLength = 4;

  List<String> _pinDigits = ['', '', '', ''];
  int _currentIndex = 0;
  bool _isBiometricAvailable = false;
  bool _isBiometricSupported = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      // Check if biometrics are available
      bool isAvailable = await _localAuth.canCheckBiometrics;
      // Check available biometrics
      List<BiometricType> availableBiometrics = await _localAuth
          .getAvailableBiometrics();
      bool isDeviceSupported = await _localAuth.isDeviceSupported();

      setState(() {
        _isBiometricAvailable = isAvailable && isDeviceSupported;
        _isBiometricSupported = isDeviceSupported;
      });
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
      setState(() {
        _isBiometricAvailable = false;
        _isBiometricSupported = false;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      // For local_auth: ^3.0.1 - AuthenticationOptions has been removed/changed
      // Use the authenticate method without options parameter or with different parameters
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Use fingerprint to unlock your smart home',
        // For newer versions, you might need to use AuthOptions or remove options
        // Option 1: Remove options parameter if it's not supported
        // Option 2: Use the correct class if it exists
      );

      if (authenticated) {
        _navigateToHome();
      }
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Biometric authentication failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Biometric authentication failed';
      });
    }
  }

  // Alternative method using the newer API if needed
  Future<void> _authenticateWithBiometricsV2() async {
    try {
      // First check if we can authenticate
      bool canAuthenticate = await _localAuth.canCheckBiometrics;

      if (!canAuthenticate) {
        setState(() {
          _errorMessage = 'Biometric authentication not available';
        });
        return;
      }

      // For local_auth 3.0.1, you might need to use a different approach
      // This is one common pattern
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Use fingerprint to unlock your smart home',
        // Some versions use optional named parameters instead of options
        biometricOnly: true, // If this parameter exists
      );

      if (didAuthenticate) {
        _navigateToHome();
      }
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Biometric authentication failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Biometric authentication failed';
      });
    }
  }

  void _onPinDigitPressed(String digit) {
    if (_currentIndex < _pinLength) {
      setState(() {
        _pinDigits[_currentIndex] = digit;
        _currentIndex++;
        _errorMessage = '';
      });
    }

    if (_currentIndex == _pinLength) {
      _verifyPin();
    }
  }

  void _onDeletePressed() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pinDigits[_currentIndex] = '';
      });
    }
  }

  Future<void> _verifyPin() async {
    String enteredPin = _pinDigits.join('');

    try {
      // In production, verify against stored hash in secure storage
      String? storedPin = await _secureStorage.read(key: 'user_pin');

      // For demo purposes, using a default PIN "1234"
      if (enteredPin == '1234' || enteredPin == storedPin) {
        _navigateToHome();
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN';
          _pinDigits = ['', '', '', ''];
          _currentIndex = 0;
        });

        // Optional: Shake animation for wrong PIN
        _shakePinDots();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying PIN';
      });
    }
  }

  void _shakePinDots() {
    // You can add a shake animation here if desired
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SHTheme.dark.primaryColor,
              SHTheme.dark.primaryColor.withValues(alpha: 0.8),
              SHTheme.dark.secondaryHeaderColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon with subtle animation
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.8, end: 1.0),
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      builder: (context, double scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Icon(
                            Icons.home_max,
                            size: 80,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                      'SmartHome Pro',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 40),
                    Text(
                      'Enter PIN to Access',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // PIN Dots
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pinLength,
                    (index) => AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      margin: EdgeInsets.all(8),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pinDigits[index].isEmpty
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.white,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ),

              // Error Message
              if (_errorMessage.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Colors.red[300],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // Biometric Option
              if (_isBiometricAvailable)
                Container(
                  margin: EdgeInsets.only(bottom: 20),
                  child: TextButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    icon: Icon(
                      Icons.fingerprint,
                      color: Colors.white,
                      size: 30,
                    ),
                    label: Text(
                      'Use Fingerprint',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),

              // Number Pad
              Expanded(
                flex: 3,
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      // Empty space at index 9 (where the 0 button would normally be in a phone keypad)
                      if (index == 9) return SizedBox.shrink();
                      // 0 button at index 10
                      if (index == 10) {
                        return _buildNumberButton('0');
                      }
                      // Delete button at index 11
                      if (index == 11) {
                        return _buildDeleteButton();
                      }
                      // Numbers 1-9 at indices 0-8
                      if (index < 9) {
                        return _buildNumberButton('${index + 1}');
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ),
              ),

              // Forgot PIN (Optional)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextButton(
                  onPressed: () {
                    // Handle forgot PIN
                    _showForgotPinDialog();
                  },
                  child: Text(
                    'Forgot PIN?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => _onPinDigitPressed(number),
        borderRadius: BorderRadius.circular(15),
        splashColor: Colors.white.withValues(alpha: 0.3),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: _onDeletePressed,
        borderRadius: BorderRadius.circular(15),
        splashColor: Colors.white.withValues(alpha: 0.3),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Center(
          child: Icon(Icons.backspace_outlined, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  void _showForgotPinDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FrostedAlertDialog(
          title: Text('Forgot PIN'),
          content: Text(
            'Please contact support or reset your PIN through email verification.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
