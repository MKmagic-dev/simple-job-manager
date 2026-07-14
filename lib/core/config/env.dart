import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');

  static String _read(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required env variable "$key". '
        'Copy .env.example to .env and fill in your Supabase credentials.',
      );
    }
    return value;
  }
}
