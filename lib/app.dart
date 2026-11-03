import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';

class BiznizTrackerApp extends StatelessWidget {
  const BiznizTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bizniz Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      home: const DashboardScreen(),
    );
  }
}
