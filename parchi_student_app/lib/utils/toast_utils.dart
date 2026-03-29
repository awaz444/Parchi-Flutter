import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/colours.dart';
import '../services/navigation_service.dart';

class ToastUtils {
  /// Defines our "Deep Crimson" color.
  static const Color unexpectedErrorColor = Color(0xFFD32F2F);

  /// Analyzes an exception/error object and maps it to a user-friendly UI Toast.
  static void handleApiError(BuildContext? context, dynamic error) {
    String errorMessage = error.toString();
    String errorLower = errorMessage.toLowerCase();

    // 1. Session / Auth Expiration
    if (errorLower.contains("session") ||
        errorLower.contains("refresh token") ||
        errorLower.contains("token expired") ||
        errorLower.contains("jwt expired") ||
        errorLower.contains("not authenticated") ||
        errorLower.contains("unauthorized")) {
      showErrorToast(
        context,
        label: "Session Expired",
        message: "Please sign in again.",
        labelColor: unexpectedErrorColor,
      );
      return;
    }

    // 2. Unhandled Backend Crashes (500s, HTML traces, Raw Exceptions, excessive length)
    bool isUnexpected = false;
    if (errorLower.contains("internal server error") ||
        errorLower.contains("<html>") ||
        errorLower.contains("nginx") ||
        errorLower.contains("typeerror:") ||
        errorLower.contains("exception:") ||
        errorLower.contains("stack trace:") ||
        errorMessage.length > 200) {
      isUnexpected = true;
    }

    if (isUnexpected) {
      showErrorToast(
        context,
        label: "Unexpected Error",
        message: "Something went wrong on our end. Please try again in a moment.",
        labelColor: unexpectedErrorColor,
      );
      return;
    }

    // 3. Known / Standard Error (Strip 'Exception:' prefix if present)
    String cleanMessage = errorMessage.replaceFirst(RegExp(r'^Exception:\s*'), '').replaceFirst(RegExp(r'^Error:\s*'), '');

    showErrorToast(
        context,
        label: "Error",
        message: cleanMessage,
        labelColor: AppColors.error, // Standard error color natively
    );
  }

  /// Displays the custom built SnackBar Error Toast
  static void showErrorToast(
    BuildContext? context, {
    required String label,
    required String message,
    Color? labelColor,
  }) {
    // Attempt to use global context if not provided
    final BuildContext? targetContext = context ?? NavigationService.messengerKey.currentContext;

    if (targetContext == null) return;

    final color = labelColor ?? unexpectedErrorColor;

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: SvgPicture.asset(
                'assets/parchi-icon.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // To keep container compact
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
      duration: const Duration(seconds: 4),
    );

    ScaffoldMessenger.of(targetContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// Displays a custom built SnackBar Success Toast
  static void showSuccessToast(
    BuildContext? context, {
    required String label,
    required String message,
  }) {
    // Attempt to use global context if not provided
    final BuildContext? targetContext = context ?? NavigationService.messengerKey.currentContext;

    if (targetContext == null) return;

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF388E3C), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2.0),
              child: Icon(Icons.check_circle_outline, color: Color(0xFF388E3C), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
      duration: const Duration(seconds: 4),
    );

    ScaffoldMessenger.of(targetContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
