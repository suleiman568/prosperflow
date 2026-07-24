import 'package:flutter/services.dart';

/// Semantic wrapper over [HapticFeedback] so screens express intent
/// ("this action succeeded") rather than a raw impact level, and the physical
/// feel stays consistent across the app.
abstract final class AppHaptics {
  /// A completed positive action — sale recorded, product/expense added,
  /// credit collected. A firm, satisfying confirmation.
  static void success() => HapticFeedback.mediumImpact();

  /// A discrete value change under the finger — the quantity steppers.
  static void selection() => HapticFeedback.selectionClick();

  /// A destructive action taken — an item deleted. A heavier bump so it
  /// registers as consequential.
  static void warning() => HapticFeedback.heavyImpact();
}
