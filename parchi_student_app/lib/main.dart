import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // [NEW] Import Riverpod
import 'package:app_links/app_links.dart'; // [NEW] Import AppLinks
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'screens/auth/reset_password/reset_password_screen.dart';
import 'config/supabase_config.dart';
import 'config/api_config.dart';
import 'utils/colours.dart';
import 'utils/toast_utils.dart'; // [NEW] Error Toast Utilities
import 'screens/home/home_screen.dart';
import 'screens/home/merchant_deep_link_screen.dart';
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
import 'screens/qr_redemption/qr_redemption_screen.dart';
import 'widgets/common/guest_login_prompt.dart'; // [NEW] Guest gate widget
import 'package:package_info_plus/package_info_plus.dart';
import 'screens/force_update/force_update_screen.dart';


import 'services/analytics_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: ".env");

  // [NEW] Initialize Firebase with generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Log app open
  analyticsService.logEvent('app_opened');

  runApp(

    // [NEW] Wrap entire app in ProviderScope
    const ProviderScope(
      child: ParchiApp(),
    ),
  );

  // Keep app startup snappy: notification setup is not required before first frame.
  unawaited(NotificationHandlerService().initialize());
}

class ParchiApp extends StatefulWidget {
  const ParchiApp({super.key});

  @override
  State<ParchiApp> createState() => _ParchiAppState();
}

class _ParchiAppState extends State<ParchiApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _pendingInitialUri; // stored so onGenerateRoute can inspect the full URI
  Uri? _lastDeepLinkUri; // tracks the most recent deep link (warm or cold start)

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

    // Handle cold-start / initial link (app launched via deep link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _pendingInitialUri = initialUri;
        // Defer until the navigator is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(initialUri);
          _pendingInitialUri = null;
        });
      }
    } catch (e) {
      debugPrint("Error getting initial link: $e");
    }

    // Handle warm-start links (app already running)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint("_handleDeepLink: $uri  host=${uri.host}  path=${uri.path}  segments=${uri.pathSegments}");
    // Always cache the full URI so onGenerateRoute can reconstruct host/path
    // even when Flutter strips the scheme+host (warm-start on iOS).
    _lastDeepLinkUri = uri;

    // Check if the route is related to auth-callback OR contains an access token fragment
    // Note: Supabase magic links often come as https://project.supabase.co/auth/v1/verify?token=...&type=signup&redirect_to=parchi://auth-callback
    // Or simpler: parchi://auth-callback#access_token=...

    // We need to parse fragment parameters primarily
    String? accessToken;
    String? refreshToken;
    String? type;
    String? errorCode;
    String? errorDescription;

    // 1. Try extracting from fragment (typical for implicit flow / magic link redirects)
    if (uri.fragment.isNotEmpty) {
      try {
        final queryParams = Uri.splitQueryString(uri.fragment);
        accessToken = queryParams['access_token'];
        refreshToken = queryParams['refresh_token'];
        type = queryParams['type'];
        errorCode = queryParams['error_code'];
        errorDescription = queryParams['error_description'];
      } catch (e) {
        debugPrint("Error parsing fragment: $e");
      }
    }

    // 2. Try extracting from query parameters (if not in fragment)
    if (accessToken == null) {
      accessToken = uri.queryParameters['access_token'];
      refreshToken = uri.queryParameters['refresh_token'];
      type = uri.queryParameters['type'];
      errorCode = uri.queryParameters['error_code'];
      errorDescription = uri.queryParameters['error_description'];
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
            errorCode: errorCode,
            errorDescription: errorDescription,
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
      title: 'Parchi',
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
        // Flutter strips scheme+host on iOS cold start and passes just the path.
        // Prefer the full URI captured from getInitialLink() when available.
        // For warm-start links, fall back to _lastDeepLinkUri set by _handleDeepLink.
        final parsedUri = Uri.tryParse(settings.name ?? '');
        final uri = _pendingInitialUri ??
            (parsedUri != null && parsedUri.host.isEmpty
                ? _lastDeepLinkUri
                : parsedUri);

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
          String? errorCode;
          String? errorDescription;

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
              errorCode = queryParams['error_code'];
              errorDescription = queryParams['error_description'];
            }
          } catch (e) {
            debugPrint("Error parsing fragment in generateRoute: $e");
          }

          // 2. Query param parsing
          if (accessToken == null) {
            accessToken = uri.queryParameters['access_token'];
            refreshToken = uri.queryParameters['refresh_token'];
            type = uri.queryParameters['type'];
            errorCode = uri.queryParameters['error_code'];
            errorDescription = uri.queryParameters['error_description'];
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
                errorCode: errorCode,
                errorDescription: errorDescription,
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

/// Aligns [authService] with Supabase GoTrue: access + refresh + JWT expiry.
/// [fetchProfile] loads the user from your API on sign-in and on cold start
/// ([AuthChangeEvent.initialSession]), not on [AuthChangeEvent.tokenRefreshed].
Future<void> _syncAuthServiceWithSupabaseSession(
  Session session, {
  required bool fetchProfile,
}) async {
  if (session.accessToken.isEmpty) return;

  await authService.setToken(session.accessToken);
  final rt = session.refreshToken;
  if (rt != null && rt.isNotEmpty) {
    await authService.setRefreshToken(rt);
  }

  final exp = session.expiresAt ??
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
          (session.expiresIn ?? 3600);
  await authService.setTokenExpiry(exp);

  if (fetchProfile) {
    try {
      await authService.getProfile();
    } catch (e) {
      debugPrint('Error syncing profile after Supabase session: $e');
    }
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _requiresUpdate = false;
  bool _isUnderMaintenance = false;
  String? _updateTitle;
  String? _updateMessage;
  late final StreamSubscription<AuthState> _authSubscription;
  StreamSubscription<String>? _authErrorSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _setupAuthListener();
    _setupAuthErrorListener();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final String localVersion = packageInfo.version; // e.g. "2.1.0"

      // Use NestJS backend — avoids Supabase schema-cache issues (PGRST002)
      final response = await http.get(
        Uri.parse(ApiConfig.appConfigEndpoint),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final String minAndroid = data['minAndroidVersion'] ?? '1.0.0';
      final String minIos = data['minIosVersion'] ?? '1.0.0';
      final bool isMaintenance = data['isUnderMaintenance'] ?? false;

      final String minRequired = Platform.isAndroid ? minAndroid : minIos;

      if (isMaintenance) {
          if (mounted) {
            setState(() {
              _isUnderMaintenance = true;
              _updateTitle = data['forceUpdateTitle'];
              _updateMessage = data['forceUpdateMessage'];
              _isLoading = false;
            });
            FlutterNativeSplash.remove();
          }
          return;
        }

        if (_isVersionLessThan(localVersion, minRequired)) {
          if (mounted) {
            setState(() {
              _requiresUpdate = true;
              _updateTitle = data['forceUpdateTitle'];
              _updateMessage = data['forceUpdateMessage'];
              _isLoading = false;
            });
            FlutterNativeSplash.remove();
          }
        }
    } catch (e) {
      debugPrint("Error checking for update: $e");
    }
  }

  /// Returns true if [version] is strictly less than [minVersion].
  /// Both must be in "major.minor.patch" format.
  bool _isVersionLessThan(String version, String minVersion) {
    final List<int> v = version.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final List<int> m = minVersion.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final int a = i < v.length ? v[i] : 0;
      final int b = i < m.length ? m[i] : 0;
      if (a < b) return true;
      if (a > b) return false;
    }
    return false; // equal
  }


  void _setupAuthListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (session != null &&
          session.accessToken.isNotEmpty &&
          (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.initialSession)) {
        try {
          final fetchProfile = event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.initialSession;
          await _syncAuthServiceWithSupabaseSession(
            session,
            fetchProfile: fetchProfile,
          );
          if (mounted) {
            await _checkAuthState();
          }
        } catch (e) {
          debugPrint('Error syncing auth state: $e');
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

      // Show the snackbar with the real reason using the custom Universal Toast
      ToastUtils.handleApiError(null, errorMessage);

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
      // Avoid artificial delays on launch; only wait for the auth check itself.
      final isStudentAuth = await authService
          .isStudentAuthenticated()
          .timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          if (!_requiresUpdate) _isLoading = false;
        });
        // Remove native splash once Flutter builds its first frame
        if (!_requiresUpdate) FlutterNativeSplash.remove();
      }

      if (!isStudentAuth) {
        final isAuth = await authService.isAuthenticated();
        if (isAuth) {
          await authService.logout();
        }
      }
    } catch (e) {
      // On timeout or SocketException, bypass the splash screen.
      // Home screen providers will handle displaying the "No Internet" UI.
      if (mounted) {
        setState(() {
          if (!_requiresUpdate) _isLoading = false;
        });
        if (!_requiresUpdate) FlutterNativeSplash.remove();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_requiresUpdate || _isUnderMaintenance) {
      return ForceUpdateScreen(
        title: _updateTitle,
        message: _updateMessage,
        isMaintenance: _isUnderMaintenance,
      );
    }

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

  // ── Deep-link handling (merchant) ─────────────────────────────────────────
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _merchantLinkSubscription;

  @override
  void initState() {
    super.initState();
    _initMerchantDeepLinks();
  }

  @override
  void dispose() {
    _merchantLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initMerchantDeepLinks() async {
    // 1. Cold-start: app was launched via a merchant deep link.
    //    getInitialLink() is only called once here, so it won't re-fire.
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        // Defer by one frame so the widget is fully mounted and
        // Navigator.of(context) is available.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleMerchantLink(initialUri);
        });
      }
    } catch (e) {
      debugPrint('MainScreen – error reading initial link: $e');
    }

    // 2. Warm-start: app was already running when the link was tapped.
    _merchantLinkSubscription = _appLinks.uriLinkStream.listen(
      _handleMerchantLink,
      onError: (e) => debugPrint('MainScreen – link stream error: $e'),
    );
  }

  void _handleMerchantLink(Uri uri) {
    debugPrint('MainScreen _handleMerchantLink: $uri');

    // Only act on parchi:// or https://parchipakistan.com links
    final bool isCustomScheme = uri.scheme == 'parchi';
    final bool isWebScheme = uri.scheme == 'https' || uri.scheme == 'http';

    if (!isCustomScheme && !isWebScheme) return;

    // ── Redeem link: parchi://redeem/{branchId} or https://parchipakistan.com/redeem/{branchId}
    final bool isRedeemPath = uri.path.contains('/redeem/') || uri.host == 'redeem';
    if (isRedeemPath) {
      String? branchId;
      if (uri.pathSegments.contains('redeem')) {
        final index = uri.pathSegments.indexOf('redeem');
        if (index + 1 < uri.pathSegments.length) {
          branchId = uri.pathSegments[index + 1];
        }
      } else if (uri.host == 'redeem' && uri.pathSegments.isNotEmpty) {
        branchId = uri.pathSegments.first;
      }
      branchId ??= uri.queryParameters['branchId'];

      if (branchId != null && branchId.isNotEmpty && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QrRedemptionScreen(branchId: branchId!),
          ),
        );
      }
      return;
    }

    // ── Merchant link ──────────────────────────────────────────────────────
    final bool isMerchantPath = uri.path.contains('/merchant/') || uri.host == 'merchant';
    if (!isMerchantPath) return;

    // Extract merchantId
    // Case 1: https://parchipakistan.com/merchant/ID -> segments: ['merchant', 'ID']
    // Case 2: parchi://merchant/ID -> host: 'merchant', segments: ['ID']
    String? merchantId;
    
    if (uri.pathSegments.contains('merchant')) {
      final index = uri.pathSegments.indexOf('merchant');
      if (index + 1 < uri.pathSegments.length) {
        merchantId = uri.pathSegments[index + 1];
      }
    } else if (uri.host == 'merchant' && uri.pathSegments.isNotEmpty) {
      merchantId = uri.pathSegments.first;
    }

    // Fallback to query parameter 'id'
    merchantId ??= uri.queryParameters['id'];

    if (merchantId == null || merchantId.isEmpty) {
      debugPrint('MainScreen – could not extract merchantId from $uri');
      return;
    }

    // Guard: widget must still be mounted before using context/Navigator.
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantDeepLinkScreen(merchantId: merchantId!),
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────────────────

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
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SvgPicture.asset(
                    'assets/home-svgrepo-com.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        AppColors.textSecondary, BlendMode.srcIn),
                  ),
                ),
                activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SvgPicture.asset(
                    'assets/home-svgrepo-com.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        AppColors.primary, BlendMode.srcIn),
                  ),
                ),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SvgPicture.asset(
                    'assets/leaderboard-svgrepo-com.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        AppColors.textSecondary, BlendMode.srcIn),
                  ),
                ),
                activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SvgPicture.asset(
                    'assets/leaderboard-svgrepo-com.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        AppColors.primary, BlendMode.srcIn),
                  ),
                ),
                label: "Leaderboard",
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SvgPicture.asset(
                    'assets/history-svgrepo-com.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        AppColors.textSecondary, BlendMode.srcIn),
                  ),
                ),
                activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SvgPicture.asset(
                    'assets/history-svgrepo-com.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        AppColors.primary, BlendMode.srcIn),
                  ),
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
