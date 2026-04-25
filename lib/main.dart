import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/auth_models.dart';
import 'navigation/app_router.dart';
import 'services/auth_service.dart';
import 'widgets/clay_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  runApp(const FuelStationDemoApp());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (error) {
    debugPrint('Firebase startup skipped: $error');
  }
}

class FuelStationDemoApp extends StatelessWidget {
  const FuelStationDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arikx fuel station',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5D86EA)),
        scaffoldBackgroundColor: kClayBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kClayBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: kClayPrimary),
          titleTextStyle: TextStyle(
            color: kClayPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        useMaterial3: true,
      ),
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  final AuthService _authService = AuthService();
  late final Future<AuthUser?> _userFuture = _resolveUser();
  AuthUser? _cachedUser;

  @override
  void initState() {
    super.initState();
    _primeCachedUser();
  }

  Future<void> _primeCachedUser() async {
    final cachedUser = await _authService.readCurrentUser();
    if (!mounted || cachedUser == null) {
      return;
    }
    setState(() {
      _cachedUser = cachedUser;
    });
  }

  Future<AuthUser?> _resolveUser() async {
    try {
      final hasToken = await _authService.hasJwtToken().timeout(
        const Duration(seconds: 4),
      );
      if (!hasToken) {
        return null;
      }
      return _authService.refreshCurrentUser().timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {
      await _authService.signOut();
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          if (_cachedUser != null) {
            return screenForUser(_cachedUser);
          }
          return const Scaffold(
            backgroundColor: kClayBg,
            body: ColoredBox(
              color: kClayBg,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return screenForUser(snapshot.data);
      },
    );
  }
}
