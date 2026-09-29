class PartnerVerificationModel {
  final String id;
  final String status;
  final String? eventLabel;
  final String partnerName;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? approvedAt;

  /// Three numbers for number-matching (the student picks the one shown on the partner's screen).
  final List<String>? matchOptions;

  /// Server clock at response time, used to correct a wrong device clock for the countdown.
  final DateTime? serverTime;

  PartnerVerificationModel({
    required this.id,
    required this.status,
    this.eventLabel,
    required this.partnerName,
    this.expiresAt,
    this.createdAt,
    this.approvedAt,
    this.matchOptions,
    this.serverTime,
  });

  bool get isTerminal => status != 'pending';

  factory PartnerVerificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) => v != null ? DateTime.tryParse(v.toString()) : null;
    final options = json['matchOptions'];
    return PartnerVerificationModel(
      id: json['id'] ?? '',
      status: json['status'] ?? 'pending',
      eventLabel: json['eventLabel'],
      partnerName: json['partnerName'] ?? 'Partner',
      expiresAt: parse(json['expiresAt']),
      createdAt: parse(json['createdAt']),
      approvedAt: parse(json['approvedAt']),
      matchOptions: options is List ? options.map((e) => e.toString()).toList() : null,
      serverTime: parse(json['serverTime']),
    );
  }
}
