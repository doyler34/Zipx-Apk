import 'package:flutter/material.dart';

/// A horizontal poster row with hover-revealed left/right arrow overlays that
/// scroll it a page at a time - so a mouse user (no swipe / trackpad fling) can
/// page through a catalogue column. The arrows only appear on hover and only on
/// the side that can still scroll.
class HScrollRow extends StatefulWidget {
  const HScrollRow({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;

  @override
  State<HScrollRow> createState() => _HScrollRowState();
}

class _HScrollRowState extends State<HScrollRow> {
  final ScrollController _controller = ScrollController();
  bool _hover = false;
  bool _canLeft = false;
  bool _canRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _controller.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final left = pos.pixels > 1;
    final right = pos.pixels < pos.maxScrollExtent - 1;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  void _page(int dir) {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final delta = pos.viewportDimension * 0.85 * dir;
    _controller.animateTo(
      (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            ListView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: widget.padding,
              itemCount: widget.itemCount,
              itemBuilder: widget.itemBuilder,
            ),
            Positioned(left: 0, top: 0, bottom: 0, child: _arrow(left: true, visible: _hover && _canLeft)),
            Positioned(right: 0, top: 0, bottom: 0, child: _arrow(left: false, visible: _hover && _canRight)),
          ],
        ),
      ),
    );
  }

  Widget _arrow({required bool left, required bool visible}) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Align(
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _page(left ? -1 : 1),
              child: Container(
                width: 44,
                margin: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: left ? Alignment.centerLeft : Alignment.centerRight,
                    end: left ? Alignment.centerRight : Alignment.centerLeft,
                    colors: const [Color(0xCC0A0A0C), Color(0x000A0A0C)],
                  ),
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xE6202028)),
                  child: Icon(left ? Icons.chevron_left : Icons.chevron_right, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
