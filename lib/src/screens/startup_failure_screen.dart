import 'package:flutter/material.dart';

import '../theme/page_transitions.dart';
import '../theme/tokens.dart';
import '../widgets/error_state.dart';

/// Shown when the app could not wire up its backend.
///
/// It stands in front of the ledger rather than beside it, because there is
/// no honest half-working state to offer: without a backend the app cannot
/// tell who is signed in, so it cannot know whose ledger to show, and it
/// cannot back anything up. The alternative — the one this replaces — was to
/// carry on with the preview fakes, which let anyone in and then reported the
/// data as backed up.
///
/// The wording avoids blaming the connection. Being offline does not cause
/// this, and a trader told to check their signal would go looking for a
/// problem that is not there.
class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProsperFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.appBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.action,
          primary: AppColors.action,
        ),
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: appPageTransitionsTheme,
      ),
      home: Scaffold(
        backgroundColor: AppColors.appBg,
        body: SafeArea(
          child: ErrorState(
            onRetry: onRetry,
            icon: Icons.error_outline_rounded,
            title: "ProsperFlow can't start",
            message:
                'This phone could not set up your account.\n'
                'Anything you have already saved is safe on the phone.',
          ),
        ),
      ),
    );
  }
}
