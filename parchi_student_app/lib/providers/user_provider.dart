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
      // If we have a cached user but no token, treat it as a stale session.
      final token = await authService.getToken().catchError((_) => null);
      if (token == null) {
        await authService.removeToken();
        return null;
      }

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
    }).catchError((_) async {
      // If the token is missing/expired, clear cached user so the UI doesn't
      // look authenticated while authenticated endpoints fail.
      final token = await authService.getToken().catchError((_) => null);
      if (token == null) {
        await authService.removeToken();
        state = const AsyncValue.data(null);
      }
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

  // Update app intro state locally (fast UI response) and ping backend
  Future<void> markAppIntroSeen() async {
    final currentUser = state.value;
    if (currentUser != null) {
      // Optimistic local update
      final updatedUser = User(
        id: currentUser.id,
        email: currentUser.email,
        role: currentUser.role,
        isActive: currentUser.isActive,
        phone: currentUser.phone,
        firstName: currentUser.firstName,
        lastName: currentUser.lastName,
        parchiId: currentUser.parchiId,
        university: currentUser.university,
        profilePicture: currentUser.profilePicture,
        isFoundersClub: currentUser.isFoundersClub,
        verificationStatus: currentUser.verificationStatus,
        hasUnreadNotifications: currentUser.hasUnreadNotifications,
        hasSeenAppIntro: true, // Mark as seen
      );
      state = AsyncValue.data(updatedUser);
      authService.setUser(updatedUser); // Update local cache

      // Ping backend asynchronously to persist without blocking UI
      try {
        await authService.markAppIntroSeen();
      } catch (e) {
        // Silently fail or log if backend call fails (can retry next session)
        print('Error marking app intro as seen: $e');
      }
    }
  }
}