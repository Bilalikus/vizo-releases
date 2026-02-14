import 'package:flutter/material.dart';

/// Vizo Deep Dark color palette — premium, cinematic, ultra-dark.
class AppColors {
  AppColors._();

  // ─── Primary Palette ───────────────────────────────────
  static const Color black = Color(0xFF000000);
  static const Color surface = Color(0xFF0D0D0D);
  static const Color surfaceLight = Color(0xFF161616);
  static const Color surfaceBright = Color(0xFF1E1E1E);
  static const Color accent = Color(0xFF8A2BE2);
  static const Color accentLight = Color(0xFFA855F7);
  static const Color accentDim = Color(0xFF6B21A8);

  // ─── Text ──────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textHint = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF374151);

  // ─── Functional ────────────────────────────────────────
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color callEnd = Color(0xFFDC2626);
  static const Color divider = Color(0xFF1A1A1A);

  // ─── Encryption Status ─────────────────────────────────
  static const Color encryptionActive = Color(0xFF8A2BE2);
  static const Color encryptionInactive = Color(0xFF4B5563);

  // ─── Glass / LiquidGlass ───────────────────────────────
  static const Color glassTint = Color(0xFF1A1A2E);
  static const Color glassBorder = Color(0x26FFFFFF); // white 15%
  static const Color glassBorderBright = Color(0x40FFFFFF); // white 25%
  static const Color glassHighlight = Color(0x0DFFFFFF); // white 5%

  // ─── Gradient ──────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x1AFFFFFF), Color(0x08FFFFFF)],
  );
}
