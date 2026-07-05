enum UserRole {
  owner,
  employee;

  String get wireName {
    switch (this) {
      case UserRole.owner:
        return 'owner';
      case UserRole.employee:
        return 'employee';
    }
  }

  String get labelAr {
    switch (this) {
      case UserRole.owner:
        return 'المالك';
      case UserRole.employee:
        return 'الموظف';
    }
  }

  static UserRole fromWireName(String value) {
    switch (value) {
      case 'owner':
        return UserRole.owner;
      case 'employee':
        return UserRole.employee;
      default:
        throw ArgumentError.value(value, 'value', 'Unknown user role.');
    }
  }
}
