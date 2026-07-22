import 'package:flutter/material.dart';

enum AppThemeMode {
  system('system', 'حسب النظام', ThemeMode.system),
  light('light', 'فاتح', ThemeMode.light),
  dark('dark', 'داكن', ThemeMode.dark);

  const AppThemeMode(this.id, this.labelAr, this.materialMode);

  final String id;
  final String labelAr;
  final ThemeMode materialMode;

  static AppThemeMode byId(String? id) {
    return values.firstWhere(
      (value) => value.id == id,
      orElse: () => system,
    );
  }
}
