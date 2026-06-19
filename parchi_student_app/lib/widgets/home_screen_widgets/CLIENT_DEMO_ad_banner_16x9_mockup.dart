// =========================================================
// CLIENT DEMO MOCKUP — NOT FOR PRODUCTION
// =========================================================
// This widget shows what a 16:9 sponsored ad banner would look like directly
// under the ParchiCard on the home screen. It renders a static sample image
// from sample_ads/16_9.jpeg — there is no backend, ad provider, or tracking
// wired up. Delete this file (and its single usage in home_sheet_content.dart)
// once the client has reviewed the placement.
import 'package:flutter/material.dart';

class AdBanner16x9Mockup extends StatelessWidget {
  const AdBanner16x9Mockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'sample_ads/16_9.jpeg',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
