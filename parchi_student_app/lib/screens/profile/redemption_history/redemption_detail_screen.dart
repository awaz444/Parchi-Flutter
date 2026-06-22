import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../utils/colours.dart';
import '../../../models/redemption_model.dart';
import '../../../providers/redemption_provider.dart';
import '../../../widgets/common/blinking_skeleton.dart';
import '../../../widgets/common/hagrid_text.dart';

class RedemptionDetailScreen extends ConsumerWidget {
  /// Only the ID is passed — full details are fetched on demand.
  final String redemptionId;

  const RedemptionDetailScreen({super.key, required this.redemptionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(redemptionDetailProvider(redemptionId));

    return Scaffold(
      backgroundColor: AppColors.lightCanvas,
      appBar: AppBar(
        title: const HagridText('Redemption Details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: detailAsync.when(
        loading: () => _buildSkeleton(),
        error: (err, _) => _buildError(context, err),
        data: (redemption) => _buildBody(context, redemption),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, RedemptionModel redemption) {
    final merchantName = redemption.merchant?.businessName ??
        redemption.offer?.merchant?.businessName ??
        "Parchi Merchant";
    final branchName = redemption.branchName ?? "Unknown Branch";
    final logoUrl = redemption.merchant?.logoPath ??
        redemption.offer?.merchant?.logoPath ??
        redemption.offer?.imageUrl;

    final status = redemption.status.toUpperCase();
    final isApproved = status == 'APPROVED' || status == 'VERIFIED';
    final statusColor = isApproved
        ? AppColors.success
        : (status == 'REJECTED' ? AppColors.error : AppColors.primary);
    final statusIcon = isApproved
        ? Icons.check_circle
        : (status == 'REJECTED' ? Icons.cancel : Icons.hourglass_top);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 1. MERCHANT & BRANCH HEADER
          Center(
            child: Column(
              children: [
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                    image: logoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(logoUrl), fit: BoxFit.cover)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: logoUrl == null
                      ? Icon(Icons.store,
                          size: 40, color: AppColors.textSecondary)
                      : null,
                ),
                const SizedBox(height: 16),
                HagridText(
                  merchantName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  branchName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 2. MAIN OFFER & STATUS
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Discount Redeemed",
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  redemption.offer?.formattedDiscount ?? "Discount",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. BONUS SECTION
          if (redemption.isBonusApplied)
            Container(
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
                    color: Colors.amber.withOpacity(0.2),
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
                      const Icon(Icons.star,
                          color: Color(0xFFF57F17), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        "BONUS UNLOCKED!",
                        style: TextStyle(
                          color: Color(0xFFF57F17),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatBonusDiscountOffLabel(
                      redemption.bonusDiscountApplied,
                      redemption.bonusDiscountType,
                    ),
                    style: const TextStyle(
                      color: Color(0xFFE65100),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatBonusDiscountSubtitle(redemption.bonusDiscountType),
                    style: TextStyle(
                      color: const Color(0xFFE65100).withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          if (redemption.isBonusApplied) const SizedBox(height: 24),

          // 4. TRANSACTION DETAILS
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("Date",
                    DateFormat('MMM d, yyyy').format(redemption.redeemedAt.toLocal())),
                const Divider(height: 24),
                _buildDetailRow(
                    "Time", DateFormat('h:mm a').format(redemption.redeemedAt.toLocal())),
                const Divider(height: 24),
                _buildDetailRow("Reference ID",
                    redemption.id.split('-').last.toUpperCase()),
                if (redemption.verifiedBy != null) ...[
                  const Divider(height: 24),
                  _buildDetailRow("Verified By", "Staff Member"),
                ],
                if (redemption.notes != null &&
                    redemption.notes!.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text("Notes",
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(redemption.notes!,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Center(
            child: Column(
              children: [
                BlinkingSkeleton(
                    width: 80,
                    height: 80,
                    borderRadius: 40,
                    baseColor: Colors.black.withOpacity(0.05)),
                const SizedBox(height: 16),
                BlinkingSkeleton(
                    width: 160,
                    height: 22,
                    baseColor: Colors.black.withOpacity(0.05)),
                const SizedBox(height: 8),
                BlinkingSkeleton(
                    width: 100,
                    height: 16,
                    baseColor: Colors.black.withOpacity(0.05)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          BlinkingSkeleton(
              width: double.infinity,
              height: 120,
              borderRadius: 20,
              baseColor: Colors.black.withOpacity(0.05)),
          const SizedBox(height: 24),
          BlinkingSkeleton(
              width: double.infinity,
              height: 160,
              borderRadius: 20,
              baseColor: Colors.black.withOpacity(0.05)),
        ],
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError(BuildContext context, Object err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              err.toString().replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
      ],
    );
  }
}
