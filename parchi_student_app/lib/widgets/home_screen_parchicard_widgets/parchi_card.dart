import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../utils/colours.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/redemption_provider.dart';
import '../../models/redemption_model.dart';
import '../common/blinking_skeleton.dart';

// =========================================================
// 1. ENTRY POINT
// =========================================================
class ParchiCard extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String universityName;
  final bool isGolden; // Gold Mode Flag
  final bool isFoundersClub; // [NEW] Founders Club Flag
  final bool isLoading;

  const ParchiCard({
    super.key,
    this.studentName = "",
    this.studentId = "",
    this.universityName = "",
    this.isGolden = false,
    this.isFoundersClub = false, // [NEW]
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Define Gradients
    final standardGradient = const LinearGradient(
      colors: [AppColors.backgroundDark, AppColors.primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final goldGradient = const LinearGradient(
      colors: [
        AppColors.goldStart, // Goldenrod
        AppColors.goldMid, // Gold
        AppColors.goldEnd, // Dark Goldenrod
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.1, 0.5, 0.9],
    );

    // [NEW] Founders Club Color (Solid or Gradient if desired, keeping it simple solid based on request)
    // Request says: make the bg #FF6A39
    final Color? cardColor = isFoundersClub 
        ? AppColors.foundersClub 
        : (isGolden ? null : AppColors.primary);
    
    final Gradient? cardGradient = isFoundersClub 
        ? null // Solid color for Founders Club
        : (isGolden ? goldGradient : null); // Primary uses user defined color but code above uses null+primary color fallbacks, wait standardGradient is defined but not used?
        // Original code: color: isGolden ? null : AppColors.primary, gradient: isGolden ? goldGradient : null
        
    // Let's stick to the requested logic:
    // If Founders -> #FF6A39
    // If Golden -> Gold Gradient
    // Else -> AppColors.primary

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(PageRouteBuilder(
            opaque: false,
            barrierDismissible: true,
            barrierColor: AppColors.textPrimary.withOpacity(0.87),
            transitionDuration: const Duration(milliseconds: 600),
            reverseTransitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (context, animation, secondaryAnimation) {
              return FadeTransition(
                opacity: animation,
                child: ParchiCardDetail(
                  studentName: studentName,
                  studentId: studentId,
                  universityName: universityName,
                  isGolden: isGolden,
                  isFoundersClub: isFoundersClub, // [NEW] Pass deep
                ),
              );
            },
          ));
        },
        child: Hero(
          tag: isGolden ? 'gold-parchi-card' : 'parchi-card-hero',
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor, 
                gradient: cardGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isGolden
                    ? [
                        BoxShadow(
                          color: AppColors.goldShadow.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: CardFrontContent(
                studentName: studentName,
                studentId: studentId,
                universityName: universityName,
                isGolden: isGolden,
                isFoundersClub: isFoundersClub, // [NEW]
                isLoading: isLoading,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// 2. DETAIL VIEW
// =========================================================
class ParchiCardDetail extends ConsumerStatefulWidget {
  final String studentName;
  final String studentId;
  final String universityName;
  final bool isGolden;
  final bool isFoundersClub; // [NEW]

  const ParchiCardDetail({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.universityName,
    this.isGolden = false,
    this.isFoundersClub = false, // [NEW]
  });

  @override
  ConsumerState<ParchiCardDetail> createState() => _ParchiCardDetailState();
}

// enum BackFaceView removed as we only show current month

class _ParchiCardDetailState extends ConsumerState<ParchiCardDetail>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    // Refresh stats when card is opened (Silent Refresh)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(redemptionStatsProvider);
    });

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutBack,
    ));

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _hoverAnimation =
        Tween<double>(begin: -5, end: 5).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOutSine,
    ));
  }

  void _flipCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  // Swipe handler removed

  Future<void> _handleClose() async {
    if (!_isFront) {
      _flipCard();
      await Future.delayed(const Duration(milliseconds: 600));
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleClose,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: _flipCard,
            child: AnimatedBuilder(
              animation: Listenable.merge([_flipAnimation, _hoverAnimation]),
              builder: (context, child) {
                final angle = _flipAnimation.value * pi;
                final flipTransform = Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle);

                return Transform.translate(
                  offset: Offset(0, _hoverAnimation.value),
                  child: Transform(
                    transform: flipTransform,
                    alignment: Alignment.center,
                    child: Hero(
                      tag: widget.isGolden
                          ? 'gold-parchi-card'
                          : 'parchi-card-hero',
                      child: Material(
                        color: Colors.transparent,
                        child: angle < pi / 2
                            ? _buildFrontFace()
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(pi),
                                child: _buildBackFace(),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrontFace() {
    final standardGradient = const LinearGradient(
      colors: [AppColors.backgroundDark, AppColors.primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final goldGradient = const LinearGradient(
      colors: [AppColors.goldStart, AppColors.goldMid, AppColors.goldEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // [NEW] Founders Club styling
    final Color? cardColor = widget.isFoundersClub
        ? AppColors.foundersClub
        : (widget.isGolden ? null : AppColors.primary);

    final Gradient? cardGradient = widget.isFoundersClub
        ? null
        : (widget.isGolden ? goldGradient : null);

    return Container(
      height: 200,
      width: MediaQuery.of(context).size.width - 32, // Match horizontal padding of 16 * 2
      decoration: BoxDecoration(
        color: cardColor,
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        // Glow removed
      ),
      child: CardFrontContent(
        studentName: widget.studentName,
        studentId: widget.studentId,
        universityName: widget.universityName,
        isGolden: widget.isGolden,
        isFoundersClub: widget.isFoundersClub, // [NEW]
      ),
    );
  }

  Widget _buildBackFace() {
    // [NEW] Founders Club styling
    final Color? cardColor = widget.isFoundersClub
        ? AppColors.foundersClub
        : (widget.isGolden ? null : AppColors.primary);

    final Gradient? cardGradient = widget.isFoundersClub
        ? null
        : (widget.isGolden
            ? const LinearGradient(
                colors: [AppColors.goldStart, AppColors.goldMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null);

    final Color borderColor = widget.isFoundersClub
        ? Colors.white.withOpacity(0.5) // Or similar contrast
        : (widget.isGolden
            ? AppColors.goldShadow
            : AppColors.primary.withOpacity(0.5));

    return Container(
      height: 200,
      width: MediaQuery.of(context).size.width - 32, // Match horizontal padding of 16 * 2
      decoration: BoxDecoration(
        color: cardColor, // Primary BG
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: borderColor,
            width: 1),
        // Glow removed
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildBackContent(),
        ),
      ),
    );
  }

  Widget _buildBackContent() {
    return _buildCurrentMonthStats();
  }

  Widget _buildCurrentMonthStats() {
    final statsAsync = ref.watch(redemptionStatsProvider);

    // [SILENT REFRESH LOGIC]
    if (statsAsync.hasValue) {
      final stats = statsAsync.value!;
      return _buildStatsContent(stats);
    } else if (statsAsync.isLoading) {
      return _buildLoadingStats();
    } else if (statsAsync.hasError) {
      return Center(
          child: Text("Error loading stats",
              style: TextStyle(color: AppColors.error)));
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildStatsContent(RedemptionStats stats) {
    // Dynamic divider color based on card mode
    final dividerColor = widget.isGolden
        ? AppColors.textPrimary.withOpacity(0.1)
        : Colors.white.withOpacity(0.2);

    return Center(
      child: IntrinsicHeight( // Ensures dividers match the height of the content
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Total Visits
            _buildSingleStat(
              value: "${stats.totalRedemptions}",
              label: "Visits",
              subLabel: "Lifetime",
            ),
            
            // Vertical Divider
            VerticalDivider(color: dividerColor, indent: 10, endIndent: 10, width: 1),

            // 2. Rewards
            _buildSingleStat(
              value: "${stats.bonusesUnlocked}",
              label: "Rewards",
              subLabel: "Earned",
            ),

            // Vertical Divider
            VerticalDivider(color: dividerColor, indent: 10, endIndent: 10, width: 1),

            // 3. Leaderboard
            _buildSingleStat(
              value: stats.leaderboardPosition > 0 ? "#${stats.leaderboardPosition}" : "-",
              label: "Rank",
              subLabel: "Nationwide",
            ),
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
    // Smart Color Logic: Dark text for Gold card, White text for Standard
    final valueColor = widget.isGolden ? AppColors.textPrimary : Colors.white;
    final labelColor = widget.isGolden ? AppColors.primary : const Color(0xFFE3E935);
    // Made sublabel subtle (opacity) so it doesn't compete with the main label
    final subLabelColor = widget.isGolden 
        ? AppColors.textPrimary.withOpacity(0.5) 
        : Colors.white.withOpacity(0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. The Big Number
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 32, 
            fontWeight: FontWeight.w900, // Extra Bold
            height: 1.0, 
          ),
        ),
        const SizedBox(height: 6),
        
        // 2. The Category Label
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: labelColor,
            fontSize: 11, 
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2, // Wide spacing for clean look
          ),
        ),
        const SizedBox(height: 2),
        
        // 3. The Context Label
        Text(
          subLabel,
          style: TextStyle(
            color: subLabelColor,
            fontSize: 10, 
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingStats() {
    // Dynamic colors for skeletons
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
        BlinkingSkeleton(width: 40, height: 32, baseColor: baseColor),
        const SizedBox(height: 6),
        BlinkingSkeleton(width: 50, height: 11, baseColor: baseColor),
        const SizedBox(height: 2),
        BlinkingSkeleton(width: 30, height: 10, baseColor: baseColor),
      ],
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
  final bool isFoundersClub; // [NEW]
  final bool isLoading;

  const CardFrontContent({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.universityName,
    required this.isGolden,
    this.isFoundersClub = false, // [NEW]
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Adjust colors for Gold Background readability
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
                  flipX: true, // This horizontally flips the child
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

                  // [NEW] Founders Club Label
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
                        // 2. Student Name
                        isLoading
                            ? BlinkingSkeleton(
                                width: 150,
                                height: 24,
                                baseColor: Colors.white.withOpacity(0.3),
                              )
                            : Text(
                                studentName,
                                maxLines: 2, // Allow 2 lines if too long (requested behavior)
                                overflow: TextOverflow.ellipsis, 
                                style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold, // Bold
                              letterSpacing: 0.1),
                              ),
                        const SizedBox(height: 2),

                        // 3. University Name
                        isLoading
                            ? BlinkingSkeleton(
                                width: 100,
                                height: 10,
                                baseColor: Colors.white.withOpacity(0.3),
                              )
                            : Text(
                                universityName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600, // Semi-bold
                                    letterSpacing: 0.1),
                              ),
                      ],
                    ),
                  ),
                  // 1. Parchi ID (Most Important)
                  isLoading
                      ? BlinkingSkeleton(
                          width: 80,
                          height: 24,
                          baseColor: Colors.white.withOpacity(0.3),
                        )
                      : Text(
                          studentId,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 24, // Larger
                              fontWeight: FontWeight.w900, // Boldest
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
// 4. COMPACT HEADER (Sticky)
// =========================================================
class CompactParchiHeader extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String universityName; // [NEW]
  final bool isGolden;
  final String? profilePicture; // [NEW]
  final String studentInitials; // [NEW]
  final VoidCallback onProfileTap; // [NEW]
  final ValueChanged<String>? onSearchChanged; // [NEW]
  final double scrollProgress;
  final VoidCallback onNotificationTap;
  final bool isLoading; // [NEW]
  final bool hasUnreadNotifications; // [NEW]

  const CompactParchiHeader({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.universityName, // [NEW]
    this.isGolden = false,
    required this.scrollProgress,
    required this.onNotificationTap,
    this.profilePicture, // [NEW]
    required this.studentInitials, // [NEW]
    required this.onProfileTap, // [NEW]
    this.onSearchChanged, // [NEW]
    this.isLoading = false, // [NEW]
    this.hasUnreadNotifications = false, // [NEW]
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.87)
        : AppColors.textOnPrimary;
    final secondaryTextColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.54)
        : AppColors.textOnPrimary.withOpacity(0.7);

    // Interpolate background color
    // Start transparent (or minimal) -> End at Primary/Gold
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
                  AppColors.goldMid.withOpacity(scrollProgress)
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
          // 0. Background Icon (Same as Main Card)
          if (scrollProgress > 0.1)
            Positioned(
              right: -110,
              top: -90, // Adjusted for compact view to sit behind search bar
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
                // 1. Search Bar & Notification Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), // Removed bottom padding
                  child: Row(
                    children: [
                      // [NEW] Profile Button (Left)
                      isLoading
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: BlinkingSkeleton(
                                width: 35,
                                height: 35,
                                borderRadius: 17.5, // Circular
                                baseColor: AppColors.lightSurface,  
                              ),
                            )
                          : GestureDetector(
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
                                      ? Image.network(
                                          profilePicture!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Center(
                                            child: Text(
                                              studentInitials,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            studentInitials,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.bold,
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
                            color: AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            onChanged: onSearchChanged,
                            decoration: InputDecoration(
                              hintText: "Search restaurants...",
                              hintStyle: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  Icons.search,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                              prefixIconConstraints:
                                  BoxConstraints(minWidth: 35),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.only(bottom: 17), // Lifted text further up
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          Container(
                            width: 35, // Fixed smaller width
                            height: 35, // Fixed smaller height
                            decoration: const BoxDecoration(
                              color: AppColors.lightSurface,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero, // Remove default padding
                              icon: const Icon(Icons.notifications_none,
                                  size: 20, // Smaller icon
                                  color: AppColors.textSecondary),
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
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2), // Add border for visibility
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Student Info (Animated Slide Down)
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: scrollProgress,
                    child: Opacity(
                      opacity: scrollProgress,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), // Reverted to original
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Name, Uni & ID
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 180, // Set width limit as requested
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 5),
                                        isLoading
                                            ? BlinkingSkeleton(
                                                width: 120,
                                                height: 16,
                                                baseColor:
                                                    Colors.white.withOpacity(0.3),
                                              )
                                            : Text(
                                                studentName,
                                                maxLines: 2, // Allow 2 lines
                                                overflow: TextOverflow.ellipsis, 
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                        const SizedBox(height: 1),
                                        isLoading
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: BlinkingSkeleton(
                                                  width: 80,
                                                  height: 10,
                                                  baseColor:
                                                      Colors.white.withOpacity(0.3),
                                                ),
                                              )
                                            : Text(
                                                universityName.toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
                                              Colors.white.withOpacity(0.3),
                                        )
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
                            // Mini Icon (Kept as requested)
                           
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
