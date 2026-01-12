import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import '../ui/app_theme.dart';
import '../config/app_config.dart';
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

    _api = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
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
