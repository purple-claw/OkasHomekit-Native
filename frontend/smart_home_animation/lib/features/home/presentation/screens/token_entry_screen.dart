// lib/features/auth/screens/token_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';

class TokenEntryScreen extends StatefulWidget {
  const TokenEntryScreen({super.key});

  @override
  State<TokenEntryScreen> createState() => _TokenEntryScreenState();
}

class _TokenEntryScreenState extends State<TokenEntryScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _obscureToken = true;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<TokenAuthService>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: SHColors.backgroundColor),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                // Title
                const Text(
                  'OKAS Authentication',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your authentication token',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // Token Field
                TextField(
                  controller: _tokenController,
                  obscureText: _obscureToken,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Authentication Token',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Enter your Auth token',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.vpn_key,
                      color: Colors.white54,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureToken = !_obscureToken;
                        });
                      },
                    ),
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
                const SizedBox(height: 16),

                // Discovery Logs
                if (authService.isLoading &&
                    authService.discoveryLogs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Discovering...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...authService.discoveryLogs.map(
                          (log) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              log,
                              style: TextStyle(
                                color: log.contains('✅')
                                    ? Colors.green
                                    : log.contains('❌')
                                    ? Colors.red
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Discovery Status
                if (authService.discoveredIp != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Board found at: ${authService.discoveredIp}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              // if (authService.discoveredMac != null)
                              //   Text(
                              //     'MAC: ${authService.discoveredMac}',
                              //     style: TextStyle(
                              //       color: Colors.white54,
                              //       fontSize: 12,
                              //     ),
                              //   ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Error Message
                if (authService.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authService.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Proceed Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authService.isLoading
                        ? null
                        : () => _handleProceed(context, authService),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SHColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authService.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Proceed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Help Text
                TextButton(
                  onPressed: () {
                    _showHelpDialog(context);
                  },
                  child: const Text(
                    'Need help? Contact OKAS Distributor',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleProceed(
    BuildContext context,
    TokenAuthService authService,
  ) async {
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the authentication token')),
      );
      return;
    }

    final success = await authService.authenticateWithToken(token);
    if (success && mounted) {
      final mqtt = authService.mqttCredentials;
      if (mqtt == null || authService.discoveredIp == null) {
        _showErrorDialog(context, 'The board did not return MQTT connection details.');
        return;
      }
      final connected = await context.read<DirectMQTTService>().connectAuthenticated(
        host: authService.discoveredIp!,
        port: mqtt['port'] as int? ?? 1884,
        username: mqtt['username'] as String? ?? '',
        password: mqtt['password'] as String? ?? '',
        commandToken: authService.commandToken ?? '',
        tls: mqtt['tls'] == true,
        expiresAt: mqtt['expiresAt'] as String?,
      );
      if (!connected && mounted) {
        _showErrorDialog(context, 'Authenticated, but unable to connect to MQTT.');
        return;
      }
      Navigator.pushReplacementNamed(context, '/home');
    } else if (mounted && authService.error != null) {
      // Show the error dialog
      _showErrorDialog(context, authService.error!);
    }
  }

  // ADD THIS METHOD - Error Dialog
  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Authentication Failed',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(error, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            const Text(
              'Please contact OKAS distributor for assistance.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
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
              _tokenController.clear();
            },
            style: ElevatedButton.styleFrom(backgroundColor: SHColors.primary),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Need Help?', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To authenticate your OKAS board:',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 12),
            Text(
              '1. Make sure your phone is on the same WiFi network as the OKAS board',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              '2. Ensure the OKAS board is powered on and connected to the network',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              '3. Contact OKAS distributor to get your token',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              '4. Enter the token to proceed',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
