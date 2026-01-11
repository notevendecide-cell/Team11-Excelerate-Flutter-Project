import '../models/app_user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<({String token, AppUser user})> login({required String email, required String password}) async {
    final json = await _api.post('/auth/login', auth: false, body: {
      'email': email,
      'password': password,
    });

    final token = (json as Map<String, dynamic>)['token'] as String;
    final userJson = (json)['user'] as Map<String, dynamic>;
    final user = AppUser.fromJson(userJson);

    return (token: token, user: user);
  }

  Future<({String token, AppUser user})> signupLearner({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final json = await _api.post('/auth/signup', auth: false, body: {
      'fullName': fullName,
      'email': email,
      'password': password,
    });

    final token = (json as Map<String, dynamic>)['token'] as String;
    final userJson = (json)['user'] as Map<String, dynamic>;
    final user = AppUser.fromJson(userJson);

    return (token: token, user: user);
  }

  Future<AppUser> me() async {
    final json = await _api.get('/auth/me', auth: true);
    final userJson = (json as Map<String, dynamic>)['user'] as Map<String, dynamic>;
    return AppUser.fromJson(userJson);
  }

  Future<void> requestPasswordReset(String email) async {
    await _api.post('/auth/request-password-reset', auth: false, body: {'email': email});
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    await _api.post('/auth/reset-password', auth: false, body: {'token': token, 'newPassword': newPassword});
  }
}
