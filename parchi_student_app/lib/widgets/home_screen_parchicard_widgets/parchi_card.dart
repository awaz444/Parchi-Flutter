import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import '../../utils/colours.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/redemption_provider.dart';
import '../../models/redemption_model.dart';
import '../common/blinking_skeleton.dart';
import '../../screens/auth/login_screens/login_screen.dart';

// =========================================================
// 1. ENTRY POINT
// =========================================================
class ParchiCard extends ConsumerStatefulWidget {
  final String studentName;
  final String studentId;
  final String universityName;
  final bool isGolden;
  final bool isFoundersClub;
  final bool isLoading;
  final bool isGuest;

  const ParchiCard({
    super.key,
    this.studentName = "",
    this.studentId = "",
    this.universityName = "",
    this.isGolden = false,
    this.isFoundersClub = false,
    this.isLoading = false,
    this.isGuest = false,
  });

  @override
  ConsumerState<ParchiCard> createState() => _ParchiCardState();
}

class _ParchiCardState extends ConsumerState<ParchiCard>
    with TickerProviderStateMixin {
  // ── Flip ──────────────────────────────────────────────────────────────
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  // ── Expand (lift toward center + backdrop) ────────────────────────────
  late AnimationController _expandController;
  late Animation<double> _expandAnim; // 0 → 1
  bool _isExpanded = false;

  // Overlay entry for the full-screen scrim + tap-dismiss layer.
  // Using Overlay means the backdrop covers ALL sibling widgets on screen,
  // not just the card's own bounding box.
  OverlayEntry? _backdropEntry;

  // GlobalKey so we can RenderBox-measure the card's position
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );

    if (!widget.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(redemptionStatsProvider);
      });
    }
  }

  @override
  void dispose() {
    _removeBackdrop();
    _flipController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  // ── Overlay helpers ───────────────────────────────────────────────────

  void _insertBackdrop() {
    _backdropEntry = OverlayEntry(builder: (_) {
      return AnimatedBuilder(
        animation: _expandAnim,
        builder: (_, __) => GestureDetector(
          onTap: _collapse,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.black.withOpacity(0.45 * _expandAnim.value),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_backdropEntry!);
  }

  void _removeBackdrop() {
    _backdropEntry?.remove();
    _backdropEntry = null;
  }

  // ── Y-offset computation ──────────────────────────────────────────────
  // Shifts the card so its centre lands at 45 % from the top of the screen
  // (slightly above true centre — feels elevated without looking like a dialog).
  double _targetYOffset() {
    final RenderBox? box =
        _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;

    final screenH = MediaQuery.of(context).size.height;
    final cardH = box.size.height;
    final cardTopGlobal = box.localToGlobal(Offset.zero).dy;
    final cardCenterY = cardTopGlobal + cardH / 2;
    final targetCenter = screenH * 0.45;

    return targetCenter - cardCenterY;
  }

  // ── Expand / collapse ─────────────────────────────────────────────────

  void _expand() {
    if (_isExpanded) return;
    setState(() => _isExpanded = true);
    _insertBackdrop();
    _expandController.forward();

    // Kick off the flip ~130 ms into the expand so they feel coupled
    Future.delayed(const Duration(milliseconds: 130), () {
      if (mounted) _doFlip();
    });
  }

  void _collapse() {
    if (!_isExpanded) return;
    // If back face is showing, flip to front first then drop
    if (!_isFront) {
      _doFlip();
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _collapseExpand();
      });
    } else {
      _collapseExpand();
    }
  }

  void _collapseExpand() {
    _expandController.reverse().then((_) {
      if (mounted) {
        _removeBackdrop();
        setState(() => _isExpanded = false);
      }
    });
  }

  void _doFlip() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) return _buildGuestCard();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: AnimatedBuilder(
        animation: _expandAnim,
        builder: (context, _) {
          final yOffset = _targetYOffset() * _expandAnim.value;
          final scale = 1.0 + (_expandAnim.value * 0.02);

          return Transform.translate(
            offset: Offset(0, yOffset),
            child: Transform.scale(
              scale: scale,
              child: GestureDetector(
                // When expanded: tap card = flip only (backdrop tap = collapse)
                // When collapsed: tap card = expand + flip
                onTap: _isExpanded ? _doFlip : _expand,
                child: _buildFlippingCard(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlippingCard() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, _) {
        final angle = _flipAnimation.value * pi;
        final flipTransform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle);

        return Transform(
          key: _cardKey,
          transform: flipTransform,
          alignment: Alignment.center,
          child: angle < pi / 2
              ? _buildFrontFace()
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _buildBackFace(),
                ),
        );
      },
    );
  }

  Widget _buildGuestCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.isFoundersClub
                ? AppColors.foundersClub
                : AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const _GuestCardContent(),
        ),
      ),
    );
  }

  Widget _buildFrontFace() {
    final goldGradient = const LinearGradient(
      colors: [AppColors.goldStart, AppColors.goldMid, AppColors.goldEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.1, 0.5, 0.9],
    );

    final Color? cardColor = widget.isFoundersClub
        ? AppColors.foundersClub
        : (widget.isGolden ? null : AppColors.primary);

    final Gradient? cardGradient =
        widget.isFoundersClub ? null : (widget.isGolden ? goldGradient : null);

    final List<BoxShadow>? shadow = widget.isGolden
        ? [
            BoxShadow(
              color: AppColors.goldShadow
                  .withOpacity(0.6 + 0.3 * _expandAnim.value),
              blurRadius: 20 + 20 * _expandAnim.value,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ]
        : _isExpanded
            ? [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.15 + 0.25 * _expandAnim.value),
                  blurRadius: 8 + 32 * _expandAnim.value,
                  spreadRadius: 0,
                  offset: Offset(0, 4 + 12 * _expandAnim.value),
                ),
              ]
            : null;

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadow,
      ),
      child: CardFrontContent(
        studentName: widget.studentName,
        studentId: widget.studentId,
        universityName: widget.universityName,
        isGolden: widget.isGolden,
        isFoundersClub: widget.isFoundersClub,
        isLoading: widget.isLoading,
      ),
    );
  }

  Widget _buildBackFace() {
    final goldGradient = const LinearGradient(
      colors: [AppColors.goldStart, AppColors.goldMid],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final Color? cardColor = widget.isFoundersClub
        ? AppColors.foundersClub
        : (widget.isGolden ? null : AppColors.primary);

    final Gradient? cardGradient =
        widget.isFoundersClub ? null : (widget.isGolden ? goldGradient : null);

    final Color borderColor = widget.isFoundersClub
        ? Colors.white.withOpacity(0.5)
        : (widget.isGolden
            ? AppColors.goldShadow
            : AppColors.primary.withOpacity(0.5));

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.15 + 0.25 * _expandAnim.value),
                  blurRadius: 8 + 32 * _expandAnim.value,
                  spreadRadius: 0,
                  offset: Offset(0, 4 + 12 * _expandAnim.value),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildBackContent(),
      ),
    );
  }

  Widget _buildBackContent() {
    final statsAsync = ref.watch(redemptionStatsProvider);

    if (statsAsync.hasValue) {
      return _buildStatsContent(statsAsync.value!);
    } else if (statsAsync.isLoading) {
      return _buildLoadingStats();
    } else if (statsAsync.hasError) {
      return Center(
          child: Text("Error loading stats",
              style: TextStyle(color: AppColors.error, fontSize: 12)));
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildStatsContent(RedemptionStats stats) {
    final dividerColor = widget.isGolden
        ? AppColors.textPrimary.withOpacity(0.1)
        : Colors.white.withOpacity(0.2);

    return Center(
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildSingleStat(
                value: "${stats.totalRedemptions}",
                label: "Visits",
                subLabel: "Lifetime"),
            VerticalDivider(
                color: dividerColor, indent: 10, endIndent: 10, width: 1),
            _buildSingleStat(
                value: "${stats.bonusesUnlocked}",
                label: "Rewards",
                subLabel: "Earned"),
            VerticalDivider(
                color: dividerColor, indent: 10, endIndent: 10, width: 1),
            _buildSingleStat(
                value: stats.leaderboardPosition > 0
                    ? "#${stats.leaderboardPosition}"
                    : "-",
                label: "Rank",
                subLabel: "Nationwide"),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleStat({
    required String value,
    required String label,
    required String subLabel,
  }) {
    final valueColor = widget.isGolden ? AppColors.textPrimary : Colors.white;
    final labelColor =
        widget.isGolden ? AppColors.primary : const Color(0xFFE3E935);
    final subLabelColor = widget.isGolden
        ? AppColors.textPrimary.withOpacity(0.5)
        : Colors.white.withOpacity(0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.0)),
        const SizedBox(height: 6),
        Text(label.toUpperCase(),
            style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text(subLabel,
            style: TextStyle(
                color: subLabelColor,
                fontSize: 9,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLoadingStats() {
    final dividerColor = widget.isGolden
        ? AppColors.textPrimary.withOpacity(0.1)
        : Colors.white.withOpacity(0.2);
    final skeletonBaseColor = widget.isGolden
        ? Colors.black.withOpacity(0.1)
        : Colors.white.withOpacity(0.3);

    return Center(
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildSkeletonColumn(skeletonBaseColor),
            VerticalDivider(
                color: dividerColor, indent: 10, endIndent: 10, width: 1),
            _buildSkeletonColumn(skeletonBaseColor),
            VerticalDivider(
                color: dividerColor, indent: 10, endIndent: 10, width: 1),
            _buildSkeletonColumn(skeletonBaseColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonColumn(Color baseColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlinkingSkeleton(width: 40, height: 28, baseColor: baseColor),
        const SizedBox(height: 6),
        BlinkingSkeleton(width: 50, height: 10, baseColor: baseColor),
        const SizedBox(height: 2),
        BlinkingSkeleton(width: 30, height: 9, baseColor: baseColor),
      ],
    );
  }
}

// =========================================================
// 1b. GUEST CARD CONTENT
// =========================================================
class _GuestCardContent extends StatelessWidget {
  const _GuestCardContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.credit_card_rounded, color: Colors.white70, size: 36),
          SizedBox(height: 10),
          Text(
            'Sign in to get your Parchi card',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Tap to create a free account',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// 3. UI HELPER (Front Face Content)
// =========================================================
class CardFrontContent extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String universityName;
  final bool isGolden;
  final bool isFoundersClub;
  final bool isLoading;

  const CardFrontContent({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.universityName,
    required this.isGolden,
    this.isFoundersClub = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.87)
        : AppColors.textOnPrimary;
    final secondaryTextColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.54)
        : AppColors.textOnPrimary.withOpacity(0.7);
    final iconColor = isGolden
        ? AppColors.textOnPrimary.withOpacity(0.3)
        : AppColors.surface.withOpacity(0.05);

    return Stack(
      children: [
        Positioned(
          right: -90,
          top: -80,
          child: isGolden
              ? Icon(Icons.emoji_events, size: 150, color: iconColor)
              : Transform.flip(
                  flipX: true,
                  child: SvgPicture.asset(
                    'assets/parchi-icon.svg',
                    height: 300,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withOpacity(0.1),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SvgPicture.asset(
                    'assets/ParchiFullTextYellow.svg',
                    height: 30,
                    colorFilter: const ColorFilter.mode(
                        Color(0xFFE3E935), BlendMode.srcIn),
                  ),
                  if (isFoundersClub)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "FOUNDER'S CLUB",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isLoading
                            ? BlinkingSkeleton(
                                width: 150,
                                height: 24,
                                baseColor: Colors.white.withOpacity(0.3))
                            : Text(
                                studentName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.1),
                              ),
                        const SizedBox(height: 2),
                        isLoading
                            ? BlinkingSkeleton(
                                width: 100,
                                height: 10,
                                baseColor: Colors.white.withOpacity(0.3))
                            : Text(
                                universityName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1),
                              ),
                      ],
                    ),
                  ),
                  isLoading
                      ? BlinkingSkeleton(
                          width: 80,
                          height: 24,
                          baseColor: Colors.white.withOpacity(0.3))
                      : Text(
                          studentId,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0),
                        ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================
// 4. COMPACT HEADER (Sticky) — unchanged from original
// =========================================================
class CompactParchiHeader extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String universityName;
  final bool isGolden;
  final String? profilePicture;
  final String studentInitials;
  final VoidCallback onProfileTap;
  final ValueChanged<String>? onSearchChanged;
  final double scrollProgress;
  final VoidCallback onNotificationTap;
  final bool isLoading;
  final bool hasUnreadNotifications;

  // Search
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool isSearching;
  final VoidCallback onCancelSearch;

  const CompactParchiHeader({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.universityName,
    this.isGolden = false,
    required this.scrollProgress,
    required this.onNotificationTap,
    this.profilePicture,
    required this.studentInitials,
    required this.onProfileTap,
    this.onSearchChanged,
    this.isLoading = false,
    this.hasUnreadNotifications = false,
    required this.searchController,
    required this.searchFocus,
    required this.isSearching,
    required this.onCancelSearch,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.87)
        : AppColors.textOnPrimary;
    final secondaryTextColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.54)
        : AppColors.textOnPrimary.withOpacity(0.7);

    final backgroundColor = Color.lerp(
      Colors.transparent,
      isGolden ? AppColors.goldStart : AppColors.primary,
      scrollProgress,
    );

    final iconColor = isGolden
        ? AppColors.textOnPrimary.withOpacity(0.3)
        : AppColors.surface.withOpacity(0.05);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        gradient: (isGolden && scrollProgress > 0.5)
            ? LinearGradient(
                colors: [
                  AppColors.goldStart.withOpacity(scrollProgress),
                  AppColors.goldMid.withOpacity(scrollProgress),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        boxShadow: scrollProgress > 0.1
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1 * scrollProgress),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          if (scrollProgress > 0.1)
            Positioned(
              right: -110,
              top: -90,
              child: Opacity(
                opacity: scrollProgress.clamp(0.0, 1.0),
                child: isGolden
                    ? Icon(Icons.emoji_events, size: 150, color: iconColor)
                    : Transform.flip(
                        flipX: true,
                        child: SvgPicture.asset(
                          'assets/parchi-icon.svg',
                          height: 400,
                          colorFilter: ColorFilter.mode(
                            Colors.white.withOpacity(0.1),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      // Toggle between Profile and Cancel Search
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: isSearching
                            ? GestureDetector(
                                key: const ValueKey('cancel_btn'),
                                onTap: onCancelSearch,
                                child: Container(
                                  width: 35,
                                  height: 35,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(
                                        scrollProgress > 0.5 ? 0.2 : 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: scrollProgress > 0.5
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : isLoading
                                ? Padding(
                                    key: const ValueKey('skeleton_btn'),
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: BlinkingSkeleton(
                                      width: 35,
                                      height: 35,
                                      borderRadius: 17.5,
                                      baseColor: AppColors.lightSurface,
                                    ),
                                  )
                                : GestureDetector(
                                    key: const ValueKey('profile_btn'),
                                    onTap: onProfileTap,
                                    child: Container(
                                      width: 35,
                                      height: 35,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: const BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: profilePicture != null
                                            ? CachedNetworkImage(
                                                imageUrl: profilePicture!,
                                                fit: BoxFit.cover,
                                                errorWidget: (context, url,
                                                        error) =>
                                                    Center(
                                                      child: Text(
                                                        studentInitials,
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .textSecondary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                              )
                                            : Center(
                                                child: Text(
                                                  studentInitials,
                                                  style: const TextStyle(
                                                    color: AppColors
                                                        .textSecondary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                      ),
                      Expanded(
                        child: Container(
                          height: 35,
                          decoration: BoxDecoration(
                            color: scrollProgress > 0.5
                                ? Colors.white.withOpacity(0.2)
                                : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: searchController,
                            focusNode: searchFocus,
                            onChanged: onSearchChanged,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: "Search restaurants...",
                              hintStyle: TextStyle(
                                  color: scrollProgress > 0.5
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                  fontSize: 13),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  Icons.search,
                                  color: scrollProgress > 0.5
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                              prefixIconConstraints:
                                  const BoxConstraints(minWidth: 35),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(bottom: 18),
                            ),
                          ),
                        ),
                      ),
                      
                      // Notification bell — hidden when searching
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: isSearching
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 35,
                                      height: 35,
                                      decoration: BoxDecoration(
                                        color: scrollProgress > 0.5
                                            ? Colors.white.withOpacity(0.2)
                                            : AppColors.lightSurface,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          Icons.notifications_none,
                                          size: 20,
                                          color: scrollProgress > 0.5
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                        onPressed: onNotificationTap,
                                      ),
                                    ),
                                    if (hasUnreadNotifications)
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: scrollProgress > 0.5
                                                ? Colors.white
                                                : AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: scrollProgress > 0.5
                                                  ? AppColors.primary
                                                  : Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: scrollProgress,
                    child: Opacity(
                      opacity: scrollProgress,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 180,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 5),
                                        isLoading
                                            ? BlinkingSkeleton(
                                                width: 120,
                                                height: 16,
                                                baseColor: Colors.white
                                                    .withOpacity(0.3))
                                            : Text(
                                                studentName,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                        const SizedBox(height: 1),
                                        isLoading
                                            ? Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        top: 4.0),
                                                child: BlinkingSkeleton(
                                                  width: 80,
                                                  height: 10,
                                                  baseColor: Colors.white
                                                      .withOpacity(0.3),
                                                ),
                                              )
                                            : Text(
                                                universityName.toUpperCase(),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: secondaryTextColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ],
                                    ),
                                  ),
                                  isLoading
                                      ? BlinkingSkeleton(
                                          width: 60,
                                          height: 20,
                                          baseColor:
                                              Colors.white.withOpacity(0.3))
                                      : Text(
                                          studentId,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}