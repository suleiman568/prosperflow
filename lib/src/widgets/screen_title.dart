import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The main title in a screen header, marked as a heading so screen readers
/// announce it as such and let users jump between screens by heading. Renders
/// with [AppText.screenTitle] to match every hand-rolled header it replaces.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.style});

  final String title;

  /// Override the default [AppText.screenTitle] (e.g. the dashboard's larger
  /// brand title) while keeping the heading semantics.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(title, style: style ?? AppText.screenTitle),
    );
  }
}
