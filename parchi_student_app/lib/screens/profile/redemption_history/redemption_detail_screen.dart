import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/colours.dart';
import '../../../models/redemption_model.dart';

class RedemptionDetailScreen extends StatelessWidget {
  final RedemptionModel redemption;

  const RedemptionDetailScreen({super.key, required this.redemption});

  @override
  Widget build(BuildContext context) {
    // Data Preparation
    final merchantName =
        redemption.merchant?.businessName ?? redemption.offer?.merchant?.businessName ?? "Parchi Merchant";
    final branchName = redemption.branchName ?? "Unknown Branch";
    final logoUrl =
        redemption.merchant?.logoPath ?? redemption.offer?.merchant?.logoPath ?? redemption.offer?.imageUrl;
    
    // Status Logic
    final status = redemption.status.toUpperCase();
    final isApproved = status == 'APPROVED';
    final statusColor = isApproved
        ? AppColors.success
        : (status == 'REJECTED' ? AppColors.error : AppColors.primary);
    final statusIcon = isApproved
        ? Icons.check_circle
        : (status == 'REJECTED' ? Icons.cancel : Icons.hourglass_top);

    return Scaffold(
      backgroundColor: AppColors.lightCanvas,
      appBar: AppBar(
        title: const Text('Redemption Details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Hagrid',
              fontWeight: FontWeight.w800,
              fontSize: 16,
            )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
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
                        ? Icon(Icons.store, size: 40, color: AppColors.textSecondary)
                        : null,
                  ),
                  const SizedBox(height: 16),
                    Text(
                      merchantName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Hagrid',
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
                  // Discount Display
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
                  
                  // Status Row
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

            // 3. BONUS SECTION (Distinct UI if Active)
            if (redemption.isBonusApplied)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFF9C4), // Light Yellow
                      Color(0xFFFFF176), // Deeper Yellow
                    ],
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
                        const Icon(Icons.star, color: Color(0xFFF57F17), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "BONUS UNLOCKED!",
                          style: TextStyle(
                            color: const Color(0xFFF57F17),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Bonus Type Logic
                    // If bonus value > 0, shows as Monetary/Percent (inferred). 
                    // If 0, shows as Additional Item/Freebie.
                    Text(
                      redemption.bonusDiscountApplied > 0 
                          ? "Rs. ${redemption.bonusDiscountApplied} OFF" 
                          : "Free Item / Reward",
                      style: const TextStyle(
                        color: Color(0xFFE65100), // Dark Orange
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      redemption.bonusDiscountApplied > 0 
                          ? "Additional Cash Discount" 
                          : "Special Item Reward",
                      style: TextStyle(
                        color: const Color(0xFFE65100).withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600
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
                  _buildDetailRow("Date", DateFormat('MMM d, yyyy').format(redemption.redeemedAt)),
                  const Divider(height: 24),
                  _buildDetailRow("Time", DateFormat('h:mm a').format(redemption.redeemedAt)),
                  const Divider(height: 24),
                  _buildDetailRow("Reference ID", redemption.id.split('-').last.toUpperCase()),
                  if (redemption.verifiedBy != null) ...[
                    const Divider(height: 24),
                    _buildDetailRow("Verified By", "Staff Member"),
                  ],
                  if (redemption.notes != null && redemption.notes!.isNotEmpty) ...[
                     const Divider(height: 24),
                     Text("Notes", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                     const SizedBox(height: 4),
                     Text(redemption.notes!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                  ]
                ],
              ),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
