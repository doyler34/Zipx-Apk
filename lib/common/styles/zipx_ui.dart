import 'package:flutter/material.dart';

/// Shared palette + metrics for the ZIPX "premium dark" home redesign.
/// Kept as explicit constants (rather than reading the theme) so the look
/// matches the reference mockup exactly regardless of the active theme.
class ZipxUi {
  ZipxUi._();

  static const Color bg = Color(0xFF0A0A0C);
  static const Color surface = Color(0xFF16161B);
  static const Color surfaceHigh = Color(0xFF23232B);
  static const Color red = Color(0xFFE11D2A);
  static const Color textMuted = Color(0xFF9A9AA5);

  static const double cardRadius = 18;
}
