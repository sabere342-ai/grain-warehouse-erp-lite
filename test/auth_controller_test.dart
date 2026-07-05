import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_state.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';

void main() {
  test('first owner setup creates a user with non-empty stable id', () async {
    final repository = LocalAuthRepository.empty();
    final controller = AuthController(repository: repository);

    await controller.initialize();
    await controller.createFirstOwner(
      name: 'مالك المخزن',
      phone: '01000000000',
      password: 'owner123',
    );

    expect(controller.state.status, AuthStatus.signedIn);
    expect(controller.state.user?.id, isNotNull);
    expect(controller.state.user!.id.trim(), isNotEmpty);
    expect(controller.state.user!.id, isNot(contains('01000000000')));
    expect(controller.state.user!.id, isNot(contains('مالك')));
  });

  test('signed-in AuthState contains user id', () async {
    final controller = AuthController(repository: LocalAuthRepository.demo());

    await controller.initialize();
    await controller.signIn(phone: '01000000000', password: 'owner123');

    expect(controller.state.status, AuthStatus.signedIn);
    expect(controller.state.user?.id, 'owner-demo');
  });

  test('duplicate phone seed users are rejected', () {
    final now = DateTime(2026, 1, 1);

    expect(
      () => LocalAuthRepository(
        seedAccounts: [
          LocalAuthAccount(
            user: _user(
              id: 'owner-1',
              phone: '01000000000',
              role: UserRole.owner,
              now: now,
            ),
            password: 'owner123',
          ),
          LocalAuthAccount(
            user: _user(
              id: 'employee-1',
              phone: '01000000000',
              role: UserRole.employee,
              now: now,
            ),
            password: 'employee123',
          ),
        ],
      ),
      throwsStateError,
    );
  });

  test('duplicate user ids are rejected', () {
    final now = DateTime(2026, 1, 1);

    expect(
      () => LocalAuthRepository(
        seedAccounts: [
          LocalAuthAccount(
            user: _user(
              id: 'same-id',
              phone: '01000000000',
              role: UserRole.owner,
              now: now,
            ),
            password: 'owner123',
          ),
          LocalAuthAccount(
            user: _user(
              id: 'same-id',
              phone: '01100000000',
              role: UserRole.employee,
              now: now,
            ),
            password: 'employee123',
          ),
        ],
      ),
      throwsStateError,
    );
  });

  test('blank user ids are rejected', () {
    final now = DateTime(2026, 1, 1);

    expect(
      () => LocalAuthRepository(
        seedAccounts: [
          LocalAuthAccount(
            user: _user(
              id: ' ',
              phone: '01000000000',
              role: UserRole.owner,
              now: now,
            ),
            password: 'owner123',
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('cannot create first owner twice', () async {
    final repository = LocalAuthRepository.empty();

    await repository.createFirstOwner(
      name: 'مالك المخزن',
      phone: '01000000000',
      password: 'owner123',
    );

    expect(
      () => repository.createFirstOwner(
        name: 'مالك آخر',
        phone: '01100000000',
        password: 'owner456',
      ),
      throwsStateError,
    );
  });

  test('inactive user cannot login or become current session', () async {
    final now = DateTime(2026, 1, 1);
    final repository = LocalAuthRepository(
      seedAccounts: [
        LocalAuthAccount(
          user: _user(
            id: 'owner',
            phone: '01000000000',
            role: UserRole.owner,
            now: now,
          ),
          password: 'owner123',
        ),
        LocalAuthAccount(
          user: _user(
            id: 'inactive-employee',
            phone: '01100000000',
            role: UserRole.employee,
            isActive: false,
            now: now,
          ),
          password: 'employee123',
        ),
      ],
    );
    final controller = AuthController(repository: repository);

    final repositoryUser = await repository.signIn(
      phone: '01100000000',
      password: 'employee123',
    );
    expect(repositoryUser?.isActive, isFalse);
    expect(await repository.currentUser(), isNull);

    await controller.initialize();
    await controller.signIn(phone: '01100000000', password: 'employee123');

    expect(controller.state.status, AuthStatus.signedOut);
    expect(controller.state.canProceed, isFalse);
    expect(controller.state.errorMessage, 'هذا المستخدم غير نشط.');
  });
}

AppUser _user({
  required String id,
  required String phone,
  required UserRole role,
  required DateTime now,
  bool isActive = true,
}) {
  return AppUser(
    id: id,
    name: role == UserRole.owner ? 'مالك' : 'موظف',
    phone: phone,
    role: role,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}
