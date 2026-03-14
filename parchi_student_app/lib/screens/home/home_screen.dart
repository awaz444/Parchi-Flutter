import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/colours.dart';
import '../../widgets/home_screen_parchicard_widgets/parchi_card.dart';
import '../../widgets/home_screen_widgets/home_sheet_content.dart';
import '../../providers/user_provider.dart';
import '../../providers/home_ui_provider.dart'; // [NEW]
import 'notfication/notification_screen.dart'; // [NEW] Import the new screen
import '../profile/profile_screen.dart'; // [NEW] Import Profile Screen

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

    return ValueListenableBuilder<double>(
      valueListenable: _expandProgress,
      builder: (context, progress, child) {
        return Scaffold(
          backgroundColor: AppColors.lightCanvas,
          body: Stack(
            children: [
              // LAYER 1: Parchi Card
              Positioned(
                top: collapsedHeaderHeight,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: (1.0 - (progress * 3)).clamp(0.0, 1.0),
                  child: userAsync.when(
                    data: (user) {
                      final fname = user?.firstName ?? "Student";
                      final lname = user?.lastName ?? "";
                      final fullName = "$fname $lname".trim().toUpperCase();
                      final pId = user?.parchiId ?? "PENDING";
                      final uni = user?.university ?? "Unknown University";

                      return ParchiCard(
                        studentName: fullName.isEmpty ? "STUDENT" : fullName,
                        studentId: pId,
                        universityName: uni,
                        isFoundersClub: user?.isFoundersClub ?? false,
                        // [NEW] Pass UI states
                        isLoading: homeUIState.isSkeletonLoading, // Override loading if refreshing
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
                        isLoading: true), // Skeleton on error
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
                child: userAsync.when(
                  data: (user) {
                    final fname = user?.firstName ?? "Student";
                    final lname = user?.lastName ?? "";
                    final fullName = "$fname $lname".trim().toUpperCase();
                    final pId = user?.parchiId ?? "PENDING";
                    final uni = user?.university ?? "Unknown University";

                    final initials = (fname.isNotEmpty ? fname[0] : "") +
                        (lname.isNotEmpty ? lname[0] : "");

                    return CompactParchiHeader(
                      studentName: fullName.isEmpty ? "STUDENT" : fullName,
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
                      isLoading: homeUIState.isSkeletonLoading, // [NEW] Pass skeleton state
                      hasUnreadNotifications: user?.hasUnreadNotifications ?? false, // [NEW]
                    );
                  },
                  loading: () => CompactParchiHeader(
                    studentName: "", // Empty for skeleton
                    studentId: "",
                    universityName: "",
                    scrollProgress: progress,
                    onNotificationTap: _openNotifications,
                    studentInitials: "",
                    onProfileTap: _navigateToProfile,
                    isLoading: true, // [NEW] Trigger skeleton
                  ),
                  error: (err, stack) => CompactParchiHeader(
                    studentName: "",
                    studentId: "",
                    universityName: "",
                    scrollProgress: progress,
                    onNotificationTap: _openNotifications,
                    studentInitials: "",
                    onProfileTap: _navigateToProfile,
                    isLoading: true, // Skeleton on error
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
