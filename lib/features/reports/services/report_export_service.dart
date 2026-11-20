import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';

class ReportExportService {
  const ReportExportService();

  static String toCsv(List<List<Object?>> rows) {
    String escape(Object? value) {
      final text = value?.toString() ?? '';
      if (!text.contains(',') && !text.contains('\n') && !text.contains('"')) {
        return text;
      }
      return '"${text.replaceAll('"', '""')}"';
    }

    return rows.map((row) => row.map(escape).join(',')).join('\r\n');
  }

  static Uint8List toXlsx(
    List<List<Object?>> rows, {
    List<double>? columnWidths,
  }) {
    String xmlEscape(Object? value) => (value?.toString() ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    final columnCount = rows.fold<int>(
      0,
      (count, row) => row.length > count ? row.length : count,
    );
    if (columnWidths != null) {
      if (columnWidths.length != columnCount ||
          columnWidths.any((width) => !width.isFinite || width <= 0)) {
        throw ArgumentError.value(
          columnWidths,
          'columnWidths',
          'Provide one positive finite width for each report column.',
        );
      }
    }
    final columnsXml = columnWidths == null
        ? ''
        : '<cols>${[for (var index = 0; index < columnWidths.length; index++) '<col min="${index + 1}" max="${index + 1}" width="${columnWidths[index]}" customWidth="1"/>'].join()}</cols>';

    final sheetRows = <StringBuffer>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final cells = <String>[];
      for (
        var columnIndex = 0;
        columnIndex < rows[rowIndex].length;
        columnIndex++
      ) {
        var column = columnIndex + 1;
        var reference = '';
        while (column > 0) {
          final remainder = (column - 1) % 26;
          reference = String.fromCharCode(65 + remainder) + reference;
          column = (column - remainder - 1) ~/ 26;
        }
        final value = xmlEscape(rows[rowIndex][columnIndex]);
        cells.add(
          '<c r="$reference${rowIndex + 1}" t="inlineStr"><is><t xml:space="preserve">$value</t></is></c>',
        );
      }
      sheetRows.add(
        StringBuffer('<row r="${rowIndex + 1}">${cells.join()}</row>'),
      );
    }

    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          '[Content_Types].xml',
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            '</Types>',
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          '_rels/.rels',
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            '</Relationships>',
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'xl/workbook.xml',
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="Report" sheetId="1" r:id="rId1"/></sheets></workbook>',
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'xl/_rels/workbook.xml.rels',
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
            '</Relationships>',
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'xl/worksheets/sheet1.xml',
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '$columnsXml<sheetData>${sheetRows.join()}</sheetData></worksheet>',
          ),
        ),
      );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<void> save({
    required String fileName,
    required String extension,
    required List<int> bytes,
    required MimeType mimeType,
  }) async {
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: extension,
      mimeType: mimeType,
    );
  }
}
