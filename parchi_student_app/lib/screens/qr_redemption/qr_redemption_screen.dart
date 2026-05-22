import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/api_config.dart';
import '../../providers/user_provider.dart';
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
  late final AnimationController _successFadeController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _checkAnimation;
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

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: _phase == _QrPhase.pending ? _cancelRequest : () => Navigator.of(context).pop(),
        ),
        title: Text(
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ScaleTransition(
            scale: _checkAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
              child: const Icon(Icons.check_rounded, size: 60, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Redeemed!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _buildMerchantCard(),
          const SizedBox(height: 16),
          _buildOfferCard(),
          const SizedBox(height: 16),
          _buildBonusCard(),
          const SizedBox(height: 32),
          _buildDoneButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMerchantCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
              image: _merchantLogo != null
                  ? DecorationImage(
                      image: NetworkImage(_merchantLogo!), fit: BoxFit.cover)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _merchantLogo == null
                ? const Icon(Icons.store, size: 36, color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _merchantBusinessName ?? _branchName ?? "Parchi Merchant",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (_merchantBusinessName != null && _branchName != null) ...[
            const SizedBox(height: 4),
            Text(
              _branchName!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "WHAT YOU UNLOCKED",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          if (_offerTitle != null) ...[
            Text(
              _offerTitle!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            _formattedDiscount ?? "Discount",
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBonusCard() {
    if (_isBonusApplied) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF9C4), Color(0xFFFFF176)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Color(0xFFF57F17), size: 20),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFFF6A39)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Bonus Unlocked!",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (_bonusDiscountApplied != null) ...[
              const SizedBox(height: 12),
              Text(
                _bonusDiscountApplied! > 0
                    ? "Rs. $_bonusDiscountApplied OFF"
                    : "Free Item / Reward",
                style: const TextStyle(
                  color: Color(0xFFE65100),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _bonusDiscountApplied! > 0 ? "Additional Loyalty Discount" : "Special Item Reward",
                style: TextStyle(
                  color: const Color(0xFFE65100).withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
            SizedBox(width: 8),
            Text(
              "Standard Offer (No loyalty bonus this time)",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDoneButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
