import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bizniz_tracker/features/reports/services/report_export_service.dart';

void main() {
  test('CSV export escapes commas, quotes, and line breaks', () {
    expect(
      ReportExportService.toCsv([
        ['Description', 'Amount'],
        ['"Shop", supplies\nweekly', 12.5],
      ]),
      'Description,Amount\r\n"""Shop"", supplies\nweekly",12.5',
    );
  });

  test('XLSX export creates a readable workbook with escaped cell text', () {
    final bytes = ReportExportService.toXlsx([
      ['Product', 'Amount'],
      ['Tea & <coffee>', '25.00'],
    ]);
    final archive = ZipDecoder().decodeBytes(bytes);
    final worksheet = archive.findFile('xl/worksheets/sheet1.xml');

    expect(worksheet, isNotNull);
    final xml = utf8.decode(worksheet!.readBytes()!);
    expect(xml, contains('Tea &amp; &lt;coffee&gt;'));
    expect(xml, contains('r="B2"'));
  });

  test('XLSX export applies requested widths to each report column', () {
    final bytes = ReportExportService.toXlsx(
      [
        ['Product', 'Total Sales'],
        ['Long product name', '125.00'],
      ],
      columnWidths: const [30, 18],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final worksheet = archive.findFile('xl/worksheets/sheet1.xml');
    final xml = utf8.decode(worksheet!.readBytes()!);

    expect(
      xml,
      contains('<col min="1" max="1" width="30.0" customWidth="1"/>'),
    );
    expect(
      xml,
      contains('<col min="2" max="2" width="18.0" customWidth="1"/>'),
    );
  });
}
