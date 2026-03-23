import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/auth_models.dart';
import 'navigation/app_router.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.initialize();
  runApp(const RkFuelsApp());
}

class RkFuelsApp extends StatelessWidget {
  const RkFuelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RK Fuels',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5D86EA)),
        scaffoldBackgroundColor: const Color(0xFFE9EEF7),
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

  Future<AuthUser?> _resolveUser() async {
    final hasToken = await _authService.hasJwtToken();
    if (!hasToken) {
      return null;
    }
    return _authService.readCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return screenForUser(null);
        }
        return screenForUser(snapshot.data);
      },
    );
  }
}
