import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps any tappable element so it works with a TV remote's D-pad as well as
/// touch.
///
/// - On a TV, arrow keys move focus between [TvFocusable]s (Flutter's built-in
///   directional traversal), and the focused one shows a clear highlight
///   (scale + accent border + glow) so the user can see what's selected.
/// - The remote's OK/Select button (as well as Enter and a gamepad A button)
///   triggers [onPressed], the same as a tap.
/// - On a phone it's effectively a normal tappable: touch never triggers the
///   focus highlight, so behaviour is unchanged.
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

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (value) {
        if (mounted) setState(() => _focused = value);
      },
      // Scroll the focused item into view within every enclosing scrollable, so
      // D-pad focus moving to an off-screen card/row brings it on-screen (both
      // the horizontal row and the vertical page). Runs after layout settles.
      onFocusChange: (focused) {
        if (!focused || !mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        });
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _focused ? widget.focusScale : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              // Always-present border (transparent when unfocused) so gaining
              // focus never shifts layout.
              border: Border.all(
                color: _focused ? accent : Colors.transparent,
                width: 3,
              ),
              boxShadow: _focused
                  ? [BoxShadow(color: accent.withOpacity(0.6), blurRadius: 14, spreadRadius: 1)]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
