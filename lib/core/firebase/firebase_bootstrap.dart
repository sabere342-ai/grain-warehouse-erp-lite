import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/firebase/firebase_options.dart';

class FirebaseBootstrap {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on UnsupportedError catch (error) {
      debugPrint('Firebase is not configured yet: $error');
    }
  }
}
