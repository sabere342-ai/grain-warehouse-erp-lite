import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_state.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository repository})
      : _repository = repository;

  final AuthRepository _repository;
  AuthState _state = const AuthState.checking();

  AuthState get state => _state;

  Future<void> initialize() async {
    _setState(const AuthState.checking());

    final currentUser = await _repository.currentUser();
    if (currentUser != null) {
      if (currentUser.canProceed) {
        _setState(AuthState.signedIn(currentUser));
      } else {
        await _repository.signOut();
        _setState(
          const AuthState.signedOut(errorMessage: 'هذا المستخدم غير نشط.'),
        );
      }
      return;
    }

    final ownerExists = await _repository.hasOwner();
    _setState(
      ownerExists
          ? const AuthState.signedOut()
          : const AuthState.needsFirstOwner(),
    );
  }

  Future<void> signIn({
    required String phone,
    required String password,
  }) async {
    if (phone.trim().isEmpty || password.isEmpty) {
      _setState(
        const AuthState.signedOut(
          errorMessage: 'ادخل رقم الهاتف وكلمة المرور.',
        ),
      );
      return;
    }

    final user = await _repository.signIn(phone: phone, password: password);
    if (user == null) {
      _setState(
        const AuthState.signedOut(errorMessage: 'بيانات الدخول غير صحيحة.'),
      );
      return;
    }

    if (!user.isActive) {
      await _repository.signOut();
      _setState(
        const AuthState.signedOut(errorMessage: 'هذا المستخدم غير نشط.'),
      );
      return;
    }

    if (!user.hasValidId) {
      await _repository.signOut();
      _setState(
        const AuthState.signedOut(errorMessage: 'هوية المستخدم غير صالحة.'),
      );
      return;
    }

    _setState(AuthState.signedIn(user));
  }

  Future<void> createFirstOwner({
    required String name,
    required String phone,
    required String password,
  }) async {
    if (name.trim().isEmpty || phone.trim().isEmpty || password.isEmpty) {
      _setState(
        const AuthState.needsFirstOwner(
          errorMessage: 'ادخل اسم المالك ورقم الهاتف وكلمة المرور.',
        ),
      );
      return;
    }

    if (password.length < 6) {
      _setState(
        const AuthState.needsFirstOwner(
          errorMessage: 'كلمة المرور يجب ألا تقل عن 6 أحرف.',
        ),
      );
      return;
    }

    try {
      final user = await _repository.createFirstOwner(
        name: name,
        phone: phone,
        password: password,
      );
      if (!user.hasValidId) {
        await _repository.signOut();
        _setState(
          const AuthState.needsFirstOwner(
            errorMessage: 'تعذر إنشاء هوية مستخدم صالحة.',
          ),
        );
        return;
      }
      _setState(AuthState.signedIn(user));
    } on StateError {
      _setState(
        const AuthState.signedOut(
          errorMessage: 'تم إنشاء المالك الأول بالفعل. سجل الدخول للمتابعة.',
        ),
      );
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    final ownerExists = await _repository.hasOwner();
    _setState(
      ownerExists
          ? const AuthState.signedOut()
          : const AuthState.needsFirstOwner(),
    );
  }

  void _setState(AuthState nextState) {
    _state = nextState;
    notifyListeners();
  }
}

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}
