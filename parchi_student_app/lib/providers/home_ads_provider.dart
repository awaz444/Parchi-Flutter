import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_ad_model.dart';
import '../services/home_ads_service.dart';

final homeAdsProvider = FutureProvider<HomeAdsConfig>((ref) async {
  return homeAdsService.getActiveAds();
});
