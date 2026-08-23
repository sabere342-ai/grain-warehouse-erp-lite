import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable, Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/drift_auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('secure credential derivation gate', () {
    test('Argon2id v1 derives deterministically and distinguishes inputs',
        () async {
      var saltSeed = 0;
      final deriver = Argon2idCredentialDeriver(
        saltGenerator: () => List<int>.generate(16, (i) => saltSeed + i),
      );
      final first = await deriver.derive('phase8m-kdf-password-a');
      saltSeed = 0;
      final same = await deriver.derive('phase8m-kdf-password-a');
      saltSeed = 1;
      final differentSalt = await deriver.derive('phase8m-kdf-password-a');
      expect(first.scheme, 'argon2id-v1');
      expect(first.salt, hasLength(16));
      expect(first.verifier, hasLength(32));
      expect(first.verifier, same.verifier);
      expect(first.verifier, isNot(differentSalt.verifier));
      expect(await deriver.verify('phase8m-kdf-password-a', first), isTrue);
      expect(await deriver.verify('phase8m-kdf-password-b', first), isFalse);
      expect(first.parametersJson,
          '{"algorithmVersion":19,"hashLengthBytes":32,"iterations":2,"memoryKiB":19456,"parallelism":1,"saltLengthBytes":16}');
    });

    test('fails closed for malformed parameters and unsupported scheme',
        () async {
      final deriver = Argon2idCredentialDeriver(
        saltGenerator: () => List<int>.filled(16, 1),
      );
      final valid = await deriver.derive('phase8m-malformed-test');
      expect(
        deriver.verify(
          'phase8m-malformed-test',
          PersistedPasswordCredential(
            scheme: 'unsupported',
            salt: valid.salt,
            verifier: valid.verifier,
            parametersJson: valid.parametersJson,
          ),
        ),
        throwsFormatException,
      );
      expect(
        deriver.verify(
          'phase8m-malformed-test',
          PersistedPasswordCredential(
            scheme: valid.scheme,
            salt: valid.salt,
            verifier: valid.verifier,
            parametersJson: '{}',
          ),
        ),
        throwsFormatException,
      );
    });

    test('comparison checks equal-length bytes without early equality API', () {
      expect(constantTimeBytesEqual([1, 2, 3], [1, 2, 3]), isTrue);
      expect(constantTimeBytesEqual([1, 2, 3], [1, 9, 3]), isFalse);
      expect(constantTimeBytesEqual([1], [1, 2]), isFalse);
    });

    test('secure generator produces independent 16-byte salts', () async {
      final deriver = Argon2idCredentialDeriver.secure();
      final first = await deriver.derive('salt-independence-a');
      final second = await deriver.derive('salt-independence-b');
      expect(first.salt, hasLength(16));
      expect(second.salt, hasLength(16));
      expect(first.salt, isNot(second.salt));
    });
  });

  test('fresh v13 schema has secure auth shape and indexes', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    expect(database.schemaVersion, 16);
    final columns =
        (await database.customSelect('PRAGMA table_info(auth_accounts)').get())
            .map((row) => row.read<String>('name'))
            .toSet();
    expect(
        columns,
        containsAll({
          'id',
          'phone_normalized',
          'name',
          'role',
          'is_active',
          'credential_scheme',
          'credential_salt',
          'credential_verifier',
          'credential_parameters_json',
        }));
    expect(columns, isNot(contains('password')));
    expect(columns, isNot(contains('session')));
    final indexes = (await database
            .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
            .get())
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(indexes, contains('auth_accounts_role_active_idx'));
    expect(indexes, contains('auth_accounts_created_idx'));
  });

  test('populated v12 migrates additively to empty auth v13', () async {
    final directory = await Directory.systemTemp.createTemp('phase8m-migrate-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final seeded = openDatabaseFile(file);
    await seeded.writeProbe('v12-data', 'preserved');
    await seeded.close();
    final legacy = sqlite3.open(file.path);
    legacy.execute('DROP TABLE auth_accounts');
    legacy.execute(
        "DELETE FROM repository_sequences WHERE repository='auth_accounts'");
    legacy.execute('PRAGMA user_version = 12');
    legacy.dispose();
    final upgraded = openDatabaseFile(file);
    expect(await upgraded.readProbe('v12-data'), 'preserved');
    expect(await DriftAuthRepository(upgraded).hasOwner(), isFalse);
    expect(
      (await upgraded.customSelect('SELECT * FROM auth_accounts').get()),
      isEmpty,
    );
    await upgraded.close();
  });

  test('owner credentials persist while session remains ephemeral', () async {
    final directory = await Directory.systemTemp.createTemp('phase8m-auth-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    const password = 'PHASE8M-UNIQUE-PLAINTEXT-PROBE-7x!';
    var database = openDatabaseFile(file);
    var repository = DriftAuthRepository(database);
    final owner = await repository.createFirstOwner(
      name: 'Owner',
      phone: ' 01000000000 ',
      password: password,
    );
    expect(owner.role, UserRole.owner);
    expect(await repository.currentUser(), owner);
    expect(
      (await repository.verifyCredentials(
        phone: '01000000000',
        password: password,
      ))
          ?.id,
      owner.id,
    );
    expect((await repository.currentUser())?.id, owner.id);
    expect(
      () => repository.createFirstOwner(
        name: 'Other Owner',
        phone: '01000000009',
        password: 'other-owner-password',
      ),
      throwsStateError,
    );
    final stored = await database.customSelect(
        'SELECT * FROM auth_accounts WHERE id = ?',
        variables: [Variable.withString(owner.id)]).getSingle();
    expect(stored.read<Uint8List>('credential_salt'), hasLength(16));
    expect(stored.read<Uint8List>('credential_verifier'), hasLength(32));
    expect(jsonEncode(stored.data), isNot(contains(password)));
    await repository.signOut();
    expect(await repository.currentUser(), isNull);
    await database.close();
    expect(_containsSequence(await file.readAsBytes(), password.codeUnits),
        isFalse);

    database = openDatabaseFile(file);
    repository = DriftAuthRepository(database);
    expect(await repository.hasOwner(), isTrue);
    expect(await repository.currentUser(), isNull);
    expect((await repository.getUserById(owner.id))?.phone, '01000000000');
    expect(await repository.signIn(phone: '01000000000', password: password),
        isNotNull);
    expect(
        await repository.signIn(
          phone: '01000000000',
          password: 'wrong-password',
        ),
        isNull);
    expect((await repository.currentUser())?.id, owner.id);
    await database.customStatement(
      'UPDATE auth_accounts SET is_active = 0 WHERE id = ?',
      [owner.id],
    );
    final inactive = await repository.signIn(
      phone: '01000000000',
      password: password,
    );
    expect(inactive?.isActive, isFalse);
    expect(inactive?.role, UserRole.owner);
    expect(await repository.currentUser(), isNull);
    await database.close();
  });

  test('concurrent first-owner attempts create exactly one durable owner',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftAuthRepository(database);
    final results = await Future.wait([
      repository
          .createFirstOwner(
            name: 'Owner A',
            phone: '01000000001',
            password: 'owner-a-secret',
          )
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      repository
          .createFirstOwner(
            name: 'Owner B',
            phone: '01000000002',
            password: 'owner-b-secret',
          )
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);
    expect(results.whereType<StateError>(), hasLength(1));
    final count = await database
        .customSelect('SELECT COUNT(*) AS total FROM auth_accounts')
        .getSingle();
    expect(count.read<int>('total'), 1);
  });

  test('production composition wires Drift auth and keeps approvals local',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(AppRepositories.authRepository, isA<DriftAuthRepository>());
    expect(
        AppRepositories.negativeBalanceApprovalRepository.runtimeType
            .toString(),
        contains('LocalNegativeBalanceApprovalRepository'));
  });
}

bool _containsSequence(List<int> bytes, List<int> sequence) {
  if (sequence.isEmpty) return true;
  for (var start = 0; start <= bytes.length - sequence.length; start++) {
    var matches = true;
    for (var offset = 0; offset < sequence.length; offset++) {
      matches &= bytes[start + offset] == sequence[offset];
    }
    if (matches) return true;
  }
  return false;
}
