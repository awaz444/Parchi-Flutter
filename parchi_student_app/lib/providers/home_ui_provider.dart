import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'offers_provider.dart';
import 'brands_provider.dart';
import 'merchants_provider.dart';
import 'user_provider.dart';
import 'redemption_provider.dart';
import 'categories_provider.dart';

class HomeUIState {
  final bool isSkeletonLoading;

  HomeUIState({
    this.isSkeletonLoading = false,
  });

  HomeUIState copyWith({
    bool? isSkeletonLoading,
  }) {
    return HomeUIState(
      isSkeletonLoading: isSkeletonLoading ?? this.isSkeletonLoading,
    );
  }
}

class HomeUINotifier extends StateNotifier<HomeUIState> {
  final Ref ref;

  HomeUINotifier(this.ref) : super(HomeUIState());

  Future<void> startRefreshSequence() async {
    // 1. Switch to Skeleton immediately (Pulse removed)
    state = state.copyWith(isSkeletonLoading: true);

    try {
      // 2. Trigger Refreshes
      // Using Future.wait to run them in parallel
      await Future.wait([
        ref.refresh(userProfileProvider.future),
        ref.refresh(featuredOffersProvider.future),
        ref.refresh(brandsProvider.future),
        ref.refresh(redemptionStatsProvider.future),
        ref.refresh(categoriesProvider.future),
        ref.read(studentMerchantsProvider.notifier).refresh(),
      ]);
    } catch (e) {
      debugPrint("Refresh Sequence Error: $e");
    } finally {
      // 3. Turn off Skeleton
      if (mounted) {
        state = state.copyWith(isSkeletonLoading: false);
      }
    }
  }
}

final homeUIProvider = StateNotifierProvider<HomeUINotifier, HomeUIState>((ref) {
  return HomeUINotifier(ref);
});
