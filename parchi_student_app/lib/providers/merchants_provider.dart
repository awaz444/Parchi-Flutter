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
  final String? selectedCategory;
  final String? selectedSubCategory;

  MerchantListState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
    this.searchQuery,
    this.selectedCategory,
    this.selectedSubCategory,
  });

  MerchantListState copyWith({
    List<StudentMerchantModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
    String? searchQuery,
    String? selectedCategory,
    String? selectedSubCategory,
    // Add flags to explicitly clear nullable fields if needed, 
    // or use a more robust copyWith pattern.
    bool clearSearch = false,
    bool clearCategory = false,
    bool clearSubCategory = false,
  }) {
    return MerchantListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedSubCategory: clearSubCategory ? null : (selectedSubCategory ?? this.selectedSubCategory),
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
        category: state.selectedCategory,
        subCategory: state.selectedSubCategory,
      );

      state = state.copyWith(
        items: response.items,
        isLoading: false,
        page: 1,
        hasMore: response.pagination.hasNext,
      );
    } catch (e) {
      String errorMessage = "Something went wrong. Please try again.";
      final errorStr = e.toString();
      
      if (errorStr.contains('SocketException') || 
          errorStr.contains('Network is unreachable') ||
          errorStr.contains('Failed host lookup')) {
        errorMessage = "No internet connection. Please check your network.";
      } else if (errorStr.contains('TimeoutException')) {
        errorMessage = "Request timed out. Please try again later.";
      } else if (errorStr.contains('404')) {
        errorMessage = "Service not found. Please contact support.";
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    }
  }

  Future<void> refresh() async {
    // Reset and reload (keeping search query and filters)
    state = MerchantListState(
      items: [], 
      isLoading: true, 
      searchQuery: state.searchQuery,
      selectedCategory: state.selectedCategory,
      selectedSubCategory: state.selectedSubCategory,
    );
    await loadInitial();
  }

  Future<void> setSearchQuery(String? query) async {
    if (state.searchQuery == query) return;
    state = state.copyWith(
      searchQuery: query, 
      clearSearch: query == null,
      items: [], 
      isLoading: true
    );
    await loadInitial();
  }

  Future<void> setFilters(String? category, String? subCategory) async {
    if (state.selectedCategory == category && state.selectedSubCategory == subCategory) return;
    state = state.copyWith(
      selectedCategory: category, 
      selectedSubCategory: subCategory, 
      clearCategory: category == null,
      clearSubCategory: subCategory == null,
      items: [], 
      isLoading: true
    );
    await loadInitial();
  }

  Future<void> clearFilters() async {
    if (state.selectedCategory == null && state.selectedSubCategory == null) return;
    state = state.copyWith(
      selectedCategory: null, 
      selectedSubCategory: null,
      clearCategory: true,
      clearSubCategory: true,
      items: [], 
      isLoading: true
    );
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
        category: state.selectedCategory,
        subCategory: state.selectedSubCategory,
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

