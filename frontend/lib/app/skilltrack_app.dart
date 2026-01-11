import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import '../ui/app_theme.dart';
import 'auth_controller.dart';
import 'router.dart';

class SkillTrackApp extends StatefulWidget {
  const SkillTrackApp({super.key});

  @override
  State<SkillTrackApp> createState() => _SkillTrackAppState();
}

class _SkillTrackAppState extends State<SkillTrackApp> {
  late final TokenStore _tokenStore;
  late final ApiClient _api;
  late final AuthService _authService;
  late final AuthController _auth;
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();

    _tokenStore = TokenStore(const FlutterSecureStorage());

    // Defaults by runtime:
    // - Flutter Web: http://localhost:3000 (same machine)
    // - Android emulator: http://10.0.2.2:3000 (host machine)
    // - iOS simulator: http://localhost:3000
    // - Physical device: use your machine LAN IP
    final baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000',
    );

    _api = ApiClient(
      baseUrl: baseUrl,
      tokenProvider: _tokenStore.read,
    );

    _authService = AuthService(_api);
    _auth = AuthController(tokenStore: _tokenStore, authService: _authService);
    _router = AppRouter(auth: _auth, api: _api);

    _auth.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SkillTrack Pro',
      theme: AppTheme.light(),
      routerConfig: _router.router,
    );
  }
}
