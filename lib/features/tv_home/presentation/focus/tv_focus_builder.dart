import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Low-level focus wrapper for TV widgets. Exposes the focused state to a
/// [builder] and fires [onSelect] on the remote's OK/Select (plus Enter and a
/// gamepad A button). [onFocusChange] lets parents react to focus - e.g. the
/// hero banner updating to the focused item.
///
/// Built on FocusableActionDetector + Shortcuts/Actions so it works with the
/// D-pad on Android TV and Fire TV.
class TvFocusBuilder extends StatefulWidget {
  const TvFocusBuilder({
    super.key,
    required this.builder,
    this.onSelect,
    this.onFocusChange,
    this.autofocus = false,
    this.focusNode,
  });

  final Widget Function(BuildContext context, bool focused) builder;
  final VoidCallback? onSelect;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<TvFocusBuilder> createState() => _TvFocusBuilderState();
}

class _TvFocusBuilderState extends State<TvFocusBuilder> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onShowFocusHighlight: _handleFocus,
      onFocusChange: _handleFocus,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onSelect?.call();
            return null;
          },
        ),
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: widget.builder(context, _focused),
      ),
    );
  }

  void _handleFocus(bool value) {
    if (value == _focused || !mounted) return;
    setState(() => _focused = value);
    widget.onFocusChange?.call(value);
  }
}
