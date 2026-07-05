import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';

enum AuthStatus {
  checking,
  needsFirstOwner,
  signedOut,
  signedIn,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.checking() : this(status: AuthStatus.checking);

  const AuthState.needsFirstOwner({String? errorMessage})
      : this(
          status: AuthStatus.needsFirstOwner,
          errorMessage: errorMessage,
        );

  const AuthState.signedOut({String? errorMessage})
      : this(
          status: AuthStatus.signedOut,
          errorMessage: errorMessage,
        );

  const AuthState.signedIn(AppUser user)
      : this(
          status: AuthStatus.signedIn,
          user: user,
        );

  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  bool get canProceed =>
      status == AuthStatus.signedIn && user?.isActive == true;
}
