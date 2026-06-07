import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard_model.dart';
import '../services/leaderboard_service.dart';

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
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final LeaderboardService _service;
  final String _period;
  final int _limit = 10;

  LeaderboardNotifier(this._service, {required String period})
      : _period = period,
        super(LeaderboardState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final response = await _service.getLeaderboard(
        page: 1,
        limit: _limit,
        period: _period,
      );
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
    state = LeaderboardState(items: [], isLoading: true);
    await loadInitial();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;

    try {
      state = state.copyWith(isLoadingMore: true);
      final nextPage = state.page + 1;
      final response = await _service.getLeaderboard(
        page: nextPage,
        limit: _limit,
        period: _period,
      );

      state = state.copyWith(
        items: [...state.items, ...response.items],
        isLoadingMore: false,
        page: nextPage,
        hasMore: response.pagination.hasNext,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final leaderboardProvider =
    StateNotifierProvider.family<LeaderboardNotifier, LeaderboardState, String>(
  (ref, period) {
    ref.keepAlive();
    return LeaderboardNotifier(leaderboardService, period: period);
  },
);
