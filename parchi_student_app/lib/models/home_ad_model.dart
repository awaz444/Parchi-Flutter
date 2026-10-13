class HomeAdModel {
  final String id;
  final String title;
  final String imageUrl;
  final String? linkUrl;

  HomeAdModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.linkUrl,
  });

  factory HomeAdModel.fromJson(Map<String, dynamic> json) {
    return HomeAdModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      linkUrl: json['linkUrl'],
    );
  }
}

/// Response of GET /ads/active — the live ads plus how long each stays on screen.
class HomeAdsConfig {
  final List<HomeAdModel> ads;
  final Duration interval;

  const HomeAdsConfig({required this.ads, required this.interval});

  factory HomeAdsConfig.fromJson(Map<String, dynamic> json) {
    final rawAds = json['ads'];
    final seconds = json['intervalSeconds'];
    return HomeAdsConfig(
      ads: rawAds is List
          ? rawAds
              .map((a) => HomeAdModel.fromJson(a as Map<String, dynamic>))
              .where((a) => a.imageUrl.isNotEmpty)
              .toList()
          : const [],
      interval: Duration(seconds: seconds is int && seconds >= 2 ? seconds : 4),
    );
  }
}
