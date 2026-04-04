import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/auth_models.dart';
import '../navigation/app_router.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _loading = false;
  String? _error;
  bool get _googleSupported => AuthService.isGoogleSignInSupported;

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
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => screenForUser(response.user)),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE9EEF7), Color(0xFFF4F7FB)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              children: [
                const SizedBox(height: 16),
                const SizedBox(width: 150, height: 150, child: AppLogo()),
                const SizedBox(height: 22),
                const Text(
                  'Fuel Station\nManager',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 1.02,
                    color: Color(0xFF1F2A44),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Manage fuel sales and meter readings easily',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 42),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 28, 18, 26),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F8),
                    borderRadius: BorderRadius.circular(34),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap:
                            (_loading || !_googleSupported)
                                ? null
                                : _continueWithGoogle,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _googleSupported
                                    ? Colors.white
                                    : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D1F2A44),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.google,
                                color: Color(0xFF4285F4),
                                size: 28,
                              ),
                              const SizedBox(width: 22),
                              Expanded(
                                child: Text(
                                  _loading
                                      ? 'Signing in...'
                                      : _googleSupported
                                      ? 'Continue with\nGoogle'
                                      : 'Use Web for\nGoogle Sign-In',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Only authorized station staff can access this app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8B95A4),
                          fontSize: 16,
                        ),
                      ),
                      if (!_googleSupported) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'On Windows desktop, sign in from the web app in Chrome or Edge.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: const [
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.security_rounded,
                        title: 'Secure Login',
                        subtitle: '256-bit auth',
                        iconColor: Color(0xFF047857),
                        iconBg: Color(0xFFD1FAE5),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.sync_rounded,
                        title: 'Real-time',
                        subtitle: 'Live updates',
                        iconColor: Color(0xFF4E7DE8),
                        iconBg: Color(0xFFDCE6FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const Text(
                  'New station owner? Get Started',
                  style: TextStyle(fontSize: 18, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
