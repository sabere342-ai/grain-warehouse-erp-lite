import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/business_identity_header.dart';

void main() {
  group('Phase 96 - BusinessIdentityHeader widget', () {
    testWidgets('shows display name and logo when both available',
        (tester) async {
      const identity = BusinessIdentity(
        establishmentName: 'مخازن النور',
        logo: LogoMetadata(
          managedFileName: 'logo.png',
          mimeType: 'image/png',
          sha256: 'abc',
          byteLength: 100,
          width: 64,
          height: 64,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(identity: identity),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مخازن النور'), findsOneWidget);
    });

    testWidgets('shows display name without logo', (tester) async {
      const identity = BusinessIdentity(establishmentName: 'غلال');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(identity: identity),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('غلال'), findsOneWidget);
    });

    testWidgets('falls back to default name when identity is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(identity: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(BusinessIdentity.defaultDisplayName), findsOneWidget);
    });

    testWidgets('shows subtitle when provided', (tester) async {
      const identity = BusinessIdentity(establishmentName: 'غلال');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(
              identity: identity,
              subtitle: 'إدارة مخازن الحبوب',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('غلال'), findsOneWidget);
      expect(find.text('إدارة مخازن الحبوب'), findsOneWidget);
    });

    testWidgets('compact mode shows truncated name', (tester) async {
      const identity = BusinessIdentity(establishmentName: 'غلال');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: BusinessIdentityHeader(
                identity: identity,
                compact: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('غلال'), findsOneWidget);
    });

    testWidgets('long Arabic name does not overflow', (tester) async {
      const identity = BusinessIdentity(
        establishmentName:
            'شركة مخازن الحبوب والقمح والذرة والبزرة والسمسم والعبادームصر',
      );

      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(
              identity: identity,
              compact: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull);
    });

    testWidgets('no overflow on narrow width', (tester) async {
      const identity = BusinessIdentity(establishmentName: 'غلال');

      tester.view.physicalSize = const Size(200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(
              identity: identity,
              compact: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull);
    });

    testWidgets('reads identity from BusinessIdentityScope', (tester) async {
      final repo = _MemoryBusinessIdentityRepository(
        const BusinessIdentity(establishmentName: 'الscope'),
      );
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIdentityScope(
            controller: controller,
            child: const Scaffold(
              body: BusinessIdentityHeader(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الscope'), findsOneWidget);
    });
  });

  group('Phase 96 - Dashboard identity', () {
    testWidgets('dashboard screen shows dynamic brand name', (tester) async {
      final repo = _MemoryBusinessIdentityRepository(
        const BusinessIdentity(establishmentName: 'النور'),
      );
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIdentityScope(
            controller: controller,
            child: Scaffold(
              body: ListView(
                children: [
                  Builder(
                    builder: (context) {
                      final displayName = BusinessIdentityScope.maybeOf(context)
                              ?.identity
                              .displayName ??
                          BusinessIdentity.defaultDisplayName;
                      return Text('لوحة متابعة $displayName');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لوحة متابعة النور'), findsOneWidget);
    });

    testWidgets('dashboard uses default name when no custom name set',
        (tester) async {
      final repo = _MemoryBusinessIdentityRepository(BusinessIdentity.empty);
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIdentityScope(
            controller: controller,
            child: Scaffold(
              body: ListView(
                children: [
                  Builder(
                    builder: (context) {
                      final displayName = BusinessIdentityScope.maybeOf(context)
                              ?.identity
                              .displayName ??
                          BusinessIdentity.defaultDisplayName;
                      return Text('لوحة متابعة $displayName');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('لوحة متابعة ${BusinessIdentity.defaultDisplayName}'),
        findsOneWidget,
      );
    });
  });
}

class _MemoryBusinessIdentityRepository implements BusinessIdentityRepository {
  _MemoryBusinessIdentityRepository(this._identity);

  BusinessIdentity _identity;

  @override
  Future<BusinessIdentity> loadIdentity() async => _identity;

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    _identity = identity;
  }

  @override
  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType) async {
    return null;
  }

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async {
    return null;
  }

  @override
  Future<void> deleteLogoFile(String managedFileName) async {}

  @override
  String get managedLogosDirectory => '';
}
