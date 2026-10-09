enum TicketStatus { upcoming, used, expired }

class EventTicketModel {
  final String id;
  final String eventId;
  final String eventTitle;
  final String? ticketTier;
  final String? venue;
  final DateTime? eventDate;
  final String? seatInfo;
  final String ticketCode;
  final String? qrPayload;
  final String? imageUrl;
  final TicketStatus status;
  final num? pricePaid;
  final String currency;
  final DateTime? purchasedAt;
  /// When set, tapping the ticket opens this URL (e.g. IK bookings) instead of a QR sheet.
  final String? bookingsUrl;

  EventTicketModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    this.ticketTier = 'General Pass',
    this.venue,
    this.eventDate,
    this.seatInfo,
    required this.ticketCode,
    this.qrPayload,
    this.imageUrl,
    this.status = TicketStatus.upcoming,
    this.pricePaid,
    this.currency = 'PKR',
    this.purchasedAt,
    this.bookingsUrl,
  });

  bool get opensExternalBookings =>
      bookingsUrl != null && bookingsUrl!.trim().isNotEmpty;

  factory EventTicketModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;

    TicketStatus parseStatus(dynamic v) {
      final s = v?.toString().toLowerCase();
      if (s == 'used') return TicketStatus.used;
      if (s == 'expired') return TicketStatus.expired;
      return TicketStatus.upcoming;
    }

    return EventTicketModel(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      eventTitle: json['eventTitle']?.toString() ?? 'Event Ticket',
      ticketTier: json['ticketTier']?.toString() ?? 'General Pass',
      venue: json['venue']?.toString(),
      eventDate: parseDate(json['eventDate']),
      seatInfo: json['seatInfo']?.toString(),
      ticketCode: json['ticketCode']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? json['ticketCode']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      status: parseStatus(json['status']),
      pricePaid: json['pricePaid'] as num?,
      currency: json['currency']?.toString() ?? 'PKR',
      purchasedAt: parseDate(json['purchasedAt']),
      bookingsUrl: json['bookingsUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'ticketTier': ticketTier,
      'venue': venue,
      'eventDate': eventDate?.toIso8601String(),
      'seatInfo': seatInfo,
      'ticketCode': ticketCode,
      'qrPayload': qrPayload,
      'imageUrl': imageUrl,
      'status': status.name,
      'pricePaid': pricePaid,
      'currency': currency,
      'purchasedAt': purchasedAt?.toIso8601String(),
      'bookingsUrl': bookingsUrl,
    };
  }
}
