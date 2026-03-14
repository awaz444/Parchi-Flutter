import 'package:flutter/material.dart';
import '../../utils/colours.dart';
import '../../services/leaderboard_service.dart';
import '../../models/leaderboard_model.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'dart:math' as math;
import '../../widgets/common/blinking_skeleton.dart';
import '../../widgets/common/parchi_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/redemption_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Data loading is handled by the provider's constructor init
  }

  Future<void> _loadMore() async {
    ref.read(leaderboardProvider.notifier).loadMore();
  }

  Future<void> _refresh() async {
    // 1. Force spinner for 1 second
    await Future.delayed(const Duration(seconds: 1));
    // 2. Start sequence (fire and forget from perspective of RefreshIndicator)
    _startRefreshSequence();
  }

  Future<void> _startRefreshSequence() async {
    setState(() => _isRefreshing = true);
    try {
      await ref.read(leaderboardProvider.notifier).refresh();
    } catch (e) {
      debugPrint("Leaderboard refresh error: $e");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppColors.lightCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.lightCanvas,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Leaderboard",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFamily: 'Hagrid',
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final state = ref.watch(leaderboardProvider);

    // 1. Get Loading State & Items
    // 1. Get Loading State & Items
    final bool showSkeleton = _isRefreshing || (state.isLoading && state.items.isEmpty);
    final bool hasError = state.error != null && state.items.isEmpty && !showSkeleton;
    final bool isEmpty = state.items.isEmpty && !showSkeleton && !hasError;

    // 2. Determine Current User Info
    final userState = ref.watch(userProfileProvider);
    final user = userState.value;

    // 3. Check if user is in the list
    bool isUserInList = false;
    if (user != null) {
      isUserInList = state.items.any((item) {
        // Match by ID, Parchi ID, or Name fallback
        if (item.userId != null && item.userId == user.id) return true;
        if (item.parchiId != null && item.parchiId == user.parchiId)
          return true;
        // Basic name fallback if IDs missing
        if (user.firstName != null && item.name.contains(user.firstName!))
          return true;
        return false;
      });
    }

    return Stack(
      children: [
        // --- MAIN LIST CONTENT ---
        if (showSkeleton)
          _buildLeaderboardListSkeleton()
        else if (hasError)
          _buildLeaderboardListSkeleton() // Skeleton on error
        else if (isEmpty)
          _buildEmptyView()
        else
          CustomRefreshIndicator(
            onRefresh: _refresh,
            offsetToArmed: 100.0,
            builder: (BuildContext context, Widget child,
                IndicatorController controller) {
              return Stack(
                children: <Widget>[
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      return SizedBox(
                        height: controller.value * 100.0,
                        width: double.infinity,
                        child: Center(
                          child: ParchiLoader(
                            isLoading: controller.isLoading,
                            progress: controller.value,
                          ),
                        ),
                      );
                    },
                  ),
                  Transform.translate(
                    offset: Offset(0.0, controller.value * 100.0),
                    child: child,
                  ),
                ],
              );
            },
            child: ListView.separated(
              padding: EdgeInsets.only(
                  bottom: !isUserInList && user != null
                      ? 100
                      : 0), // Pad for sticky bar
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (context, index) {
                if (index < state.items.length - 1 ||
                    (index == state.items.length - 1 && !state.hasMore)) {
                  return const Divider(
                    height: 1,
                    thickness: 1.0,
                    color: AppColors.surfaceVariant,
                  );
                }
                return const SizedBox.shrink();
              },
              itemBuilder: (context, index) {
                if (index == state.items.length) {
                  return _buildLoadMoreIndicator();
                }

                final item = state.items[index];
                final isCurrentUser = _isCurrentUser(item, user);

                return _buildLeaderboardItem(
                  rank: item.rank,
                  name: item.name,
                  university: item.university,
                  redemptions: item.redemptions,
                  isCurrentUser: isCurrentUser,
                );
              },
            ),
          ),

        // --- STICKY BOTTOM BAR (If user not in list) ---
        if (!showSkeleton && !hasError && !isUserInList && user != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24, // Floating above bottom
            child: _buildStickyUserBar(user),
          ),
      ],
    );
  }

  bool _isCurrentUser(LeaderboardItem item, dynamic user) {
    if (user == null) return false;
    if (item.userId != null && item.userId == user.id) return true;
    if (item.parchiId != null && item.parchiId == user.parchiId) return true;
    if (user.firstName != null && item.name.contains(user.firstName!))
      return true;
    return false;
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            error,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.leaderboard_outlined,
              size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'No leaderboard data available',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyUserBar(dynamic user) {
    final statsAsync = ref.watch(redemptionStatsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Rank Placeholder
          SizedBox(
            width: 40,
            child: statsAsync.when(
              data: (stats) => Text(
                stats.leaderboardPosition > 0
                    ? "#${stats.leaderboardPosition}"
                    : "-",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              loading: () => BlinkingSkeleton(
                  width: 30,
                  height: 20,
                  baseColor: Colors.white.withOpacity(0.3)),
              error: (_, __) =>
                  const Text("-", style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "You",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.university ?? "Your University",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              statsAsync.when(
                data: (stats) => Text(
                  "${stats.totalRedemptions}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                loading: () => BlinkingSkeleton(
                    width: 30,
                    height: 20,
                    baseColor: Colors.white.withOpacity(0.3)),
                error: (_, __) =>
                    const Text("-", style: TextStyle(color: Colors.white)),
              ),
              const Text(
                "Parchiyan",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    final state = ref.watch(leaderboardProvider);
    if (!state.hasMore) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: state.isLoadingMore
          ? const CircularProgressIndicator()
          : GestureDetector(
              onTap: _loadMore,
              child: const Text(
                'Load More',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }

  Widget _buildLeaderboardItem({
    required int rank,
    required String name,
    required String university,
    required int redemptions,
    required bool isCurrentUser,
  }) {
    return Container(
      color: isCurrentUser ? AppColors.primary : AppColors.lightSurface, // Highlight BG vs Surface tile
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Rank
          SizedBox(
            width: 40,
            child: Text(
              "#$rank",
              style: TextStyle(
                color: isCurrentUser ? Colors.white : AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name & University
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  university,
                  style: TextStyle(
                    color: isCurrentUser
                        ? Colors.white70
                        : AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Total Redemptions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$redemptions",
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Parchiyan",
                style: TextStyle(
                  color:
                      isCurrentUser ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardListSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: 15, // Show plenty of items
      physics:
          const NeverScrollableScrollPhysics(), // Or allow scrolling? Usually static for skeleton
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1.0,
        color: AppColors.surfaceVariant,
      ),
      itemBuilder: (context, index) => _buildLeaderboardItemSkeleton(),
    );
  }

  Widget _buildLeaderboardItemSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Rank
          BlinkingSkeleton(
              width: 30,
              height: 20,
              baseColor: AppColors.primary.withOpacity(0.1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlinkingSkeleton(
                    width: 120,
                    height: 16,
                    baseColor: AppColors.textPrimary.withOpacity(0.1)),
                const SizedBox(height: 6),
                BlinkingSkeleton(
                    width: 80,
                    height: 14,
                    baseColor: AppColors.textSecondary.withOpacity(0.1)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BlinkingSkeleton(
                  width: 30,
                  height: 20,
                  baseColor: AppColors.primary.withOpacity(0.1)),
              const SizedBox(height: 4),
              BlinkingSkeleton(
                  width: 50,
                  height: 10,
                  baseColor: AppColors.textSecondary.withOpacity(0.1)),
            ],
          )
        ],
      ),
    );
  }
}


