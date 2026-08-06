import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/beta_popup_service.dart';

/// A responsive, reusable "Beta V1" launch popup.
///
/// It adapts to any screen (phone / tablet / Android TV / Firestick / desktop)
/// using [MediaQuery] + [LayoutBuilder] and percentage-based constraints - no
/// hard-coded modal dimensions and no device-name checks. Content determines
/// the height; a [SingleChildScrollView] prevents overflow on small screens.
///
/// Use [showIfNeeded] to display it once per version (subject to the
/// [BetaPopupService] cooldown) over the current app UI, behind a darkened +
/// blurred, non-dismissible modal barrier.
class BetaV1Popup extends StatefulWidget {
  const BetaV1Popup({super.key, this.onReportIssue, this.reportUrl});

  /// Called when "Report Issue" is tapped. Provide this OR [reportUrl].
  final VoidCallback? onReportIssue;

  /// Placeholder URL opened on "Report Issue" (replace with your real one).
  final String? reportUrl;

  static const Color _red = Color(0xFFE11D2A);

  /// Shows the popup if [BetaPopupService.shouldShow] allows it. Darkens and
  /// blurs the app behind a modal barrier that can't be dismissed by tapping
  /// outside or the system back button. Persists the dismissal on close.
  static Future<void> showIfNeeded(
    BuildContext context, {
    VoidCallback? onReportIssue,
    String? reportUrl,
  }) async {
    if (!await BetaPopupService.shouldShow()) return;
    // Claim the session slot immediately so a rebuild can't open a second one.
    BetaPopupService.markHandledThisSession();
    if (!context.mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false, // no accidental outside-tap dismissal
      barrierLabel: 'Beta V1',
      barrierColor: Colors.black.withOpacity(0.55), // darken the app behind
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a1, a2) => BetaV1Popup(onReportIssue: onReportIssue, reportUrl: reportUrl),
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return BackdropFilter(
          // Slightly blur everything behind the popup.
          filter: ImageFilter.blur(sigmaX: 6 * curved.value, sigmaY: 6 * curved.value),
          child: FadeTransition(
            opacity: curved,
            child: Transform.scale(scale: 0.98 + 0.02 * curved.value, child: child),
          ),
        );
      },
    );

    await BetaPopupService.markSeen();
  }

  @override
  State<BetaV1Popup> createState() => _BetaV1PopupState();
}

class _BetaV1PopupState extends State<BetaV1Popup> {
  // Focus nodes for keyboard + TV-remote navigation. Continue is focused first.
  final FocusNode _continueFocus = FocusNode(debugLabel: 'beta_continue');
  final FocusNode _reportFocus = FocusNode(debugLabel: 'beta_report');

  static const List<String> _paragraphs = [
    'Thanks for downloading and using the app.',
    'This version is still in beta, so you may run into bugs or unfinished features.',
    'If you find any issues, please report them and they will be fixed in future updates.',
  ];

  @override
  void dispose() {
    _continueFocus.dispose();
    _reportFocus.dispose();
    super.dispose();
  }

  Future<void> _onReport() async {
    if (widget.onReportIssue != null) {
      widget.onReportIssue!();
      return;
    }
    final url = widget.reportUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignore launch failures - the popup stays open so the user can Continue.
    }
  }

  // Explicit pop (not maybePop) so it closes past the PopScope guard.
  void _onContinue() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Honour increased system text scaling, but clamp the extremes so the
    // layout stays usable.
    final clampedScaler = media.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.5);

    return PopScope(
      canPop: false, // system back can't dismiss the beta modal
      child: MediaQuery(
        data: media.copyWith(textScaler: clampedScaler),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final maxH = constraints.maxHeight;

              // Responsive width fraction: narrower as the screen grows, so the
              // card never stretches across a TV/desktop. These are breakpoints
              // on the AVAILABLE width, not fixed modal dimensions.
              final double widthFactor;
              if (maxW < 480) {
                widthFactor = 0.94;
              } else if (maxW < 900) {
                widthFactor = 0.72;
              } else if (maxW < 1400) {
                widthFactor = 0.5;
              } else {
                widthFactor = 0.36;
              }

              final modalMaxWidth = maxW * widthFactor;
              final modalMaxHeight = maxH * 0.9; // cap height to a % of the screen

              // Scale spacing + typography from the smaller side of the screen,
              // with sensible clamps.
              final unit = maxW < maxH ? maxW : maxH;
              final outerMargin = (unit * 0.04).clamp(12.0, 28.0);
              final pad = (unit * 0.055).clamp(18.0, 34.0);
              final gap = (unit * 0.03).clamp(12.0, 22.0);
              final titleSize = (unit * 0.08).clamp(24.0, 40.0);
              final bodySize = (unit * 0.036).clamp(14.0, 18.0);
              final btnTextSize = (unit * 0.036).clamp(14.0, 18.0);

              return Center(
                child: Padding(
                  padding: EdgeInsets.all(outerMargin), // safe margins around the modal
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: modalMaxWidth, maxHeight: modalMaxHeight),
                    child: FocusTraversalGroup(
                      child: _card(pad: pad, gap: gap, titleSize: titleSize, bodySize: bodySize, btnTextSize: btnTextSize),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card({
    required double pad,
    required double gap,
    required double titleSize,
    required double bodySize,
    required double btnTextSize,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BetaV1Popup._red.withOpacity(0.55), width: 1.4), // subtle red border
        boxShadow: [
          // Soft shadow
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: 2, offset: const Offset(0, 20)),
          // Subtle red glow
          BoxShadow(color: BetaV1Popup._red.withOpacity(0.28), blurRadius: 34, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), // glass effect on the card
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16161B).withOpacity(0.82), // dark charcoal, slightly transparent
              borderRadius: BorderRadius.circular(24),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView( // never overflows on small screens
                padding: EdgeInsets.all(pad),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // content determines height
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title(titleSize),
                    SizedBox(height: gap),
                    _bodyText(bodySize),
                    SizedBox(height: gap * 1.4),
                    _buttons(gap: gap, textSize: btnTextSize),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(double size) {
    // FittedBox scales the (short) title down if huge text settings would
    // otherwise overflow horizontally.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.1),
          children: const [
            TextSpan(text: 'Beta', style: TextStyle(color: Colors.white)),
            TextSpan(text: ' V1', style: TextStyle(color: BetaV1Popup._red)),
          ],
        ),
      ),
    );
  }

  Widget _bodyText(double size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _paragraphs.length; i++) ...[
          if (i > 0) SizedBox(height: size * 0.8),
          Text(
            _paragraphs[i],
            softWrap: true, // text wraps naturally
            style: TextStyle(color: Colors.white70, fontSize: size, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _buttons({required double gap, required double textSize}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decide side-by-side vs stacked based on the available content width.
        final fitsRow = constraints.maxWidth >= 360;
        final report = _reportButton(textSize);
        final cont = _continueButton(textSize);

        if (fitsRow) {
          return Row(
            children: [
              Expanded(child: report), // expand evenly in a row
              SizedBox(width: gap),
              Expanded(child: cont),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(width: double.infinity, child: report),
            SizedBox(height: gap),
            SizedBox(width: double.infinity, child: cont),
          ],
        );
      },
    );
  }

  Widget _reportButton(double textSize) {
    return OutlinedButton(
      focusNode: _reportFocus,
      onPressed: _onReport,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.04), // dark transparent
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24, width: 1), // thin grey border
        padding: EdgeInsets.symmetric(vertical: textSize * 0.95, horizontal: textSize),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: BetaV1Popup._red, size: textSize * 1.25), // red warning icon
          SizedBox(width: textSize * 0.5),
          Flexible(
            child: Text(
              'Report Issue',
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(fontSize: textSize, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueButton(double textSize) {
    return ElevatedButton(
      focusNode: _continueFocus,
      autofocus: true, // initial focus for Android TV / Firestick / keyboard
      onPressed: _onContinue,
      style: ElevatedButton.styleFrom(
        backgroundColor: BetaV1Popup._red, // bright red
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: textSize * 0.95, horizontal: textSize),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'Continue',
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(fontSize: textSize, color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: textSize * 0.5),
          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: textSize * 1.25), // right-arrow icon
        ],
      ),
    );
  }
}
