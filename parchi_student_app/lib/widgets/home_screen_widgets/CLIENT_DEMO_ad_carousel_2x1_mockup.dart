// =========================================================
// CLIENT DEMO MOCKUP — NOT FOR PRODUCTION
// =========================================================
// Shows what a 2:1 sponsored ad carousel would look like right under the
// "Top Brands" grid. Cycles through sample_ads/wide-ad.webp and
// sample_ads/wide-ad2.webp — there is no backend, ad provider, or tracking
// wired up. Delete this file (and its single usage in home_sheet_content.dart)
// once the client has reviewed the placement.
import 'dart:async';
import 'package:flutter/material.dart';

class AdCarousel2x1Mockup extends StatefulWidget {
  const AdCarousel2x1Mockup({super.key});

  @override
  State<AdCarousel2x1Mockup> createState() => _AdCarousel2x1MockupState();
}

class _AdCarousel2x1MockupState extends State<AdCarousel2x1Mockup> {
  static const List<String> _images = [
    'sample_ads/wide-ad.webp',
    'sample_ads/wide-ad2.webp',
  ];

  final PageController _controller = PageController();
  Timer? _autoPlayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final nextPage = (_currentPage + 1) % _images.length;
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 3.2 / 1,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _images.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) => Image.asset(
                      _images[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_images.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.black.withOpacity(0.7)
                      : Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
