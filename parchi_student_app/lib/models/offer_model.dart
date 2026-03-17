class OfferModel {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String discountType;
  final num discountValue;
  final DateTime validUntil;
  final Merchant? merchant;
  final double? distance;
  final String? branchName;
  final int? featuredOrder;
  final List<FeaturedBranch>? branches;

  OfferModel({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.discountType,
    required this.discountValue,
    required this.validUntil,
    this.merchant,
    this.distance,
    this.branchName,
    this.featuredOrder,
    this.branches,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      // Backend sends camelCase keys
      imageUrl: json['imageUrl'], 
      discountType: json['discountType'] ?? 'percentage',
      discountValue: json['discountValue'] ?? 0,
      validUntil: DateTime.tryParse(json['validUntil'] ?? '') ?? DateTime.now(),
      merchant: json['merchant'] != null ? Merchant.fromJson(json['merchant']) : null,
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
      branchName: json['branchName'],
      featuredOrder: json['featuredOrder'],
      branches: (json['branches'] as List<dynamic>?)
          ?.map((b) => FeaturedBranch.fromJson(b))
          .toList(),
    );
  }

  // Helper to format the discount text for the UI
  String get formattedDiscount {
    if (discountValue <= 0) {
      return 'SPECIAL OFFER';
    }
    
    if (discountType.toLowerCase() == 'percentage') {
      return '${discountValue.toStringAsFixed(0)}% OFF';
    } else if (discountType.toLowerCase() == 'fixed' || discountType.toLowerCase() == 'pkr') {
      return 'RS ${discountValue.toStringAsFixed(0)} OFF';
    } else {
      return 'SPECIAL OFFER';
    }
  }
}

class FeaturedBranch {
  final String branchId;
  final String branchName;
  final bool isActive;

  FeaturedBranch({required this.branchId, required this.branchName, required this.isActive});

  factory FeaturedBranch.fromJson(Map<String, dynamic> json) {
    return FeaturedBranch(
      branchId: json['branchId'] ?? '',
      branchName: json['branchName'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }
}

class Merchant {
  final String id;
  final String businessName;
  final String? logoPath;
  final String? category;
  final String? bannerUrl;

  Merchant({
    required this.id,
    required this.businessName,
    this.logoPath,
    this.category,
    this.bannerUrl,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'] ?? '',
      businessName: json['businessName'] ?? 'Unknown',
      logoPath: json['logoPath'],
      category: json['category'],
      bannerUrl: json['bannerUrl'],
    );
  }
}