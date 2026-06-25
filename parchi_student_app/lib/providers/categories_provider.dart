import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../services/categories_service.dart';

final categoriesProvider = FutureProvider<List<MerchantCategory>>((ref) async {
  return categoriesService.fetchCategories();
});
