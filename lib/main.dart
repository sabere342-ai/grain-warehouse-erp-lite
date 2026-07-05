import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/app/grain_warehouse_app.dart';
import 'package:grain_warehouse_erp_lite/core/firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const GrainWarehouseApp());
}
