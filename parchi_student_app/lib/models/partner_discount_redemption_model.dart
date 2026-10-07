class PartnerDiscountRedemptionModel {
  final String redemptionId;
  final String verificationRequestId;
  final String externalReference;
  final String? eventLabel;
  final String partnerName;
  final num discountAmountPkr;
  final num? orderTotalPkr;
  final String currency;
  final DateTime? paidAt;

  PartnerDiscountRedemptionModel({
    required this.redemptionId,
    required this.verificationRequestId,
    required this.externalReference,
    this.eventLabel,
    required this.partnerName,
    required this.discountAmountPkr,
    this.orderTotalPkr,
    required this.currency,
    this.paidAt,
  });

  String get formattedDiscount {
    final value = discountAmountPkr;
    if (value == value.roundToDouble()) {
      return 'Rs. ${value.toInt()} off';
    }
    return 'Rs. ${value.toStringAsFixed(2)} off';
  }

  factory PartnerDiscountRedemptionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) => v != null ? DateTime.tryParse(v.toString()) : null;
    num readNum(dynamic v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? 0;
      return 0;
    }

    return PartnerDiscountRedemptionModel(
      redemptionId: json['redemptionId']?.toString() ?? '',
      verificationRequestId: json['verificationRequestId']?.toString() ?? '',
      externalReference: json['externalReference']?.toString() ?? '',
      eventLabel: json['eventLabel']?.toString(),
      partnerName: json['partnerName']?.toString() ?? 'Partner',
      discountAmountPkr: readNum(json['discountAmountPkr']),
      orderTotalPkr: json['orderTotalPkr'] == null ? null : readNum(json['orderTotalPkr']),
      currency: json['currency']?.toString() ?? 'PKR',
      paidAt: parse(json['paidAt']),
    );
  }
}
