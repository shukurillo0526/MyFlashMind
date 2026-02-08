/// Quizlet Premium color palette for MyFlashMind
/// Colors sourced from Quizlet's official design system
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════
  // QUIZLET SIGNATURE COLORS
  // ═══════════════════════════════════════════════════════════════
  
  /// Quizlet's signature blue (brand primary)
  static const Color primary = Color(0xFF4255FF);
  static const Color primaryDark = Color(0xFF3347CC);
  static const Color primaryLight = Color(0xFF6B7BFF);
  
  /// Purple accent for gradients and highlights
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color secondaryLight = Color(0xFFA78BFA);
  
  /// Gold/Yellow for stars, achievements, premium
  static const Color accent = Color(0xFFFFCD1F);
  static const Color gold = Color(0xFFFFD700);

  // ═══════════════════════════════════════════════════════════════
  // BACKGROUNDS (Dark Mode - Quizlet Dark Theme)
  // ═══════════════════════════════════════════════════════════════
  
  /// Main app background - deep dark blue
  static const Color background = Color(0xFF0D1B2A);
  
  /// Card/tile backgrounds - slightly lighter
  static const Color cardBackground = Color(0xFF1B2838);
  
  /// Elevated surface (modals, dropdowns)
  static const Color surface = Color(0xFF2D3E50);
  static const Color surfaceLight = Color(0xFF3D4F61);
  
  /// Divider/border color
  static const Color divider = Color(0xFF374151);

  // ═══════════════════════════════════════════════════════════════
  // SEMANTIC / FEEDBACK COLORS
  // ═══════════════════════════════════════════════════════════════
  
  /// Correct / Know / Mastered
  static const Color success = Color(0xFF23B26D);
  
  /// Learning / In Progress
  static const Color warning = Color(0xFFFFBF00);
  
  /// Wrong / Still Learning / Error
  static const Color error = Color(0xFFFF5252);
  
  /// Info blue
  static const Color info = Color(0xFF4CA6FF);

  // ═══════════════════════════════════════════════════════════════
  // PROGRESS TRACKING (SM-2 / Mastery)
  // ═══════════════════════════════════════════════════════════════
  
  /// Mastered cards (green)
  static const Color progressMastered = Color(0xFF23B26D);
  
  /// Familiar/Learning cards (orange/yellow)
  static const Color progressLearning = Color(0xFFFFBF00);
  
  /// New/Not started cards (gray or accent)
  static const Color progressNew = Color(0xFF6B7280);

  // ═══════════════════════════════════════════════════════════════
  // TEXT
  // ═══════════════════════════════════════════════════════════════
  
  /// Primary text - white for dark mode
  static const Color textPrimary = Colors.white;
  
  /// Secondary text - muted gray
  static const Color textSecondary = Color(0xFF9CA3AF);
  
  /// Hint/placeholder text
  static const Color textHint = Color(0xFF6B7280);
  
  /// Disabled text
  static const Color textDisabled = Color(0xFF4B5563);

  // ═══════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════
  
  /// Primary brand gradient (used on buttons, headers, CTAs)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Success gradient (for completion screens)
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF23B26D), Color(0xFF17A589)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Premium/Gold gradient
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════════════════════════
  // LEGACY ALIASES (for backwards compatibility)
  // ═══════════════════════════════════════════════════════════════
  
  @Deprecated('Use progressMastered instead')
  static const Color progressKnow = progressMastered;
}
