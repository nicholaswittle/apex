import 'package:flutter/material.dart';

class UniversalTheme {
  static const Color primary = Color(0xFF5A2A18);      // Deep Roast Brown
  static const Color accent = Color(0xFFD97706);       // Amber Gold
  static const Color background = Color(0xFFF7EFE5);   // Cream / Soft Tan
  static const Color darkSlate = Color(0xFF3E1F13);    // Dark Chocolate Brown
  static const Color lightCard = Color(0xFFFFFDF9);    // Crisp Ivory White
  static const Color alertRed = Color(0xFF991B1B);     // Deep Brick Red
  static const Color bannerBg = Color(0xFFE2D4C5);     // Medium Warm Tan
  static const Color warningText = Color(0xFF92400E);  // Burnt Amber — warning copy
}

/// Palette for the four staff availability states rendered by
/// `StaffAvailabilityCard`. Grouped here so the states stay visually
/// distinguishable from each other as the set changes.
class AvailabilityPalette {
  static const Color vacationBg = Color(0xFFFEF3C7);
  static const Color vacationAccent = UniversalTheme.accent;
  static const Color vacationText = UniversalTheme.warningText;

  static const Color bookedBg = Color(0xFFDBEAFE);
  static const Color bookedAccent = Color(0xFF2563EB);
  static const Color bookedText = Color(0xFF1E3A8A);

  static const Color availableBg = Color(0xFFD1FAE5);
  static const Color availableAccent = Color(0xFF059669);
  static const Color availableText = Color(0xFF065F46);

  static const Color idleBg = Color(0xFFF3F4F6);
  static const Color idleBorder = Color(0xFFD1D5DB);
  static const Color idleAccent = Color(0xFF9CA3AF);
}