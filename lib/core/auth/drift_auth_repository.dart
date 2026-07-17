import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';

class DriftAuthRepository implements AuthRepository {
  DriftAuthRepository(
    this._database, {
    PasswordCredentialDeriver? credentialDeriver,
  }) : _credentialDeriver =
            credentialDeriver ?? Argon2idCredentialDeriver.secure();

  final FoundationDatabase _database;
  final PasswordCredentialDeriver _credentialDeriver;
  AppUser? _currentUser;

  @override
  Future<bool> hasOwner() async {
    final row = await _database.customSelect(
      'SELECT 1 FROM auth_accounts WHERE role = ? LIMIT 1',
      variables: [Variable.withString(UserRole.owner.name)],
    ).getSingleOrNull();
    return row != null;
  }

  @override
  Future<AppUser?> currentUser() async {
    final user = _currentUser;
    return user != null && user.canProceed ? user : null;
  }

  @override
  Future<AppUser> createFirstOwner({
    required String name,
    required String phone,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = _normalizePhone(phone);
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Name is required.');
    }
    if (cleanPhone.isEmpty) {
      throw ArgumentError.value(phone, 'phone', 'Phone is required.');
    }
    final credential = await _credentialDeriver.derive(password);
    final now = DateTime.now();
    final user = await _database.inTransaction(() async {
      if (await hasOwner()) throw StateError('Owner already exists.');
      final sequence = await _allocateIdSequence();
      final id = 'usr-${now.microsecondsSinceEpoch}-$sequence';
      await _database.customStatement(
        'INSERT INTO auth_accounts '
        '(id, phone_normalized, name, role, is_active, created_at, updated_at, '
        'credential_scheme, credential_salt, credential_verifier, '
        'credential_parameters_json, credential_updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          cleanPhone,
          cleanName,
          UserRole.owner.name,
          1,
          now.toIso8601String(),
          now.toIso8601String(),
          credential.scheme,
          credential.salt,
          credential.verifier,
          credential.parametersJson,
          now.toIso8601String(),
        ],
      );
      return AppUser(
        id: id,
        name: cleanName,
        phone: cleanPhone,
        role: UserRole.owner,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
    });
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser?> signIn({
    required String phone,
    required String password,
  }) async {
    final account = await _accountByPhone(_normalizePhone(phone));
    if (account == null ||
        !await _credentialDeriver.verify(password, account.credential)) {
      return null;
    }
    if (!account.user.isActive) {
      _currentUser = null;
      return account.user;
    }
    if (!account.user.hasValidId) {
      _currentUser = null;
      return null;
    }
    _currentUser = account.user;
    return account.user;
  }

  @override
  Future<AppUser?> verifyCredentials({
    required String phone,
    required String password,
  }) async {
    final account = await _accountByPhone(_normalizePhone(phone));
    if (account == null ||
        !await _credentialDeriver.verify(password, account.credential)) {
      return null;
    }
    return account.user;
  }

  @override
  Future<void> signOut() async => _currentUser = null;

  @override
  Future<AppUser?> getUserById(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return null;
    final row = await _database.customSelect(
      'SELECT * FROM auth_accounts WHERE id = ? LIMIT 1',
      variables: [Variable.withString(id)],
    ).getSingleOrNull();
    return row == null ? null : _decodeAccount(row.data).user;
  }

  Future<int> _allocateIdSequence() async {
    final row = await _database.customSelect(
      'UPDATE repository_sequences SET next_value = next_value + 1 '
      'WHERE repository = ? RETURNING next_value - 1 AS allocated',
      variables: [Variable.withString('auth_accounts')],
    ).getSingleOrNull();
    if (row == null) {
      await _database.customStatement(
        'INSERT INTO repository_sequences (repository, next_value) VALUES (?, ?)',
        ['auth_accounts', 2],
      );
      return 1;
    }
    return row.read<int>('allocated');
  }

  Future<_PersistedAuthAccount?> _accountByPhone(String phone) async {
    if (phone.isEmpty) return null;
    final row = await _database.customSelect(
      'SELECT * FROM auth_accounts WHERE phone_normalized = ? LIMIT 1',
      variables: [Variable.withString(phone)],
    ).getSingleOrNull();
    return row == null ? null : _decodeAccount(row.data);
  }

  _PersistedAuthAccount _decodeAccount(Map<String, Object?> row) {
    final roleName = row['role'];
    final role =
        UserRole.values.where((value) => value.name == roleName).firstOrNull;
    if (role == null) throw const FormatException('Unknown auth role.');
    DateTime date(String key) {
      final raw = row[key];
      if (raw is! String) throw FormatException('Invalid $key.');
      final value = DateTime.tryParse(raw);
      if (value == null) throw FormatException('Invalid $key.');
      return value;
    }

    final salt = row['credential_salt'];
    final verifier = row['credential_verifier'];
    if (salt is! Uint8List || verifier is! Uint8List) {
      throw const FormatException('Invalid credential bytes.');
    }
    return _PersistedAuthAccount(
      user: AppUser(
        id: row['id'] as String,
        name: row['name'] as String,
        phone: row['phone_normalized'] as String,
        role: role,
        isActive: (row['is_active'] as int) == 1,
        createdAt: date('created_at'),
        updatedAt: date('updated_at'),
      ),
      credential: PersistedPasswordCredential(
        scheme: row['credential_scheme'] as String,
        salt: salt,
        verifier: verifier,
        parametersJson: row['credential_parameters_json'] as String,
      ),
    );
  }

  String _normalizePhone(String value) => value.trim();
}

abstract class PasswordCredentialDeriver {
  Future<PersistedPasswordCredential> derive(String password);
  Future<bool> verify(String password, PersistedPasswordCredential credential);
}

class Argon2idCredentialDeriver implements PasswordCredentialDeriver {
  Argon2idCredentialDeriver({required List<int> Function() saltGenerator})
      : _saltGenerator = saltGenerator;

  factory Argon2idCredentialDeriver.secure() => Argon2idCredentialDeriver(
        saltGenerator: () {
          final random = Random.secure();
          return List<int>.generate(16, (_) => random.nextInt(256));
        },
      );

  static const scheme = 'argon2id-v1';
  static const memoryKiB = 19456;
  static const iterations = 2;
  static const parallelism = 1;
  static const hashLengthBytes = 32;
  static const algorithmVersion = 19;

  final List<int> Function() _saltGenerator;

  @override
  Future<PersistedPasswordCredential> derive(String password) async {
    final salt = List<int>.unmodifiable(_saltGenerator());
    if (salt.length != 16) throw StateError('Secure salt generation failed.');
    return PersistedPasswordCredential(
      scheme: scheme,
      salt: salt,
      verifier: await _derive(
        password,
        salt,
        _parseParameters(_defaultParameters),
      ),
      parametersJson: _defaultParameters,
    );
  }

  @override
  Future<bool> verify(
    String password,
    PersistedPasswordCredential credential,
  ) async {
    if (credential.scheme != scheme) {
      throw const FormatException('Unsupported credential scheme.');
    }
    final parameters = _parseParameters(credential.parametersJson);
    if (credential.salt.length != 16 ||
        credential.verifier.length != hashLengthBytes) {
      throw const FormatException('Invalid credential material.');
    }
    final candidate = await _derive(password, credential.salt, parameters);
    return constantTimeBytesEqual(candidate, credential.verifier);
  }

  Future<List<int>> _derive(
    String password,
    List<int> salt,
    Map<String, int> parameters,
  ) async {
    final algorithm = Argon2id(
      memory: parameters['memoryKiB']!,
      iterations: parameters['iterations']!,
      parallelism: parameters['parallelism']!,
      hashLength: parameters['hashLengthBytes']!,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return key.extractBytes();
  }

  static const _defaultParameters =
      '{"algorithmVersion":19,"hashLengthBytes":32,"iterations":2,"memoryKiB":19456,"parallelism":1,"saltLengthBytes":16}';

  Map<String, int> _parseParameters(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded.length != 6) {
      throw const FormatException('Invalid credential parameters.');
    }
    const expected = {
      'algorithmVersion': algorithmVersion,
      'hashLengthBytes': hashLengthBytes,
      'iterations': iterations,
      'memoryKiB': memoryKiB,
      'parallelism': parallelism,
      'saltLengthBytes': 16,
    };
    for (final entry in expected.entries) {
      if (decoded[entry.key] != entry.value) {
        throw const FormatException('Invalid credential parameters.');
      }
    }
    return decoded.cast<String, int>();
  }
}

bool constantTimeBytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

class PersistedPasswordCredential {
  const PersistedPasswordCredential({
    required this.scheme,
    required this.salt,
    required this.verifier,
    required this.parametersJson,
  });

  final String scheme;
  final List<int> salt;
  final List<int> verifier;
  final String parametersJson;
}

class _PersistedAuthAccount {
  const _PersistedAuthAccount({required this.user, required this.credential});
  final AppUser user;
  final PersistedPasswordCredential credential;
}
