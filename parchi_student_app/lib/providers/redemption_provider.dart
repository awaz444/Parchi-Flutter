import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/redemption_model.dart';
import '../services/redemption_service.dart';

// ---------------------------------------------------------------------------
// Stats provider (unchanged)
// ---------------------------------------------------------------------------
final redemptionStatsProvider = FutureProvider<RedemptionStats>((ref) async {
  return await redemptionService.getStats();
});

final redemptionStatsMonthlyProvider = FutureProvider<RedemptionStats>((ref) async {
  return await redemptionService.getStats(period: 'monthly');
});

// ---------------------------------------------------------------------------
// Paginated history state
// ---------------------------------------------------------------------------
class RedemptionHistoryState {
  final List<RedemptionModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;

  const RedemptionHistoryState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  RedemptionHistoryState copyWith({
    List<RedemptionModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return RedemptionHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class RedemptionHistoryNotifier
    extends StateNotifier<RedemptionHistoryState> {
  final int _limit = 10;

  RedemptionHistoryNotifier() : super(const RedemptionHistoryState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final items =
          await redemptionService.getRedemptions(page: 1, limit: _limit);
      state = state.copyWith(
        items: items,
        isLoading: false,
        page: 1,
        hasMore: items.length >= _limit,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> refresh() async {
    state = const RedemptionHistoryState(items: [], isLoading: true);
    await loadInitial();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    try {
      state = state.copyWith(isLoadingMore: true);
      final nextPage = state.page + 1;
      final items = await redemptionService.getRedemptions(
          page: nextPage, limit: _limit);
      state = state.copyWith(
        items: [...state.items, ...items],
        isLoadingMore: false,
        page: nextPage,
        hasMore: items.length >= _limit,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final redemptionHistoryProvider = StateNotifierProvider<
    RedemptionHistoryNotifier, RedemptionHistoryState>(
  (ref) {
    ref.keepAlive(); // Persist across tab switches — prevents re-fetch on every navigation
    return RedemptionHistoryNotifier();
  },
);

// ---------------------------------------------------------------------------
// Per-redemption detail provider (fetches by ID on demand)
// ---------------------------------------------------------------------------
final redemptionDetailProvider =
    FutureProvider.autoDispose.family<RedemptionModel, String>((ref, id) async {
  return await redemptionService.getRedemptionDetails(id);
});

// ---------------------------------------------------------------------------
// Kept for backwards compat with recentRedemptionsProvider usages
// ---------------------------------------------------------------------------
final recentRedemptionsProvider =
    FutureProvider.autoDispose<List<RedemptionModel>>((ref) async {
  return await redemptionService.getRedemptions(page: 1);
});
