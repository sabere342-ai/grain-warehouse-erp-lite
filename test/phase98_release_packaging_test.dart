import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final projectRoot = Directory.current.path;
  final pubspecPath = p.join(projectRoot, 'pubspec.yaml');
  final runnerRcPath = p.join(projectRoot, 'windows', 'runner', 'Runner.rc');
  final cmakeListsPath = p.join(projectRoot, 'windows', 'CMakeLists.txt');
  final mainCppPath = p.join(projectRoot, 'windows', 'runner', 'main.cpp');
  final issPath = p.join(projectRoot, 'windows', 'installer', 'ghalal.iss');
  final buildReleaseScript = p.join(projectRoot, 'tool', 'build_release.ps1');
  final createDemoScript =
      p.join(projectRoot, 'tool', 'create_demo_package.ps1');
  final scanSafetyScript =
      p.join(projectRoot, 'tool', 'scan_package_safety.ps1');
  final verifyChecksumsScript =
      p.join(projectRoot, 'tool', 'verify_package_checksums.ps1');
  final installationGuidePath =
      p.join(projectRoot, 'docs', 'CLIENT-INSTALLATION-GUIDE-AR.md');
  final walkthroughPath =
      p.join(projectRoot, 'docs', 'CLIENT-DEMO-WALKTHROUGH-AR.md');
  final limitationsPath =
      p.join(projectRoot, 'docs', 'CLIENT-KNOWN-LIMITATIONS-AR.md');
  final releaseNotesPath =
      p.join(projectRoot, 'docs', 'PHASE-98-RELEASE-NOTES-AR.md');

  late String pubspecContent;
  late String runnerRcContent;
  late String cmakeListsContent;
  late String mainCppContent;

  setUpAll(() {
    pubspecContent = File(pubspecPath).readAsStringSync();
    runnerRcContent = File(runnerRcPath).readAsStringSync();
    cmakeListsContent = File(cmakeListsPath).readAsStringSync();
    mainCppContent = File(mainCppPath).readAsStringSync();
  });

  group('Phase 98 - Version parsing from pubspec.yaml', () {
    test('version format is valid semantic+build', () {
      final versionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspecContent);
      expect(versionMatch, isNotNull);
      final version = versionMatch!.group(1)!;
      expect(RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(version), isTrue);
    });

    test('version can be split into semver and build number', () {
      final versionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspecContent);
      expect(versionMatch, isNotNull);
      final version = versionMatch!.group(1)!;
      final parts = version.split('+');
      expect(parts.length, equals(2));
      expect(parts[0], matches(RegExp(r'^\d+\.\d+\.\d+$')));
      expect(parts[1], matches(RegExp(r'^\d+$')));
    });

    test('semver parts are non-negative integers', () {
      final versionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspecContent);
      expect(versionMatch, isNotNull);
      final semver = versionMatch!.group(1)!.split('+')[0];
      final parts = semver.split('.');
      expect(parts.length, equals(3));
      for (final part in parts) {
        final value = int.tryParse(part);
        expect(value, isNotNull);
        expect(value!, greaterThanOrEqualTo(0));
      }
    });

    test('build number is a non-negative integer', () {
      final versionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspecContent);
      expect(versionMatch, isNotNull);
      final buildNumber = int.tryParse(versionMatch!.group(1)!.split('+')[1]);
      expect(buildNumber, isNotNull);
      expect(buildNumber!, greaterThanOrEqualTo(0));
    });
  });

  group('Phase 98 - Product name and branding in metadata', () {
    test('Runner.rc CompanyName contains Grala', () {
      expect(runnerRcContent, contains('"CompanyName", "Grala"'));
    });

    test('Runner.rc ProductName contains Grala', () {
      expect(runnerRcContent, contains('"ProductName", "Grala"'));
    });

    test('Runner.rc FileDescription contains Grala', () {
      expect(
        runnerRcContent,
        contains('"FileDescription", "Grala - Grain Warehouse Management"'),
      );
    });

    test('Runner.rc has no com.example references', () {
      expect(runnerRcContent, isNot(contains('com.example')));
    });

    test('main.cpp window title is غلال', () {
      expect(mainCppContent, contains(r'"\u063A\u0644\u0627\u0644"'));
    });

    test('BusinessIdentity.defaultDisplayName is غلال', () {
      final identityPath = p.join(
        projectRoot,
        'lib',
        'core',
        'business_identity',
        'business_identity.dart',
      );
      final identityContent = File(identityPath).readAsStringSync();
      expect(
        identityContent,
        contains(
          "static const defaultDisplayName = '\u063A\u0644\u0627\u0644'",
        ),
      );
    });
  });

  group('Phase 98 - Manifest schema and required fields', () {
    test('Inno Setup source file exists', () {
      expect(File(issPath).existsSync(), isTrue);
    });

    test('Inno Setup AppName contains Arabic product name', () {
      final issContent = File(issPath).readAsStringSync();
      expect(issContent, contains('#define MyAppNameArabic'));
      expect(issContent, contains('\u063A\u0644\u0627\u0644'));
    });

    test('Inno Setup uses per-user installation (no admin required)', () {
      final issContent = File(issPath).readAsStringSync();
      expect(issContent, contains('PrivilegesRequired=lowest'));
    });

    test('Inno Setup references the correct executable name', () {
      final issContent = File(issPath).readAsStringSync();
      expect(issContent, contains('grain_warehouse_erp_lite.exe'));
    });

    test('Inno Setup has uninstall support', () {
      final issContent = File(issPath).readAsStringSync();
      expect(issContent, contains('UninstallDisplayIcon'));
      expect(issContent, contains('uninstallexe'));
    });

    test('Inno Setup preserves user data on uninstall', () {
      final issContent = File(issPath).readAsStringSync();
      expect(
        issContent.toLowerCase(),
        contains('user data must be preserved'),
      );
    });
  });

  group('Phase 98 - SHA-256 checksum generation and verification', () {
    test('can compute SHA-256 hash of a file', () async {
      final testDir = Directory.systemTemp.createTempSync('phase98_test_');
      try {
        final testFile = File(p.join(testDir.path, 'test.txt'));
        testFile.writeAsStringSync('hello world');
        final bytes = await testFile.readAsBytes();
        final digest = sha256.convert(bytes);
        expect(digest.toString(), hasLength(64));
        expect(
          digest.toString(),
          equals(
            'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
          ),
        );
      } finally {
        testDir.deleteSync(recursive: true);
      }
    });

    test('different files produce different checksums', () async {
      final testDir = Directory.systemTemp.createTempSync('phase98_test_');
      try {
        final file1 = File(p.join(testDir.path, 'a.txt'));
        final file2 = File(p.join(testDir.path, 'b.txt'));
        file1.writeAsStringSync('content A');
        file2.writeAsStringSync('content B');

        final hash1 = sha256.convert(await file1.readAsBytes());
        final hash2 = sha256.convert(await file2.readAsBytes());
        expect(hash1.toString(), isNot(equals(hash2.toString())));
      } finally {
        testDir.deleteSync(recursive: true);
      }
    });

    test('same content produces same checksum', () async {
      final testDir = Directory.systemTemp.createTempSync('phase98_test_');
      try {
        final file1 = File(p.join(testDir.path, 'a.txt'));
        final file2 = File(p.join(testDir.path, 'b.txt'));
        file1.writeAsStringSync('identical content');
        file2.writeAsStringSync('identical content');

        final hash1 = sha256.convert(await file1.readAsBytes());
        final hash2 = sha256.convert(await file2.readAsBytes());
        expect(hash1.toString(), equals(hash2.toString()));
      } finally {
        testDir.deleteSync(recursive: true);
      }
    });
  });

  group('Phase 98 - Prohibited file detection', () {
    test('build_release.ps1 exists', () {
      expect(File(buildReleaseScript).existsSync(), isTrue);
    });

    test('create_demo_package.ps1 exists', () {
      expect(File(createDemoScript).existsSync(), isTrue);
    });

    test('scan_package_safety.ps1 exists', () {
      expect(File(scanSafetyScript).existsSync(), isTrue);
    });

    test('verify_package_checksums.ps1 exists', () {
      expect(File(verifyChecksumsScript).existsSync(), isTrue);
    });

    test('safety scanner checks for .git directory', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('.git'));
    });

    test('safety scanner checks for lib directory', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains("'lib'"));
    });

    test('safety scanner checks for test directory', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains("'test'"));
    });

    test('safety scanner checks for .dart extension', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('.dart'));
    });

    test('safety scanner checks for developer paths', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('C:\\dev\\'));
    });

    test('safety scanner checks for com.example references', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('com.example'));
    });

    test('safety scanner verifies required runtime files', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('Release/grain_warehouse_erp_lite.exe'));
      expect(script, contains('Release/flutter_windows.dll'));
      expect(script, contains('Release/data/icudtl.dat'));
    });

    test('safety scanner uses allowlist approach', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('prohibitedDirectories'));
      expect(script, contains('prohibitedExtensions'));
      expect(script, contains('prohibitedFileNames'));
    });
  });

  group('Phase 98 - Required runtime file detection', () {
    test('build_release.ps1 checks for flutter_windows.dll', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('flutter_windows.dll'));
    });

    test('build_release.ps1 checks for flutter_assets directory', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('flutter_assets'));
    });

    test('build_release.ps1 checks for icudtl.dat', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('icudtl.dat'));
    });

    test('build_release.ps1 checks for executable', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('grain_warehouse_erp_lite.exe'));
    });

    test('build_release.ps1 reads version from pubspec.yaml', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('pubspec.yaml'));
      expect(script, contains('version:'));
    });

    test('build_release.ps1 reads git commit hash', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('rev-parse'));
      expect(script, contains('HEAD'));
    });
  });

  group('Phase 98 - Failure when main executable is absent', () {
    test('build_release.ps1 fails when exe not found', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('throw'));
      expect(script.toLowerCase(), contains('not found'));
    });

    test('create_demo_package.ps1 fails when exe not found', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('throw'));
      expect(script.toLowerCase(), contains('not found'));
    });
  });

  group('Phase 98 - Exclusion of source code and local data', () {
    test(
        'create_demo_package.ps1 does not copy lib/ directory from project root',
        () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, isNot(matches(RegExp(r"Join-Path.*'\.\.'.*'lib'"))));
    });

    test(
        'create_demo_package.ps1 does not copy test/ directory from project root',
        () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, isNot(matches(RegExp(r"Join-Path.*'\.\.'.*'test'"))));
    });

    test('create_demo_package.ps1 lists .git as prohibited in manifest', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('.git/*'));
    });

    test('safety scanner blocks .db files', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('.db'));
    });

    test('safety scanner blocks .sqlite3 files', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('.sqlite3'));
    });

    test('safety scanner blocks .log files', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('.log'));
    });
  });

  group('Phase 98 - Path with spaces handling', () {
    test('build_release.ps1 uses quoted paths', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('Join-Path'));
    });

    test('create_demo_package.ps1 uses quoted paths', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('Join-Path'));
    });

    test('safety scanner uses quoted paths', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains('Join-Path'));
    });
  });

  group('Phase 98 - Error handling', () {
    test('build_release.ps1 uses ErrorActionPreference Stop', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains("\$ErrorActionPreference = 'Stop'"));
    });

    test('create_demo_package.ps1 uses ErrorActionPreference Stop', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains("\$ErrorActionPreference = 'Stop'"));
    });

    test('scan_package_safety.ps1 uses ErrorActionPreference Stop', () {
      final script = File(scanSafetyScript).readAsStringSync();
      expect(script, contains("\$ErrorActionPreference = 'Stop'"));
    });

    test('verify_package_checksums.ps1 uses ErrorActionPreference Stop', () {
      final script = File(verifyChecksumsScript).readAsStringSync();
      expect(script, contains("\$ErrorActionPreference = 'Stop'"));
    });

    test('build_release.ps1 checks flutter build exit code', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('LASTEXITCODE'));
    });

    test('build_release.ps1 outputs version info', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('Version:'));
    });
  });

  group('Phase 98 - Installer metadata consistency', () {
    test('Inno Setup version matches pubspec version', () {
      final issContent = File(issPath).readAsStringSync();
      final pubspecVersionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspecContent);
      expect(pubspecVersionMatch, isNotNull);
      final semver = pubspecVersionMatch!.group(1)!.split('+')[0];
      expect(issContent, contains('#define MyAppVersion "$semver"'));
    });

    test('Inno Setup AppPublisher contains Grala', () {
      final issContent = File(issPath).readAsStringSync();
      expect(issContent, contains('#define MyAppPublisher "Grala"'));
    });

    test('Inno Setup references correct source directory', () {
      final issContent = File(issPath).readAsStringSync();
      expect(
        issContent,
        contains('MyAppSourceDir'),
      );
      expect(issContent, contains('Release'));
    });

    test('Inno Setup has Start Menu group', () {
      final issContent = File(issPath).readAsStringSync();
      expect(issContent, contains('DefaultGroupName'));
    });

    test('Inno Setup has optional desktop shortcut', () {
      final issContent = File(issPath).readAsStringSync();
      expect(issContent, contains('desktopicon'));
    });
  });

  group('Phase 98 - Client documentation references', () {
    test('installation guide exists', () {
      expect(File(installationGuidePath).existsSync(), isTrue);
    });

    test('installation guide contains product name غلال', () {
      final content = File(installationGuidePath).readAsStringSync();
      expect(content, contains('\u063A\u0644\u0627\u0644'));
    });

    test('installation guide references correct executable name', () {
      final content = File(installationGuidePath).readAsStringSync();
      expect(content, contains('grain_warehouse_erp_lite.exe'));
    });

    test('installation guide mentions Windows security warning', () {
      final content = File(installationGuidePath).readAsStringSync();
      expect(
        content,
        contains('\u0623\u0645\u0627\u0646'), // أمان
      );
      expect(content.toLowerCase(), contains('run anyway'));
    });

    test('installation guide explains data location', () {
      final content = File(installationGuidePath).readAsStringSync();
      expect(content, contains('APPDATA'));
    });

    test('installation guide explains uninstall', () {
      final content = File(installationGuidePath).readAsStringSync();
      expect(content.toLowerCase(), contains('uninstall'));
    });

    test('walkthrough exists', () {
      expect(File(walkthroughPath).existsSync(), isTrue);
    });

    test('walkthrough covers core workflow steps', () {
      final content = File(walkthroughPath).readAsStringSync();
      expect(content, contains('\u0634\u0631\u0627\u0621')); // شراء
      expect(content, contains('\u0628\u064A\u0639')); // بيع
      expect(content, contains('\u062A\u062D\u0635\u064A\u0644')); // تحصيل
      expect(content, contains('\u0645\u0635\u0631\u0648\u0641')); // مصروف
      expect(
        content,
        contains(
            '\u0627\u0644\u0646\u0633\u062E \u0627\u0644\u0627\u062D\u062A\u064A\u0627\u0637\u064A'), // النسخ الاحتياطي
      );
    });

    test('limitations exist', () {
      expect(File(limitationsPath).existsSync(), isTrue);
    });

    test('limitations document mentions single-device constraint', () {
      final content = File(limitationsPath).readAsStringSync();
      expect(
        content,
        contains(
            '\u062C\u0647\u0627\u0632 \u0648\u0627\u062D\u062F'), // جهاز واحد
      );
    });

    test('limitations document mentions no cloud sync', () {
      final content = File(limitationsPath).readAsStringSync();
      expect(
        content,
        contains('\u0633\u062D\u0627\u0628\u0629'), // سحابة
      );
    });

    test('limitations document mentions unsigned package', () {
      final content = File(limitationsPath).readAsStringSync();
      expect(
        content,
        contains(
            '\u063A\u064A\u0631 \u0645\u0648\u0642\u0639\u0629'), // غير موقعة
      );
    });

    test('release notes exist', () {
      expect(File(releaseNotesPath).existsSync(), isTrue);
    });

    test('release notes contain version', () {
      final content = File(releaseNotesPath).readAsStringSync();
      expect(content, contains('1.0.0'));
    });

    test('release notes contain product name', () {
      final content = File(releaseNotesPath).readAsStringSync();
      expect(content, contains('\u063A\u0644\u0627\u0644'));
    });
  });

  group('Phase 98 - Phase 97 branding regression', () {
    test('CompanyName is not Flutter placeholder com.example', () {
      expect(
        runnerRcContent,
        isNot(contains('"CompanyName", "com.example"')),
      );
    });

    test('CompanyName contains Grala brand', () {
      expect(runnerRcContent, contains('"CompanyName", "Grala"'));
    });

    test('FileDescription is branded, not generic', () {
      final match =
          RegExp(r'"FileDescription",\s*"([^"]+)"').firstMatch(runnerRcContent);
      expect(match, isNotNull);
      final desc = match!.group(1)!;
      expect(desc.toLowerCase(), contains('grala'));
    });

    test('ProductName is branded', () {
      final match =
          RegExp(r'"ProductName",\s*"([^"]+)"').firstMatch(runnerRcContent);
      expect(match, isNotNull);
      final name = match!.group(1)!;
      expect(name.toLowerCase(), contains('grala'));
    });

    test('OriginalFilename matches CMakeLists BINARY_NAME', () {
      final cmakeMatch = RegExp(r'set\(BINARY_NAME\s+"([^"]+)"\)')
          .firstMatch(cmakeListsContent);
      expect(cmakeMatch, isNotNull);
      final binaryName = cmakeMatch!.group(1);
      expect(
        runnerRcContent,
        contains('"OriginalFilename", "$binaryName.exe"'),
      );
    });

    test('CMakeLists BINARY_NAME is defined', () {
      expect(
        cmakeListsContent,
        matches(RegExp(r'set\(BINARY_NAME\s+"[^"]+"\)')),
      );
    });

    test('main.cpp window title is not raw internal name', () {
      expect(
        mainCppContent,
        isNot(contains('L"grain_warehouse_erp_lite"')),
      );
    });

    test('Runner.rc InternalName remains as technical identifier', () {
      expect(
        runnerRcContent,
        contains('"InternalName", "grain_warehouse_erp_lite"'),
      );
    });

    test('LegalCopyright references Grala', () {
      expect(runnerRcContent, contains('Grala'));
    });

    test('LegalCopyright does not reference com.example', () {
      expect(runnerRcContent, isNot(contains('com.example')));
    });
  });

  group('Phase 98 - Build script does not have hardcoded paths', () {
    test('build_release.ps1 uses PSScriptRoot for project root', () {
      final script = File(buildReleaseScript).readAsStringSync();
      expect(script, contains('PSScriptRoot'));
      expect(script, isNot(contains('C:\\dev\\')));
      expect(script, isNot(contains('C:\\Users\\')));
    });

    test('create_demo_package.ps1 uses PSScriptRoot for project root', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('PSScriptRoot'));
      expect(script, isNot(contains('C:\\dev\\')));
      expect(script, isNot(contains('C:\\Users\\')));
    });

    test(
      'build_post_feature_delivery.py no longer has hardcoded path',
      () {
        final pythonScript =
            File(p.join(projectRoot, 'tool', 'build_post_feature_delivery.py'))
                .readAsStringSync();
        expect(pythonScript, isNot(contains('C:\\dev\\multi-pos')));
        expect(pythonScript, contains('__file__'));
      },
    );
  });

  group('Phase 98 - Demo package structure', () {
    test('create_demo_package.ps1 generates release-manifest.json', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('release-manifest.json'));
    });

    test('create_demo_package.ps1 generates checksums.sha256', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('checksums.sha256'));
    });

    test('create_demo_package.ps1 generates file-listing.txt', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('file-listing.txt'));
    });

    test('create_demo_package.ps1 generates README-AR.txt', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('README-AR.txt'));
    });

    test('create_demo_package.ps1 copies client documentation', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('CLIENT-INSTALLATION-GUIDE-AR.md'));
      expect(script, contains('CLIENT-DEMO-WALKTHROUGH-AR.md'));
      expect(script, contains('CLIENT-KNOWN-LIMITATIONS-AR.md'));
    });

    test('create_demo_package.ps1 uses SHA-256 for checksums', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('SHA256'));
    });

    test('create_demo_package.ps1 includes manifest metadata fields', () {
      final script = File(createDemoScript).readAsStringSync();
      expect(script, contains('productName'));
      expect(script, contains('version'));
      expect(script, contains('gitCommitHash'));
      expect(script, contains('buildConfiguration'));
      expect(script, contains('targetPlatform'));
      expect(script, contains('signed'));
      expect(script, contains('installerAvailable'));
    });
  });
}
