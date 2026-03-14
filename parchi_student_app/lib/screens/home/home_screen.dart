import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/colours.dart';
import '../../widgets/home_screen_parchicard_widgets/parchi_card.dart';
import '../../widgets/home_screen_widgets/home_sheet_content.dart';
import '../../providers/user_provider.dart';
import '../../providers/home_ui_provider.dart'; // [NEW]
import 'notfication/notification_screen.dart'; // [NEW] Import the new screen
import '../profile/profile_screen.dart'; // [NEW] Import Profile Screen
import '../auth/login_screens/login_screen.dart'; // [GUEST] Login screen for guest CTA

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<double> _expandProgress = ValueNotifier(0.0);

  double _minSheetSize = 0.5;
  double _maxSheetSize = 0.9;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
  }

  void _onSheetChanged() {
    double currentSize = _sheetController.size;
    double progress =
        (currentSize - _minSheetSize) / (_maxSheetSize - _minSheetSize);
    _expandProgress.value = progress.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    super.dispose();
  }

  // [NEW] THE COOL TRANSITION LOGIC
  void _openNotifications() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration:
            const Duration(milliseconds: 500), // Slightly slower for effect
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NotificationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 1. Use a curved animation for that "bouncy/smooth" feel
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves
                .easeOutExpo, // Expo makes it pop fast then settle smoothly
          );

          return ScaleTransition(
            // This aligns the origin to the Bell Icon (Top Right)
            alignment: const Alignment(0.85, -0.9),
            scale: curvedAnimation,
            child: AnimatedBuilder(
              animation: curvedAnimation,
              builder: (context, child) {
                // 2. Animate the Radius
                // Start with 200 (Circle) -> End with 0 (Rectangle)
                // We use (1 - value) so it starts high and goes to zero
                final double currentRadius =
                    200 * (1.0 - curvedAnimation.value);

                return ClipRRect(
                  borderRadius: BorderRadius.circular(currentRadius),
                  child: child,
                );
              },
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration:
            const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutExpo,
          );

          return ScaleTransition(
            // Aligned to Top Left (Profile Icon)
            alignment: const Alignment(-0.85, -0.9),
            scale: curvedAnimation,
            child: AnimatedBuilder(
              animation: curvedAnimation,
              builder: (context, child) {
                final double currentRadius =
                    200 * (1.0 - curvedAnimation.value);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(currentRadius),
                  child: child,
                );
              },
              child: child,
            ),
          );
        },
      ),
    );
  }

  // State for search
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = MediaQuery.of(context).padding.top;

    final double collapsedHeaderHeight = topPadding + 5.0 + 60.0;
    // Add extra height for the expanded student info part (~70px)
    final double expandedHeaderHeight = collapsedHeaderHeight + 70.0;
    
    final double cardHeight = 180.0;

    const double initialGap = 66.0;
    const double expandedGap = 0.0; // Removed gap to eliminate white padding

    _maxSheetSize =
        (screenHeight - (expandedHeaderHeight + expandedGap)) / screenHeight;
    _minSheetSize = (screenHeight - (collapsedHeaderHeight + cardHeight + initialGap)) /
        screenHeight;

    if (_minSheetSize < 0.2) _minSheetSize = 0.2;
    if (_maxSheetSize > 0.95) _maxSheetSize = 0.95;
    if (_minSheetSize > _maxSheetSize) _minSheetSize = _maxSheetSize - 0.05;

    final userAsync = ref.watch(userProfileProvider);
    final homeUIState = ref.watch(homeUIProvider); // [NEW]

    // Determine if the user is a guest (not authenticated)
    final bool isGuest = userAsync.maybeWhen(
      data: (user) => user == null,
      orElse: () => false,
    );

    return ValueListenableBuilder<double>(
      valueListenable: _expandProgress,
      builder: (context, progress, child) {
        return Scaffold(
          backgroundColor: AppColors.lightCanvas,
          body: Stack(
            children: [
              // LAYER 1: Parchi Card (hidden for guests)
              Positioned(
                top: collapsedHeaderHeight,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: (1.0 - (progress * 3)).clamp(0.0, 1.0),
                  child: isGuest
                      // [GUEST] Show a sign-in teaser card instead of the Parchi card
                      ? _GuestParchiCardTeaser(
                          onSignInTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                        )
                      : userAsync.when(
                          data: (user) {
                            final fname = user?.firstName ?? "Student";
                            final lname = user?.lastName ?? "";
                            final fullName =
                                "$fname $lname".trim().toUpperCase();
                            final pId = user?.parchiId ?? "PENDING";
                            final uni =
                                user?.university ?? "Unknown University";

                            return ParchiCard(
                              studentName:
                                  fullName.isEmpty ? "STUDENT" : fullName,
                              studentId: pId,
                              universityName: uni,
                              isFoundersClub: user?.isFoundersClub ?? false,
                              isLoading: homeUIState.isSkeletonLoading,
                            );
                          },
                          loading: () => const ParchiCard(
                              studentName: "",
                              studentId: "",
                              universityName: "",
                              isLoading: true),
                          error: (err, stack) => const ParchiCard(
                              studentName: "",
                              studentId: "",
                              universityName: "",
                              isLoading: true),
                        ),
                ),
              ),

              // LAYER 2: Draggable Sheet
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: _minSheetSize,
                minChildSize: _minSheetSize,
                maxChildSize: _maxSheetSize,
                snap: true,
                builder:
                    (BuildContext context, ScrollController scrollController) {
                  return HomeSheetContent(
                    scrollController: scrollController,
                    searchQuery: _searchQuery, // Pass search query
                  );
                },
              ),

              // LAYER 3: Fixed Header (Unified Search & Compact Parchi Card)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: isGuest
                    // [GUEST] Minimal header: no profile avatar, just a Sign In button
                    ? _GuestCompactHeader(
                        scrollProgress: progress,
                        onNotificationTap: _openNotifications,
                        onSearchChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        onSignInTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                      )
                    : userAsync.when(
                        data: (user) {
                          final fname = user?.firstName ?? "Student";
                          final lname = user?.lastName ?? "";
                          final fullName =
                              "$fname $lname".trim().toUpperCase();
                          final pId = user?.parchiId ?? "PENDING";
                          final uni = user?.university ?? "Unknown University";

                          final initials =
                              (fname.isNotEmpty ? fname[0] : "") +
                                  (lname.isNotEmpty ? lname[0] : "");

                          return CompactParchiHeader(
                            studentName:
                                fullName.isEmpty ? "STUDENT" : fullName,
                            studentId: pId,
                            universityName: uni,
                            scrollProgress: progress,
                            onNotificationTap: _openNotifications,
                            profilePicture: user?.profilePicture,
                            studentInitials: initials.toUpperCase(),
                            onProfileTap: _navigateToProfile,
                            onSearchChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            isLoading: homeUIState.isSkeletonLoading,
                            hasUnreadNotifications:
                                user?.hasUnreadNotifications ?? false,
                          );
                        },
                        loading: () => CompactParchiHeader(
                          studentName: "",
                          studentId: "",
                          universityName: "",
                          scrollProgress: progress,
                          onNotificationTap: _openNotifications,
                          studentInitials: "",
                          onProfileTap: _navigateToProfile,
                          isLoading: true,
                        ),
                        error: (err, stack) => CompactParchiHeader(
                          studentName: "",
                          studentId: "",
                          universityName: "",
                          scrollProgress: progress,
                          onNotificationTap: _openNotifications,
                          studentInitials: "",
                          onProfileTap: _navigateToProfile,
                          isLoading: true,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guest header: search bar + Sign In button (no profile avatar)
// ─────────────────────────────────────────────────────────────────────────────
class _GuestCompactHeader extends StatelessWidget {
  final double scrollProgress;
  final VoidCallback onNotificationTap;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback onSignInTap;

  const _GuestCompactHeader({
    required this.scrollProgress,
    required this.onNotificationTap,
    required this.onSignInTap,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Color.lerp(
      Colors.transparent,
      AppColors.primary,
      scrollProgress,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              // Search Bar
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
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 35),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(bottom: 17),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sign In button
              GestureDetector(
                onTap: onSignInTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guest Parchi card teaser: prompts the user to sign in
// ─────────────────────────────────────────────────────────────────────────────
class _GuestParchiCardTeaser extends StatelessWidget {
  final VoidCallback onSignInTap;

  const _GuestParchiCardTeaser({required this.onSignInTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onSignInTap,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.credit_card_rounded,
                    color: Colors.white70, size: 36),
                SizedBox(height: 10),
                Text(
                  'Sign in to get your Parchi card',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap to create a free account',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}