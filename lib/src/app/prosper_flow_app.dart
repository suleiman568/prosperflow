import 'package:flutter/material.dart';

import 'app_router.dart';
import 'app_theme.dart';

class ProsperFlowApp extends StatelessWidget {
  const ProsperFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ProsperFlow',
      debugShowCheckedModeBanner: false,
      theme: ProsperFlowTheme.light(),
      routerConfig: appRouter,
    );
  }
}
