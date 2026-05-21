import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/user_provider.dart';
import '../../utils/colours.dart';

const _stepCount = 3;
const _autoCycleDuration = Duration(seconds: 4);

class HowToClaimGuideDialog extends ConsumerStatefulWidget {
  const HowToClaimGuideDialog({super.key});

  @override
  ConsumerState<HowToClaimGuideDialog> createState() =>
      _HowToClaimGuideDialogState();
}

class _HowToClaimGuideDialogState extends ConsumerState<HowToClaimGuideDialog> {
  late PageController _pageController;
  int _currentStep = 0;
  Timer? _autoCycleTimer;

  static const _steps = [
    _GuideStepData(
      icon: Icons.badge_outlined,
      title: 'Your Parchi ID',
      body:
          'Find your unique Parchi ID on your home screen card or profile. This is what you share at the counter.',
    ),
    _GuideStepData(
      icon: Icons.storefront_outlined,
      title: 'Tell the cashier',
      body:
          'At dine-in or takeaway, say you\'re using Parchi and give your Parchi ID. The cashier verifies you and applies the offer you want.',
    ),
    _GuideStepData(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Or scan the QR code',
      body:
          'Tap the blue scan button on this page, scan the merchant\'s QR code, then follow the prompts to redeem.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoCycle();
  }

  @override
  void dispose() {
    _autoCycleTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoCycle() {
    _autoCycleTimer?.cancel();
    _autoCycleTimer = Timer.periodic(_autoCycleDuration, (_) {
      if (!mounted) return;
      final next = (_currentStep + 1) % _stepCount;
      _goToStep(next, fromAuto: true);
    });
  }

  void _resetAutoCycle() {
    _startAutoCycle();
  }

  Future<void> _goToStep(int index, {bool fromAuto = false}) async {
    if (!mounted || index == _currentStep) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
    if (!fromAuto) _resetAutoCycle();
  }

  void _nextStep() {
    if (_currentStep < _stepCount - 1) {
      _goToStep(_currentStep + 1);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  void _close() {
    _autoCycleTimer?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              SizedBox(
                height: 300,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentStep = index),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stepCount,
                  itemBuilder: (context, index) {
                    return _buildStep(
                      data: _steps[index],
                      step: index,
                      userAsync: userAsync,
                    );
                  },
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.secondary.withOpacity(0.12),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SvgPicture.asset(
              'assets/parchi-icon.svg',
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to claim',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Step ${_currentStep + 1} of $_stepCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _close,
            icon: Icon(
              Icons.close_rounded,
              size: 22,
              color: AppColors.textSecondary.withOpacity(0.8),
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.7),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_stepCount, (index) {
          final isActive = index == _currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: isActive ? 28 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepDots(),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_currentStep > 0)
                TextButton(
                  onPressed: _prevStep,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text(
                    'Back',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                )
              else
                const SizedBox(width: 8),
              const Spacer(),
              SizedBox(
                width: _currentStep < _stepCount - 1 ? 140 : 160,
                child: ElevatedButton(
                  onPressed:
                      _currentStep < _stepCount - 1 ? _nextStep : _close,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _currentStep < _stepCount - 1 ? 'Next' : 'Got it',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required _GuideStepData data,
    required int step,
    required AsyncValue userAsync,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.14),
                    AppColors.secondary.withOpacity(0.25),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                data.icon,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.95),
                height: 1.55,
              ),
            ),
            if (step == 0) _buildParchiIdChip(userAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildParchiIdChip(AsyncValue userAsync) {
    return userAsync.when(
      data: (user) {
        if (user?.parchiId == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.06),
                  AppColors.secondary.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fingerprint_rounded,
                  size: 18,
                  color: AppColors.primary.withOpacity(0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  user!.parchiId!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _GuideStepData {
  final IconData icon;
  final String title;
  final String body;

  const _GuideStepData({
    required this.icon,
    required this.title,
    required this.body,
  });
}
