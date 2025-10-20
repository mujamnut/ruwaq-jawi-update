import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';

class EbookSearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final bool isSearchFocused;
  final AnimationController animationController;
  final Function(bool) onFocusChanged;
  final Function(String) onChanged;
  final VoidCallback onClear;

  const EbookSearchBarWidget({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.isSearchFocused,
    required this.animationController,
    required this.onFocusChanged,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AnimatedBuilder(
        animation: animationController,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isSearchFocused
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : AppTheme.borderColor,
                width: isSearchFocused ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSearchFocused
                      ? AppTheme.primaryColor.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: isSearchFocused ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: TextField(
              controller: controller,
              onTap: () {
                onFocusChanged(true);
                animationController.forward();
              },
              onEditingComplete: () {
                onFocusChanged(false);
                animationController.reverse();
                FocusScope.of(context).unfocus();
              },
              onChanged: onChanged,
              decoration: InputDecoration(
                filled: false,
                hintText: 'Cari e-book yang anda inginkan...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: PhosphorIcon(
                    PhosphorIcons.magnifyingGlass(),
                    color: isSearchFocused
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: PhosphorIcon(
                          PhosphorIcons.x(),
                          color: AppTheme.textSecondaryColor,
                          size: 18,
                        ),
                        onPressed: onClear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          );
        },
      ),
    );
  }
}
