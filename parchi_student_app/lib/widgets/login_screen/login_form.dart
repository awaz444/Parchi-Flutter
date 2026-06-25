import 'package:flutter/material.dart';
import '../common/spinning_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/colours.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../providers/user_provider.dart';
import '../../utils/toast_utils.dart';

class LoginForm extends ConsumerStatefulWidget {
  final VoidCallback onSignupTap;
  final VoidCallback onForgotTap; // Added callback

  const LoginForm({
    super.key,
    required this.onSignupTap,
    required this.onForgotTap, // Required now
  });

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // 1. Manual Validation (No Layout Shift)
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ToastUtils.showErrorToast(context, label: "Validation Error", message: "Please Fill Out All The Fields");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text);
      if (mounted) {
        await ref.read(userProfileProvider.notifier).refresh();
        final user = ref.read(userProfileProvider).value;

        if (user == null) throw Exception("Failed to load user.");
        if (user.role.toLowerCase() != 'student') {
          await SessionService.signOut(ref: ref);
          throw Exception("Access denied. Students only.");
        }

        if (mounted)
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false);
      }
    } catch (e) {
      ToastUtils.handleApiError(context, e, showDetailedErrors: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account? ",
                    style: TextStyle(color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: widget.onSignupTap,
                  child: const Text("Sign Up",
                      style: TextStyle(
                          color: AppColors.textLink,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 22),

            _buildTextField(_emailController, "Email", Icons.email_outlined,
                action: TextInputAction.next),
            const SizedBox(height: 16),
            _buildTextField(_passwordController, "Password", Icons.lock_outline,
                isPassword: true, action: TextInputAction.done),

            const SizedBox(height: 20), // Spacing for forgot password

            // Forgot Password Link
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: widget.onForgotTap, // Triggers the transition
                child: const Text(
                  "Forgot password?",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20), // Replaced Spacer with fixed space

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary, // Keep Blue on Loading
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const SpinningLoader(size: 20, color: AppColors.secondary)
                    : const Text("Sign In",
                        style: TextStyle(
                            color: AppColors.textOnPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isPassword = false, TextInputAction action = TextInputAction.done}) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
          color: AppColors.textSecondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16)),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        textInputAction: action, // [NEW] Controls keyboard return key
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textSecondary),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: AppColors.textSecondary),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
