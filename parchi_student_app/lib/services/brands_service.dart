import 'dart:convert';
import '../config/api_config.dart';
import '../models/brand_model.dart';
import 'auth_service.dart';

class BrandsService {
  Future<List<BrandModel>> getAllBrands() async {
    try {
      final response = await authService.publicGet(ApiConfig.allBrandsEndpoint);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        List<dynamic> list = [];
         if (responseData['data'] is List) {
          list = responseData['data'];
        } else if (responseData is List) {
          list = responseData as List;
        }

        return list.map((json) => BrandModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load brands: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching brands: $e');
    }
  }
}

final brandsService = BrandsService();
