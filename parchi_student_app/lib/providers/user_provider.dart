import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

part 'user_provider.g.dart';

@Riverpod(keepAlive: true)
class UserProfile extends _$UserProfile {
  @override
  FutureOr<User?> build() async {
    // 1. Serve from local storage immediately (zero network latency on startup)
    final cached = await authService.getUser();
    if (cached != null) {
      // 2. Refresh from API in the background without blocking the UI
      _refreshInBackground();
      return cached;
    }

    // 3. No local data at all — must fetch from network (first login)
    try {
      final profile = await authService.getProfile();
      return profile.user;
    } catch (e) {
      return null;
    }
  }

  /// Silently refreshes the profile from the API and updates state when done.
  /// Does not show a loading indicator so the UI stays responsive.
  void _refreshInBackground() {
    authService.getProfile().then((profile) {
      state = AsyncValue.data(profile.user);
    }).catchError((_) {
      // Ignore background refresh errors — cached data is already showing
    });
  }

  // Use this to manually refresh data (e.g. Pull-to-Refresh)
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final profile = await authService.getProfile();
      return profile.user;
    });
  }

  // Use this after Login to update UI instantly
  void setUser(User? user) {
    state = AsyncValue.data(user);
  }

  // [THIS WAS MISSING] Use this on Logout to clear the state
  void clearUser() {
    state = const AsyncValue.data(null);
  }
}