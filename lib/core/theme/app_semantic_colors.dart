import 'package:flutter/material.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.information,
    required this.income,
    required this.payment,
    required this.pending,
    required this.executed,
    required this.rejected,
    required this.cancelled,
    required this.stale,
    required this.inventoryIncrease,
    required this.inventoryDecrease,
    required this.elevatedSurface,
  });

  final Color success;
  final Color warning;
  final Color information;
  final Color income;
  final Color payment;
  final Color pending;
  final Color executed;
  final Color rejected;
  final Color cancelled;
  final Color stale;
  final Color inventoryIncrease;
  final Color inventoryDecrease;
  final Color elevatedSurface;

  factory AppSemanticColors.forBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const AppSemanticColors(
        success: Color(0xFF75D69B),
        warning: Color(0xFFFFCB6B),
        information: Color(0xFF82B8FF),
        income: Color(0xFF75D69B),
        payment: Color(0xFFFF9C8C),
        pending: Color(0xFFFFCB6B),
        executed: Color(0xFF75D69B),
        rejected: Color(0xFFFF8E8E),
        cancelled: Color(0xFFB6BCC5),
        stale: Color(0xFFD8A7FF),
        inventoryIncrease: Color(0xFF75D69B),
        inventoryDecrease: Color(0xFFFF9C8C),
        elevatedSurface: Color(0xFF252A25),
      );
    }
    return const AppSemanticColors(
      success: Color(0xFF1B7A45),
      warning: Color(0xFF9A5A00),
      information: Color(0xFF285EA8),
      income: Color(0xFF167047),
      payment: Color(0xFFB23A36),
      pending: Color(0xFF9A5A00),
      executed: Color(0xFF1B7A45),
      rejected: Color(0xFFB3261E),
      cancelled: Color(0xFF5E646B),
      stale: Color(0xFF70429B),
      inventoryIncrease: Color(0xFF167047),
      inventoryDecrease: Color(0xFFB23A36),
      elevatedSurface: Color(0xFFFFFFFF),
    );
  }

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>()!;
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? information,
    Color? income,
    Color? payment,
    Color? pending,
    Color? executed,
    Color? rejected,
    Color? cancelled,
    Color? stale,
    Color? inventoryIncrease,
    Color? inventoryDecrease,
    Color? elevatedSurface,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      information: information ?? this.information,
      income: income ?? this.income,
      payment: payment ?? this.payment,
      pending: pending ?? this.pending,
      executed: executed ?? this.executed,
      rejected: rejected ?? this.rejected,
      cancelled: cancelled ?? this.cancelled,
      stale: stale ?? this.stale,
      inventoryIncrease: inventoryIncrease ?? this.inventoryIncrease,
      inventoryDecrease: inventoryDecrease ?? this.inventoryDecrease,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant AppSemanticColors? other,
    double t,
  ) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      information: Color.lerp(information, other.information, t)!,
      income: Color.lerp(income, other.income, t)!,
      payment: Color.lerp(payment, other.payment, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      executed: Color.lerp(executed, other.executed, t)!,
      rejected: Color.lerp(rejected, other.rejected, t)!,
      cancelled: Color.lerp(cancelled, other.cancelled, t)!,
      stale: Color.lerp(stale, other.stale, t)!,
      inventoryIncrease:
          Color.lerp(inventoryIncrease, other.inventoryIncrease, t)!,
      inventoryDecrease:
          Color.lerp(inventoryDecrease, other.inventoryDecrease, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
    );
  }
}
