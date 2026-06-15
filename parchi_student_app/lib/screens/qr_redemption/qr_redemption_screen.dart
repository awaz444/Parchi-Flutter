import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/api_config.dart';
import '../../providers/user_provider.dart';
import '../../providers/redemption_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/colours.dart';
import '../../widgets/common/guest_login_prompt.dart';

// ── Phase enum ─────────────────────────────────────────────────────────────

enum _QrPhase { initiating, pending, success, rejected, expired, error }

// ── Screen ────────────────────────────────────────────────────────────────

class QrRedemptionScreen extends ConsumerStatefulWidget {
  final String branchId;

  const QrRedemptionScreen({super.key, required this.branchId});

  @override
  ConsumerState<QrRedemptionScreen> createState() => _QrRedemptionScreenState();
}

class _QrRedemptionScreenState extends ConsumerState<QrRedemptionScreen>
    with TickerProviderStateMixin {
  _QrPhase _phase = _QrPhase.initiating;
  String? _requestId;
  String? _offerTitle;
  String? _formattedDiscount;
  bool _isBonusApplied = false;
  num? _bonusDiscountApplied;
  String? _merchantBusinessName;
  String? _rejectionReason;
  String? _errorMessage;
  DateTime? _expiresAt;

  // Animations
  late final AnimationController _pulseController;
  late final AnimationController _checkController;
  late final AnimationController _morphController;
  late final AnimationController _successFadeController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _checkAnimation;
  late final Animation<double> _morphAnimation;
  late final Animation<double> _successFadeAnimation;
  late final AnimationController _timerController;

  // Branch/offer selection
  List<dynamic> _offers = [];
  String? _selectedOfferId;
  bool _isLoadingOffers = true;
  String? _branchName;
  String? _merchantLogo;

  bool _isInitiating = false;
  RealtimeChannel? _realtimeChannel;
  Timer? _expiryTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnimation = CurvedAnimation(parent: _checkController, curve: Curves.elasticOut);

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _morphAnimation = CurvedAnimation(parent: _morphController, curve: Curves.easeInOutBack);

    _checkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _morphController.forward();
          }
        });
      }
    });

    _successFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _successFadeAnimation = CurvedAnimation(parent: _successFadeController, curve: Curves.easeOut);

    _timerController = AnimationController(vsync: this, duration: const Duration(minutes: 2));

    _loadOffers();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _checkController.dispose();
    _morphController.dispose();
    _successFadeController.dispose();
    _timerController.dispose();
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadOffers() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/qr-redemptions/branch/${widget.branchId}/offers');
      // Pre-warm auth token concurrently — by the time _initiateRequest() runs it hits the cache
      authService.getToken().then((_) {}).catchError((_) {});
      final response = await authService.publicGet(uri.toString());
      if (!mounted) return;
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        final branchData = data['data'];
        setState(() {
          _branchName = branchData['branch']?['branchName'];
          _merchantLogo = branchData['branch']?['merchant']?['logoPath'];
          _merchantBusinessName = branchData['branch']?['merchant']?['businessName'];
          _offers = branchData['offers'] ?? [];
          _isLoadingOffers = false;
          if (_offers.length == 1) {
            _selectedOfferId = _offers[0]['id'];
          }
        });
        // Single offer: skip the picker and initiate immediately
        if (_offers.length == 1) {
          _initiateRequest();
        }
      } else {
        setState(() {
          _isLoadingOffers = false;
          _phase = _QrPhase.error;
          _errorMessage = 'No active offers at this branch right now.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingOffers = false;
        _phase = _QrPhase.error;
        _errorMessage = 'Failed to load branch offers.';
      });
    }
  }

  void _applyRedemptionSummary(Map<String, dynamic>? redemption) {
    if (redemption == null) return;
    setState(() {
      _isBonusApplied = redemption['isBonusApplied'] ?? false;
      _bonusDiscountApplied = redemption['bonusDiscountApplied'];

      // Load offer fields if present in the response
      if (redemption['offer'] != null) {
        _offerTitle = redemption['offer']['title'] ?? _offerTitle;
        _formattedDiscount = redemption['offer']['formattedDiscount'] ?? _formattedDiscount;
      }

      // Load branch/merchant fields if present in the response
      if (redemption['branch'] != null) {
        _branchName = redemption['branch']['branchName'] ?? _branchName;
        if (redemption['branch']['merchant'] != null) {
          _merchantBusinessName = redemption['branch']['merchant']['businessName'] ?? _merchantBusinessName;
          _merchantLogo = redemption['branch']['merchant']['logoPath'] ?? _merchantLogo;
        }
      }
    });
  }

  /// Refresh home/profile/history stats so QR redemptions appear without pull-to-refresh.
  Future<void> _refreshRedemptionProviders() async {
    try {
      await Future.wait([
        ref.refresh(redemptionStatsProvider.future),
        ref.refresh(redemptionStatsMonthlyProvider.future),
        ref.refresh(userProfileProvider.future),
        ref.read(redemptionHistoryProvider.notifier).refresh(),
        ref.read(leaderboardProvider('alltime').notifier).refresh(),
        ref.read(leaderboardProvider('monthly').notifier).refresh(),
      ]);
    } catch (_) {
      // Non-critical — pull-to-refresh remains available
    }
  }

  Future<void> _initiateRequest() async {
    if (_selectedOfferId == null || _isInitiating) return;
    _isInitiating = true;
    setState(() => _phase = _QrPhase.initiating);

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/qr-redemptions/initiate');
      final response = await authService.authenticatedPost(uri.toString(), body: {
        'branchId': widget.branchId,
        'offerId': _selectedOfferId,
      });

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['data'] != null) {
        final result = data['data'];
        _requestId = result['requestId'];

        // Capture offer details for the success screen
        final selectedOffer = _offers.firstWhere(
          (o) => o['id'] == _selectedOfferId,
          orElse: () => null,
        );
        _offerTitle = selectedOffer?['title'];
        _formattedDiscount = selectedOffer?['formattedDiscount'];

        if (result['autoApproved'] == true) {
          // Skip pending — jump straight to success
          HapticFeedback.heavyImpact();
          _applyRedemptionSummary(result['redemption']);
          _refreshRedemptionProviders();
          setState(() {
            _phase = _QrPhase.success;
          });
          _successFadeController.forward();
          _checkController.forward();
        } else {
          // Manual approval — go to pending and subscribe to Realtime
          final expiresAt = DateTime.tryParse(result['expiresAt'] ?? '');
          setState(() {
            _phase = _QrPhase.pending;
            _expiresAt = expiresAt;
          });
          if (expiresAt != null) {
            final remaining = expiresAt.difference(DateTime.now());
            if (remaining > Duration.zero) {
              _timerController.forward(from: 0);
              _expiryTimer = Timer(remaining, _handleExpiry);
            }
          }
          _subscribeToRealtime(_requestId!);
        }
      } else {
        final msg = data['message'] ?? 'Failed to initiate request';
        setState(() {
          _phase = _QrPhase.error;
          _errorMessage = msg is List ? msg.join(', ') : msg.toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _QrPhase.error;
        _errorMessage = 'Network error. Please try again.';
      });
    }
  }

  void _subscribeToRealtime(String requestId) {
    final client = Supabase.instance.client;
    // No server-side filter — row-level filters silently drop when RLS blocks them.
    // We filter client-side instead, which always works.
    _realtimeChannel = client
        .channel('qr-student-$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'qr_redemption_requests',
          callback: (payload) {
            if (!mounted) return;
            if (payload.newRecord['id'] != requestId) return;
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus == 'pending') return;
            _handleStatusChange(newStatus);
          },
        )
        .subscribe();

    // Polling fallback: fires every 3 s in case Realtime drops the event
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _phase != _QrPhase.pending) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final uri = Uri.parse('${ApiConfig.baseUrl}/qr-redemptions/status/$requestId');
        final response = await authService.authenticatedGet(uri.toString());
        if (!mounted) return;
        final data = jsonDecode(response.body);
        final status = data['data']?['status'] as String?;
        if (status != null && status != 'pending') {
          _pollTimer?.cancel();
          _handleStatusChange(status, responseData: data);
        }
      } catch (_) {}
    });
  }

  Future<void> _fetchFinalStatusAndShowSuccess() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/qr-redemptions/status/$_requestId');
      final response = await authService.authenticatedGet(uri.toString());
      if (!mounted) return;
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        _applyRedemptionSummary(data['data']['redemption']);
      }
    } catch (_) {}
    _refreshRedemptionProviders();
    if (mounted) {
      setState(() => _phase = _QrPhase.success);
      _pulseController.stop();
      _successFadeController.forward();
      _checkController.forward();
    }
  }

  void _handleStatusChange(String? status, {Map<String, dynamic>? responseData}) {
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    _realtimeChannel?.unsubscribe();

    switch (status) {
      case 'approved':
      case 'auto_approved':
        HapticFeedback.heavyImpact();
        if (responseData != null && responseData['data']?['redemption'] != null) {
          _applyRedemptionSummary(responseData['data']['redemption']);
          _refreshRedemptionProviders();
          setState(() => _phase = _QrPhase.success);
          _pulseController.stop();
          _successFadeController.forward();
          _checkController.forward();
        } else {
          _fetchFinalStatusAndShowSuccess();
        }
        break;
      case 'rejected':
        HapticFeedback.mediumImpact();
        setState(() => _phase = _QrPhase.rejected);
        _pulseController.stop();
        break;
      case 'expired':
        setState(() => _phase = _QrPhase.expired);
        _pulseController.stop();
        break;
      default:
        break;
    }
  }

  void _handleExpiry() {
    if (!mounted || _phase != _QrPhase.pending) return;
    _realtimeChannel?.unsubscribe();
    setState(() => _phase = _QrPhase.expired);
    _pulseController.stop();
  }

  Future<void> _cancelRequest() async {
    if (_requestId == null) {
      Navigator.of(context).pop();
      return;
    }
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/qr-redemptions/$_requestId/cancel');
      await authService.authenticatedDelete(uri.toString());
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final bool isAuthenticated = userAsync.maybeWhen(
      data: (user) => user != null,
      orElse: () => false,
    );

    if (!isAuthenticated) {
      return const Scaffold(
        body: GuestLoginPrompt(
          title: 'Sign in to redeem',
          subtitle: 'You need a Parchi account to scan and redeem offers.',
          icon: Icons.qr_code_scanner_rounded,
        ),
      );
    }

    final bool isSuccess = _phase == _QrPhase.success;

    return Scaffold(
      backgroundColor: isSuccess ? const Color(0xFFFAFAFE) : AppColors.backgroundLight,
      extendBodyBehindAppBar: isSuccess,
      appBar: AppBar(
        backgroundColor: isSuccess ? Colors.transparent : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isSuccess ? const Color(0xFF2D2A3A) : AppColors.textPrimary,
          ),
          onPressed: _phase == _QrPhase.pending ? _cancelRequest : () => Navigator.of(context).pop(),
        ),
        title: isSuccess
            ? null
            : Text(
                _branchName ?? 'Redeem Offer',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingOffers) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    switch (_phase) {
      case _QrPhase.initiating:
        return _buildInitiating();
      case _QrPhase.pending:
        return _buildPending();
      case _QrPhase.success:
        return _buildSuccess();
      case _QrPhase.rejected:
        return _buildRejected();
      case _QrPhase.expired:
        return _buildExpired();
      case _QrPhase.error:
        return _buildError();
    }
  }

  // ── Phase: Offer selection + Initiating ──────────────────────────────────

  Widget _buildInitiating() {
    // If offers are loaded but user hasn't initiated yet, show offer picker
    if (_offers.isEmpty) {
      return _buildError();
    }

    if (_offers.length > 1 && _selectedOfferId == null) {
      return _buildOfferPicker();
    }

    // Show pulsing animation while API call is in flight
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: Center(
                child: _merchantLogo != null
                    ? ClipOval(
                        child: Image.network(_merchantLogo!, width: 70, height: 70, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.store_outlined, size: 50, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connecting to branch...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferPicker() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select an offer to redeem',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This branch has multiple active offers. Choose one to continue.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: _offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final offer = _offers[i];
                final isSelected = _selectedOfferId == offer['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedOfferId = offer['id']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (offer['description'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  offer['description'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                offer['formattedDiscount'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedOfferId == null ? null : _initiateRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase: Pending ────────────────────────────────────────────────────────

  Widget _buildPending() {
    final timeLeft = _expiresAt != null
        ? _expiresAt!.difference(DateTime.now())
        : const Duration(minutes: 5);
    final totalSeconds = timeLeft.inSeconds.clamp(0, 300).toDouble();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Branch logo with pulse ring
          Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                  ),
                ),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: _merchantLogo != null
                    ? ClipOval(
                        child: Image.network(_merchantLogo!, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.store_outlined, size: 44, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Waiting for approval...',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _offerTitle ?? '',
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (_formattedDiscount != null) ...[
            const SizedBox(height: 4),
            Text(
              _formattedDiscount!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Progress timer bar
          if (_expiresAt != null)
            Column(
              children: [
                AnimatedBuilder(
                  animation: _timerController,
                  builder: (_, __) {
                    final elapsed = DateTime.now().difference(_expiresAt!.subtract(Duration(seconds: totalSeconds.toInt())));
                    final progress = 1.0 - (elapsed.inSeconds / totalSeconds).clamp(0.0, 1.0);
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress > 0.3 ? AppColors.primary : AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (_, __) {
                            final remaining = _expiresAt!.difference(DateTime.now());
                            if (remaining.isNegative) return const SizedBox.shrink();
                            final m = remaining.inMinutes;
                            final s = remaining.inSeconds % 60;
                            return Text(
                              '$m:${s.toString().padLeft(2, '0')} remaining',
                              style: TextStyle(
                                fontSize: 13,
                                color: remaining.inSeconds < 60 ? AppColors.error : AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: _cancelRequest,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase: Success ────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return FadeTransition(
      opacity: _successFadeAnimation,
      child: _buildSuccessContent(),
    );
  }

  Widget _buildSuccessContent() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFEEF2FE), // Very soft Parchi blue tint
            Color(0xFFF9FAFF),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'ALL DONE!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Color(0xFF2D2A3A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Confetti/particles floating around the checkmark
                          ..._buildConfettiParticles(),

                          // Outer glowing checkmark
                          ScaleTransition(
                            scale: _checkAnimation,
                            child: _FlippingSuccessIcon(
                              animation: _morphAnimation,
                              front: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE2FBE9),
                                  border: Border.all(color: const Color(0xFFB3F5C7), width: 2),
                                ),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        spreadRadius: 4,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 46,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              back: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE8F1FF), // Soft Parchi blue halo
                                  border: Border.all(color: const Color(0xFFB3D4FF), width: 2),
                                ),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0069db).withValues(alpha: 0.15),
                                        blurRadius: 20,
                                        spreadRadius: 4,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/parchi-app-icon.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _formattedDiscount ?? "Discount",
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D2A3A),
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Discount Unlocked',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (_offerTitle != null) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _offerTitle!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Container(
                        width: 48,
                        height: 1.5,
                        color: const Color(0xFFE5E5EA), // Light grey divider line
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'REDEEMED AT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _merchantBusinessName ?? _branchName ?? "Parchi Merchant",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D2A3A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_merchantBusinessName != null && _branchName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _branchName!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_isBonusApplied) ...[
                        const SizedBox(height: 48),
                        _buildPremiumBonusSection(),
                        const SizedBox(height: 48),
                      ] else ...[
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConfettiParticles() {
    return [
      // Left orange bar
      Positioned(
        top: 30,
        left: 15,
        child: Transform.rotate(
          angle: -0.4,
          child: Container(
            width: 8,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      // Left pink dot
      Positioned(
        bottom: 40,
        left: 25,
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: Color(0xFFFF4081),
            shape: BoxShape.circle,
          ),
        ),
      ),
      // Right pink crescent-like shape
      Positioned(
        top: 40,
        right: 15,
        child: Transform.rotate(
          angle: 0.6,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4081).withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ),
        ),
      ),
      // Right orange bar
      Positioned(
        bottom: 30,
        right: 20,
        child: Transform.rotate(
          angle: 0.5,
          child: Container(
            width: 8,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      // Left blue bar
      Positioned(
        top: 90,
        left: 5,
        child: Transform.rotate(
          angle: 0.8,
          child: Container(
            width: 6,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
      // Right yellow star
      const Positioned(
        top: 100,
        right: 5,
        child: Icon(
          Icons.star_rounded,
          color: Color(0xFFFFD600),
          size: 14,
        ),
      ),
    ];
  }

  Widget _buildPremiumBonusSection() {
    return CustomPaint(
      painter: TicketPainter(
        borderColor: const Color(0xFFB8860B),
        borderRadius: 16,
        clipRadius: 10,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 20, right: 16, top: 16, bottom: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2205).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2C2205).withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: Color(0xFF2C2205),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LOYALTY BONUS UNLOCKED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2C2205),
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Additional discount applied!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A3B12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            if (_bonusDiscountApplied != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2205), // Dark luxury bronze contrast capsule
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _bonusDiscountApplied! > 0
                      ? "+ Rs. ${_bonusDiscountApplied!.toInt()}"
                      : "Free Reward",
                  style: const TextStyle(
                    color: Color(0xFFFFF6D1), // Champagne text on dark capsule
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: const Text(
          'DONE',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  // ── Phase: Rejected ───────────────────────────────────────────────────────

  Widget _buildRejected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.close_rounded, size: 72, color: AppColors.error),
            ),
            const SizedBox(height: 28),
            const Text(
              'Request Rejected',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (_rejectionReason != null && _rejectionReason!.isNotEmpty)
              Text(
                _rejectionReason!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                textAlign: TextAlign.center,
              )
            else
              const Text(
                'The branch declined this redemption.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase: Expired ────────────────────────────────────────────────────────

  Widget _buildExpired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.timer_off_outlined, size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 28),
            const Text(
              'Request Expired',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "The branch didn't respond in time.\nPlease try scanning again.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase: Error ──────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 80, color: AppColors.error),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'Something went wrong.',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlippingSuccessIcon extends AnimatedWidget {
  final Widget front;
  final Widget back;

  const _FlippingSuccessIcon({
    required Animation<double> animation,
    required this.front,
    required this.back,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final double value = animation.value;
    final double angle = value * 3.141592653589793;
    final bool isFront = angle < 3.141592653589793 / 2;

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // perspective
        ..rotateY(angle),
      alignment: Alignment.center,
      child: isFront
          ? front
          : Transform(
              transform: Matrix4.identity()..rotateY(3.141592653589793),
              alignment: Alignment.center,
              child: back,
            ),
    );
  }
}

class TicketPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double clipRadius;

  TicketPainter({
    required this.borderColor,
    this.borderRadius = 16.0,
    this.clipRadius = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw shadow first
    final shadowPaint = Paint()
      ..color = const Color(0xFFFF8F00).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    
    final path = Path();
    
    // Construct the ticket path with circular side notches
    path.moveTo(borderRadius, 0);
    path.lineTo(size.width - borderRadius, 0);
    
    path.arcToPoint(
      Offset(size.width, borderRadius),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );
    
    path.lineTo(size.width, size.height / 2 - clipRadius);
    path.arcToPoint(
      Offset(size.width, size.height / 2 + clipRadius),
      radius: Radius.circular(clipRadius),
      clockwise: false,
    );
    
    path.lineTo(size.width, size.height - borderRadius);
    path.arcToPoint(
      Offset(size.width - borderRadius, size.height),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );
    
    path.lineTo(borderRadius, size.height);
    
    path.arcToPoint(
      Offset(0, size.height - borderRadius),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );
    
    path.lineTo(0, size.height / 2 + clipRadius);
    path.arcToPoint(
      Offset(0, size.height / 2 - clipRadius),
      radius: Radius.circular(clipRadius),
      clockwise: false,
    );
    
    path.lineTo(0, borderRadius);
    path.arcToPoint(
      Offset(borderRadius, 0),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );
    
    path.close();

    // Paint shadow shifted down slightly
    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // 2. Draw ticket body with metallic gradient
    final gradient = const LinearGradient(
      colors: [
        Color(0xFFFFF7C2), // Light champagne/gold highlight
        Color(0xFFFFD54F), // Bright sunshine gold
        Color(0xFFFF8F00), // Rich orange gold
      ],
      stops: [0.0, 0.45, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Offset.zero & size);

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, paint);

    // 3. Draw inner shiny glow layer
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final innerPath = Path();
    const inset = 4.0;
    const innerRadius = 12.0;
    
    innerPath.moveTo(innerRadius + inset, inset);
    innerPath.lineTo(size.width - innerRadius - inset, inset);
    innerPath.arcToPoint(
      Offset(size.width - inset, innerRadius + inset),
      radius: const Radius.circular(innerRadius),
      clockwise: true,
    );
    innerPath.lineTo(size.width - inset, size.height / 2 - clipRadius - 2);
    innerPath.arcToPoint(
      Offset(size.width - inset, size.height / 2 + clipRadius + 2),
      radius: Radius.circular(clipRadius + 2),
      clockwise: false,
    );
    innerPath.lineTo(size.width - inset, size.height - innerRadius - inset);
    innerPath.arcToPoint(
      Offset(size.width - innerRadius - inset, size.height - inset),
      radius: const Radius.circular(innerRadius),
      clockwise: true,
    );
    innerPath.lineTo(innerRadius + inset, size.height - inset);
    innerPath.arcToPoint(
      Offset(inset, size.height - innerRadius - inset),
      radius: const Radius.circular(innerRadius),
      clockwise: true,
    );
    innerPath.lineTo(inset, size.height / 2 + clipRadius + 2);
    innerPath.arcToPoint(
      Offset(inset, size.height / 2 - clipRadius - 2),
      radius: Radius.circular(clipRadius + 2),
      clockwise: false,
    );
    innerPath.lineTo(inset, innerRadius + inset);
    innerPath.arcToPoint(
      const Offset(innerRadius + inset, inset),
      radius: const Radius.circular(innerRadius),
      clockwise: true,
    );
    innerPath.close();
    
    canvas.drawPath(innerPath, glowPaint);

    // 4. Draw dark gold border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    
    canvas.drawPath(path, borderPaint);

    // 5. Draw vertical dash divider line
    final dashPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    
    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 8.0;
    final double dashX = size.width - 108.0; // Leaves nice space for capsule on the right
    while (startY < size.height - 8.0) {
      canvas.drawLine(Offset(dashX, startY), Offset(dashX, startY + dashHeight), dashPaint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


