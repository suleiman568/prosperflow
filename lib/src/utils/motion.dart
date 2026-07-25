import 'package:flutter/widgets.dart';

/// Collapses [duration] to zero when the platform "reduce motion" accessibility
/// setting is on, so implicit animations (press feedback, expand/collapse)
/// become instant state changes instead of tweened motion — the same principle
/// the shimmer loaders and page transitions already follow.
Duration reducedMotion(BuildContext context, Duration duration) =>
    MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
