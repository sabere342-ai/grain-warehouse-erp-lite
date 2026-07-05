import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';

abstract class AuthRepository {
  Future<bool> hasOwner();

  Future<AppUser?> currentUser();

  Future<AppUser?> signIn({
    required String phone,
    required String password,
  });

  Future<AppUser> createFirstOwner({
    required String name,
    required String phone,
    required String password,
  });

  Future<void> signOut();
}

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({List<LocalAuthAccount> seedAccounts = const []}) {
    for (final account in seedAccounts) {
      _addSeedAccount(account);
    }
  }

  factory LocalAuthRepository.empty() {
    return LocalAuthRepository();
  }

  factory LocalAuthRepository.demo() {
    final now = DateTime(2026, 1, 1);

    return LocalAuthRepository(
      seedAccounts: [
        LocalAuthAccount(
          user: AppUser(
            id: 'owner-demo',
            name: 'مالك المخزن',
            phone: '01000000000',
            role: UserRole.owner,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          password: 'owner123',
        ),
        LocalAuthAccount(
          user: AppUser(
            id: 'employee-demo',
            name: 'موظف المخزن',
            phone: '01100000000',
            role: UserRole.employee,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          password: 'employee123',
        ),
      ],
    );
  }

  final Map<String, LocalAuthAccount> _accountsByPhone = {};
  final Set<String> _userIds = {};
  int _generatedIdCounter = 0;
  AppUser? _currentUser;

  @override
  Future<bool> hasOwner() async {
    return _accountsByPhone.values.any(
      (account) => account.user.role == UserRole.owner,
    );
  }

  @override
  Future<AppUser?> currentUser() async {
    final user = _currentUser;
    if (user == null || !user.canProceed) {
      return null;
    }

    return user;
  }

  @override
  Future<AppUser?> signIn({
    required String phone,
    required String password,
  }) async {
    final account = _accountsByPhone[_normalizePhone(phone)];
    if (account == null || account.password != password) {
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
    return _currentUser;
  }

  @override
  Future<AppUser> createFirstOwner({
    required String name,
    required String phone,
    required String password,
  }) async {
    if (await hasOwner()) {
      throw StateError('Owner already exists.');
    }

    final normalizedPhone = _normalizePhone(phone);
    if (_accountsByPhone.containsKey(normalizedPhone)) {
      throw StateError('Phone already exists.');
    }

    final now = DateTime.now();
    final user = AppUser(
      id: _generateUserId(now),
      name: name.trim(),
      phone: normalizedPhone,
      role: UserRole.owner,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    final account = LocalAuthAccount(user: user, password: password);
    _accountsByPhone[normalizedPhone] = account;
    _userIds.add(user.id);
    _currentUser = user;

    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  void _addSeedAccount(LocalAuthAccount account) {
    final normalizedPhone = _normalizePhone(account.user.phone);
    final userId = account.user.id.trim();

    if (userId.isEmpty) {
      throw ArgumentError.value(account.user.id, 'id', 'User id is required.');
    }
    if (_userIds.contains(userId)) {
      throw StateError('Duplicate user id.');
    }
    if (_accountsByPhone.containsKey(normalizedPhone)) {
      throw StateError('Duplicate phone.');
    }

    _userIds.add(userId);
    _accountsByPhone[normalizedPhone] = account;
  }

  String _generateUserId(DateTime now) {
    String id;
    do {
      _generatedIdCounter++;
      id = 'usr-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
    } while (_userIds.contains(id));

    return id;
  }

  String _normalizePhone(String value) {
    return value.trim();
  }
}

class LocalAuthAccount {
  const LocalAuthAccount({
    required this.user,
    required this.password,
  });

  final AppUser user;
  final String password;
}
