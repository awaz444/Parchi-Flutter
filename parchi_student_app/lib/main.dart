import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // [NEW] Import Riverpod
import 'package:app_links/app_links.dart'; // [NEW] Import AppLinks
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'screens/auth/reset_password/reset_password_screen.dart';
import 'config/supabase_config.dart';
import 'utils/colours.dart';
import 'screens/home/home_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/profile/redemption_history/redemption_history_screen.dart'; // [NEW] History Screen
import 'screens/splash/splash_screen.dart'; // [NEW] Splash Screen
import 'screens/auth/login_screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/navigation_service.dart'; // [NEW] Use generic navigation service
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_handler_service.dart';
import 'firebase_options.dart'; // [NEW] Import generated options
import 'screens/auth/sign_up_screens/signup_verification_screen.dart'; // [NEW] Import Verification Screen
import 'providers/user_provider.dart'; // [NEW] For guest detection
import 'widgets/common/guest_login_prompt.dart'; // [NEW] Guest gate widget

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: ".env");

  // [NEW] Initialize Firebase with generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // [NEW] Initialize Notification Service (Subscribes to 'students_all')
  await NotificationHandlerService().initialize();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(
    // [NEW] Wrap entire app in ProviderScope
    const ProviderScope(
      child: ParchiApp(),
    ),
  );
}

class ParchiApp extends StatefulWidget {
  const ParchiApp({super.key});

  @override
  State<ParchiApp> createState() => _ParchiAppState();
}

class _ParchiAppState extends State<ParchiApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinkListener() async {
    _appLinks = AppLinks();

    // Check initial link checks are now handled by onGenerateRoute to avoid double navigation
    // and "Failed to handle route" errors.
    // However, for pure AppLinks support (if onGenerateRoute fails), we can keep the listener.

    // Listen for new links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    // Check if the route is related to auth-callback OR contains an access token fragment
    // Note: Supabase magic links often come as https://project.supabase.co/auth/v1/verify?token=...&type=signup&redirect_to=parchi://auth-callback
    // Or simpler: parchi://auth-callback#access_token=...

    // We need to parse fragment parameters primarily
    String? accessToken;
    String? refreshToken;
    String? type;

    // 1. Try extracting from fragment (typical for implicit flow / magic link redirects)
    if (uri.fragment.isNotEmpty) {
      try {
        final queryParams = Uri.splitQueryString(uri.fragment);
        accessToken = queryParams['access_token'];
        refreshToken = queryParams['refresh_token'];
        type = queryParams['type'];
      } catch (e) {
        debugPrint("Error parsing fragment: $e");
      }
    }

    // 2. Try extracting from query parameters (if not in fragment)
    if (accessToken == null) {
      accessToken = uri.queryParameters['access_token'];
      refreshToken = uri.queryParameters['refresh_token'];
      type = uri.queryParameters['type'];
    }

    // Identify if it's a reset password or signup verification
    // Sometimes 'type' param tells us.
    // Also check path/host
    if (uri.path.contains('reset-password') ||
        uri.host.contains('reset-password') ||
        type == 'recovery') {
      NavigationService.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(
            accessToken: accessToken,
            refreshToken: refreshToken,
          ),
        ),
      );
    } else if (uri.path.contains('auth-callback') ||
        uri.host.contains('auth-callback') ||
        type == 'signup' ||
        type == 'magiclink') {
      NavigationService.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => SignupVerificationScreen(
            accessToken: accessToken,
            refreshToken: refreshToken,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey:
          NavigationService.navigatorKey, // [NEW] Global Navigator Key
      scaffoldMessengerKey:
          NavigationService.messengerKey, // [NEW] Global Messenger Key
      debugShowCheckedModeBanner: false,
      title: 'Parchi MVP',
      routes: {
        '/login': (context) =>
            const LoginScreen(), // [NEW] Named route for global navigation
      },
      theme: ThemeData(
        textTheme: GoogleFonts.outfitTextTheme(),
        primaryColor: AppColors.primary,
        // [NEW] Enforce Blue Color Scheme to remove default Purple
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundLight,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        // [NEW] Global Cursor & Selection Color
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.primary,
          selectionColor: AppColors.primary.withOpacity(0.3),
          selectionHandleColor: AppColors.primary,
        ),
      ),
      home: const AuthWrapper(),
      onGenerateRoute: (settings) {
        debugPrint("onGenerateRoute: ${settings.name}");
        // [NEW] Restore onGenerateRoute to handle "Cold Start" deep links directly
        // This prevents "Failed to handle route information" error
        final uri = Uri.tryParse(settings.name ?? '');

        if (uri != null &&
            (uri.path.contains('auth-callback') ||
                uri.host.contains('auth-callback') ||
                uri.path.contains('reset-password') ||
                uri.host.contains('reset-password') ||
                uri.path.contains('verify') ||
                // [NEW] Check for tokens in fragment (implicit flow) or query
                uri.fragment.contains('access_token') ||
                uri.queryParameters.containsKey('access_token'))) {
          String? accessToken;
          String? refreshToken;
          String? type;

          // 1. Fragment parsing (primary for Supabase)
          // We treat settings.name as a full URI or path
          try {
            // Retrieve fragment directly if possible, or parse logic
            // If settings.name is just `/auth-callback#...`, Uri.tryParse handles it.
            if (uri.fragment.isNotEmpty) {
              final queryParams = Uri.splitQueryString(uri.fragment);
              accessToken = queryParams['access_token'];
              refreshToken = queryParams['refresh_token'];
              type = queryParams['type'];
            }
          } catch (e) {
            debugPrint("Error parsing fragment in generateRoute: $e");
          }

          // 2. Query param parsing
          if (accessToken == null) {
            accessToken = uri.queryParameters['access_token'];
            refreshToken = uri.queryParameters['refresh_token'];
            type = uri.queryParameters['type'];
          }

          // Determine screen
          if (uri.path.contains('reset-password') ||
              uri.host.contains('reset-password') ||
              type == 'recovery') {
            return MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(
                accessToken: accessToken,
                refreshToken: refreshToken,
              ),
            );
          } else {
            return MaterialPageRoute(
              builder: (context) => SignupVerificationScreen(
                accessToken: accessToken,
                refreshToken: refreshToken,
              ),
            );
          }
        }

        // [Fix] Default fallback to AuthWrapper instead of null to prevent "Failed to handle route" crash
        return MaterialPageRoute(
          builder: (context) => const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  late final StreamSubscription<AuthState> _authSubscription;
  StreamSubscription<String>? _authErrorSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _setupAuthListener();
    _setupAuthErrorListener();
  }

  void _setupAuthListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        if (session.accessToken.isNotEmpty) {
          try {
            await authService.setToken(session.accessToken);
            if (session.refreshToken != null) {
              await authService.setRefreshToken(session.refreshToken!);
            }

            // Sync user profile from backend
            await authService.getProfile();

            if (mounted) {
              // Re-check auth state to update UI
              await _checkAuthState();
            }
          } catch (e) {
            debugPrint("Error syncing auth state: $e");
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        if (mounted) {
          _checkAuthState();
        }
      } else if (event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const ResetPasswordScreen()),
          );
        }
      }
    });
  }

  void _setupAuthErrorListener() {
    // Listen for auth errors (e.g., account deactivation, token rejection)
    _authErrorSubscription =
        authService.onAuthError.listen((errorMessage) async {
      debugPrint('Auth error received: $errorMessage');

      // Show the snackbar with the real reason (deactivated, rejected, etc.)
      NavigationService.messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      // Navigate to login screen — tokens are already cleared by AuthService.logout()
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _authErrorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    try {
      // Start both auth logic and a minimum 2-second delay
      final results = await Future.wait([
        authService.isStudentAuthenticated(),
        Future.delayed(const Duration(seconds: 2)),
      ]);

      final isStudentAuth = results[0] as bool;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Remove native splash once Flutter builds its first frame
        FlutterNativeSplash.remove();
      }

      if (!isStudentAuth) {
        final isAuth = await authService.isAuthenticated();
        if (isAuth) {
          await authService.logout();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        FlutterNativeSplash.remove();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    // Always show MainScreen — guests can browse restaurants freely.
    // Account-based features (History, Profile) gate themselves individually.
    return const MainScreen();
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Watch the user provider to know if a guest is using the app.
    // A null user means the user is not authenticated (guest).
    final userAsync = ref.watch(userProfileProvider);
    final bool isAuthenticated = userAsync.maybeWhen(
      data: (user) => user != null,
      orElse: () => false,
    );

    // Resolve the active page.
    // For the History tab (index 2), show a guest prompt if not authenticated.
    Widget activePage;
    if (_currentIndex == 2 && !isAuthenticated) {
      activePage = const GuestLoginPrompt(
        title: 'Sign in to view your history',
        subtitle:
            'Your redemption history and Parchi card are only available to signed-in students.',
        icon: Icons.history_rounded,
      );
    } else {
      activePage = _currentIndex == 0
          ? const HomeScreen()
          : _currentIndex == 1
              ? const LeaderboardScreen()
              : const RedemptionHistoryScreen();
    }

    return Scaffold(
      body: activePage,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.textSecondary.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        // [UPDATED] Wrapped in Theme to remove splash effects
        child: Theme(
          data: ThemeData(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            enableFeedback: false, // Disables vibration/sound
            items: [
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  'assets/home-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                      AppColors.textSecondary, BlendMode.srcIn),
                ),
                activeIcon: SvgPicture.asset(
                  'assets/home-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                  colorFilter:
                      const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
                ),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  'assets/leaderboard-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                      AppColors.textSecondary, BlendMode.srcIn),
                ),
                activeIcon: SvgPicture.asset(
                  'assets/leaderboard-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                  colorFilter:
                      const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
                ),
                label: "Leaderboard",
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  'assets/history-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                      AppColors.textSecondary, BlendMode.srcIn),
                ),
                activeIcon: SvgPicture.asset(
                  'assets/history-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                  colorFilter:
                      const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
                ),
                label: "History",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
