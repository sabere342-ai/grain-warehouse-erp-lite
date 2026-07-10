import 'dart:convert';

class BackupRestorePreviewService {
  const BackupRestorePreviewService();

  static const supportedBackupVersions = {1, 2, 3, 4};
  static const _appName = 'grain-warehouse-erp-lite';
  static const _requiredCountKeys = [
    'products',
    'inventoryMovements',
    'suppliers',
    'purchases',
    'sales',
    'documentHistory',
  ];
  static const _optionalCountKeys = [
    'customers',
    'customerLedgerEntries',
    'customerCollections',
    'supplierLedgerEntries',
    'supplierPayments',
    'expenses',
    'auditLogs',
    'financialAccounts',
    'financialAccountEntries',
  ];
  static const _sensitiveKeys = {
    'password',
    'passwordhash',
    'token',
    'session',
    'secret',
  };

  BackupRestorePreviewResult preview(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, Object?>) {
        return _failure('JSON غير صالح.', 'root-not-object');
      }

      final metadata = decoded['metadata'];
      final counts = decoded['counts'];
      final data = decoded['data'];
      if (metadata is! Map<String, Object?>) {
        return _failure(
          'النسخة لا تحتوي على بيانات metadata.',
          'missing-metadata',
        );
      }
      if (counts is! Map<String, Object?>) {
        return _failure('النسخة لا تحتوي على بيانات counts.', 'missing-counts');
      }
      if (data is! Map<String, Object?>) {
        return _failure('النسخة لا تحتوي على بيانات data.', 'missing-data');
      }
      if (_containsSensitiveKey(decoded)) {
        return _failure(
          'النسخة تحتوي على مفاتيح حساسة ولا يمكن قبولها.',
          'sensitive-key',
        );
      }

      final app = metadata['app'];
      if (app != _appName) {
        return _failure(
          'هذه ليست نسخة صادرة من نظام مخزن الغلال.',
          'unsupported-app',
        );
      }

      final backupVersion = metadata['backupVersion'];
      if (backupVersion is! int || !supportedBackupVersions.contains(backupVersion)) {
        return _failure(
          'إصدار النسخة غير مدعوم.',
          'unsupported-version',
        );
      }
      if (metadata['restoreSupported'] != false) {
        return _failure(
          'هذه النسخة لا تطابق قواعد الفحص الآمن.',
          'restore-supported',
        );
      }

      final generatedAtText = metadata['generatedAt'];
      final warning = metadata['warning'];
      if (generatedAtText is! String || generatedAtText.trim().isEmpty) {
        return _failure('تاريخ إنشاء النسخة غير موجود.', 'missing-generatedAt');
      }
      if (DateTime.tryParse(generatedAtText) == null) {
        return _failure('تاريخ إنشاء النسخة غير صالح.', 'invalid-generatedAt');
      }
      if (warning is! String || warning.trim().isEmpty) {
        return _failure('تحذير النسخة غير موجود.', 'missing-warning');
      }

      final parsedCounts = <String, int>{};
      for (final key in _requiredCountKeys) {
        final value = counts[key];
        final records = data[key];
        if (value is! int || value < 0) {
          return _failure('عدد السجلات غير صالح.', 'invalid-count-$key');
        }
        if (records is! List<Object?>) {
          return _failure('محتوى بيانات النسخة غير صالح.', 'invalid-data-$key');
        }
        if (records.length != value) {
          return _failure(
            'عدد السجلات لا يطابق محتوى البيانات.',
            'count-mismatch-$key',
          );
        }
        parsedCounts[key] = value;
      }
      for (final key in _optionalCountKeys) {
        final value = counts[key] ?? 0;
        final records = data[key] ?? const <Object?>[];
        if (value is! int || value < 0) {
          return _failure('عدد السجلات غير صالح.', 'invalid-count-$key');
        }
        if (records is! List<Object?>) {
          return _failure('محتوى بيانات النسخة غير صالح.', 'invalid-data-$key');
        }
        if (records.length != value) {
          return _failure(
            'عدد السجلات لا يطابق محتوى البيانات.',
            'count-mismatch-$key',
          );
        }
        parsedCounts[key] = value;
      }

      return BackupRestorePreviewResult.valid(
        summary: BackupRestorePreviewSummary(
          generatedAt: DateTime.parse(generatedAtText),
          backupVersion: backupVersion,
          counts: BackupRestorePreviewCounts.fromMap(parsedCounts),
          fileName: metadata['fileName'] is String
              ? metadata['fileName'] as String
              : null,
          checksum: decoded['checksum'] is String
              ? decoded['checksum'] as String
              : null,
        ),
        warnings: const [
          'يمكن الاسترجاع إلى نظام فارغ فقط بعد فحص النسخة وظهور قسم الاسترجاع.',
          'فحص النسخ البسيط للعرض فقط ولا يعني تحقق تشفير أو حماية.',
        ],
      );
    } on FormatException {
      return _failure(
        'JSON غير صالح. تأكد أنك نسخت محتوى ملف JSON كاملا بدون حذف أي جزء.',
        'invalid-json',
      );
    } catch (_) {
      return _failure(
        'تعذر فحص النسخة الاحتياطية. تأكد أنك نسخت محتوى ملف JSON كاملا بدون حذف أي جزء.',
        'unknown',
      );
    }
  }

  BackupRestorePreviewResult _failure(String message, String reason) {
    return BackupRestorePreviewResult.invalid(
      message: message,
      technicalReason: reason,
    );
  }

  bool _containsSensitiveKey(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if (_sensitiveKeys.contains(key)) {
          return true;
        }
        if (_containsSensitiveKey(entry.value)) {
          return true;
        }
      }
      return false;
    }
    if (value is Iterable) {
      return value.any(_containsSensitiveKey);
    }

    return false;
  }
}

class BackupRestorePreviewResult {
  const BackupRestorePreviewResult._({
    required this.isValid,
    required this.message,
    required this.warnings,
    this.summary,
    this.technicalReason,
  });

  factory BackupRestorePreviewResult.valid({
    required BackupRestorePreviewSummary summary,
    required List<String> warnings,
  }) {
    return BackupRestorePreviewResult._(
      isValid: true,
      message: 'تم فحص النسخة بنجاح.',
      summary: summary,
      warnings: warnings,
    );
  }

  factory BackupRestorePreviewResult.invalid({
    required String message,
    required String technicalReason,
  }) {
    return BackupRestorePreviewResult._(
      isValid: false,
      message: message,
      technicalReason: technicalReason,
      warnings: const [],
    );
  }

  final bool isValid;
  final String message;
  final BackupRestorePreviewSummary? summary;
  final List<String> warnings;
  final String? technicalReason;
}

class BackupRestorePreviewSummary {
  const BackupRestorePreviewSummary({
    required this.generatedAt,
    required this.backupVersion,
    required this.counts,
    this.fileName,
    this.checksum,
  });

  final DateTime generatedAt;
  final int backupVersion;
  final BackupRestorePreviewCounts counts;
  final String? fileName;
  final String? checksum;
}

class BackupRestorePreviewCounts {
  const BackupRestorePreviewCounts({
    required this.products,
    required this.inventoryMovements,
    required this.suppliers,
    required this.purchases,
    required this.sales,
    required this.documentHistory,
    required this.customers,
    required this.customerLedgerEntries,
    required this.customerCollections,
    this.supplierLedgerEntries = 0,
    this.supplierPayments = 0,
    required this.expenses,
    required this.auditLogs,
    this.financialAccounts = 0,
    this.financialAccountEntries = 0,
  });

  factory BackupRestorePreviewCounts.fromMap(Map<String, int> counts) {
    return BackupRestorePreviewCounts(
      products: counts['products']!,
      inventoryMovements: counts['inventoryMovements']!,
      suppliers: counts['suppliers']!,
      purchases: counts['purchases']!,
      sales: counts['sales']!,
      documentHistory: counts['documentHistory']!,
      customers: counts['customers'] ?? 0,
      customerLedgerEntries: counts['customerLedgerEntries'] ?? 0,
      customerCollections: counts['customerCollections'] ?? 0,
      supplierLedgerEntries: counts['supplierLedgerEntries'] ?? 0,
      supplierPayments: counts['supplierPayments'] ?? 0,
      expenses: counts['expenses'] ?? 0,
      auditLogs: counts['auditLogs'] ?? 0,
      financialAccounts: counts['financialAccounts'] ?? 0,
      financialAccountEntries: counts['financialAccountEntries'] ?? 0,
    );
  }

  final int products;
  final int inventoryMovements;
  final int suppliers;
  final int purchases;
  final int sales;
  final int documentHistory;
  final int customers;
  final int customerLedgerEntries;
  final int customerCollections;
  final int supplierLedgerEntries;
  final int supplierPayments;
  final int expenses;
  final int auditLogs;
  final int financialAccounts;
  final int financialAccountEntries;
}
