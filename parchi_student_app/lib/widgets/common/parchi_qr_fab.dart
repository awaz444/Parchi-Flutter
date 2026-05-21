import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/user_provider.dart';
import '../../screens/qr_scan/qr_scan_screen.dart';
import '../../utils/colours.dart';
import 'guest_login_prompt.dart';

class QrScanLauncher {
  static void open(BuildContext context, WidgetRef ref) {
    final userAsync = ref.read(userProfileProvider);
    final bool isAuthenticated = userAsync.maybeWhen(
      data: (user) => user != null,
      orElse: () => false,
    );

    if (!isAuthenticated) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const GuestLoginPrompt(
          title: 'Sign in to scan QR codes',
          subtitle: 'QR redemption is only available to signed-in students.',
          icon: Icons.qr_code_scanner_rounded,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
  }
}

class ParchiQrFab extends ConsumerWidget {
  const ParchiQrFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      backgroundColor: AppColors.primary,
      shape: const CircleBorder(),
      elevation: 6,
      onPressed: () => QrScanLauncher.open(context, ref),
      child: SvgPicture.asset(
        'assets/scan-svgrepo-com.svg',
        width: 26,
        height: 26,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
}