import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/skilltrack_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional: allows setting API_BASE_URL from `frontend/.env`.
  // App still runs with platform defaults if this file is missing.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // ignore
  }

  runApp(const SkillTrackApp());
}
