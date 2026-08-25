// =========================================================
// CLIENT DEMO MOCKUP — NOT FOR PRODUCTION
// =========================================================
// Shows what a 3.2:1 sponsored ad banner would look like right under the
// "Top Brands" grid. Renders a static sample image from assets/3.2-1-ad.png —
// there is no backend, ad provider, or tracking wired up. Delete this file
// (and its single usage in home_sheet_content.dart) once the client has
// reviewed the placement.
import 'package:flutter/material.dart';

class AdCarousel2x1Mockup extends StatelessWidget {
  const AdCarousel2x1Mockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: AspectRatio(
        aspectRatio: 3.2 / 1,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/3.2-1-ad.png',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Ad",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
