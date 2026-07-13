// lib/screens/web/quality_management/quality_colors.dart
import 'package:flutter/material.dart';

class QColors {
  // Primary colors
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFFEEF2FF);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Neutral colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  // Performance colors
  static Color getPerformanceColor(double percentage) {
    if (percentage >= 85) return const Color(0xFF10B981);
    if (percentage >= 70) return const Color(0xFF3B82F6);
    if (percentage >= 55) return const Color(0xFFF59E0B);
    if (percentage >= 40) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  static Color getPerformanceBgColor(double percentage) {
    return getPerformanceColor(percentage).withOpacity(0.1);
  }

  static String getPerformanceLabel(double percentage) {
    if (percentage >= 85) return 'ممتاز';
    if (percentage >= 70) return 'جيد جداً';
    if (percentage >= 55) return 'جيد';
    if (percentage >= 40) return 'مقبول';
    return 'ضعيف';
  }
}
