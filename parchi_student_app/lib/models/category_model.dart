class MerchantSubcategory {
  final String id;
  final String categoryId;
  final String name;
  final int sortOrder;
  final bool isActive;

  MerchantSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  factory MerchantSubcategory.fromJson(Map<String, dynamic> json) {
    return MerchantSubcategory(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class MerchantCategory {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final List<MerchantSubcategory> subcategories;

  MerchantCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.subcategories,
  });

  factory MerchantCategory.fromJson(Map<String, dynamic> json) {
    var subList = json['merchant_subcategories'] as List? ?? [];
    List<MerchantSubcategory> subcategories = subList
        .map((subJson) => MerchantSubcategory.fromJson(subJson as Map<String, dynamic>))
        .toList();

    return MerchantCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      subcategories: subcategories,
    );
  }
}
