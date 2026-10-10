import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/event_model.dart';
import '../../models/event_ticket_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/user_tickets_provider.dart';
import '../../services/navigation_service.dart';
import '../../utils/colours.dart';
import '../../utils/tab_scroll_to_top.dart';
import '../../widgets/common/blinking_skeleton.dart';
import '../../widgets/common/hagrid_text.dart';
import '../../widgets/common/parchi_pull_to_refresh.dart';
import '../../widgets/common/parchi_segmented_tabs.dart';

class EventsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const EventsScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabIndex.clamp(0, 1);
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: initial);
    NavigationService.tabIntent.addListener(_onTabIntent);
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final next = widget.initialTabIndex.clamp(0, 1);
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    }
  }

  @override
  void dispose() {
    NavigationService.tabIntent.removeListener(_onTabIntent);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabIntent() {
    final intent = NavigationService.tabIntent.value;
    final sub = intent?.eventsSubTab;
    if (sub == null || !mounted) return;
    if (_tabController.index != sub) {
      _tabController.animateTo(sub.clamp(0, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketCount = ref
        .watch(userTicketsProvider.select((s) => s.valueOrNull?.length ?? 0));

    return Scaffold(
      backgroundColor: AppColors.lightCanvas,
      appBar: AppBar(
        title: const HagridText(
          'Events',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        backgroundColor: AppColors.lightCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          ParchiSegmentedTabs(
            controller: _tabController,
            tabs: [
              const ParchiSegmentedTab(label: 'Events'),
              ParchiSegmentedTab(
                label: 'My Tickets',
                badgeCount: ticketCount > 0 ? ticketCount : null,
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _EventsTab(),
                _TicketsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openBookingsPage(
    BuildContext context, EventTicketModel ticket) async {
  final raw = ticket.bookingsUrl?.trim();
  if (raw == null || raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https') {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Bookings link is not available right now.')),
    );
    return;
  }
  final params = Map<String, List<String>>.from(uri.queryParametersAll);
  params['ref'] = ['parchi_app'];
  final target = uri.replace(queryParameters: params);
  try {
    final launched =
        await launchUrl(target, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open bookings right now.')),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open bookings right now.')),
    );
  }
}

Future<void> _openEvent(
    BuildContext context, WidgetRef ref, EventModel event) async {
  final user = ref.read(userProfileProvider).valueOrNull;
  final base = event.externalUrl.trim().isNotEmpty
      ? event.externalUrl.trim()
      : 'https://www.insidekarachi.com/events/prismfest-26';
  final uri = Uri.tryParse(base);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('This event link is not available right now.')),
    );
    return;
  }

  final params = Map<String, List<String>>.from(uri.queryParametersAll);
  params['ref'] = ['parchi_app'];
  if (user?.parchiId != null && user!.parchiId!.isNotEmpty) {
    params['parchiId'] = [user.parchiId!];
  }
  final target = uri.replace(queryParameters: params);

  try {
    final launched =
        await launchUrl(target, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this event right now.')),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this event right now.')),
    );
  }
}

void _onTicketTap(
    BuildContext context, WidgetRef ref, EventTicketModel ticket) {
  if (ticket.opensExternalBookings) {
    _openBookingsPage(context, ticket);
    return;
  }
  _showTicketDetailsSheet(context, ref, ticket);
}

void _showTicketDetailsSheet(
    BuildContext context, WidgetRef ref, EventTicketModel ticket) {
  final user = ref.read(userProfileProvider).valueOrNull;
  final attendeeName = [user?.firstName, user?.lastName]
      .where((s) => s != null && s.isNotEmpty)
      .join(' ')
      .trim();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final dateLabel = ticket.eventDate != null
          ? DateFormat('EEEE, d MMMM y • h:mm a')
              .format(ticket.eventDate!.toLocal())
          : 'Date to be announced';

      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              ticket.eventTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ticket.ticketTier ?? 'General Admission',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: ticket.qrPayload ?? ticket.ticketCode,
                    version: QrVersions.auto,
                    size: 190.0,
                    gapless: false,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.textPrimary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pass #${ticket.ticketCode}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 1.1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: ticket.ticketCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ticket code copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightCanvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dateLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (ticket.venue != null && ticket.venue!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ticket.venue!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (attendeeName.isNotEmpty) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Attendee:',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          attendeeName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Show this QR code at the entrance gate for instant check-in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _EventsTab extends ConsumerStatefulWidget {
  const _EventsTab();

  @override
  ConsumerState<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<_EventsTab>
    with AutomaticKeepAliveClientMixin {
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TabScrollToTop.listenable(TabScrollToTop.events)
        .addListener(_onNavReselected);
  }

  void _onNavReselected() => TabScrollToTop.scrollToTop(_scrollController);

  @override
  void dispose() {
    TabScrollToTop.listenable(TabScrollToTop.events)
        .removeListener(_onNavReselected);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _reload();
  }

  Future<void> _reload() async {
    try {
      ref.invalidate(eventsProvider);
      await ref.read(eventsProvider.future);
    } catch (_) {
      // Provider already holds the error; UI reads eventsAsync.hasError.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final eventsAsync = ref.watch(eventsProvider);
    final showSkeleton = _isRefreshing || eventsAsync.isLoading;

    Widget body;
    if (showSkeleton) {
      body = const _EventsSkeleton();
    } else if (eventsAsync.hasError) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Could not load events',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pull down to try again',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    } else {
      final events = eventsAsync.valueOrNull ?? const <EventModel>[];
      if (events.isEmpty) {
        body = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            const Icon(
              Icons.confirmation_number_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No events right now',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'When partner events drop, you will find them here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
            ),
          ],
        );
      } else {
        body = ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final event = events[index];
            return _EventCard(
              event: event,
              onTap: () => _openEvent(context, ref, event),
            );
          },
        );
      }
    }

    return RepaintBoundary(
      child: ParchiPullToRefresh(
        onRefresh: _onRefresh,
        child: body,
      ),
    );
  }
}

class _TicketsTab extends ConsumerStatefulWidget {
  const _TicketsTab();

  @override
  ConsumerState<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends ConsumerState<_TicketsTab>
    with AutomaticKeepAliveClientMixin {
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TabScrollToTop.listenable(TabScrollToTop.events)
        .addListener(_onNavReselected);
  }

  void _onNavReselected() => TabScrollToTop.scrollToTop(_scrollController);

  @override
  void dispose() {
    TabScrollToTop.listenable(TabScrollToTop.events)
        .removeListener(_onNavReselected);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _reload();
  }

  Future<void> _reload() async {
    try {
      await ref.read(userTicketsProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ticketsAsync = ref.watch(userTicketsProvider);
    final showSkeleton = _isRefreshing || ticketsAsync.isLoading;

    Widget body;
    if (showSkeleton) {
      body = const _TicketsSkeleton();
    } else if (ticketsAsync.hasError) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Could not load your tickets',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pull down to refresh',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    } else {
      final tickets = ticketsAsync.valueOrNull ?? const <EventTicketModel>[];
      if (tickets.isEmpty) {
        body = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Tickets Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'When you buy a ticket with your Parchi discount on Inside Karachi, it will show up here. Tap a ticket to open your bookings page.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ],
        );
      } else {
        body = ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: tickets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return _TicketCard(
              ticket: ticket,
              onTap: () => _onTicketTap(context, ref, ticket),
            );
          },
        );
      }
    }

    return RepaintBoundary(
      child: ParchiPullToRefresh(
        onRefresh: _onRefresh,
        child: body,
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateLabel = event.eventDate != null
        ? DateFormat('EEE, d MMM y').format(event.eventDate!.toLocal())
        : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAEAEA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => BlinkingSkeleton(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 0,
                          baseColor: Colors.black.withValues(alpha: 0.05),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: const Icon(
                            Icons.confirmation_number_rounded,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        child: const Icon(
                          Icons.confirmation_number_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (event.description != null &&
                        event.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        event.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (dateLabel != null ||
                        (event.venue != null && event.venue!.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (dateLabel != null) ...[
                            const Icon(Icons.calendar_today_rounded,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              dateLabel,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                          if (dateLabel != null &&
                              event.venue != null &&
                              event.venue!.isNotEmpty)
                            const SizedBox(width: 14),
                          if (event.venue != null &&
                              event.venue!.isNotEmpty) ...[
                            const Icon(Icons.place_outlined,
                                size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.venue!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Get tickets',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final EventTicketModel ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateLabel = ticket.eventDate != null
        ? DateFormat('EEE, d MMM y').format(ticket.eventDate!.toLocal())
        : null;

    final isUpcoming = ticket.status == TicketStatus.upcoming;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EAEF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section with Event branding & Status
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Event / Partner Icon Badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: (ticket.imageUrl != null &&
                              ticket.imageUrl!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: ticket.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.confirmation_number_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.confirmation_number_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Verified Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 11,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Inside Karachi Partner',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Modern Emerald Active Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isUpcoming
                            ? const Color(0xFFECFDF5)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isUpcoming
                              ? const Color(0xFFA7F3D0)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isUpcoming
                                  ? const Color(0xFF10B981)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isUpcoming ? 'ACTIVE' : 'USED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isUpcoming
                                  ? const Color(0xFF059669)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Perforated Ticket Divider with side cutouts
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppColors.lightCanvas,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boxWidth = constraints.constrainWidth();
                        const dashWidth = 5.0;
                        const dashSpace = 4.0;
                        final dashCount =
                            (boxWidth / (dashWidth + dashSpace)).floor();
                        return Flex(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          direction: Axis.horizontal,
                          children: List.generate(dashCount, (_) {
                            return const SizedBox(
                              width: dashWidth,
                              height: 1.2,
                              child: DecoratedBox(
                                decoration:
                                    BoxDecoration(color: Color(0xFFE2E4E9)),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppColors.lightCanvas,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),

              // Ticket Details & Action Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    // Info Row (Venue & Date / Monospace ID)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEEF0F3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VENUE / EVENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.place_outlined,
                                        size: 14, color: AppColors.textPrimary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        ticket.venue?.isNotEmpty == true
                                            ? ticket.venue!
                                            : 'Inside Karachi',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 28,
                            width: 1,
                            color: const Color(0xFFE5E7EB),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DATE / PASS REF',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded,
                                        size: 13, color: AppColors.textPrimary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        dateLabel ?? '#${ticket.ticketCode}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Primary Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        icon: Icon(
                          ticket.opensExternalBookings
                              ? Icons.open_in_new_rounded
                              : Icons.qr_code_rounded,
                          size: 18,
                        ),
                        label: Text(
                          ticket.opensExternalBookings
                              ? 'Open Bookings'
                              : 'View Ticket QR',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsSkeleton extends StatelessWidget {
  const _EventsSkeleton();

  static final Color _skeletonColor = Colors.black.withValues(alpha: 0.05);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: 3,
      physics: const AlwaysScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlinkingSkeleton(
              width: double.infinity,
              height: 180,
              borderRadius: 0,
              baseColor: _skeletonColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlinkingSkeleton(
                    width: 220,
                    height: 20,
                    borderRadius: 6,
                    baseColor: _skeletonColor,
                  ),
                  const SizedBox(height: 10),
                  BlinkingSkeleton(
                    width: double.infinity,
                    height: 14,
                    borderRadius: 6,
                    baseColor: _skeletonColor,
                  ),
                  const SizedBox(height: 6),
                  BlinkingSkeleton(
                    width: 180,
                    height: 14,
                    borderRadius: 6,
                    baseColor: _skeletonColor,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      BlinkingSkeleton(
                        width: 110,
                        height: 13,
                        borderRadius: 6,
                        baseColor: _skeletonColor,
                      ),
                      const SizedBox(width: 14),
                      BlinkingSkeleton(
                        width: 90,
                        height: 13,
                        borderRadius: 6,
                        baseColor: _skeletonColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  BlinkingSkeleton(
                    width: double.infinity,
                    height: 44,
                    borderRadius: 12,
                    baseColor: _skeletonColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketsSkeleton extends StatelessWidget {
  const _TicketsSkeleton();

  static final Color _skeletonColor = Colors.black.withValues(alpha: 0.05);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: 2,
      physics: const AlwaysScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BlinkingSkeleton(
                  width: 48,
                  height: 48,
                  borderRadius: 14,
                  baseColor: _skeletonColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BlinkingSkeleton(
                        width: 160,
                        height: 18,
                        borderRadius: 6,
                        baseColor: _skeletonColor,
                      ),
                      const SizedBox(height: 6),
                      BlinkingSkeleton(
                        width: 110,
                        height: 14,
                        borderRadius: 6,
                        baseColor: _skeletonColor,
                      ),
                    ],
                  ),
                ),
                BlinkingSkeleton(
                  width: 65,
                  height: 24,
                  borderRadius: 12,
                  baseColor: _skeletonColor,
                ),
              ],
            ),
            const SizedBox(height: 18),
            BlinkingSkeleton(
              width: double.infinity,
              height: 50,
              borderRadius: 12,
              baseColor: _skeletonColor,
            ),
            const SizedBox(height: 14),
            BlinkingSkeleton(
              width: double.infinity,
              height: 44,
              borderRadius: 12,
              baseColor: _skeletonColor,
            ),
          ],
        ),
      ),
    );
  }
}
