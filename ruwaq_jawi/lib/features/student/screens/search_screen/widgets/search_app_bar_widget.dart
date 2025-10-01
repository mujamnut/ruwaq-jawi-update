import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';

class SearchAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final Function(String) onChanged;

  const SearchAppBarWidget({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearch,
    required this.onClear,
    required this.onChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: AppTheme.textPrimaryColor,
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      leading: IconButton(
        icon: PhosphorIcon(
          PhosphorIcons.arrowLeft(),
          color: AppTheme.textPrimaryColor,
          size: 24,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          children: [
            Expanded(child: _buildSearchField(context)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (searchController.text.isNotEmpty) {
                  onSearch();
                }
              },
              child: Text(
                'Search',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
      titleSpacing: 0,
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: TextField(
        controller: searchController,
        focusNode: searchFocusNode,
        style: const TextStyle(
          color: AppTheme.textPrimaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFEEEEEE),
          hintText: 'Cari kitab yang anda inginkan...',
          hintStyle: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: PhosphorIcon(
              PhosphorIcons.magnifyingGlass(),
              color: AppTheme.textSecondaryColor,
              size: 20,
            ),
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: onClear,
                  icon: PhosphorIcon(
                    PhosphorIcons.x(),
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: onChanged,
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            onSearch();
          }
        },
      ),
    );
  }
}
