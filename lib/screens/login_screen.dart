import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/auth_models.dart';
import '../navigation/app_router.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _loading = false;
  String? _error;
  bool get _googleSupported => AuthService.isGoogleSignInSupported;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('clientConfigurationError') ||
        raw.contains('serverClientId must be provided') ||
        raw.contains('GOOGLE_WEB_CLIENT_ID') ||
        raw.contains('Google Sign-In is not configured in Firebase')) {
      return 'Google Sign-In is not configured in Firebase for this Android app yet.';
    }
    if (raw.contains('Google Sign-In was cancelled')) {
      return 'Google Sign-In was cancelled.';
    }
    if (raw.contains('MissingPluginException') ||
        raw.contains('not available on Windows desktop')) {
      return 'Google Sign-In is not available in the Windows desktop app. Use the web version in Chrome or Edge.';
    }
    if (raw.contains('No credentials available') ||
        raw.contains('no credential available')) {
      return 'No Google account is available on this device. Add a Google account and try again.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AuthResponse response = await _authService.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => screenForUser(response.user)),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [kClayHeroStart, kClayHeroEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kClayHeroEnd.withValues(alpha: 0.45),
                          offset: const Offset(0, 10),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: AppLogo(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'RK Fuels',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Secure station operations and daily fuel tracking in one place.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClayCard(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SIGN IN',
                          style: TextStyle(
                            color: kClaySub,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Continue to your station workspace',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: kClayPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This build currently uses the existing Google sign-in flow configured for your project.',
                          style: TextStyle(
                            fontSize: 13,
                            color: kClaySub,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!_googleSupported) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: kClayBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: kClayPrimary,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'On Windows, open in Chrome or Edge.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: kClayPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loading || !_googleSupported
                                ? null
                                : _continueWithGoogle,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const FaIcon(
                                    FontAwesomeIcons.google,
                                    size: 16,
                                  ),
                            label: Text(
                              _googleSupported
                                  ? 'Sign In'
                                  : 'Use Web for Sign-In',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: kClayHeroStart,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Center(
                          child: Text(
                            'Only authorized station staff can access this app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: kClaySub,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8E8),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFD4AAAA,
                            ).withValues(alpha: 0.6),
                            offset: const Offset(4, 4),
                            blurRadius: 10,
                          ),
                          const BoxShadow(
                            color: Colors.white,
                            offset: Offset(-3, -3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFCC3333),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF991111),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Expanded(
                        child: _FeatureChip(
                          icon: Icons.security_rounded,
                          label: 'Secure Auth',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _FeatureChip(
                          icon: Icons.bolt_rounded,
                          label: 'Real-time',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _FeatureChip(
                          icon: Icons.bar_chart_rounded,
                          label: 'Reports',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      radius: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kClayHeroStart, size: 24),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kClayPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
