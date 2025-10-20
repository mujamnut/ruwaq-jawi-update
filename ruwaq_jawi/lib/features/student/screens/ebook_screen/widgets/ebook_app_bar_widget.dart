import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';

class EbookAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final bool isScrolled;
  const EbookAppBarWidget({super.key, this.isScrolled = false});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      title: Text(
        'E-Book',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimaryColor,
        ),
      ),
      backgroundColor: isScrolled ? AppTheme.surfaceColor : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: isScrolled ? 1 : 0,
      automaticallyImplyLeading: false,
      titleSpacing: 20, // Letak kiri dengan spacing
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }
}
