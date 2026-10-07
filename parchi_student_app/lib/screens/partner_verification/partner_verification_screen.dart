import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/partner_discount_redemption_model.dart';
import '../../models/partner_verification_model.dart';
import '../../providers/user_provider.dart';
import '../../services/partner_verification_service.dart';
import '../../utils/colours.dart';
import '../../utils/verify_nav_guard.dart';
import '../../widgets/common/guest_login_prompt.dart';
import '../../widgets/common/redemption_success_view.dart';

enum _VerifyPhase { loading, pending, verified, redeemed, rejected, expired, error }

class PartnerVerificationScreen extends ConsumerStatefulWidget {
  final String requestId;

  /// True when the student scanned the partner's QR in-app. That already proves they are
  /// looking at the partner's screen, so number-matching is skipped. Push / link entry
  /// requires it.
  final bool viaQr;

  const PartnerVerificationScreen({
    super.key,
    required this.requestId,
    this.viaQr = false,
  });

  @override
  ConsumerState<PartnerVerificationScreen> createState() =>
      _PartnerVerificationScreenState();
}

class _PartnerVerificationScreenState
    extends ConsumerState<PartnerVerificationScreen> with WidgetsBindingObserver {
  static const Duration _basePollInterval = Duration(seconds: 5);
  static const Duration _maxPollInterval = Duration(seconds: 15);
  // Keep polling a little past expiry so the server-side expired state is picked up.
  static const Duration _pollGraceAfterExpiry = Duration(seconds: 20);
  static const Duration _discountPollInterval = Duration(seconds: 3);

  _VerifyPhase _phase = _VerifyPhase.loading;
  PartnerVerificationModel? _request;
  PartnerDiscountRedemptionModel? _discount;
  String? _errorMessage;
  bool _acting = false;
  String? _selectedCode;

  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _discountRealtimeChannel;
  Timer? _pollTimer;
  Timer? _expiryTimer;
  Timer? _discountPollTimer;
  bool _pollInFlight = false;
  bool _discountPollInFlight = false;
  int _pollFailures = 0;
  bool _loadStarted = false;

  /// serverTime - deviceTime, so countdown/expiry do not depend on a correct device clock.
  Duration _clockOffset = Duration.zero;
  DateTime get _now => DateTime.now().add(_clockOffset);

  @override
  void initState() {
    super.initState();
    markVerifyScreenOpen(widget.requestId);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    markVerifyScreenClosed(widget.requestId);
    _stopWatching();
    _stopDiscountWatching();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers are unreliable while suspended; refresh immediately on return.
    if (state == AppLifecycleState.resumed) {
      if (_phase == _VerifyPhase.pending) {
        _pollOnce();
      } else if (_phase == _VerifyPhase.verified) {
        _pollDiscountOnce();
      }
    }
  }

  // ── Loading / state ───────────────────────────────────────────────────────

  Future<void> _load() async {
    _loadStarted = true;
    try {
      final request = await partnerVerificationService.getRequest(widget.requestId);
      if (!mounted) return;
      _noteServerTime(request);
      await _applyStatus(request, startWatching: true);
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  void _showError(Object e) {
    var message = e.toString().replaceFirst('Exception: ', '');
    var phase = _VerifyPhase.error;

    if (e is PartnerVerificationException) {
      switch (e.statusCode) {
        case 404:
          message =
              'This request is not linked to your account. Make sure you are signed in with the account whose Parchi ID was entered.';
          break;
        case 410:
          phase = _VerifyPhase.expired;
          break;
        case 429:
          message = 'Too many attempts. Please wait a moment and try again.';
          break;
      }
    }

    _stopWatching();
    _stopDiscountWatching();
    setState(() {
      _phase = phase;
      _errorMessage = message;
    });
  }

  void _noteServerTime(PartnerVerificationModel request) {
    final serverTime = request.serverTime;
    if (serverTime != null) {
      _clockOffset = serverTime.difference(DateTime.now());
    }
  }

  Future<void> _applyStatus(
    PartnerVerificationModel request, {
    bool startWatching = false,
  }) async {
    // Terminal reject/expire are final; approved can still advance to redeemed.
    if (_phase == _VerifyPhase.redeemed) return;
    if (_request != null &&
        (_request!.status == 'rejected' || _request!.status == 'expired') &&
        request.status == 'pending') {
      return;
    }

    _request = request;
    switch (request.status) {
      case 'approved':
        _stopWatching();
        // Deep link / notification reopen: jump straight to paid success if logged.
        final existing = await _tryFetchDiscount();
        if (!mounted) return;
        if (existing != null) {
          _showRedeemed(existing);
          return;
        }
        setState(() => _phase = _VerifyPhase.verified);
        _watchDiscount();
        break;
      case 'rejected':
        _stopWatching();
        _stopDiscountWatching();
        setState(() => _phase = _VerifyPhase.rejected);
        break;
      case 'expired':
        _stopWatching();
        _stopDiscountWatching();
        setState(() => _phase = _VerifyPhase.expired);
        break;
      default:
        setState(() => _phase = _VerifyPhase.pending);
        if (startWatching) _watch(request);
        break;
    }
  }

  void _showRedeemed(PartnerDiscountRedemptionModel discount) {
    _stopWatching();
    _stopDiscountWatching();
    setState(() {
      _discount = discount;
      _phase = _VerifyPhase.redeemed;
    });
    HapticFeedback.heavyImpact();
  }

  Future<PartnerDiscountRedemptionModel?> _tryFetchDiscount() async {
    try {
      return await partnerVerificationService.getDiscountRedemption(widget.requestId);
    } on PartnerVerificationException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Realtime + polling (pending verification) ─────────────────────────────

  void _watch(PartnerVerificationModel request) {
    _stopWatching();

    final expiresAt = request.expiresAt;
    if (expiresAt != null) {
      final remaining = expiresAt.difference(_now);
      if (remaining <= Duration.zero) {
        _pollOnce();
      } else {
        _expiryTimer = Timer(remaining, () {
          if (!mounted || _phase != _VerifyPhase.pending) return;
          _pollOnce();
        });
      }
    }

    _realtimeChannel = Supabase.instance.client
        .channel('partner-verify-${widget.requestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'partner_verification_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.requestId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final status = payload.newRecord['status'] as String?;
            if (status == null || status == 'pending') return;
            _applyStatus(
              PartnerVerificationModel(
                id: widget.requestId,
                status: status,
                eventLabel: _request?.eventLabel,
                partnerName: _request?.partnerName ?? 'Partner',
                expiresAt: _request?.expiresAt,
              ),
            );
          },
        )
        .subscribe();

    _scheduleNextPoll();
  }

  Duration get _currentPollInterval {
    if (_pollFailures == 0) return _basePollInterval;
    final ms = _basePollInterval.inMilliseconds * math.pow(2, _pollFailures).toInt();
    return Duration(milliseconds: math.min(ms, _maxPollInterval.inMilliseconds));
  }

  bool get _pastPollingDeadline {
    final expiresAt = _request?.expiresAt;
    if (expiresAt == null) return false;
    return _now.isAfter(expiresAt.add(_pollGraceAfterExpiry));
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    if (!mounted || _phase != _VerifyPhase.pending) return;
    if (_pastPollingDeadline) return;
    _pollTimer = Timer(_currentPollInterval, () async {
      await _pollOnce();
      _scheduleNextPoll();
    });
  }

  Future<void> _pollOnce() async {
    if (_pollInFlight || !mounted) return;
    if (_phase != _VerifyPhase.pending && _phase != _VerifyPhase.loading) return;
    _pollInFlight = true;
    try {
      final latest = await partnerVerificationService.getRequest(widget.requestId);
      if (!mounted) return;
      _pollFailures = 0;
      _noteServerTime(latest);
      if (latest.isTerminal) await _applyStatus(latest);
    } catch (e) {
      if (!mounted) return;
      _pollFailures = math.min(_pollFailures + 1, 3);
      if (e is PartnerVerificationException && (e.statusCode == 404 || e.statusCode == 410)) {
        _showError(e);
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _stopWatching() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
  }

  // ── Discount watch (after approve, waiting for partner payment log) ───────

  void _watchDiscount() {
    _stopDiscountWatching();

    _discountRealtimeChannel = Supabase.instance.client
        .channel('partner-discount-${widget.requestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'partner_discount_redemptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'verification_request_id',
            value: widget.requestId,
          ),
          callback: (_) {
            if (!mounted || _phase != _VerifyPhase.verified) return;
            _pollDiscountOnce();
          },
        )
        .subscribe();

    _scheduleDiscountPoll();
  }

  void _scheduleDiscountPoll() {
    _discountPollTimer?.cancel();
    if (!mounted || _phase != _VerifyPhase.verified) return;

    _discountPollTimer = Timer(_discountPollInterval, () async {
      await _pollDiscountOnce();
      _scheduleDiscountPoll();
    });
  }

  Future<void> _pollDiscountOnce() async {
    if (_discountPollInFlight || !mounted) return;
    if (_phase != _VerifyPhase.verified) return;
    _discountPollInFlight = true;
    try {
      final discount = await _tryFetchDiscount();
      if (!mounted || discount == null) return;
      _showRedeemed(discount);
    } on PartnerVerificationException catch (e) {
      // 404 = not paid yet; keep waiting. Other errors: soft-fail and retry.
      if (e.statusCode == 404) return;
    } catch (_) {
      // Offline / 5xx: keep waiting.
    } finally {
      _discountPollInFlight = false;
    }
  }

  void _stopDiscountWatching() {
    _discountPollTimer?.cancel();
    _discountPollTimer = null;
    final channel = _discountRealtimeChannel;
    _discountRealtimeChannel = null;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  bool get _needsMatch =>
      !widget.viaQr && (_request?.matchOptions?.isNotEmpty ?? false);

  Future<void> _approve() async {
    if (_acting) return;
    if (_needsMatch && _selectedCode == null) return;
    setState(() => _acting = true);
    try {
      final updated = await partnerVerificationService.approve(
        widget.requestId,
        viaQr: widget.viaQr,
        matchCode: _selectedCode,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await _applyStatus(updated);
    } catch (e) {
      await _recoverAfterActionError(e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final updated = await partnerVerificationService.reject(widget.requestId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await _applyStatus(updated);
    } catch (e) {
      await _recoverAfterActionError(e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _recoverAfterActionError(Object original) async {
    if (!mounted) return;
    try {
      final truth = await partnerVerificationService.getRequest(widget.requestId);
      if (!mounted) return;
      _noteServerTime(truth);
      if (truth.isTerminal) {
        await _applyStatus(truth);
        return;
      }
    } catch (_) {
      // fall through to the original error
    }
    if (!mounted) return;
    _showError(original);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    ref.listen(userProfileProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null && _request == null && _loadStarted) {
        setState(() => _phase = _VerifyPhase.loading);
        _load();
      }
    });

    final knownGuest = userAsync.hasValue && userAsync.valueOrNull == null;
    if (knownGuest) {
      return const Scaffold(
        body: GuestLoginPrompt(
          title: 'Sign in to confirm',
          subtitle: 'You need a Parchi account to confirm this student discount.',
          icon: Icons.verified_user_outlined,
        ),
      );
    }

    final hideAppBar = _phase == _VerifyPhase.redeemed;

    return Scaffold(
      backgroundColor:
          hideAppBar ? const Color(0xFFF9FAFF) : AppColors.backgroundLight,
      appBar: hideAppBar
          ? null
          : AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Confirm student status',
                style: TextStyle(
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
    switch (_phase) {
      case _VerifyPhase.loading:
        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      case _VerifyPhase.pending:
        return _buildPending();
      case _VerifyPhase.verified:
        return _buildVerifiedWaiting();
      case _VerifyPhase.redeemed:
        return _buildRedeemed();
      case _VerifyPhase.rejected:
        return _buildResult(
          icon: Icons.close_rounded,
          iconColor: AppColors.error,
          iconBg: AppColors.error.withValues(alpha: 0.1),
          title: 'Request declined',
          subtitle: 'The partner will not apply a student discount for this checkout.',
        );
      case _VerifyPhase.expired:
        return _buildResult(
          icon: Icons.timer_off_outlined,
          iconColor: Colors.orange,
          iconBg: Colors.orange.withValues(alpha: 0.1),
          title: 'Request expired',
          subtitle: 'Go back to checkout and enter your Parchi ID again to retry.',
        );
      case _VerifyPhase.error:
        return _buildResult(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          iconBg: AppColors.error.withValues(alpha: 0.1),
          title: 'Something went wrong',
          subtitle: _errorMessage ?? 'Please try again from checkout.',
        );
    }
  }

  Widget _buildPending() {
    final partner = _request?.partnerName ?? 'Partner';
    final eventLabel = _request?.eventLabel;
    final expiresAt = _request?.expiresAt;
    final options = _request?.matchOptions ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.verified_user_rounded, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            '$partner wants to confirm it is you',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _needsMatch
                ? 'Tap the number shown on the $partner checkout screen. If you did not start a checkout, tap "No, deny".'
                : (eventLabel == null || eventLabel.isEmpty
                    ? 'Approve only if you are buying this ticket.'
                    : 'For $eventLabel. Approve only if you started this checkout.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
          ),
          if (_needsMatch) ...[
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final code in options)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _MatchChip(
                      code: code,
                      selected: _selectedCode == code,
                      onTap: _acting ? null : () => setState(() => _selectedCode = code),
                    ),
                  ),
              ],
            ),
          ],
          if (expiresAt != null) ...[
            const SizedBox(height: 20),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (_, __) {
                final remaining = expiresAt.difference(_now);
                if (remaining.isNegative) return const SizedBox.shrink();
                final m = remaining.inMinutes;
                final s = remaining.inSeconds % 60;
                return Text(
                  '$m:${s.toString().padLeft(2, '0')} remaining',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: remaining.inSeconds < 30 ? AppColors.error : AppColors.textSecondary,
                  ),
                );
              },
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_acting || (_needsMatch && _selectedCode == null)) ? null : _approve,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _acting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _needsMatch ? 'Confirm' : 'Yes, it is me',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _acting ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: Color(0xFFE5E5EA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'No, deny',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildVerifiedWaiting() {
    final partner = _request?.partnerName ?? 'Partner';
    final eventLabel = _request?.eventLabel;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE2FBE9),
            ),
            child: const Icon(Icons.check_rounded, size: 64, color: Color(0xFF27AE60)),
          ),
          const SizedBox(height: 24),
          const Text(
            'You are verified',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            eventLabel == null || eventLabel.isEmpty
                ? 'Finish checkout and pay on $partner. This screen updates when your discount is applied.'
                : 'Finish checkout and pay for $eventLabel. This screen updates when your discount is applied.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 28),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Waiting for payment…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildRedeemed() {
    final discount = _discount;
    final partner = discount?.partnerName ?? _request?.partnerName ?? 'Partner';
    final eventLabel = discount?.eventLabel ?? _request?.eventLabel;

    return RedemptionSuccessView(
      headline: discount?.formattedDiscount ?? 'Discount',
      statusLabel: 'Discount Unlocked',
      subtitle: eventLabel,
      redeemedAtPrimary: partner,
      onDone: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildResult({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, size: 64, color: iconColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchChip extends StatelessWidget {
  final String code;
  final bool selected;
  final VoidCallback? onTap;

  const _MatchChip({required this.code, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 78,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
        ),
        child: Text(
          code,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
