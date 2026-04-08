import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/colours.dart';
import '../../../utils/toast_utils.dart'; // [NEW] Import ToastUtils
import '../login_screens/login_screen.dart';
import '../../../main.dart'; // To navigate to MainScreen (wrapped in AuthWrapper)
import 'verification_success_screen.dart'; // [NEW]

class SignupVerificationScreen extends StatefulWidget {
  final String? parchiId;
  final String? email;
  final String? accessToken; // [NEW]
  final String? refreshToken; // [NEW]

  const SignupVerificationScreen({
    super.key,
    this.parchiId,
    this.email,
    this.accessToken,
    this.refreshToken,
  });

  @override
  State<SignupVerificationScreen> createState() =>
      _SignupVerificationScreenState();
}

class _SignupVerificationScreenState extends State<SignupVerificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  late StreamSubscription<AuthState> _authSubscription;
  bool _isVerified = false;
  bool _isResending = false;
  bool _isLinkExpired = false; // [NEW] Track link expiry
  
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  void _startResendTimer() {
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      } else {
         timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
    
    // [NEW] Manually set session if tokens are passed
    // [NEW] Manually set session if tokens are passed
    if (widget.refreshToken != null) {
      _setManualSession();
    }

    _setupDeepLinkListener();
    _startResendTimer(); // Start timer immediately on load
  }

  Future<void> _setManualSession() async {
    try {
      if (widget.refreshToken != null) {
        await Supabase.instance.client.auth.setSession(
          widget.refreshToken!,
        );
      }
      // The listener will pick up the 'signedIn' event shortly
    } catch (e) {
      debugPrint("Error setting manual session: $e");
      // If error occurs here, it likely means the token is invalid or expired
      if (mounted) {
        setState(() {
          _isLinkExpired = true;
        });
        ToastUtils.handleApiError(context, e);
      }
    }
  }

  void _setupDeepLinkListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      if (session != null) {
        _handleVerificationSuccess();
      } else {
        // Force check current session if event suggests we should have one
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession != null) {
             _handleVerificationSuccess();
        }
      }
    });
  }

  void _handleVerificationSuccess() {
    print("_handleVerificationSuccess called. isVerified: $_isVerified, mounted: $mounted");
    if (_isVerified) return;
    if (mounted) {
      setState(() {
        _isVerified = true;
        _isLinkExpired = false; // Reset expiry if successful
      });
      // Restart animation for the checkmark
      _controller.reset();
      _controller.forward();

      // Navigate after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          // Navigate to Success Screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const VerificationSuccessScreen()),
            (route) => false,
          );
        }
      });
    }
  }

  Future<void> _resendEmail() async {
    print("Resend Email clicked");
    if (widget.email == null) {
      print("Email is null");
      return;
    }
    setState(() {
      _isResending = true;
      _isLinkExpired = false; // Reset expiry while resending
    });

    try {
      print("Resending email to ${widget.email}");
      await Supabase.instance.client.auth.resend(
        email: widget.email!,
        type: OtpType.signup,
        emailRedirectTo: 'https://www.parchipakistan.com/auth-callback',
      );
      print("Resend successful");
      if (mounted) {
        _startResendTimer(); // Restart timer on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification email sent!"),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      print("Resend failed: $e");
      if (mounted) {
        ToastUtils.handleApiError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _resendTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final containerHeight = screenHeight * 0.75;

    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND (Solid Primary)
          Container(
            color: AppColors.primary,
          ),

          // 2. LOGO
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutQuart,
            top: -screenHeight * 0.10,
            left: 0,
            right: 0,
            height: screenHeight * 0.45,
            child: SafeArea(
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: SvgPicture.asset(
                    'assets/ParchiFullTextYellow.svg',
                    colorFilter: const ColorFilter.mode(
                        Color(0xFFE3E935), BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),

          // 3. WHITE CONTAINER
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutQuart,
            bottom: 0,
            left: 0,
            right: 0,
            height: containerHeight,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Column(
                  children: [
                    // --- HEADER ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            _isVerified ? "Verification" : "Check Mail",
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),

                    // --- CONTENT ---
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),

                            // Animated Icon
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                height: 140,
                                width: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _isLinkExpired
                                          ? Colors.red.withOpacity(0.15)
                                          : AppColors.primary.withOpacity(0.15),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _isVerified
                                        ? Icons.check_circle_rounded
                                        : (_isLinkExpired
                                            ? Icons.error_outline_rounded
                                            : Icons.mark_email_unread_rounded),
                                    size: 80,
                                    color: _isLinkExpired
                                        ? Colors.red
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            Text(
                              _isVerified
                                  ? "You're all set!"
                                  : (_isLinkExpired
                                      ? "Link Expired"
                                      : "Verify your email"),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: _isLinkExpired
                                    ? Colors.red
                                    : AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isVerified
                                  ? "Your email has been verified successfully.\nRedirecting you..."
                                  : (_isLinkExpired
                                      ? "This verification link has expired or is invalid.\nPlease request a new one."
                                      : "We've sent a verification link to\n${widget.email ?? 'your email address'}.\nPlease check your inbox and spam folder."),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary.withOpacity(0.8),
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 40),

                            // If NOT verified, show buttons
                            if (!_isVerified) ...[
                              // Open Mail App (Optional, hard to do cross-platform reliably without specific package, let's just stick to Resend/Back)

                              // Resend Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton(
                                  onPressed: (_canResend && !_isResending)
                                      ? _resendEmail
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: _canResend 
                                           ? AppColors.primary 
                                           : AppColors.textSecondary.withOpacity(0.3), 
                                        width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _isResending
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : Text(
                                          _canResend 
                                              ? "Resend Email" 
                                              : "Resend in $_resendCountdown s",
                                          style: TextStyle(
                                            color: _canResend 
                                                ? AppColors.primary 
                                                : AppColors.textSecondary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              const SizedBox(height: 16),
                            ] else ...[
                               // Verified State Loading Indicator
                               const SizedBox(height: 20),
                               const CircularProgressIndicator(color: AppColors.primary),
                            ],
                            
                            const SizedBox(height: 20),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                "Your submitted documents are solely used for verification and will not be permanently held by Parchi.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
