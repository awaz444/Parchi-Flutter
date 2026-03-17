import 'package:flutter/material.dart';
import '../../utils/colours.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          "Help Center",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFamily: 'Hagrid',
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Membership & Verification"),
              _buildFaqItem(
                "What is a \"Closed-Loop\" ecosystem?",
                "Parchi is a restricted environment. To maintain the quality and exclusivity of our offers, only verified students currently enrolled in a recognized Pakistani institution can access the platform.",
              ),
              _buildFaqItem(
                "How do I verify my student status?",
                "You can verify your account by uploading a clear photo of your valid Student ID or by using your university-issued email address (.edu.pk). Our team typically reviews and approves profiles within 24 hours.",
              ),
              _buildFaqItem(
                "My institute isn't listed. What should I do?",
                "We are rapidly expanding across Pakistan. If your institution isn't there yet, select \"Request Institute\" in the signup menu, and our campus expansion team will prioritize your location.",
              ),

              const SizedBox(height: 24),
              _buildSectionHeader("Redeeming Benefits (The \"Parchi\" System)"),
              _buildFaqItem(
                "How do I use a deal at a restaurant or shop?",
                "1. Find your Deal: Open the Parchi app and browse the \"Offers\" section to find a vendor you want to visit.\n\n"
                "2. Locate your Parchi ID: Your unique Parchi ID is displayed prominently on your home screen and profile. This is your digital student passport.\n\n"
                "3. Identify Yourself: When you’re at the counter (for dine-in or takeaway), simply tell the cashier: \"I’m using Parchi,\" and provide them with your Parchi ID.\n\n"
                "4. Vendor Validation: The cashier will enter your ID into their Parchi Dashboard to verify your active student status.\n\n"
                "5. Choose & Order: Once verified, tell the cashier which specific Parchi deal you’d like to claim. They will select it on their end and punch your order into their system.\n\n"
                "6. Done! Your redemption is instantly logged in your \"Activity History\" in the app, and you enjoy your student-exclusive pricing.",
              ),
              _buildFaqItem(
                "Can I use the same offer twice?",
                "This depends on the brand's policy. Each offer will clearly state if it is a \"One-Time Use\" or \"Recurring\" benefit.",
              ),
              _buildFaqItem(
                "The merchant is unfamiliar with Parchi. What now?",
                "Every partner merchant is trained to recognize the Parchi interface. If you encounter an issue, please use the \"Report a Problem\" button directly on the brand’s page in the app, and our merchant success team will intervene.",
              ),

              const SizedBox(height: 24),
              _buildSectionHeader("Data, Privacy & Security"),
              _buildFaqItem(
                "Is my data shared with brands?",
                "Your privacy is our priority. We provide brands with aggregated insights (e.g., \"1,000 students used this offer\"), but we never sell your personal contact information or individual data to third parties.",
              ),
              _buildFaqItem(
                "How do I delete my account?",
                "You can delete your account directly from the app:\n\n"
                "1. Go to your Profile screen.\n"
                "2. Tap the 'Delete Account' tile.\n"
                "3. Confirm the deletion in the dialog that appears.\n\n"
                "This will open our secure account deletion page where you can complete the process. Once confirmed, all your personal data and records are permanently and irreversibly removed from our servers.",
              ),

              const SizedBox(height: 24),
              _buildSectionHeader("Troubleshooting"),
              _buildFaqItem(
                "Why is my location access required?",
                "Parchi uses your location to show you the most relevant deals at your specific campus or in your current city.",
              ),
              _buildFaqItem(
                "I lost access to my university email.",
                "If you can no longer access your .edu email, please contact support with a photo of your updated semester fee challan or physical ID to recover your account.",
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Builder(
      builder: (context) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.surfaceVariant.withOpacity(0.5)),
          ),
          color: AppColors.surface,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                question,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              iconColor: AppColors.primary,
              collapsedIconColor: AppColors.textSecondary,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  answer,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}

// Simple Get context helper mock since looking at previous files didn't show GetX usage but context is needed for Theme.
// Wait, previous files show standard Riverpod/Flutter. I should use standard context passed to build or just Theme.of(context) if inside a widget.
// The ExpansionTile needs a context for Theme.of(context).
// I will adjust `_buildFaqItem` to take `BuildContext context` or remove the Theme wrapper if not strictly necessary,
// but the customized Theme wrapper is good for hiding dividers.
// Let's rewrite `_buildFaqItem` to use `Builder` or just standard styling.
// Actually standard ExpansionTile has `shape` and `collapsedShape` properties in newer Flutter versions to hide borders.
// But to be safe and compatible, wrapping in Theme with transparent divider color is a classic trick.
// Since `Get.context` is not guaranteed, I'll remove it.
// I'll rewrite the helper in the actual file writing call.
