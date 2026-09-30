import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/colours.dart';
import '../../widgets/common/blinking_skeleton.dart';
import '../../widgets/common/hagrid_text.dart';
import '../../widgets/common/parchi_loader.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  Future<void> _openEvent(BuildContext context, WidgetRef ref, EventModel event) async {
    if (event.externalUrl.isEmpty) return;

    final user = ref.read(userProfileProvider).valueOrNull;
    final uri = Uri.tryParse(event.externalUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This event link is not available right now.')),
      );
      return;
    }

    // Preserve every existing query parameter (including repeated keys) and add ours.
    final params = Map<String, List<String>>.from(uri.queryParametersAll);
    params['ref'] = ['parchi_app'];
    if (user?.parchiId != null && user!.parchiId!.isNotEmpty) {
      params['parchiId'] = [user.parchiId!];
    }
    final target = uri.replace(queryParameters: params);

    try {
      // External browser so the user can switch back to Parchi for 2FA while
      // checkout stays open in Safari/Chrome.
      final launched = await launchUrl(target, mode: LaunchMode.externalApplication);
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

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(eventsProvider);
    await ref.read(eventsProvider.future);
  }

  Widget _withParchiRefresh({
    required WidgetRef ref,
    required Widget child,
  }) {
    return CustomRefreshIndicator(
      onRefresh: () => _refresh(ref),
      offsetToArmed: 100.0,
      builder: (BuildContext context, Widget child, IndicatorController controller) {
        return Stack(
          children: <Widget>[
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return SizedBox(
                  height: controller.value * 100.0,
                  width: double.infinity,
                  child: Center(
                    child: ParchiLoader(
                      isLoading: controller.isLoading,
                      progress: controller.value,
                      color: AppColors.secondary,
                    ),
                  ),
                );
              },
            ),
            Transform.translate(
              offset: Offset(0.0, controller.value * 100.0),
              child: child,
            ),
          ],
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const HagridText(
          'Events',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: eventsAsync.when(
        loading: () => const _EventsSkeleton(),
        error: (_, __) => _withParchiRefresh(
          ref: ref,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
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
          ),
        ),
        data: (events) {
          if (events.isEmpty) {
            return _withParchiRefresh(
              ref: ref,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.22),
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
              ),
            );
          }

          return _withParchiRefresh(
            ref: ref,
            child: ListView.separated(
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
            ),
          );
        },
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
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                    if (event.description != null && event.description!.isNotEmpty) ...[
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
                    if (dateLabel != null || (event.venue != null && event.venue!.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (dateLabel != null) ...[
                            const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              dateLabel,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                          if (dateLabel != null && event.venue != null && event.venue!.isNotEmpty)
                            const SizedBox(width: 14),
                          if (event.venue != null && event.venue!.isNotEmpty) ...[
                            const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.venue!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Get tickets',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
