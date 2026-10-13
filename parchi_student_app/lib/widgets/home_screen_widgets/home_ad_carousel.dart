// Auto-swiping 3.2:1 ad carousel shown under Top Brands. Ads, their order and
// the rotation speed come from GET /ads/active and are managed on the admin
// dashboard at /admin/ads.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/home_ad_model.dart';
import '../../providers/home_ads_provider.dart';
import '../../providers/user_provider.dart';
import '../common/blinking_skeleton.dart';

const double _adAspectRatio = 3.2 / 1;

class HomeAdCarousel extends ConsumerWidget {
  const HomeAdCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(homeAdsProvider);
    // valueOrNull keeps the current ads on screen while a pull-to-refresh
    // refetches them.
    final config = adsAsync.valueOrNull;

    if (config == null) {
      if (adsAsync.isLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: AspectRatio(
            aspectRatio: _adAspectRatio,
            child: BlinkingSkeleton(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 20,
            ),
          ),
        );
      }
      // Ads are non-essential: on error, just leave the slot out.
      return const SizedBox.shrink();
    }
    if (config.ads.isEmpty) return const SizedBox.shrink();

    return _AdPager(
      // Rebuild the pager (and restart its timer) when the ad set changes.
      key: ValueKey(config.ads.map((a) => a.id).join(',')),
      ads: config.ads,
      interval: config.interval,
    );
  }
}

class _AdPager extends ConsumerStatefulWidget {
  final List<HomeAdModel> ads;
  final Duration interval;

  const _AdPager({super.key, required this.ads, required this.interval});

  @override
  ConsumerState<_AdPager> createState() => _AdPagerState();
}

class _AdPagerState extends ConsumerState<_AdPager> {
  // Start deep in an unbounded PageView so the user can swipe backwards from
  // the first ad too; index % ads.length maps a page to its ad.
  static const int _loopOffset = 10000;

  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  bool get _loops => widget.ads.length > 1;

  @override
  void initState() {
    super.initState();
    _page = _loops ? widget.ads.length * _loopOffset : 0;
    _controller = PageController(initialPage: _page);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_loops) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap(HomeAdModel ad) async {
    final link = ad.linkUrl;
    if (link == null || link.isEmpty) return;
    var uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;

    // Same referral params as the Events tab, so Inside Karachi applies the
    // Parchi student discount.
    final host = uri.host.toLowerCase();
    if (host == 'insidekarachi.com' || host.endsWith('.insidekarachi.com')) {
      final user = ref.read(userProfileProvider).valueOrNull;
      final params = Map<String, List<String>>.from(uri.queryParametersAll);
      params['ref'] = ['parchi_app'];
      if (user?.parchiId != null && user!.parchiId!.isNotEmpty) {
        params['parchiId'] = [user.parchiId!];
      }
      uri = uri.replace(queryParameters: params);
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open ad link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ads = widget.ads;
    final activeIndex = _page % ads.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: _adAspectRatio,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Hold auto-swipe while the user drags; restart the countdown
              // once they let go so it doesn't jump right after a manual swipe.
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _timer?.cancel();
              } else if (notification is ScrollEndNotification) {
                _startTimer();
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: _loops ? null : 1,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, page) {
                final ad = ads[page % ads.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GestureDetector(
                    onTap: () => _onTap(ad),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CachedNetworkImage(
                        imageUrl: ad.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const BlinkingSkeleton(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 20,
                        ),
                        errorWidget: (context, url, error) =>
                            Container(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_loops)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(ads.length, (i) {
                final active = i == activeIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.black87 : Colors.black26,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
