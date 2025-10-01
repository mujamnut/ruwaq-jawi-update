import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../managers/search_manager.dart';

class SearchFilterChipsWidget extends StatelessWidget {
  final SearchManager searchManager;
  final Function(String) onFilterChanged;

  const SearchFilterChipsWidget({
    super.key,
    required this.searchManager,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      child: Container(
        height: 45,
        padding: const EdgeInsets.only(left: 16, top: 6, bottom: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: SearchManager.filterOptions.length,
          itemBuilder: (context, index) {
            final filter = SearchManager.filterOptions[index];
            final isSelected = searchManager.selectedFilter == filter;

            return Container(
              margin: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () => onFilterChanged(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE8E8E8) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? Colors.grey.shade300
                          : Colors.grey.shade200,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimaryColor
                          : AppTheme.textSecondaryColor,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
