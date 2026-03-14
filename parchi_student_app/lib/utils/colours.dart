import 'package:flutter/material.dart';

// This class contains the primary color palette for the application.
// Using static const ensures these colors are accessible globally without
// needing an instance of the class (e.g., AppColors.primary).
class AppColors {
  // --- Primary Brand Colors ---
  // Used for:
  // - Parchi Card Gradient End (parchi_card.dart)
  // - Active Buttons & Tab Icons (main.dart)
  // - Link Text (login_form.dart, signup_verification_screen.dart)
  // - Arrow Icons (profile_screen.dart)

    // new blue that we have been using

    // static const Color primary = Color(0xFF007AFF);

    // dull blue parchi original
    // static const Color primary = Color(0xFF326295); 

    // testing another blue
    // static const Color primary = Color(0xFF1581BF); 

    // static const Color primary = Color(0xFF0573eb); 

    static const Color primary = Color(0xFF0069db);

  // Used for:
  // - Main App Background (Top Section)
  // - Leaderboard Top 3 Ranks (leaderboard_screen.dart)
  // - Stats Progress Ring (home_sheet_content.dart)
  // - Profile Screen Background (profile_screen.dart)
  static const Color secondary = Color(0xFFFFF700);

  // Used for:
  // - Success messages & Tags
  // - "Total Saved" green text (home_sheet_content.dart)
  // - Redemption History Icon Background (profile_screen.dart)
  static const Color accent = Color(0xFF34C759); // A bright green
  static const Color bonus = Color(0xFFFF6A39); // Bonus Orange

  // --- Background/Surface Colors ---
  // Used for:
  // - The rounded white sheet background (home_sheet_content.dart)
  // - Scaffold Background (main.dart)
  // - Avatar Background (profile_screen.dart)
  static const Color backgroundLight = Colors.white; // Light grey background

  // Used for:
  // - Parchi Card Gradient Start (parchi_card.dart)
  // - Login/Signup Backgrounds (if applicable)
  // - Dark Mode Text Contrast
  static const Color backgroundDark =
      Color(0xFF1C1C1E); // Dark charcoal background

  // Used for:
  // - Search Bar background
  // - Bottom Navigation Bar (main.dart)
  // - Brand Logo backgrounds (brand_card.dart)
  static const Color surface =
      Color(0xFFFFFFFF); // Pure white for cards/surfaces

  // --- New Design System Colors ---
  static const Color lightSurface = Color(0xFFFFFFFF); // The Surface: Main cards, search bars, and modal bodies.
  static const Color lightCanvas  = Color(0xFFFAFBFB); // The Canvas: The global background that makes white cards "pop."

  static const Color surfaceVariant =
      Color(0xFFF5F5F5); // Light grey for search bar and other elements

  // --- Text/Content Colors ---
  // Used for:
  // - Main Headings ("Top Brands", "Up to 30% off")
  // - Restaurant Names (restaurant_big_card.dart)
  // - AppBar Titles (main.dart)
  static const Color textPrimary = Color(0xFF1C1C1E);

  // Used for:
  // - Subtitles & Hints
  // - Search bar placeholder
  // - Unselected Icons (main.dart)
  // - Delivery Times (restaurant_mini_card.dart)
  static const Color textSecondary = Color(0xFF8E8E93);

  // Used for:
  // - Clickable links (login_form.dart)
  static const Color textLink = primary;

  // Used for:
  // - Text inside the Parchi Card (Name, ID) (parchi_card.dart)
  // - Button Text on Primary Buttons
  static const Color textOnPrimary = Colors.white;

  // --- Utility Colors ---
  // Used for:
  // - "30% OFF" tags on Restaurant cards
  // - Error Messages (login_form.dart)
  // - Logout Icon & Text (profile_screen.dart)
  static const Color error = Color(0xFFFF3B30); // Red for errors/danger

  // Used for:
  // - Positive stats displays
  static const Color success = accent;

  // Used for:
  // - Warnings (Generic)
  static const Color warning = Color(0xFFFFCC00); // Yellow for warnings

  // --- Auth Gradients ---
  // Used for: Login and Signup Backgrounds
  static const Color authGradientStart = Color(0xFF0B1021);
  static const Color authGradientMid = Color(0xFF1B2845);
  static const Color authGradientEnd = Color(0xFF274060);

  // Used for: Verification Screen Background
  static const Color verificationGradientStart = Color(0xFFE8F5E9);
  static const Color verificationGradientEnd = Color(0xFFF5F7FA);

  // --- Premium/Gold Colors ---
  // Used for: Parchi Card Gold Mode
  static const Color goldStart = Color(0xFFDAA520);
  static const Color goldMid = Color(0xFFFFD700);
  static const Color goldEnd = Color(0xFFB8860B);
  static const Color goldShadow = Colors.amber;

  // Used for:
  // - Profile Screen Header SVG & Ring
  static const Color parchiGold = Color(0xFFE3E935);
  
  // Founders Club
  static const Color foundersClub = Color(0xFFFF6A39);
}
