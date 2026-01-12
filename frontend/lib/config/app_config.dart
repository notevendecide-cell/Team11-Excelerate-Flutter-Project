import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Global app configuration.
///
/// Change the backend URL in ONE place:
/// - `frontend/.env` (recommended)
/// - or `--dart-define=API_BASE_URL=...`
///
/// Priority order:
/// 1) `--dart-define=API_BASE_URL=...`
/// 2) `.env` value `API_BASE_URL=...` (if present)
/// 3) Platform defaults (web localhost, android emulator 10.0.2.2)
class AppConfig {
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.trim().isNotEmpty) return fromDefine;

    final fromEnvFile = dotenv.env['API_BASE_URL'];
    if (fromEnvFile != null && fromEnvFile.trim().isNotEmpty) return fromEnvFile;

    return kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
  }
}
