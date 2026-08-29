import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks, per this device only, the last time the boss opened a given
/// screen — used to compute "N new since you last looked" badge counts.
/// Not synced anywhere: a fresh device/browser starts with everything
/// counted as unread.
class LastSeenController extends StateNotifier<DateTime?> {
  LastSeenController(this._prefsKey) : super(null) {
    _load();
  }

  final String _prefsKey;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    state = raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markSeenNow() async {
    final now = DateTime.now();
    state = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, now.toIso8601String());
  }
}

final lastSeenRequestsProvider =
    StateNotifierProvider<LastSeenController, DateTime?>((ref) {
      return LastSeenController('last_seen_requests_at');
    });

final lastSeenWorkPhotosProvider =
    StateNotifierProvider<LastSeenController, DateTime?>((ref) {
      return LastSeenController('last_seen_work_photos_at');
    });
