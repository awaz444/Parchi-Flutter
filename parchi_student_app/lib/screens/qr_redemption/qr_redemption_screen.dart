import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  String? _rejectionReason;
  String? _errorMessage;
  DateTime? _expiresAt;

  // Animations
  late final AnimationController _pulseController;
  late final AnimationController _checkController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _checkAnimation;
  late final AnimationController _timerController;

  // Branch/offer selection
  List<dynamic> _offers = [];
  String? _selectedOfferId;
  bool _isLoadingOffers = true;
  String? _branchName;
  String? _merchantLogo;

  RealtimeChannel? _realtimeChannel;
  Timer? _expiryTimer;

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

    _timerController = AnimationController(vsync: this, duration: const Duration(minutes: 5));

    _loadOffers();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _checkController.dispose();
    _timerController.dispose();
    _expiryTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadOffers() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/qr-redemptions/branch/${widget.branchId}/offers');
      final response = await authService.publicGet(uri.toString());
      if (!mounted) return;
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        final branchData = data['data'];
        setState(() {
          _branchName = branchData['branch']?['branchName'];
          _merchantLogo = branchData['branch']?['merchant']?['logoPath'];
          _offers = branchData['offers'] ?? [];
          _isLoadingOffers = false;
          if (_offers.length == 1) {
            _selectedOfferId = _offers[0]['id'];
          }
        });
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

  Future<void> _initiateRequest() async {
    if (_selectedOfferId == null) return;
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
          setState(() {
            _phase = _QrPhase.success;
          });
          _checkController.forward();
          _scheduleAutoDismiss();
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
    _realtimeChannel = client
        .channel('qr-student-$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'qr_redemption_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: requestId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newStatus = payload.newRecord['status'] as String?;
            _handleStatusChange(newStatus);
          },
        )
        .subscribe();
  }

  void _handleStatusChange(String? status) {
    _expiryTimer?.cancel();
    _realtimeChannel?.unsubscribe();

    switch (status) {
      case 'approved':
        setState(() => _phase = _QrPhase.success);
        _pulseController.stop();
        _checkController.forward();
        _scheduleAutoDismiss();
        break;
      case 'rejected':
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

  void _scheduleAutoDismiss() {
    Timer(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context).pop();
    });
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _checkAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
                child: const Icon(Icons.check_rounded, size: 72, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Redeemed!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (_offerTitle != null)
              Text(
                _offerTitle!,
                style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            if (_formattedDiscount != null) ...[
              const SizedBox(height: 6),
              Text(
                _formattedDiscount!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
            if (_isBonusApplied) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFFF6A39)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '🎉 Bonus Unlocked!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
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
                child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
