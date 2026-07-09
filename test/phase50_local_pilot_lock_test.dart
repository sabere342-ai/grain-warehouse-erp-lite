import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 50 local pilot lock docs', () {
    late final String content;

    setUpAll(() {
      content = File('docs/PHASE-50-LOCAL-PILOT-LOCK.md').readAsStringSync();
    });

    test('Phase 50 doc exists and mentions lock purpose', () {
      expect(content, contains('Phase 50 — Local Pilot Lock'));
      expect(content, contains('locks the current local Windows pilot'));
    });

    test('Phase 50 doc explicitly denies cloud and mobile', () {
      expect(content, contains('No automatic cloud sync'));
      expect(content, contains('No Android/mobile app in this package'));
      expect(content, contains('No multi-device live sync'));
    });

    test('Phase 50 doc mentions read-only stock adjustment report', () {
      expect(content, contains('No PDF/export for stock adjustment report yet'));
      expect(content, contains('No invented before/after stock balances'));
    });

    test('Phase 50 doc includes Arabic owner checklist and stop conditions', () {
      expect(content, contains('فتح البرنامج من نسخة التسليم'));
      expect(content, contains('أوقف التجربة وأبلغ المطور'));
      expect(content, contains('تضمّن أي حزمة عميل ملفات مصدر أو ملفات مطور داخلية'));
    });

    test('Client docs explicitly deny cloud/mobile promises', () {
      final releaseNotes = File('docs/PILOT-RELEASE-NOTES-AR.md').readAsStringSync().toLowerCase();
      final ownerChecklist = File('docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md').readAsStringSync().toLowerCase();
      final quickStart = File('docs/OWNER-QUICK-START-AR.md').readAsStringSync().toLowerCase();

      expect(releaseNotes, contains('لا تضيف مزامنة سحابية'));
      expect(releaseNotes, contains('لا تضيف تطبيق موبايل'));
      expect(ownerChecklist, contains('لا تعتبر السحابة أو الموبايل جزءًا من هذه النسخة'));
      expect(quickStart, isNot(contains('سحابة')));
    });
  });
}
