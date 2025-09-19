import 'package:flutter/material.dart';

/// Consistent border radius constants following shadcn design principles
/// Context-based usage:
/// - sm: Admin panels, data-heavy UI (4px)
/// - md: Secondary buttons, inputs, smaller components (8px)
/// - lg: Medium components, cards (12px)
/// - xl: Primary buttons, large cards (16px)
/// - 2xl: Dialogs, modals, overlays (20px)
/// - 3xl: Hero sections, large containers (24px)
class BorderRadiusConstants {
  static const double sm = 4.0;   // Small - Admin panels
  static const double md = 8.0;   // Medium - Secondary buttons
  static const double lg = 12.0;  // Large - Inputs, small cards
  static const double xl = 16.0;  // Extra Large - Primary buttons, cards
  static const double xl2 = 20.0; // 2XL - Dialogs
  static const double xl3 = 24.0; // 3XL - Large containers

  // BorderRadius objects for easy use
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius extraLargeRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius extraLarge2Radius = BorderRadius.all(Radius.circular(xl2));
  static const BorderRadius extraLarge3Radius = BorderRadius.all(Radius.circular(xl3));

  // Specific use cases
  static const BorderRadius adminPanelRadius = smallRadius;
  static const BorderRadius secondaryButtonRadius = mediumRadius;
  static const BorderRadius inputRadius = largeRadius;
  static const BorderRadius cardRadius = extraLargeRadius;
  static const BorderRadius primaryButtonRadius = extraLargeRadius;
  static const BorderRadius dialogRadius = extraLarge2Radius;
  static const BorderRadius heroSectionRadius = extraLarge3Radius;
}