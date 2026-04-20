import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colours.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String? title;
  final String? message;
  final bool isMaintenance;

  const ForceUpdateScreen({
    super.key,
    this.title,
    this.message,
    this.isMaintenance = false,
  });

  @override
  Widget build(BuildContext context) {
    // WillPopScope or PopScope prevents back button navigation
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isMaintenance ? Icons.engineering : Icons.system_update_alt,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              Text(
                title ?? (isMaintenance ? "Under Maintenance" : "New Version Available"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Hagrid',
                  fontFamilyFallback: ['sans-serif'],
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message ?? (isMaintenance 
                  ? "We're currently performing some scheduled maintenance to improve your experience. We'll be back shortly!"
                  : "To keep your Parchiyan safe and enjoy the latest deals, please update the app."),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              if (!isMaintenance)
                ElevatedButton(
                  onPressed: _launchStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Update Now",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchStore() {
    final url = Platform.isAndroid
        ? 'https://play.google.com/store/apps/details?id=com.parchi.student'
        : 'https://apps.apple.com/app/idYOUR_APP_ID';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
