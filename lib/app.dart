import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/products/presentation/controllers.dart';
import 'features/sales/domain/sale_repository.dart';

class BiznizTrackerApp extends StatelessWidget {
  final ProductController? productController;
  final SaleRepository? saleRepository;

  const BiznizTrackerApp({
    super.key,
    this.productController,
    this.saleRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bizniz Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      home: DashboardScreen(
        productController: productController,
        saleRepository: saleRepository,
      ),
    );
  }
}
