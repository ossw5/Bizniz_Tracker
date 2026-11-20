import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SalesSummaryPdfBuilder {
  const SalesSummaryPdfBuilder();

  pw.Document build({
    required String title,
    required List<List<Object?>> rows,
  }) {
    final sections = _sectionsFromRows(rows);
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 42, 28, 32),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
        build: (_) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          for (final section in sections) ...[
            if (section.title != null) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                section.title!,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
            ],
            pw.TableHelper.fromTextArray(
              headers: section.headers,
              data: section.rows,
              headerCount: section.headers == null ? 0 : 1,
              columnWidths: _columnWidths(section),
              cellAlignments: _cellAlignments(section),
              headerAlignments: {
                for (
                  var index = 0;
                  index < (section.headers?.length ?? 2);
                  index++
                )
                  index: pw.Alignment.center,
              },
              defaultColumnWidth: const pw.FlexColumnWidth(1),
              tableWidth: pw.TableWidth.max,
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 6,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );
    return document;
  }

  List<_PdfSection> _sectionsFromRows(List<List<Object?>> rows) {
    final sections = <_PdfSection>[];
    var index = 0;
    final metadata = <List<String>>[];
    while (index < rows.length && rows[index].length == 2) {
      metadata.add(_stringRow(rows[index]));
      index++;
    }
    if (metadata.isNotEmpty) {
      sections.add(_PdfSection(rows: metadata));
    }

    while (index < rows.length) {
      final row = rows[index];
      if (row.isEmpty) {
        index++;
        continue;
      }
      if (row.length != 1) {
        throw const FormatException('A sales report section is malformed.');
      }
      final title = row.single?.toString() ?? '';
      index++;

      if (title == 'Sales Overview') {
        final overview = <List<String>>[];
        while (index < rows.length && rows[index].length == 2) {
          overview.add(_stringRow(rows[index]));
          index++;
        }
        sections.add(_PdfSection(title: title, rows: overview));
        continue;
      }

      if (index >= rows.length || rows[index].length < 2) {
        throw const FormatException('A sales report table header is missing.');
      }
      final headers = _stringRow(rows[index]);
      index++;
      final data = <List<String>>[];
      while (index < rows.length && rows[index].length == headers.length) {
        data.add(_stringRow(rows[index]));
        index++;
      }
      sections.add(_PdfSection(title: title, headers: headers, rows: data));
    }
    return sections;
  }

  List<String> _stringRow(List<Object?> row) =>
      row.map((value) => value?.toString() ?? '').toList(growable: false);

  Map<int, pw.TableColumnWidth> _columnWidths(_PdfSection section) {
    final columnCount = section.headers?.length ?? 2;
    final widths = switch (section.title) {
      'Sales Transaction Records' => const [1.35, 0.85, 0.7, 1.0, 0.95, 1.0],
      'Product Total Sales' => const [1.45, 0.8, 0.8, 1.0, 1.0, 1.1],
      _ => switch (columnCount) {
        2 => const [2.0, 1.0],
        3 => const [1.5, 1.0, 1.1],
        5 => const [1.45, 0.85, 0.7, 1.0, 1.0],
        6 => const [1.4, 0.85, 0.75, 1.05, 0.95, 1.0],
        _ => List<double>.filled(columnCount, 1),
      },
    };
    return {
      for (var column = 0; column < widths.length; column++)
        column: pw.FlexColumnWidth(widths[column]),
    };
  }

  Map<int, pw.Alignment> _cellAlignments(_PdfSection section) {
    final columnCount = section.headers?.length ?? 2;
    final rightAlignedColumns = switch (section.title) {
      'Sales Overview' || null => {1},
      'Sales Transaction Records' => {2, 3},
      'Payment Summary' => {1},
      'Product Total Sales' => {2, 3, 4, 5},
      _ => {2, 3, 4},
    };
    return {
      for (var index = 0; index < columnCount; index++)
        index: rightAlignedColumns.contains(index)
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
    };
  }
}

class _PdfSection {
  final String? title;
  final List<String>? headers;
  final List<List<String>> rows;

  const _PdfSection({this.title, this.headers, required this.rows});
}
