import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';

enum AuthStatus { initializing, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  final TokenStore _tokenStore;
  final AuthService _authService;

  AuthStatus status = AuthStatus.initializing;
  AppUser? user;

  AuthController({
    required TokenStore tokenStore,
    required AuthService authService,
  })  : _tokenStore = tokenStore,
        _authService = authService;

  Future<void> init() async {
    status = AuthStatus.initializing;
    notifyListeners();

    String? token;
    try {
      token = await _tokenStore.read();
    } catch (_) {
      // If secure storage is unavailable/misconfigured, don't crash the app.
      token = null;
    }
    if (token == null || token.isEmpty) {
      status = AuthStatus.unauthenticated;
      user = null;
      notifyListeners();
      return;
    }

    try {
      final me = await _authService.me();
      user = me;
      status = AuthStatus.authenticated;
    } on ApiException {
      await _tokenStore.clear();
      user = null;
      status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _authService.login(email: email, password: password);
    await _tokenStore.write(result.token);
    user = result.user;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> signupLearner({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final result = await _authService.signupLearner(fullName: fullName, email: email, password: password);
    await _tokenStore.write(result.token);
    user = result.user;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await _tokenStore.clear();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
