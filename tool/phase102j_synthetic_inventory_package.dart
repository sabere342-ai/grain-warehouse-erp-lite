import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/synthetic_profitability_activation_service.dart';
import 'package:xml/xml.dart';

class Phase102JPackageReader {
  static const approvedSha256 =
      '461F3EE16B2895E3AC898352384EA0D927A49688912A3B6DB4C7C62B96271DFC';
  static const approvedFileName =
      'phase_102j_synthetic_inventory_test_package.xlsx';
  static const expectedRows = 12;
  static const expectedQuantityKg = 73650;
  static const expectedValueQirsh = 168009000;

  Future<Phase102JPackage> read(File file) async {
    if (file.uri.pathSegments.last != approvedFileName) {
      throw StateError('The owner package file name is not approved.');
    }
    final digest =
        (await sha256.bind(file.openRead()).first).toString().toUpperCase();
    if (digest != approvedSha256) {
      throw StateError('The owner package SHA-256 does not match approval.');
    }
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    _validateArchiveSurface(archive);
    final workbook = _xml(archive, 'xl/workbook.xml');
    final sheetNames = workbook.descendants
        .whereType<XmlElement>()
        .where((node) => node.name.local == 'sheet')
        .map((node) => node.getAttribute('name'))
        .toList(growable: false);
    const expectedSheets = [
      'تعليمات_الحزمة',
      'بيانات_المخزون_الوهمية',
      'ملخص_التحقق',
    ];
    if (sheetNames.length != expectedSheets.length ||
        !List.generate(expectedSheets.length,
                (index) => sheetNames[index] == expectedSheets[index])
            .every((value) => value)) {
      throw StateError('The workbook sheet inventory is not approved.');
    }

    final inventorySheet = _xml(archive, 'xl/worksheets/sheet2.xml');
    _ensureNoHiddenRowsOrColumns(inventorySheet);
    final xmlRows = inventorySheet.descendants
        .whereType<XmlElement>()
        .where((node) => node.name.local == 'row')
        .toList(growable: false);
    if (xmlRows.length != expectedRows + 1) {
      throw StateError(
          'The workbook must contain exactly $expectedRows data rows.');
    }
    final headers = _cells(xmlRows.first);
    const expectedHeaders = {
      'A': 'Row ID',
      'B': 'SKU',
      'C': 'اسم الصنف',
      'E': 'الوحدة',
      'F': 'الكمية كجم',
      'G': 'تكلفة الوحدة EGP/كجم',
      'H': 'إجمالي القيمة EGP',
      'I': 'نوع الدليل',
      'J': 'مرجع الدليل',
      'K': 'موافقة الصف',
      'L': 'مفتاح منع التكرار',
      'M': 'تصنيف البيانات',
    };
    for (final entry in expectedHeaders.entries) {
      if (headers[entry.key]?.value != entry.value) {
        throw StateError('Unexpected workbook header in column ${entry.key}.');
      }
    }

    final rows = <SyntheticInventoryRow>[];
    for (var index = 1; index < xmlRows.length; index++) {
      final rowNumber = index + 1;
      final cells = _cells(xmlRows[index]);
      final rowId = _required(cells, 'A');
      final sku = _required(cells, 'B');
      final name = _required(cells, 'C');
      final quantity = int.parse(_required(cells, 'F'));
      final unitCostQirsh = _egpDecimalToQirsh(_required(cells, 'G'));
      final totalValueQirsh =
          (double.parse(_required(cells, 'H')) * 100).round();
      final formula = cells['H']?.formula;
      if (formula != 'F$rowNumber*G$rowNumber') {
        throw StateError('Unexpected total formula in row $rowNumber.');
      }
      if (_required(cells, 'E') != 'كجم' ||
          _required(cells, 'I') != 'SYNTHETIC_DECLARATION' ||
          _required(cells, 'K') != 'TEST_APPROVED_ONLY' ||
          _required(cells, 'L') != '$sku|TEST-SANDBOX' ||
          _required(cells, 'M') !=
              SyntheticProfitabilityActivationService.dataClassification) {
        throw StateError(
            'Row $rowNumber is outside the approved test classification.');
      }
      final expectedValue = quantity * unitCostQirsh;
      if (totalValueQirsh != expectedValue) {
        throw StateError('Row $rowNumber valuation does not reconcile.');
      }
      rows.add(SyntheticInventoryRow(
        rowId: rowId,
        sku: sku,
        productNameAr: name,
        quantityKg: quantity,
        unitCostQirshPerKg: unitCostQirsh,
        totalValueQirsh: totalValueQirsh,
        evidenceReference: _required(cells, 'J'),
      ));
    }
    final quantityTotal = rows.fold<int>(0, (sum, row) => sum + row.quantityKg);
    final valueTotal =
        rows.fold<int>(0, (sum, row) => sum + row.totalValueQirsh);
    if (quantityTotal != expectedQuantityKg ||
        valueTotal != expectedValueQirsh) {
      throw StateError('Workbook control totals do not match owner approval.');
    }
    return Phase102JPackage(
      file: file,
      sha256: digest,
      rows: List.unmodifiable(rows),
      quantityTotalKg: quantityTotal,
      valueTotalQirsh: valueTotal,
    );
  }

  void _validateArchiveSurface(Archive archive) {
    final names = archive.files.map((file) => file.name.toLowerCase()).toList();
    const forbidden = [
      'vbaproject.bin',
      'externallinks/',
      'connections.xml',
      'customxml/',
      'embeddings/',
    ];
    if (names.any((name) => forbidden.any(name.contains))) {
      throw StateError(
          'The workbook contains a forbidden active or external part.');
    }
  }

  void _ensureNoHiddenRowsOrColumns(XmlDocument sheet) {
    final hidden = sheet.descendants.whereType<XmlElement>().any((node) =>
        (node.name.local == 'row' || node.name.local == 'col') &&
        node.getAttribute('hidden') == '1');
    if (hidden) throw StateError('Hidden workbook content is not accepted.');
  }

  XmlDocument _xml(Archive archive, String path) {
    final part = archive.findFile(path);
    if (part == null) throw StateError('Missing workbook part: $path');
    return XmlDocument.parse(utf8.decode(part.content));
  }

  Map<String, _WorkbookCell> _cells(XmlElement row) {
    final result = <String, _WorkbookCell>{};
    for (final cell
        in row.childElements.where((node) => node.name.local == 'c')) {
      final reference = cell.getAttribute('r') ?? '';
      final column = RegExp(r'^[A-Z]+').stringMatch(reference);
      if (column == null) continue;
      final value = cell.childElements
          .where((node) => node.name.local == 'v')
          .map((node) => node.innerText)
          .firstOrNull;
      final formula = cell.childElements
          .where((node) => node.name.local == 'f')
          .map((node) => node.innerText)
          .firstOrNull;
      result[column] = _WorkbookCell(value: value ?? '', formula: formula);
    }
    return result;
  }

  String _required(Map<String, _WorkbookCell> cells, String column) {
    final value = cells[column]?.value.trim() ?? '';
    if (value.isEmpty) {
      throw StateError('Required workbook cell $column is empty.');
    }
    return value;
  }

  int _egpDecimalToQirsh(String value) {
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value.trim());
    if (match == null) {
      throw StateError('Invalid monetary value: $value');
    }
    final pounds = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    if (fraction.length > 2 &&
        fraction.substring(2).contains(RegExp('[1-9]'))) {
      throw StateError('Monetary value has sub-qirsh precision: $value');
    }
    return pounds * 100 + int.parse(fraction.substring(0, 2));
  }
}

class Phase102JPackage {
  const Phase102JPackage({
    required this.file,
    required this.sha256,
    required this.rows,
    required this.quantityTotalKg,
    required this.valueTotalQirsh,
  });

  final File file;
  final String sha256;
  final List<SyntheticInventoryRow> rows;
  final int quantityTotalKg;
  final int valueTotalQirsh;
}

class _WorkbookCell {
  const _WorkbookCell({required this.value, required this.formula});

  final String value;
  final String? formula;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
