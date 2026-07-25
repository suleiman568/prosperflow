import 'package:flutter/material.dart';

/// The app's signature route transition: the incoming page fades in while
/// rising a few percent of the screen height, on an ease-out curve. Calmer and
/// more consistent than the per-platform defaults (Android's zoom, iOS's
/// horizontal slide), so navigation feels the same everywhere.
///
/// Only the incoming page is animated; the outgoing page rests underneath,
/// which keeps the motion light for a business app used all day.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Honour the platform "reduce motion" setting: skip the fade+slide and
    // show the destination instantly, the same way the shimmer loaders drop
    // their animation.
    if (MediaQuery.of(context).disableAnimations) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Applies [AppPageTransitionsBuilder] to every platform so route transitions
/// are identical across Android, iOS, and the web preview.
const appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: AppPageTransitionsBuilder(),
    TargetPlatform.iOS: AppPageTransitionsBuilder(),
    TargetPlatform.macOS: AppPageTransitionsBuilder(),
    TargetPlatform.windows: AppPageTransitionsBuilder(),
    TargetPlatform.linux: AppPageTransitionsBuilder(),
    TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
  },
);
