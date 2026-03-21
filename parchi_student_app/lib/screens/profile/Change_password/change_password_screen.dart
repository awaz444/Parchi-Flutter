import 'package:flutter/material.dart';
import '../../../utils/colours.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/common/spinning_loader.dart';
import '../../../widgets/common/tap_to_dismiss_keyboard.dart';

class ChangePasswordSheet extends StatefulWidget {
  // Callback to let the parent ProfileScreen handle the closing animation
  final VoidCallback onClose;

  const ChangePasswordSheet({super.key, required this.onClose});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await authService.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      if (mounted) {
        widget.onClose(); // Trigger parent close animation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password changed!'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: The parent ProfileScreen wraps this sheet in
    // Padding(padding: MediaQuery.viewInsetsOf(context)) to lift it above
    // the keyboard. We must NOT also add viewInsets here — doing so on
    // Android causes a double-shift where the sheet overshoots the keyboard.
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    // We wrap in Material to give it the white sheet look
    return TapToDismissKeyboard(
      child: Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Container(
          // Constrain height if needed, or let it grow.
          // Using ~80% height for password sheet usually looks good.
          constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrink wrap content
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onClose, // Close button logic
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.textSecondary.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text("Change Password",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.textSecondary),

            // --- FORM CONTENT ---
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, bottomSafeArea + 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoBox(),
                      const SizedBox(height: 30),
                      _buildLabel("Current Password"),
                      _buildTextField(
                          _currentPasswordController,
                          "Enter current password",
                          _obscureCurrent,
                          () => setState(
                              () => _obscureCurrent = !_obscureCurrent)),
                      const SizedBox(height: 20),
                      _buildLabel("New Password"),
                      _buildTextField(
                          _newPasswordController,
                          "Enter new password",
                          _obscureNew,
                          () => setState(() => _obscureNew = !_obscureNew)),
                      const SizedBox(height: 20),
                      _buildLabel("Confirm New Password"),
                      _buildTextField(
                          _confirmPasswordController,
                          "Re-enter new password",
                          _obscureConfirm,
                          () => setState(
                              () => _obscureConfirm = !_obscureConfirm)),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleChangePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          child: _isLoading
                              ? const SpinningLoader(size: 30, color: AppColors.secondary)
                              : const Text("Update Password",
                                  style: TextStyle(
                                      color: AppColors.textOnPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(children: [
        const Icon(Icons.security, color: AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Expanded(
            child: Text("Verify your current password to continue.",
                style: TextStyle(
                    color: AppColors.textPrimary.withOpacity(0.8),
                    fontSize: 14))),
      ]),
    );
  }

  Widget _buildLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)));

  Widget _buildTextField(TextEditingController controller, String hint,
      bool isObscure, VoidCallback onToggle) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.textSecondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16)),
      child: TextFormField(
        controller: controller,
        obscureText: isObscure,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: IconButton(
              icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary),
              onPressed: onToggle),
        ),
      ),
    );
  }
}
