import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_theme.dart';

class AdminUsersSearchFilters extends StatelessWidget {
  const AdminUsersSearchFilters({
    super.key,
    required this.searchQuery,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final String searchQuery;
  final String selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surfaceColor,
      child: Column(
        children: [
          TextFormField(
            initialValue: searchQuery,
            decoration: InputDecoration(
              hintText: 'Cari nama atau email pengguna...',
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: Colors.grey,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipOption(
                  label: 'Semua',
                  value: 'all',
                  selectedValue: selectedFilter,
                  onChanged: onFilterChanged,
                ),
                _FilterChipOption(
                  label: 'Langganan Aktif',
                  value: 'active',
                  selectedValue: selectedFilter,
                  onChanged: onFilterChanged,
                ),
                _FilterChipOption(
                  label: 'Tiada Langganan',
                  value: 'inactive',
                  selectedValue: selectedFilter,
                  onChanged: onFilterChanged,
                ),
                _FilterChipOption(
                  label: 'Admin',
                  value: 'admin',
                  selectedValue: selectedFilter,
                  onChanged: onFilterChanged,
                ),
                _FilterChipOption(
                  label: 'Pelajar',
                  value: 'student',
                  selectedValue: selectedFilter,
                  onChanged: onFilterChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipOption extends StatelessWidget {
  const _FilterChipOption({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          onChanged(selected ? value : 'all');
        },
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        backgroundColor: AppTheme.backgroundColor,
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
