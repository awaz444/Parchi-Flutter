import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../utils/colours.dart';
import '../../../widgets/login_screen/login_form.dart';
import '../../../widgets/signup_screen/sign_form.dart';
import '../../../widgets/common/tap_to_dismiss_keyboard.dart';
import 'forgot_password/forgot_password_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Initialize PageController to start at index 1 (Login)
  // This places ForgotPassword at 0 (Left) and Signup at 2 (Right)
  final PageController _pageController = PageController(initialPage: 1);

  // 0 = Forgot Password, 1 = Login, 2 = Signup
  int _currentPage = 1;

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // Switch to Signup (Index 2)
  void _goToSignup() {
    _pageController.animateToPage(2,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart);
    setState(() => _currentPage = 2);
  }

  // Switch to Login (Index 1)
  void _goToLogin() {
    _pageController.animateToPage(1,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart);
    setState(() => _currentPage = 1);
  }

  // Switch to Forgot Password (Index 0)
  void _goToForgotPassword() {
    _pageController.animateToPage(0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart);
    setState(() => _currentPage = 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    double containerHeight;
    if (_currentPage == 2) {
      if (isKeyboardOpen) {
        // Shrink to fit available space above keyboard; clamp to avoid going
        // negative on short Android screens (e.g. 5" 480p budget phones).
        containerHeight = (screenHeight - keyboardHeight - 40)
            .clamp(200.0, screenHeight * 0.85);
      } else {
        containerHeight = screenHeight * 0.75;
      }
    } else {
      containerHeight = screenHeight * 0.42;
    }

    return TapToDismissKeyboard(
      child: Scaffold(
        resizeToAvoidBottomInset: true, // [FIXED] Allow screen to lift with keyboard
        body: Stack(
        children: [
          // 1. BACKGROUND
          Container(
            color: AppColors.primary,
          ),

          // 2. LOGO & TEXT
          // Moves up and fades out ONLY when signing up (index 2).
          // Stays visible for Login (1) and Forgot Password (0).
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutQuart,
            top: 0, // [CENTERED] Vertically centered in remaining space
            left: 0, right: 0,
            height: screenHeight - containerHeight, // [DYNAMIC HEIGHT] Use all space above container
            child: SafeArea(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: 1.0, 
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutQuart,
                    width: MediaQuery.of(context).size.width *
                        (_currentPage == 2 ? 0.5 : 0.6),
                    child: SvgPicture.asset(
                      'assets/ParchiFullTextYellow.svg',
                      colorFilter: const ColorFilter.mode(
                          Color(0xFFE3E935), BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. THE EXPANDING WHITE CONTAINER
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutQuart,
            bottom: 0, left: 0, right: 0,
            height: containerHeight, // [ANIMATED HEIGHT]
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
                child: Padding(
                  // [FIX] Constrain the PageView to the visible area above the keyboard
                  // This allows internal ScrollViews to auto-scroll focused fields into view
                  padding: EdgeInsets.zero,
                  child: PageView(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable swipe
                    children: [
                      // PAGE 0: FORGOT PASSWORD
                      ForgotPasswordForm(onBackTap: _goToLogin),

                      // PAGE 1: LOGIN
                      LoginForm(
                        onSignupTap: _goToSignup,
                        onForgotTap: _goToForgotPassword,
                      ),

                      // PAGE 2: SIGNUP
                      SignupForm(onLoginTap: _goToLogin),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
