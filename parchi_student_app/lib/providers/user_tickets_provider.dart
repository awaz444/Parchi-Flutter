import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../models/event_ticket_model.dart';
import '../models/redemption_model.dart';
import '../services/redemption_service.dart';
import 'events_provider.dart';

/// Inside Karachi bookings dashboard — where redeemed partner tickets live.
const kInsideKarachiBookingsUrl =
    'https://www.insidekarachi.com/dashboard/bookings';

class UserTicketsNotifier extends AsyncNotifier<List<EventTicketModel>> {
  @override
  Future<List<EventTicketModel>> build() async {
    return _fetchUserTickets();
  }

  Future<List<EventTicketModel>> _fetchUserTickets() async {
    try {
      final activeEvents = await ref.read(eventsProvider.future).catchError((_) => <EventModel>[]);
      final redemptions =
          await redemptionService.getRedemptions(page: 1, limit: 50);
      // Only paid partner ticket purchases — never cafe QR redemptions or
      // unverified/browsed events. See [RedemptionModel.isPartnerDiscountPurchase].
      return redemptions
          .where((r) => r.isPartnerDiscountPurchase)
          .map((r) => _mapRedemptionToTicket(r, activeEvents))
          .toList();
    } catch (_) {
      return <EventTicketModel>[];
    }
  }

  EventTicketModel _mapRedemptionToTicket(
      RedemptionModel r, List<EventModel> activeEvents) {
    final rawTitle = (r.offer?.title?.trim().isNotEmpty == true)
        ? r.offer!.title.trim()
        : (r.branchName?.trim().isNotEmpty == true
            ? r.branchName!.trim()
            : 'Event ticket');
    final partnerName = r.merchant?.businessName ?? 'Inside Karachi';
    final shortCode = r.id.length > 8
        ? r.id.substring(0, 8).toUpperCase()
        : r.id.toUpperCase();

    // Match with active events to inherit rich banner artwork & venue if available
    EventModel? matchedEvent;
    for (final event in activeEvents) {
      final cleanEvTitle = event.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final cleanRawTitle = rawTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cleanRawTitle.contains(cleanEvTitle) || cleanEvTitle.contains(cleanRawTitle)) {
        matchedEvent = event;
        break;
      }
    }

    DateTime? parsedDate = matchedEvent?.eventDate;
    // Attempt parse date from raw title like "PRISMFEST'26 - 20 Oct"
    if (parsedDate == null && rawTitle.contains(' - ')) {
      final parts = rawTitle.split(' - ');
      if (parts.length > 1) {
        final dateStr = '${parts.last.trim()} 2026';
        try {
          final now = DateTime.now();
          final d = DateTime.tryParse(dateStr);
          if (d != null) parsedDate = d;
        } catch (_) {}
      }
    }

    final venue = matchedEvent?.venue?.isNotEmpty == true
        ? matchedEvent!.venue
        : (partnerName.isNotEmpty ? partnerName : 'Inside Karachi');

    final imageUrl = matchedEvent?.imageUrl?.isNotEmpty == true
        ? matchedEvent!.imageUrl
        : r.merchant?.logoPath;

    return EventTicketModel(
      id: r.id,
      eventId: matchedEvent?.id ?? r.merchant?.id ?? r.id,
      eventTitle: rawTitle,
      ticketTier: 'Student Discount Pass',
      venue: venue,
      eventDate: parsedDate,
      seatInfo: 'General Admission',
      ticketCode: shortCode,
      qrPayload: null,
      imageUrl: imageUrl,
      status: TicketStatus.upcoming,
      pricePaid: r.offer?.discountValue,
      currency: 'PKR',
      purchasedAt: r.redeemedAt,
      bookingsUrl: kInsideKarachiBookingsUrl,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchUserTickets());
  }
}

final userTicketsProvider =
    AsyncNotifierProvider<UserTicketsNotifier, List<EventTicketModel>>(() {
  return UserTicketsNotifier();
});
