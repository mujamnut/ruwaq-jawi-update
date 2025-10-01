import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary 
              ? AppTheme.surfaceColor 
              : AppTheme.primaryColor,
          foregroundColor: isSecondary 
              ? AppTheme.primaryColor 
              : AppTheme.textLightColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSecondary 
                ? BorderSide(color: AppTheme.primaryColor)
                : BorderSide.none,
          ),
          disabledBackgroundColor: isSecondary 
              ? AppTheme.surfaceColor.withValues(alpha: 0.5)
              : AppTheme.primaryColor.withValues(alpha: 0.5),
          disabledForegroundColor: isSecondary 
              ? AppTheme.textSecondaryColor
              : AppTheme.textLightColor.withValues(alpha: 0.7),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSecondary 
                        ? AppTheme.primaryColor 
                        : AppTheme.textLightColor,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSecondary 
                          ? AppTheme.primaryColor 
                          : AppTheme.textLightColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
