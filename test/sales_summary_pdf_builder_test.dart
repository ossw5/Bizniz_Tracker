import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bizniz_tracker/features/sales_management/services/sales_summary_pdf_builder.dart';

void main() {
  test(
    'lays out multiple transaction and product rows across PDF pages',
    () async {
      final rows = <List<Object?>>[
        ['Business Name', 'Corner Shop'],
        ['Report Type', 'Sales Summary with Product Total Sales'],
        ['Report Period', 'Monthly'],
        ['Start Date', '2026-11-01'],
        ['End Date', '2026-11-30'],
        ['Generated Date', '2026-12-01'],
        ['Prepared By', 'Owner'],
        [],
        ['Sales Overview'],
        ['Total Sales Revenue', '2500.00'],
        ['Total Completed Transactions', 36],
        ['Total Quantity of Products Sold', 72],
        ['Total Discounts', '25.00'],
        ['Estimated Gross Profit', '900.00'],
        [],
        ['Sales Transaction Records'],
        [
          'Receipt/Transaction Number',
          'Transaction Date',
          'Number of Items',
          'Total Amount',
          'Payment Method',
          'Transaction Status',
        ],
        for (var index = 1; index <= 36; index++)
          [
            'Receipt-${index.toString().padLeft(3, '0')}',
            '2026-11-${(index % 30 + 1).toString().padLeft(2, '0')}',
            index % 4 + 1,
            (index * 25).toStringAsFixed(2),
            index.isEven ? 'Bank Transfer' : 'Cash',
            'Completed',
          ],
        [],
        ['Payment Summary'],
        ['Payment Method', 'Total Amount'],
        ['Cash', '1250.00'],
        ['Bank Transfer', '1250.00'],
        [],
        ['Product Total Sales'],
        [
          'Product Name',
          'Product ID',
          'Total Quantity Sold',
          'Total Sales Revenue',
          'Total Cost of Goods Sold',
          'Estimated Profit per Product',
        ],
        for (var index = 1; index <= 36; index++)
          [
            'Product $index - Long display name',
            'product-$index',
            index * 2,
            (index * 25).toStringAsFixed(2),
            (index * 15).toStringAsFixed(2),
            (index * 10).toStringAsFixed(2),
          ],
        [],
        ['Best-Selling Products'],
        ['Product Name', 'Product ID', 'Quantity', 'Sales Revenue', 'Profit'],
        ['Product 1', 'product-1', 72, '900.00', '360.00'],
        [],
        ['Products with Highest Sales Revenue'],
        ['Product Name', 'Product ID', 'Quantity', 'Sales Revenue', 'Profit'],
        ['Product 2', 'product-2', 70, '850.00', '340.00'],
        [],
        ['Products with Highest Estimated Profit'],
        ['Product Name', 'Product ID', 'Quantity', 'Sales Revenue', 'Profit'],
        ['Product 3', 'product-3', 68, '800.00', '320.00'],
      ];

      final document = const SalesSummaryPdfBuilder().build(
        title: 'Sales Summary with Product Total Sales - Corner Shop',
        rows: rows,
      );
      final pdf = await document.save();

      expect(utf8.decode(pdf.take(5).toList()), '%PDF-');
      expect(pdf.length, greaterThan(2500));
    },
  );
}
