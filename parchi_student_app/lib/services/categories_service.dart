import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/category_model.dart';

class CategoriesService {
  Future<List<MerchantCategory>> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.categoriesEndpoint));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        // Handle both wrapped { data: [...] } and raw [...] array formats
        final List<dynamic> listData = (decoded is Map && decoded.containsKey('data'))
            ? decoded['data'] as List<dynamic>
            : (decoded is List ? decoded : []);

        return listData.map((json) => MerchantCategory.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }
}

// Global instance of the service
final categoriesService = CategoriesService();
