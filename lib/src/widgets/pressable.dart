import 'package:flutter/material.dart';

/// Wraps a tappable control with subtle press feedback — a quick scale-down
/// while held — so custom `GestureDetector` controls (FABs, steppers, cards,
/// pickers) feel responsive like Material buttons do. Preserves tap
/// semantics; a null [onTap] renders the child inert.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.scale = 0.97,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Screen-reader label. When set, the control is exposed as a button
  /// (enabled when [onTap] is non-null) with this label, and its visual
  /// children are hidden from semantics to avoid a doubled announcement.
  final String? semanticLabel;

  /// Pressed scale (1.0 = no shrink). 0.97 is the default nudge.
  final double scale;

  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    // Only a live control shrinks; releasing always clears the state, even
    // if onTap has since gone null (so it can't stay stuck scaled-down).
    if (value && widget.onTap == null) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a parent disables the control (onTap → null) mid-press — and no
    // release event ever arrives because it's now inert — release the
    // pressed state here so the button returns to full size.
    if (_pressed && widget.onTap == null) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget result = GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.semanticLabel == null
            ? widget.child
            : ExcludeSemantics(child: widget.child),
      ),
    );
    if (widget.semanticLabel != null) {
      // container: true forces a standalone semantics node so the control is
      // its own focusable button even when nested among a card's text —
      // otherwise the label gets merged into the surrounding content.
      result = Semantics(
        container: true,
        button: true,
        enabled: widget.onTap != null,
        label: widget.semanticLabel,
        child: result,
      );
    }
    return result;
  }
}
