import 'package:flutter/painting.dart';

/// Colour from the ProsperFlow Identity Spec (§01).
///
/// Deliberately separate from [AppColors] in theme/tokens.dart: the product
/// palette is still the green system, and the two are being reconciled as a
/// distinct piece of work. Anything that is *the brand* — logo, app icon,
/// splash — reads from here; product chrome still reads from AppColors.
abstract final class BrandColors {
  /// All type, the icon on light, app-icon tiles. Carries every text role.
  ///
  /// On [bone] this is 16.9:1.
  static const ink = Color(0xFF17150F);

  /// The single accent: icon on dark, the F crossbar, one primary action per
  /// screen.
  ///
  /// On [ink] this is 8.3:1 (AAA) — the app-icon and dark-mode pairing. On
  /// [bone] it is 2.0:1, which fails for text: on a light ground marigold is
  /// for shapes and fills only, never body text. The spec names a second
  /// accent and a gradient as explicit don'ts.
  static const marigold = Color(0xFFE5A21C);

  /// Light-mode ground. Pure white is permitted; bone is preferred.
  static const bone = Color(0xFFFAF7F0);
}
