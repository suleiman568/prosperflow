import 'package:flutter/material.dart';

import 'app_router.dart';
import 'app_theme.dart';
import '../shared/offline/offline_banner.dart';

class ProsperFlowApp extends StatelessWidget {
  const ProsperFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ProsperFlow',
      debugShowCheckedModeBanner: false,
      theme: ProsperFlowTheme.light(),
      routerConfig: appRouter,
      builder: (context, child) {
        return OfflineBanner(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
