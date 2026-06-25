import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/colours.dart';
import '../../providers/merchants_provider.dart';
import '../../providers/categories_provider.dart';
import '../../models/category_model.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  String? _tempCategory;
  String? _tempSubCategory;

  final Map<String, IconData> _categoryIcons = {
    "Food & Beverage": Icons.fastfood_rounded,
    "Food & Beverages": Icons.fastfood_rounded,
    "Retail": Icons.shopping_bag_rounded,
    "Health": Icons.medical_services_rounded,
    "Services": Icons.miscellaneous_services_rounded,
    "Entertainment": Icons.movie_rounded,
    "Sports": Icons.sports_soccer_rounded,
    "Fitness & Wellness": Icons.fitness_center_rounded,
    "Lifestyle": Icons.style_rounded,
  };

  @override
  void initState() {
    super.initState();
    final currentState = ref.read(studentMerchantsProvider);
    _tempCategory = currentState.selectedCategory;
    _tempSubCategory = currentState.selectedSubCategory;
  }

  void _onCategorySelected(String category) {
    setState(() {
      if (_tempCategory == category) {
        _tempCategory = null;
        _tempSubCategory = null;
      } else {
        _tempCategory = category;
        _tempSubCategory = null; // Reset subcat when cat changes
      }
    });
  }

  void _onSubCategorySelected(String subCategory) {
    setState(() {
      if (_tempSubCategory == subCategory) {
        _tempSubCategory = null;
      } else {
        _tempSubCategory = subCategory;
      }
    });
  }

  List<MerchantCategory> _getStaticCategoriesFallback() {
    return [
      MerchantCategory(
        id: '1',
        name: 'Food & Beverages',
        sortOrder: 1,
        isActive: true,
        subcategories: [
          'Fast Food', 'Pizza', 'Burgers', 'Desi', 'Asian', 'BBQ',
          'Cafés', 'Coffee Shops', 'Desserts & Ice Cream', 'Bakery', 'Juices & Smoothies'
        ].asMap().entries.map((e) => MerchantSubcategory(
          id: '1-${e.key}',
          categoryId: '1',
          name: e.value,
          sortOrder: e.key + 1,
          isActive: true,
        )).toList(),
      ),
      MerchantCategory(
        id: '2',
        name: 'Sports',
        sortOrder: 2,
        isActive: true,
        subcategories: [
          'Indoor sports clubs', 'Snooker clubs', 'Football', 'Cricket',
          'Badminton', 'Tennis & Padel', 'Swimming', 'Martial Arts',
          'Sportswear', 'Sports Equipment', 'Coaching & Academies'
        ].asMap().entries.map((e) => MerchantSubcategory(
          id: '2-${e.key}',
          categoryId: '2',
          name: e.value,
          sortOrder: e.key + 1,
          isActive: true,
        )).toList(),
      ),
      MerchantCategory(
        id: '3',
        name: 'Entertainment',
        sortOrder: 3,
        isActive: true,
        subcategories: [
          'Cinemas', 'Gaming', 'Escape Rooms', 'Bowling', 'Go-Karting',
          'Theme Parks', 'Board Games', 'Events & Concerts', 'VR Experiences'
        ].asMap().entries.map((e) => MerchantSubcategory(
          id: '3-${e.key}',
          categoryId: '3',
          name: e.value,
          sortOrder: e.key + 1,
          isActive: true,
        )).toList(),
      ),
      MerchantCategory(
        id: '4',
        name: 'Fitness & Wellness',
        sortOrder: 4,
        isActive: true,
        subcategories: [
          'Gyms', 'CrossFit', 'Physiotherapy', 'Wellness Centers'
        ].asMap().entries.map((e) => MerchantSubcategory(
          id: '4-${e.key}',
          categoryId: '4',
          name: e.value,
          sortOrder: e.key + 1,
          isActive: true,
        )).toList(),
      ),
      MerchantCategory(
        id: '5',
        name: 'Lifestyle',
        sortOrder: 5,
        isActive: true,
        subcategories: [
          'Beauty & Grooming', 'Salons & Barbers', 'Skincare & Cosmetics',
          'Perfumes', 'Accessories', 'Gifts', 'Books & Stationery', 'Tech Accessories'
        ].asMap().entries.map((e) => MerchantSubcategory(
          id: '5-${e.key}',
          categoryId: '5',
          name: e.value,
          sortOrder: e.key + 1,
          isActive: true,
        )).toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? _getStaticCategoriesFallback();

    // Find active subcategories for selected category
    List<String> subcategories = [];
    if (_tempCategory != null) {
      final matchedCat = categories.firstWhere(
        (cat) => cat.name == _tempCategory,
        orElse: () => MerchantCategory(id: '', name: '', sortOrder: 0, isActive: false, subcategories: []),
      );
      subcategories = matchedCat.subcategories.where((sub) => sub.isActive).map((sub) => sub.name).toList();
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Filter Restaurants",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_tempCategory != null || _tempSubCategory != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _tempCategory = null;
                      _tempSubCategory = null;
                    });
                  },
                  child: const Text(
                    "Clear All",
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Categories Wrap
          const Text(
            "Category",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: categories.where((c) => c.isActive).map((cat) {
              final isSelected = _tempCategory == cat.name;
              return GestureDetector(
                onTap: () => _onCategorySelected(cat.name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.lightCanvas,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[200]!,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _categoryIcons[cat.name] ?? Icons.category_rounded,
                        size: 18,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Subcategories
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _tempCategory != null && subcategories.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        "Subcategory",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: subcategories.map((sub) {
                            final isSelected = _tempSubCategory == sub;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(sub),
                                selected: isSelected,
                                onSelected: (_) => _onSubCategorySelected(sub),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                ),
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.lightCanvas,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.primary : Colors.grey[200]!,
                                  ),
                                ),
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 40),

          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                ref.read(studentMerchantsProvider.notifier).setFilters(_tempCategory, _tempSubCategory);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.4),
              ),
              child: const Text(
                "Apply Filters",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
