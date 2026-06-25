import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/redemption_provider.dart';
import '../providers/user_provider.dart';
import 'auth_service.dart';

class SessionService {
  /// Fully signs the user out across all auth sources and clears in-memory state.
  ///
  /// Pass either a [WidgetRef] (preferred) or a [BuildContext] (for non-Consumer widgets).
  static Future<void> signOut({
    WidgetRef? ref,
    BuildContext? context,
    bool signOutSupabase = true,
  }) async {
    await authService.logout();

    if (signOutSupabase) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // Best-effort. Local logout already cleared tokens and persisted user.
      }
    }

    if (ref != null) {
      ref.read(userProfileProvider.notifier).clearUser();
      ref.invalidate(redemptionHistoryProvider);
      ref.invalidate(redemptionStatsProvider);
      ref.invalidate(redemptionStatsMonthlyProvider);
      return;
    }

    if (context == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    container.read(userProfileProvider.notifier).clearUser();
    container.invalidate(redemptionHistoryProvider);
    container.invalidate(redemptionStatsProvider);
    container.invalidate(redemptionStatsMonthlyProvider);
  }
}

