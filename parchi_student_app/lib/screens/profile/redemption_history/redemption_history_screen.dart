import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/colours.dart';
import '../../../models/redemption_model.dart';
import 'redemption_detail_screen.dart';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import '../../../widgets/common/parchi_refresh_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/redemption_provider.dart';
import '../../../providers/user_provider.dart'; // [GUEST] For auth check
import '../../../widgets/common/blinking_skeleton.dart';
import '../../../widgets/common/guest_login_prompt.dart'; // [GUEST]

class RedemptionHistoryScreen extends ConsumerStatefulWidget {
  const RedemptionHistoryScreen({super.key});

  @override
  ConsumerState<RedemptionHistoryScreen> createState() =>
      _RedemptionHistoryScreenState();
}

class _RedemptionHistoryScreenState
    extends ConsumerState<RedemptionHistoryScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final ScrollController _historyScrollController = ScrollController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<double> _expandProgress = ValueNotifier(0.0);

  // Sheet configuration
  final double _minSheetSize = 0.65;
  final double _maxSheetSize = 0.92;

  bool _isRefreshing = false; // [NEW] State control for custom UX

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sheetController.addListener(_onSheetChanged);
    _historyScrollController.addListener(_onHistoryScroll);
  }

  void _onSheetChanged() {
    double currentSize = _sheetController.size;
    double progress =
        (currentSize - _minSheetSize) / (_maxSheetSize - _minSheetSize);
    _expandProgress.value = progress.clamp(0.0, 1.0);
  }

  @override
  bool get wantKeepAlive => true; // Keep alive across tab switches

  Future<void> _refresh() async {
    // Start the refresh sequence immediately — no artificial delay.
    await _startRefreshSequence();
  }

  void _onHistoryScroll() {
    if (!_historyScrollController.hasClients) return;
    if (_historyScrollController.position.extentAfter > 200) return;

    final historyState = ref.read(redemptionHistoryProvider);
    if (!historyState.hasMore || historyState.isLoadingMore) return;
    ref.read(redemptionHistoryProvider.notifier).loadMore();
  }

  Future<void> _startRefreshSequence() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
      await Future.wait([
        ref.refresh(redemptionStatsProvider.future),
        ref.read(redemptionHistoryProvider.notifier).refresh(),
        ref.refresh(userProfileProvider.future),
      ]);
    } catch (e) {
      debugPrint("Redemption refresh error: $e");
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _historyScrollController.removeListener(_onHistoryScroll);
    _historyScrollController.dispose();
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    // [GUEST] Show login prompt if user is not authenticated
    final userAsync = ref.watch(userProfileProvider);
    final bool isGuest = userAsync.maybeWhen(
      data: (user) => user == null,
      orElse: () => false,
    );

    if (isGuest) {
      return const GuestLoginPrompt(
        title: 'Sign in to view your history',
        subtitle:
            'Your redemption history and savings stats are only available to signed-in students.',
        icon: Icons.history_rounded,
      );
    }

    // Watch providers
    final statsAsync = ref.watch(redemptionStatsProvider);
    final historyState = ref.watch(redemptionHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Redemption History',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontFamily: 'Hagrid',
              fontSize: 16,
            )),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: NestedScrollView(
        // clipBehavior prevents the white rounded corner from "bleeding" past
        // the primary scroll area on Android during overscroll.
        clipBehavior: Clip.antiAlias,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // 1. STATS HEADER (Primary Background) - Now in Sliver
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                child: statsAsync.when(
                  data: (stats) => Column(
                    children: [
                      const Text(
                        "TOTAL REDEMPTIONS",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${stats.totalRedemptions}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildHeaderStat(
                              "Rewards", "${stats.bonusesUnlocked}"),
                          Container(
                              width: 1, height: 24, color: Colors.white24),
                          _buildHeaderStat(
                              "Rank",
                              stats.leaderboardPosition > 0
                                  ? "#${stats.leaderboardPosition}"
                                  : "-"),
                        ],
                      ),
                    ],
                  ),
                  loading: () => _buildHeaderSkeleton(),
                  error: (_, __) => _buildHeaderSkeleton(), // Skeleton on error
                ),
              ),
            ),
          ];
        },
        // 2. LIST BODY (White Surface)
        body: Container(
          decoration: const BoxDecoration(
            color: AppColors.lightCanvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Builder(builder: (_) {
            if (historyState.isLoading || _isRefreshing) {
              return _buildListSkeleton();
            }
            if (historyState.error != null && historyState.items.isEmpty) {
              return _buildListSkeleton();
            }
            if (historyState.items.isEmpty) return _buildEmptyState();

            final items = historyState.items;
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              child: CustomRefreshIndicator(
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
                  controller: _historyScrollController,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  // +1 for the load-more footer
                  itemCount: items.length + (historyState.hasMore ? 1 : 0),
                  separatorBuilder: (context, index) => const Divider(
                      height: 1, color: AppColors.surfaceVariant),
                  itemBuilder: (context, index) {
                    // Load-more trigger at the bottom
                    if (index == items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.secondary,
                          ),
                        ),
                      );
                    }
                    return _buildRedemptionNotificationItem(items[index]);
                  },
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // --- Header Helpers ---
  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- List Item (Notification Style) ---
  Widget _buildRedemptionNotificationItem(RedemptionModel item) {
    // Data extraction
    final merchantName = item.merchant?.businessName ??
        item.offer?.merchant?.businessName ??
        "Parchi Merchant";
    final branchName = item.branchName ?? "Unknown Branch";
    final logoUrl = item.merchant?.logoPath ??
        item.offer?.merchant?.logoPath ??
        item.offer?.imageUrl;
    final timeStr = DateFormat('MMM d').format(item.redeemedAt.toLocal()); // e.g. Oct 24

    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
              // Pass only the ID — detail screen fetches the full data
              builder: (_) => RedemptionDetailScreen(redemptionId: item.id),
            ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Circle Avatar (Logo)
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
                image: logoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(logoUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: logoUrl == null
                  ? Icon(Icons.store, color: AppColors.textSecondary, size: 24)
                  : null,
            ),
            const SizedBox(width: 16),

            // 2. Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant Name
                  Text(
                    merchantName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Branch Name
                  Text(
                    branchName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Trailing Info (Time & Status)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                // Bonus Indicator (Only show if bonus is applied)
                if (item.isBonusApplied)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bonus, // Solid orange background
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "BONUS",
                      style: TextStyle(
                          color: Colors.white, // White text
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history,
              size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text("No redemption history yet",
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // --- SKELETON HELPERS ---
  Widget _buildHeaderSkeleton() {
    return Column(
      children: [
        BlinkingSkeleton(width: 120, height: 12, baseColor: Colors.white24),
        const SizedBox(height: 8),
        BlinkingSkeleton(width: 80, height: 48, baseColor: Colors.white24),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatSkeleton(),
            Container(width: 1, height: 24, color: Colors.white24),
            _buildStatSkeleton(),
          ],
        )
      ],
    );
  }

  Widget _buildStatSkeleton() {
    return Column(
      children: [
        BlinkingSkeleton(width: 30, height: 20, baseColor: Colors.white24),
        const SizedBox(height: 4),
        BlinkingSkeleton(width: 50, height: 10, baseColor: Colors.white24),
      ],
    );
  }

  Widget _buildListSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (c, i) =>
          const Divider(height: 1, color: AppColors.surfaceVariant),
      itemBuilder: (c, i) => _buildListItemSkeleton(),
    );
  }

  Widget _buildListItemSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlinkingSkeleton(
              width: 50,
              height: 50,
              borderRadius: 25,
              baseColor: Colors.black.withOpacity(0.05)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlinkingSkeleton(
                    width: 150,
                    height: 16,
                    baseColor: Colors.black.withOpacity(0.05)),
                const SizedBox(height: 10),
                BlinkingSkeleton(
                    width: 100,
                    height: 14,
                    baseColor: Colors.black.withOpacity(0.05)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BlinkingSkeleton(
                  width: 40,
                  height: 12,
                  baseColor: Colors.black.withOpacity(0.05)),
            ],
          )
        ],
      ),
    );
  }
}
