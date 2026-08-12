import 'package:flutter/material.dart';

/// Wraps a widget so it scales up slightly (and lifts above its neighbours) when
/// the mouse hovers it - the standard desktop poster-card interaction. No-op on
/// touch devices since hover never fires there.
class HoverScale extends StatefulWidget {
  const HoverScale({super.key, required this.child, this.scale = 1.06});

  final Widget child;
  final double scale;

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
