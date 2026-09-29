import 'package:flutter/material.dart';
import '../screens/partner_verification/partner_verification_screen.dart';
import '../services/navigation_service.dart';
import 'verify_nav_guard.dart';

export 'verify_link_parser.dart' show extractVerifyRequestId, extractVerifyRequestIdFromRoute;
export 'verify_nav_guard.dart' show tryClaimVerifyNav;

String? extractRedeemBranchId(Uri uri) {
  try {
    if (uri.scheme == 'parchi' && uri.host == 'redeem') {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.pathSegments.contains('redeem')) {
      final idx = uri.pathSegments.indexOf('redeem');
      if (idx + 1 < uri.pathSegments.length) {
        return uri.pathSegments[idx + 1];
      }
    }
    if (uri.path.contains('/redeem/') || uri.host == 'redeem') {
      if (uri.pathSegments.contains('redeem')) {
        final index = uri.pathSegments.indexOf('redeem');
        if (index + 1 < uri.pathSegments.length) {
          return uri.pathSegments[index + 1];
        }
      } else if (uri.host == 'redeem' && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      return uri.queryParameters['branchId'];
    }
  } catch (_) {}
  return null;
}

/// Opens the approve screen for a link/notification. Safe to call more than once for the
/// same request. If the navigator is not ready yet (cold start), retries for a few frames
/// BEFORE claiming, so an early call never burns the dedupe window.
void openPartnerVerificationScreen(
  String requestId, {
  bool viaQr = false,
  int attemptsLeft = 30,
}) {
  final nav = NavigationService.navigatorKey.currentState;
  if (nav == null) {
    if (attemptsLeft <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openPartnerVerificationScreen(
        requestId,
        viaQr: viaQr,
        attemptsLeft: attemptsLeft - 1,
      );
    });
    // Make sure a frame is actually scheduled even if the app is idle.
    WidgetsBinding.instance.scheduleFrame();
    return;
  }

  if (!tryClaimVerifyNav(requestId)) return;
  nav.push(
    MaterialPageRoute(
      builder: (_) => PartnerVerificationScreen(requestId: requestId, viaQr: viaQr),
    ),
  );
}
