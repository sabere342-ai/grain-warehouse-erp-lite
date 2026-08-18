import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';

class ApplicationScope extends InheritedWidget {
  const ApplicationScope({
    super.key,
    required this.application,
    required super.child,
  });

  final ApplicationBoundary application;

  static ApplicationBoundary of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ApplicationScope>();
    assert(scope != null, 'ApplicationScope is missing from the widget tree.');
    return scope!.application;
  }

  @override
  bool updateShouldNotify(ApplicationScope oldWidget) =>
      !identical(application, oldWidget.application);
}
