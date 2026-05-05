import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/colours.dart';
import '../../widgets/home_screen_parchicard_widgets/parchi_card.dart';
import '../../widgets/home_screen_widgets/home_sheet_content.dart';
import '../../providers/user_provider.dart';
import '../../providers/home_ui_provider.dart';
import 'notfication/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/login_screens/login_screen.dart';
import '../../widgets/home_screen_widgets/app_intro_modal.dart';
import '../../providers/merchants_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _expandProgress = ValueNotifier(0.0);
  ProviderSubscription<AsyncValue<dynamic>>? _userProfileSub;
  Timer? _debounce;

  // Pixels of scroll before the header is fully expanded.
  // Tuned to card height (180) + top gap (16).
  static const double _scrollThreshold = 196.0;

  // Search state — owned here and shared down to both the header and sheet.
  String _searchQuery = "";
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _hasShownIntro = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _userProfileSub = ref.listenManual(userProfileProvider, (previous, next) {
      if (!next.isLoading && !next.hasError) {
        final user = next.value;
        if (user != null) {
          // Subscribe to targeted notifications based on profile
          NotificationHandlerService().subscribeToTargetedTopics(
            university: user.university,
            isFoundersClub: user.isFoundersClub,
          );

          if (user.role.toLowerCase() == 'student' &&
              !user.hasSeenAppIntro &&
              !_hasShownIntro) {
            _hasShownIntro = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final notifier = ref.read(userProfileProvider.notifier);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AppIntroModal(
                  onDismiss: () {
                    notifier.markAppIntroSeen();
                    Navigator.of(context).pop();
                  },
                ),
              );
            });
          }
        }
      }
    });
  }

  void _onScroll() {
    final pixels =
        _scrollController.hasClients ? _scrollController.position.pixels : 0.0;
    _expandProgress.value = (pixels / _scrollThreshold).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _userProfileSub?.close();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
      _isSearching = val.isNotEmpty;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(studentMerchantsProvider.notifier).setSearchQuery(val);
      }
    });
  }

  void _cancelSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    _debounce?.cancel();
    setState(() {
      _searchQuery = "";
      _isSearching = false;
    });
    ref.read(studentMerchantsProvider.notifier).setSearchQuery("");
  }

  // ─── Navigation transitions ────────────────────────────────────────────────

  void _openNotifications() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NotificationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutExpo,
          );
          return ScaleTransition(
            alignment: const Alignment(0.85, -0.9),
            scale: curvedAnimation,
            child: AnimatedBuilder(
              animation: curvedAnimation,
              builder: (context, child) {
                final double r = 200 * (1.0 - curvedAnimation.value);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(r),
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
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutExpo,
          );
          return ScaleTransition(
            alignment: const Alignment(-0.85, -0.9),
            scale: curvedAnimation,
            child: AnimatedBuilder(
              animation: curvedAnimation,
              builder: (context, child) {
                final double r = 200 * (1.0 - curvedAnimation.value);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(r),
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

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.paddingOf(context).top;
    final double collapsedHeaderHeight = topPadding + 5.0 + 60.0;

    final userAsync = ref.watch(userProfileProvider);
    final homeUIState = ref.watch(homeUIProvider);

    final bool isGuest = userAsync.maybeWhen(
      data: (user) => user == null,
      orElse: () => false,
    );

    final Widget parchiCardWidget = userAsync.when(
      data: (user) {
        if (isGuest) return const ParchiCard(isGuest: true);
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
          isLoading: homeUIState.isSkeletonLoading,
        );
      },
      loading: () => const ParchiCard(
          studentName: "", studentId: "", universityName: "", isLoading: true),
      error: (err, stack) => const ParchiCard(
          studentName: "", studentId: "", universityName: "", isLoading: false, hasError: true),
    );

    return Scaffold(
      backgroundColor: AppColors.lightCanvas,
      body: Stack(
        children: [
          // ── LAYER 1: Full-screen scrollable content ──────────────────────
          HomeSheetContent(
            scrollController: _scrollController,
            searchQuery: _searchQuery,
            headerSpacerHeight: collapsedHeaderHeight,
            parchiCardWidget: parchiCardWidget,
            isSearching: _isSearching,
          ),

          // ── LAYER 2: Fixed header overlay ────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _expandProgress,
              builder: (context, progress, child) {
                if (isGuest) {
                  return _GuestCompactHeader(
                    scrollProgress: progress,
                    onNotificationTap: _openNotifications,
                    searchController: _searchController,
                    searchFocus: _searchFocus,
                    isSearching: _isSearching,
                    onSearchChanged: _onSearchChanged,
                    onCancelSearch: _cancelSearch,
                    onSignInTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                  );
                }

                return userAsync.when(
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
                      searchController: _searchController,
                      searchFocus: _searchFocus,
                      isSearching: _isSearching,
                      onSearchChanged: _onSearchChanged,
                      onCancelSearch: _cancelSearch,
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
                    searchController: _searchController,
                    searchFocus: _searchFocus,
                    isSearching: _isSearching,
                    onSearchChanged: _onSearchChanged,
                    onCancelSearch: _cancelSearch,
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
                    searchController: _searchController,
                    searchFocus: _searchFocus,
                    isSearching: _isSearching,
                    onSearchChanged: _onSearchChanged,
                    onCancelSearch: _cancelSearch,
                    isLoading: false,
                    hasError: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guest header
// ─────────────────────────────────────────────────────────────────────────────
class _GuestCompactHeader extends StatelessWidget {
  final double scrollProgress;
  final VoidCallback onNotificationTap;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool isSearching;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCancelSearch;
  final VoidCallback onSignInTap;

  const _GuestCompactHeader({
    required this.scrollProgress,
    required this.onNotificationTap,
    required this.searchController,
    required this.searchFocus,
    required this.isSearching,
    required this.onSearchChanged,
    required this.onCancelSearch,
    required this.onSignInTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        Color.lerp(Colors.transparent, AppColors.primary, scrollProgress);

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 35,
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
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
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.search,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                prefixIconConstraints:
                                    const BoxConstraints(minWidth: 35),
                                border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.only(bottom: 18),
                              ),
                    ),
                ),
              ),
              const SizedBox(width: 8),
              // Cancel vs Sign-In — smooth scale swap
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: isSearching
                    ? GestureDetector(
                        key: const ValueKey('cancel'),
                        onTap: onCancelSearch,
                        child: Container(
                          width: 35,
                          height: 35,
                          decoration: const BoxDecoration(
                            color: AppColors.lightSurface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.textSecondary),
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('signin'),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}