// Theme colors matching Quizlet's dark mode design
import 'package:flutter/material.dart';

/// App color palette derived from Quizlet screenshots
class AppColors {
  AppColors._();

  // Background colors
  static const Color background = Color(0xFF0D1B2A);
  static const Color cardBackground = Color(0xFF1B2838);
  static const Color surface = Color(0xFF2D3E50);
  static const Color surfaceLight = Color(0xFF3D4F61);

  // Accent colors
  static const Color primary = Color(0xFF4255FF);
  static const Color primaryLight = Color(0xFF6B7BFF);
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color accent = Color(0xFFFFCD1F);

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFFF5252);

  // Progress colors
  static const Color progressKnow = Color(0xFF4CAF50);
  static const Color progressLearning = Color(0xFFFFC107);
  static const Color progressNew = Color(0xFFFF9800);

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textHint = Color(0xFF6B7280);

  // Gradient for cards
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
