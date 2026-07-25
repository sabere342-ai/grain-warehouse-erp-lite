import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectRoot = Directory.current.path;
  final runnerRcPath = '$projectRoot/windows/runner/Runner.rc';
  final mainCppPath = '$projectRoot/windows/runner/main.cpp';
  final cmakeListsPath = '$projectRoot/windows/CMakeLists.txt';
  final pubspecPath = '$projectRoot/pubspec.yaml';
  final iconPath = '$projectRoot/windows/runner/resources/app_icon.ico';
  final deliveryScriptPath =
      '$projectRoot/tool/create_pilot_delivery_package.ps1';
  final checkScriptPath = '$projectRoot/tool/check_pilot_delivery_package.ps1';

  late String runnerRcContent;
  late String mainCppContent;
  late String cmakeListsContent;
  late String pubspecContent;

  setUpAll(() {
    runnerRcContent = File(runnerRcPath).readAsStringSync();
    mainCppContent = File(mainCppPath).readAsStringSync();
    cmakeListsContent = File(cmakeListsPath).readAsStringSync();
    pubspecContent = File(pubspecPath).readAsStringSync();
  });

  group('Phase 97 - Runner.rc metadata', () {
    test('CompanyName is not Flutter placeholder com.example', () {
      expect(runnerRcContent, isNot(contains('"CompanyName", "com.example"')));
    });

    test('CompanyName contains Grala brand', () {
      expect(runnerRcContent, contains('"CompanyName", "Grala"'));
    });

    test('FileDescription is not raw internal name', () {
      expect(
        runnerRcContent,
        isNot(contains('"FileDescription", "grain_warehouse_erp_lite"')),
      );
    });

    test('FileDescription contains Grala brand', () {
      expect(
        runnerRcContent,
        contains('"FileDescription", "Grala - Grain Warehouse Management"'),
      );
    });

    test('ProductName is not raw internal name', () {
      expect(
        runnerRcContent,
        isNot(contains('"ProductName", "grain_warehouse_erp_lite"')),
      );
    });

    test('ProductName contains Grala brand', () {
      expect(runnerRcContent, contains('"ProductName", "Grala"'));
    });

    test('LegalCopyright does not reference com.example', () {
      expect(runnerRcContent, isNot(contains('com.example')));
    });

    test('LegalCopyright references Grala', () {
      expect(runnerRcContent, contains('Grala'));
    });

    test('OriginalFilename matches executable name from CMakeLists', () {
      final cmakeMatch = RegExp(r'set\(BINARY_NAME\s+"([^"]+)"\)')
          .firstMatch(cmakeListsContent);
      expect(cmakeMatch, isNotNull);
      final binaryName = cmakeMatch!.group(1);
      expect(
        runnerRcContent,
        contains('"OriginalFilename", "$binaryName.exe"'),
      );
    });

    test('InternalName remains as technical identifier', () {
      expect(
        runnerRcContent,
        contains('"InternalName", "grain_warehouse_erp_lite"'),
      );
    });
  });

  group('Phase 97 - Window title', () {
    test('main.cpp window title is not raw internal name', () {
      expect(mainCppContent, isNot(contains('L"grain_warehouse_erp_lite"')));
    });

    test('main.cpp window title contains غلال', () {
      expect(mainCppContent, contains(r'"\u063A\u0644\u0627\u0644"'));
    });
  });

  group('Phase 97 - Version consistency', () {
    test('pubspec.yaml version format is valid', () {
      final versionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspecContent);
      expect(versionMatch, isNotNull);
      final version = versionMatch!.group(1)!;
      expect(RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(version), isTrue);
    });

    test('Runner.rc uses Flutter version macros for version info', () {
      expect(runnerRcContent, contains('FLUTTER_VERSION_MAJOR'));
      expect(runnerRcContent, contains('FLUTTER_VERSION_MINOR'));
      expect(runnerRcContent, contains('FLUTTER_VERSION_PATCH'));
    });
  });

  group('Phase 97 - Icon file', () {
    test('app_icon.ico exists', () {
      expect(File(iconPath).existsSync(), isTrue);
    });

    test('app_icon.ico is valid ICO format', () {
      final bytes = File(iconPath).readAsBytesSync();
      expect(bytes.length, greaterThan(6));
      // ICO header: type should be 1
      final type = bytes[2] | (bytes[3] << 8);
      expect(type, equals(1));
      // Entry count should be > 0
      final entryCount = bytes[4] | (bytes[5] << 8);
      expect(entryCount, greaterThan(0));
    });

    test('app_icon.ico has multiple sizes for Windows display', () {
      final bytes = File(iconPath).readAsBytesSync();
      final entryCount = bytes[4] | (bytes[5] << 8);
      expect(entryCount, greaterThanOrEqualTo(3));
    });
  });

  group('Phase 97 - Delivery scripts consistency', () {
    test('create script references correct executable name', () {
      final script = File(deliveryScriptPath).readAsStringSync();
      expect(script, contains('grain_warehouse_erp_lite.exe'));
    });

    test('check script references correct executable name', () {
      final script = File(checkScriptPath).readAsStringSync();
      expect(script, contains('grain_warehouse_erp_lite.exe'));
    });

    test('create script does not contain outdated phase69 reference', () {
      final script = File(deliveryScriptPath).readAsStringSync();
      expect(script, isNot(contains('phase69')));
    });

    test('check script does not contain outdated phase69 reference', () {
      final script = File(checkScriptPath).readAsStringSync();
      expect(script, isNot(contains('phase69')));
    });
  });

  group('Phase 97 - CMakeLists binary name', () {
    test('BINARY_NAME is defined', () {
      expect(
        cmakeListsContent,
        matches(RegExp(r'set\(BINARY_NAME\s+"[^"]+"\)')),
      );
    });

    test('BINARY_NAME matches OriginalFilename in Runner.rc', () {
      final cmakeMatch = RegExp(r'set\(BINARY_NAME\s+"([^"]+)"\)')
          .firstMatch(cmakeListsContent);
      expect(cmakeMatch, isNotNull);
      final binaryName = cmakeMatch!.group(1);
      expect(
        runnerRcContent,
        contains('"OriginalFilename", "$binaryName.exe"'),
      );
    });
  });

  group('Phase 97 - No Flutter default branding remnants', () {
    test('Runner.rc has no com.example references', () {
      expect(runnerRcContent, isNot(contains('com.example')));
    });

    test('Runner.rc FileDescription is branded, not generic', () {
      final match =
          RegExp(r'"FileDescription",\s*"([^"]+)"').firstMatch(runnerRcContent);
      expect(match, isNotNull);
      final desc = match!.group(1)!;
      expect(desc, isNot('grain_warehouse_erp_lite'));
      expect(desc, isNot('Flutter'));
      expect(desc.toLowerCase(), contains('grala'));
    });

    test('Runner.rc ProductName is branded, not generic', () {
      final match =
          RegExp(r'"ProductName",\s*"([^"]+)"').firstMatch(runnerRcContent);
      expect(match, isNotNull);
      final name = match!.group(1)!;
      expect(name, isNot('grain_warehouse_erp_lite'));
      expect(name, isNot('Flutter'));
      expect(name.toLowerCase(), contains('grala'));
    });
  });

  group('Phase 97 - Application title in Flutter', () {
    test('BusinessIdentity.defaultDisplayName is غلال', () {
      final identityPath =
          '$projectRoot/lib/core/business_identity/business_identity.dart';
      final identityContent = File(identityPath).readAsStringSync();
      expect(
          identityContent,
          contains(
              "static const defaultDisplayName = '\u063A\u0644\u0627\u0644'"));
    });
  });
}
