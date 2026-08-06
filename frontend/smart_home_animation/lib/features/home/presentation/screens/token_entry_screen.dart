// lib/features/auth/screens/token_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';

class TokenEntryScreen extends StatefulWidget {
  const TokenEntryScreen({super.key});

  @override
  State<TokenEntryScreen> createState() => _TokenEntryScreenState();
}

class _TokenEntryScreenState extends State<TokenEntryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureToken = true;
  bool _obscurePassword = true;
  bool _isAdminLogin = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(_fadeAnim);
    _animController.forward();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<TokenAuthService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF01080D),
      body: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(child: _AuthBackground()),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(height: 136),
                            const _OkasLogo(),
                            const SizedBox(height: 17),
                            const Text(
                              'Control',
                              style: TextStyle(
                                color: Color(0xFFE4F0F2),
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                height: 1.1,
                              ),
                            ),
                            const Text.rich(
                              TextSpan(
                                text: 'Your ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300,
                                  height: 1.1,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'World',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Sign in as Owner or Guest',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _buildSegmentedControl(),
                            const SizedBox(height: 39),
                            RepaintBoundary(
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  layoutBuilder: (currentChild,
                                      previousChildren) {
                                    return Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        ...previousChildren,
                                        if (currentChild != null)
                                          currentChild,
                                      ],
                                    );
                                  },
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOut,
                                        reverseCurve: Curves.easeIn,
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: _isAdminLogin
                                      ? _buildAdminFields(authService)
                                      : _buildGuestField(authService),
                                ),
                              ),
                            ),
                            const SizedBox(height: 38),
                            if (authService.error != null)
                              _buildErrorBanner(authService),
                            if (authService.isLoading ||
                                authService.error != null)
                              const SizedBox(height: 16),
                            _buildLoginButton(authService),
                            const SizedBox(height: 22),
                            if (_isAdminLogin)
                              _buildLinkButton(
                                label: 'Forgot password?',
                                onPressed: () =>
                                    _showForgotPasswordDialog(context),
                              ),
                            const SizedBox(height: 16),
                            _buildLinkButton(
                              label: 'Need Help? Contact Okas Distributor',
                              onPressed: () => _showHelpDialog(context),
                              prominent: true,
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminFields(TokenAuthService authService) {
    return Center(
      key: const ValueKey('admin-fields'),
      child: SizedBox(
        width: 320,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 296),
          child: Column(
            children: [
              _buildInputField(
                controller: _emailController,
                hintText: 'Email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                obscureText: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              _buildInputField(
                controller: _passwordController,
                hintText: 'Password',
                prefixIcon: Icons.lock_outline,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.password],
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                suffixIcon: _buildVisibilityButton(
                  visible: !_obscurePassword,
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                onSubmitted: (_) => _handleProceed(context, authService),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestField(TokenAuthService authService) {
    return Center(
      key: const ValueKey('guest-field'),
      child: SizedBox(
        width: 280,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 296),
          child: _buildInputField(
            controller: _tokenController,
            hintText: 'Guest Token',
            prefixIcon: Icons.vpn_key_outlined,
            keyboardType: TextInputType.text,
            autofillHints: const [],
            obscureText: _obscureToken,
            textInputAction: TextInputAction.done,
            suffixIcon: _buildVisibilityButton(
              visible: !_obscureToken,
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
            ),
            onSubmitted: (_) => _handleProceed(context, authService),
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityButton({
    required bool visible,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: visible ? 'Hide password' : 'Show password',
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          key: ValueKey(visible),
          visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: const Color(0xFF8AAAB3),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildLinkButton({
    required String label,
    required VoidCallback onPressed,
    bool prominent = false,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: prominent
            ? const Color(0xFFE2EFF1)
            : const Color(0xFFC8DDE0),
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: TextStyle(
          fontSize: prominent ? 14 : 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 296),
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF052B3A).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF124A5A).withValues(alpha: 0.75),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleOption(
              label: 'Owner',
              selected: _isAdminLogin,
              onTap: () => setState(() => _isAdminLogin = true),
            ),
          ),
          Expanded(
            child: _buildRoleOption(
              label: 'Guest',
              selected: !_isAdminLogin,
              onTap: () => setState(() => _isAdminLogin = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label sign in',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF4BC2C7) : null,
              borderRadius: BorderRadius.circular(19),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4BC2C7).withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF9CB4BA),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Input Field ────────────────────────────────────────────────────
  Widget _buildInputField({
    Key? key,
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required TextInputType keyboardType,
    required List<String> autofillHints,
    required bool obscureText,
    required TextInputAction textInputAction,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      cursorColor: const Color(0xFF63D4D5),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: const Color(0xFFB1C8CC).withValues(alpha: 0.55),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: const Color(0xFF8AAAB3),
          size: 20,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        enabledBorder: _inputBorder(const Color(0xFF6A9DAC)),
        focusedBorder: _inputBorder(const Color(0xFF65D0D2), width: 1.4),
        border: _inputBorder(const Color(0xFF6A9DAC)),
      ),
    );
  }

  OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color.withValues(alpha: 0.9), width: width),
    );
  }

  // ─── Log In Button ──────────────────────────────────────────────────
  Widget _buildLoginButton(TokenAuthService authService) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: authService.isLoading
            ? const Color(0xFF35979D)
            : const Color(0xFF4BC2C7),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4BC2C7).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: SizedBox(
        width: 176,
        height: 42,
        child: ElevatedButton(
          onPressed: authService.isLoading
              ? null
              : () => _handleProceed(context, authService),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(21),
            ),
            padding: EdgeInsets.zero,
          ),
          child: authService.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'LOGIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatusShell({required Widget child, required Color accent}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: child,
    );
  }

  // ─── Status Banners ─────────────────────────────────────────────────
  Widget _buildErrorBanner(TokenAuthService authService) {
    return _buildStatusShell(
      accent: const Color(0xFFFF8585),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF8585), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              authService.error!,
              style: const TextStyle(color: Color(0xFFFFB3B3), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Auth Logic ─────────────────────────────────────────────────────
  Future<void> _handleProceed(
    BuildContext context,
    TokenAuthService authService,
  ) async {
    final bool success;
    if (_isAdminLogin) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your email and password')),
        );
        return;
      }
      success = await authService.authenticateWithEmail(
        email: email,
        password: password,
      );
    } else {
      final token = _tokenController.text.trim();
      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your Guest token')),
        );
        return;
      }
      success = await authService.authenticateWithToken(token);
    }

    if (success && mounted) {
      final mqtt = authService.mqttCredentials;
      if (mqtt == null || authService.discoveredIp == null) {
        _showErrorDialog(
          context,
          'The Device did not return connection details.',
        );
        return;
      }
      final commandToken = authService.commandToken;
      if (commandToken == null || commandToken.isEmpty) {
        _showErrorDialog(
          context,
          'The Device did not return a command session token.',
        );
        return;
      }
      final connected = await context
          .read<DirectMQTTService>()
          .connectAuthenticated(
            host: authService.discoveredIp!,
            port: mqtt['port'] as int? ?? 1884,
            username: mqtt['username'] as String? ?? '',
            password: mqtt['password'] as String? ?? '',
            commandToken: commandToken,
            tls: mqtt['tls'] == true,
            expiresAt: mqtt['expiresAt'] as String?,
          );
      if (!connected && mounted) {
        _showErrorDialog(
          context,
          'Authenticated, but unable to connect to MQTT.',
        );
        return;
      }
      Navigator.pushReplacementNamed(context, '/home');
    } else if (mounted && authService.error != null) {
      _showErrorDialog(context, authService.error!);
    }
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF173F4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Authentication Failed',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SHColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final ownerTokenController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF173F4B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Reset Password',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter Your Owner token (printed on the device / '
                  'configured by your distributor) and a new password.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ownerTokenController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Owner token',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                  ),
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
              onPressed: saving
                  ? null
                  : () async {
                      final ownerToken = ownerTokenController.text.trim();
                      final next = newPasswordController.text;
                      final confirm = confirmController.text;
                      if (next != confirm) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await context.read<TokenAuthService>().resetPassword(
                          ownerToken: ownerToken,
                          newPassword: next,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password reset. Sign in with the new password.',
                              ),
                              backgroundColor: SHColors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: SHColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(saving ? 'Resetting…' : 'Reset'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF173F4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Need Help?', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To authenticate with your OKAS Homekit:',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 12),
            Text(
              '1. Make sure your phone is on the same WiFi network as the OKAS Homekit',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              '2. Ensure the OKAS Homekit is powered on and connected to the network',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              '3. Contact OKAS Distributor/Programmer to get your token',
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

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.94, -1.1),
          radius: 1.55,
          colors: [
            Color(0xFF1595A3),
            Color(0xFF087487),
            Color(0xFF064E6B),
            Color(0xFF032D46),
            Color(0xFF01080D),
          ],
          stops: [0.0, 0.2, 0.42, 0.67, 1.0],
        ),
      ),
    );
  }
}

class _OkasLogo extends StatelessWidget {
  const _OkasLogo();

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: SvgPicture.asset(
        'assets/svg/okas-logo.svg',
        width: 52,
        height: 200,
        fit: BoxFit.contain,
      ),
    );
  }
}
