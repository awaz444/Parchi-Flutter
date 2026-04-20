import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/merchant_detail_model.dart';
import '../models/student_merchant_model.dart';
import '../services/merchants_service.dart';

// Provider for fetching merchant details by ID
final merchantDetailsProvider = FutureProvider.family<MerchantDetailModel, String>(
  (ref, merchantId) async {
    return merchantsService.getMerchantDetails(merchantId);
  },
);

// State class for Merchant List
class MerchantListState {
  final List<StudentMerchantModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;
  final String? searchQuery;

  MerchantListState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
    this.searchQuery,
  });

  MerchantListState copyWith({
    List<StudentMerchantModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
    String? searchQuery,
  }) {
    return MerchantListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// Notifier to manage the merchant list state
class MerchantListNotifier extends StateNotifier<MerchantListState> {
  final MerchantsService _service;
  final int _limit = 10;

  MerchantListNotifier(this._service) : super(MerchantListState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final now = DateTime.now();
      final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      final response = await _service.getStudentMerchants(
        page: 1,
        limit: _limit,
        month: currentMonth,
        search: state.searchQuery,
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
    // Reset and reload (keeping search query if any)
    state = MerchantListState(
        items: [], isLoading: true, searchQuery: state.searchQuery);
    await loadInitial();
  }

  Future<void> setSearchQuery(String? query) async {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query, items: [], isLoading: true);
    await loadInitial();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;

    try {
      state = state.copyWith(isLoadingMore: true);
      final nextPage = state.page + 1;
      
      final now = DateTime.now();
      final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      final response = await _service.getStudentMerchants(
        page: nextPage,
        limit: _limit,
        month: currentMonth,
        search: state.searchQuery,
      );

      state = state.copyWith(
        items: [...state.items, ...response.items],
        isLoadingMore: false,
        page: nextPage,
        hasMore: response.pagination.hasNext,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
      // Optional: Handle error toast here
    }
  }
}

final studentMerchantsProvider =
    StateNotifierProvider<MerchantListNotifier, MerchantListState>((ref) {
  return MerchantListNotifier(merchantsService);
});

