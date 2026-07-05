import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Firebase options are intentionally not committed. '
          'Run FlutterFire configuration and provide local options.',
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('This MVP targets Android and Windows only.');
    }
  }
}
