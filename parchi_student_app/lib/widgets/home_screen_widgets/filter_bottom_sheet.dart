import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/colours.dart';
import '../../providers/merchants_provider.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  String? _tempCategory;
  String? _tempSubCategory;

  final Map<String, List<String>> _categoryMap = {
    "Food & Beverage": ["Fast Food", "Cafe", "Restaurant", "Bakery", "Desserts", "Coffee Shop"],
    "Retail": ["Fashion", "Electronics", "Grocery", "Home & Living", "Beauty"],
    "Health": ["Pharmacy", "Clinic", "Gym & Fitness", "Wellness", "Diagnostics"],
    "Services": ["Salon", "Laundry", "Auto Service", "Education", "Repairs"],
    "Entertainment": ["Gaming", "Cinema", "Travel", "Sports", "Events"],
  };

  final Map<String, IconData> _categoryIcons = {
    "Food & Beverage": Icons.fastfood_rounded,
    "Retail": Icons.shopping_bag_rounded,
    "Health": Icons.medical_services_rounded,
    "Services": Icons.miscellaneous_services_rounded,
    "Entertainment": Icons.movie_rounded,
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

  @override
  Widget build(BuildContext context) {
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

          // Categories Grid
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
            children: _categoryMap.keys.map((cat) {
              final isSelected = _tempCategory == cat;
              return GestureDetector(
                onTap: () => _onCategorySelected(cat),
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
                        _categoryIcons[cat],
                        size: 18,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat,
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

          // Subcategories (Animate appearance)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _tempCategory != null
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
                          children: _categoryMap[_tempCategory]!.map((sub) {
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
