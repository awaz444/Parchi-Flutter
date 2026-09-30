import 'package:shared_preferences/shared_preferences.dart';

/// iOS (and sometimes Android) keep returning the same URL from
/// [AppLinks.getInitialLink] on later launches / widget remounts (e.g. after login).
/// Once we have acted on an initial link, remember it and ignore repeats.
const _prefsKey = 'parchi_last_consumed_initial_app_link';

String? _memoryConsumed;

/// Returns true the first time this exact initial-link URI should be handled.
Future<bool> tryConsumeInitialAppLink(Uri uri) async {
  final key = uri.toString();
  if (_memoryConsumed == key) return false;

  try {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_prefsKey);
    if (previous == key) {
      _memoryConsumed = key;
      return false;
    }
    await prefs.setString(_prefsKey, key);
  } catch (_) {
    // Still gate in-memory for this process if prefs fail.
  }

  _memoryConsumed = key;
  return true;
}

/// For tests.
void resetInitialAppLinkStore() {
  _memoryConsumed = null;
}
