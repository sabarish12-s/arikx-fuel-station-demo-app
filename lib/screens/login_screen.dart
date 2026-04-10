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
      backgroundColor: const Color(0xFFECEFF8),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  // ── Top content — centered in remaining space ─────────────
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        _ClayCircle(
                          size: 96,
                          child: Padding(
                            padding: const EdgeInsets.all(11),
                            child: const AppLogo(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Brand name
                        const Text(
                          'RK Fuels',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A2561),
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Fuel Station Manager',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8A93B8),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Sign-in card
                        _ClayCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A2561),
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Sign in to continue',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8A93B8),
                                ),
                              ),
                              const SizedBox(height: 22),
                              _GoogleButton(
                                loading: _loading,
                                supported: _googleSupported,
                                onTap: _continueWithGoogle,
                              ),
                              if (!_googleSupported) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8ECFB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: Color(0xFF4A5598),
                                        size: 15,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'On Windows, open in Chrome or Edge.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF4A5598),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              const Center(
                                child: Text(
                                  'Only authorized station staff can access this app.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFAAB3D0),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Error
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
                                  color: const Color(0xFFD4AAAA)
                                      .withValues(alpha: 0.6),
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
                      ],
                    ),
                  ),

                  // ── Feature chips — pinned to bottom ──────────────────────
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Clay card ─────────────────────────────────────────────────────────────────
class _ClayCard extends StatelessWidget {
  const _ClayCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.8),
            offset: const Offset(7, 7),
            blurRadius: 18,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-6, -6),
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Clay circle (logo) ────────────────────────────────────────────────────────
class _ClayCircle extends StatelessWidget {
  const _ClayCircle({required this.size, required this.child});
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.9),
            offset: const Offset(8, 8),
            blurRadius: 20,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-7, -7),
            blurRadius: 16,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Google button ─────────────────────────────────────────────────────────────
class _GoogleButton extends StatefulWidget {
  const _GoogleButton({
    required this.loading,
    required this.supported,
    required this.onTap,
  });
  final bool loading;
  final bool supported;
  final VoidCallback onTap;

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.loading || !widget.supported;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _pressed || disabled
              ? [
                  BoxShadow(
                    color: const Color(0xFFB8C0DC).withValues(alpha: 0.4),
                    offset: const Offset(2, 2),
                    blurRadius: 5,
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFFB8C0DC).withValues(alpha: 0.9),
                    offset: const Offset(6, 6),
                    blurRadius: 14,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-5, -5),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: Center(
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF3D5AFE),
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.google,
                      color: disabled
                          ? const Color(0xFFAAB3D0)
                          : const Color(0xFF4285F4),
                      size: 19,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.supported
                          ? 'Continue with Google'
                          : 'Use Web for Google Sign-In',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: disabled
                            ? const Color(0xFFAAB3D0)
                            : const Color(0xFF1A2561),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Feature chip ──────────────────────────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.7),
            offset: const Offset(5, 5),
            blurRadius: 12,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF3D5AFE), size: 24),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A5598),
            ),
          ),
        ],
      ),
    );
  }
}
