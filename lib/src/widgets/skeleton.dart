import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A shimmering placeholder block shown while a screen's data loads, so the
/// first frame reads as "loading" instead of flashing blank or a stale ₦0.
///
/// Each box runs its own repeating controller that sweeps a lighter highlight
/// band left-to-right across the placeholder fill (the same [AppColors.inputBg]
/// used for inactive pills and filled inputs).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8})
    : shape = BoxShape.rectangle;

  /// A round placeholder (e.g. an icon-circle); [size] is the diameter.
  const Skeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = 0,
      shape = BoxShape.circle;

  /// Null width fills the available horizontal space.
  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = AppColors.inputBg;
    const highlight = Color(0xFFF8F8F6);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.radius)
                : null,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [base, highlight, base],
              // A highlight band centred on t, sweeping across as t: 0 → 1.
              stops: [
                (t - 0.3).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
