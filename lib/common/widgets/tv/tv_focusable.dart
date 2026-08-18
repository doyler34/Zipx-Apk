import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/platform/tv.dart';

/// Makes any tappable element work with a TV remote's D-pad as well as touch.
///
/// - **On Fire TV / Android TV** the `dpad` package is the sole navigation
///   authority: this delegates entirely to [DpadFocusable] (focus memory,
///   TV-correct directional traversal, auto-scroll-into-view and OK/Select), and
///   none of the app's own focus/traversal/key handling runs. The focus effect
///   (scale + accent border + glow) is drawn through dpad's builder so the
///   design is unchanged.
/// - **Everywhere else** (Android touch, Windows/desktop mouse + keyboard) it
///   keeps its original behaviour: a plain tappable with a keyboard-focus
///   highlight, so those platforms are untouched by the TV migration.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    required this.onPressed,
    this.autofocus = false,
    this.borderRadius = 10,
    this.focusScale = 1.06,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool autofocus;
  final double borderRadius;
  final double focusScale;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  /// The focus highlight (scale + accent border + glow). Shared by both paths so
  /// the look is identical on TV and desktop.
  Widget _effect(BuildContext context, bool focused, Widget child) {
    final accent = Theme.of(context).colorScheme.tertiary;
    return AnimatedScale(
      scale: focused ? widget.focusScale : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: focused ? accent : Colors.transparent, width: 3),
          boxShadow: focused
              ? [BoxShadow(color: accent.withOpacity(0.6), blurRadius: 14, spreadRadius: 1)]
              : null,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fire TV / Android TV: dpad owns focus + navigation + select + scroll.
    if (isAndroidTv) {
      return DpadFocusable(
        autofocus: widget.autofocus,
        onSelect: widget.onPressed,
        // dpad scrolls the focused item into view (its own ensureVisible).
        autoScroll: true,
        builder: (context, isFocused, child) => _effect(context, isFocused, child ?? const SizedBox.shrink()),
        child: widget.child,
      );
    }

    // Non-TV: original tappable with keyboard-focus highlight (unchanged).
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (value) {
        if (mounted) setState(() => _focused = value);
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onPressed();
          return null;
        }),
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: _effect(context, _focused, widget.child),
      ),
    );
  }
}
