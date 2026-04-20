import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A specialized Text widget that uses the 'Hagrid' font for letters
/// but automatically falls back to the default 'Outfit' font for digits.
/// This solves rendering issues where Hagrid lacks high-quality numeric glyphs.
class HagridText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  const HagridText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    // If the text contains any digits, we swap the WHOLE string to the default
    // app font (Outfit) to keep weights consistent and avoid typographic artifacts.
    // Otherwise, we use the brand font 'Hagrid'.
    final bool hasDigits = text.contains(RegExp(r'\d'));
    
    return Text(
      text,
      style: style.copyWith(
        fontFamily: hasDigits ? null : 'Hagrid',
        // If it's the fallback font for numbers, ensure it's still nice and bold
        fontWeight: hasDigits ? FontWeight.w800 : style.fontWeight,
      ),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
