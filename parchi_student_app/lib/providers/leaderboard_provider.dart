import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard_model.dart';
import '../services/leaderboard_service.dart';

// State class for Leaderboard
class LeaderboardState {
  final List<LeaderboardItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;

  LeaderboardState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  LeaderboardState copyWith({
    List<LeaderboardItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return LeaderboardState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error, // Nullable update
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// Notifier to manage the state
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final LeaderboardService _service;
  final int _limit = 10;

  LeaderboardNotifier(this._service) : super(LeaderboardState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final response = await _service.getLeaderboard(page: 1, limit: _limit);
      state = state.copyWith(
        items: response.items,
        isLoading: false,
        page: 1,
        hasMore: response.pagination.hasNext,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> refresh() async {
    // Reset state and reload
    state = LeaderboardState(items: [], isLoading: true); 
    // ^ Note: keeping items empty during refresh or keeping them is a design choice. 
    // Usually detailed refresh keeps items but shows spinner. 
    // user wanted "refreshing method" which usually implies reload.
    await loadInitial();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;

    try {
      state = state.copyWith(isLoadingMore: true);
      final nextPage = state.page + 1;
      final response = await _service.getLeaderboard(page: nextPage, limit: _limit);
      
      state = state.copyWith(
        items: [...state.items, ...response.items],
        isLoadingMore: false,
        page: nextPage,
        hasMore: response.pagination.hasNext,
      );
    } catch (e) {
      // For pagination error, we might just want to show a snackbar usually,
      // but here we just stop loading more.
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final leaderboardProvider = StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  ref.keepAlive(); // Persist across tab switches — prevents re-fetch on every navigation
  return LeaderboardNotifier(leaderboardService);
});
