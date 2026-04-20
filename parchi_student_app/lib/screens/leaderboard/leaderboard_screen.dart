import 'package:flutter/material.dart';
import '../../utils/colours.dart';
import '../../models/leaderboard_model.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import '../../widgets/common/blinking_skeleton.dart';
import '../../widgets/common/parchi_loader.dart';
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
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 200) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    ref.read(leaderboardProvider.notifier).loadMore();
  }

  Future<void> _refresh() async {
    await _startRefreshSequence();
  }

  Future<void> _startRefreshSequence() async {
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ref.read(leaderboardProvider.notifier).refresh(),
        ref.refresh(redemptionStatsProvider.future),
      ]);
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
    super.build(context);
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
            fontFamilyFallback: const ['sans-serif'],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final state = ref.watch(leaderboardProvider);

    final bool showSkeleton = _isRefreshing || (state.isLoading && state.items.isEmpty);
    final bool hasError = state.error != null && state.items.isEmpty && !showSkeleton;
    final bool isEmpty = state.items.isEmpty && !showSkeleton && !hasError;

    final userState = ref.watch(userProfileProvider);
    final user = userState.value;

    bool isUserInList = false;
    if (user != null) {
      isUserInList = state.items.any((item) => _isCurrentUser(item, user));
    }

    return Stack(
      children: [
        if (showSkeleton)
          _buildLeaderboardListSkeleton()
        else if (hasError)
          _buildLeaderboardListSkeleton()
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
                            size: 50,
                            color: AppColors.secondary,
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
              controller: _scrollController,
              padding: EdgeInsets.only(
                  bottom: !isUserInList && user != null ? 100 : 0),
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

        if (!showSkeleton && !hasError && !isUserInList && user != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildStickyUserBar(user),
          ),
      ],
    );
  }

 bool _isCurrentUser(LeaderboardItem item, dynamic user) {
  if (user == null) return false;

  // Convert both to Strings to ensure "String vs UUID" or "int vs String" 
  // comparison doesn't fail silently.
  final String? itemUserId = item.userId?.toString();
  final String? sessionUserId = user.id?.toString();

  if (itemUserId != null && sessionUserId != null) {
    if (itemUserId == sessionUserId) return true;
  }

  // Double-check the Parchi ID as a fallback
  final String? itemParchiId = item.parchiId?.toString();
  final String? sessionParchiId = user.parchiId?.toString();

  if (itemParchiId != null && sessionParchiId != null) {
    if (itemParchiId == sessionParchiId) return true;
  }

  return false;
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

  /// Returns the user's full name, falling back to their parchiId, then "You".
  String _displayName(dynamic user) {
    final first = (user?.firstName ?? '').toString().trim();
    final last = (user?.lastName ?? '').toString().trim();
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    if (user?.parchiId != null) return user.parchiId.toString();
    return 'You';
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
          SizedBox(
            width: 48,
            child: statsAsync.when(
              data: (stats) => Text(
                stats.leaderboardPosition > 0
                    ? "#${stats.leaderboardPosition}"
                    : "-",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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
                  _displayName(user),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: const ParchiLoader(
        isLoading: true,
        progress: 1.0,
        size: 25,
        color: AppColors.secondary,
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
      color: isCurrentUser ? AppColors.primary : AppColors.lightSurface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              "#$rank",
              style: TextStyle(
                color: isCurrentUser ? Colors.white : AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
      itemCount: 15,
      physics: const NeverScrollableScrollPhysics(),
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
          BlinkingSkeleton(
              width: 38,
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