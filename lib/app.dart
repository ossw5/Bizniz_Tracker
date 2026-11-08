import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/products/presentation/controllers.dart';
import 'features/sales/domain/sale_repository.dart';
import 'features/settings/controllers/app_settings_controller.dart';

class BiznizTrackerApp extends StatelessWidget {
  final ProductController? productController;
  final SaleRepository? saleRepository;
  final AppSettingsController settingsController;

  BiznizTrackerApp({
    super.key,
    this.productController,
    this.saleRepository,
    AppSettingsController? settingsController,
  }) : settingsController = settingsController ?? AppSettingsController();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) => MaterialApp(
        title: 'Bizniz Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.buildTheme(),
        darkTheme: AppTheme.buildTheme(brightness: Brightness.dark),
        themeMode: settingsController.themeMode,
        home: DashboardScreen(
          productController: productController,
          saleRepository: saleRepository,
          settingsController: settingsController,
        ),
      ),
    );
  }
}
