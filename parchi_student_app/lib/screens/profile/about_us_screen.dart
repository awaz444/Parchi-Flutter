import 'package:flutter/material.dart';
import '../../utils/colours.dart';
import '../../widgets/common/hagrid_text.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const HagridText(
          "About Us",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo or Image could go here
              
              // Title Section
              const Text(
                "The Student Identity,\nReimagined.",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              
              // Intro Text
              _buildParagraph(
                "Parchi is Pakistan’s first closed-loop ecosystem built exclusively for the student community. We don't just offer deals; we provide the digital infrastructure that connects the country’s most ambitious demographic directly to the nation’s leading brands."
              ),
              const SizedBox(height: 12),
              _buildParagraph(
                "In a rapidly evolving economy, students are the primary drivers of growth, yet the gap between corporate giants and the campus lifestyle has always been wide. Parchi acts as the essential bridge. We simplify the exchange, ensuring that brands can reach students with precision, and students can access high-value utilities that were previously out of reach."
              ),
              
              const SizedBox(height: 32),
              const Divider(color: AppColors.surfaceVariant),
              const SizedBox(height: 32),

              // Why We Exist Section
              const Text(
                "Why We Exist:",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _buildBulletPoint(
                "Verified Exclusivity:",
                "Our verification system ensures that Parchi remains a sanctuary for students only."
              ),
              _buildBulletPoint(
                "National Reach:",
                "From Karachi to Kashmir, we are building a unified network that recognizes and rewards your status as a student, no matter which corner of Pakistan you call home."
              ),
              _buildBulletPoint(
                "A Purpose-Driven Ecosystem:",
                "We believe your student ID should be the most powerful card in your wallet. Parchi is here to make that a reality by unlocking exclusive benefits, career pathways, and financial utilities designed for your stage of life."
              ),

              const SizedBox(height: 32),

              // Footer Quote
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.parchiGold.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.parchiGold.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  "This is more than an app. This is the new standard for the Pakistani student.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    );
  }

  Widget _buildBulletPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            height: 8,
            width: 8,
            decoration: const BoxDecoration(
              color: AppColors.parchiGold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontFamily: 'Outfit', // Assuming global font is reused, but explicit safety
                ),
                children: [
                  TextSpan(
                    text: "$title\n",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
