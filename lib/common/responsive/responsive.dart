import 'package:flutter/widgets.dart';

/// Screen-width breakpoints that drive the app's responsive (phone vs desktop)
/// layouts. Keyed off the live window width - not the platform - so a resized
/// Windows window, a tablet, or a phone all pick the right layout.
class Responsive {
  Responsive._();

  /// At or above this width the app uses its desktop layout: a left navigation
  /// rail instead of the bottom bar, and width-constrained, centred content.
  static const double desktopBreakpoint = 900;

  /// A roomier breakpoint for two-/three-column content (e.g. the details page).
  static const double wideBreakpoint = 1200;

  /// The largest the main content column is ever allowed to grow, so rows and
  /// heroes don't stretch edge-to-edge across an ultrawide monitor.
  static const double maxContentWidth = 1360;

  static double _width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isDesktop(BuildContext context) => _width(context) >= desktopBreakpoint;

  static bool isWide(BuildContext context) => _width(context) >= wideBreakpoint;
}
