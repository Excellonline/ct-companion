// File generated for CardTrove Companion.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCKSMQoxXsh4URswwGzddyR4ROTIroPkzM',
    appId: '1:458945984736:android:2d168746046b136fecb885',
    messagingSenderId: '458945984736',
    projectId: 'cardtrove-companion',
    storageBucket: 'cardtrove-companion.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCbSevHZ4RJPauKMaLlfS7iuNTSRXSPayo',
    appId: '1:458945984736:web:e4e35e61bea18dd3ecb885',
    messagingSenderId: '458945984736',
    projectId: 'cardtrove-companion',
    authDomain: 'cardtrove-companion.firebaseapp.com',
    storageBucket: 'cardtrove-companion.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAJyyj-FpyrDVVnyKh-B6C8M6idGQ6CAs4',
    appId: '1:458945984736:ios:48986d5b9fc73c33ecb885',
    messagingSenderId: '458945984736',
    projectId: 'cardtrove-companion',
    storageBucket: 'cardtrove-companion.firebasestorage.app',
    iosBundleId: 'io.cardtrove.companion',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAJyyj-FpyrDVVnyKh-B6C8M6idGQ6CAs4',
    appId: '1:458945984736:ios:48986d5b9fc73c33ecb885',
    messagingSenderId: '458945984736',
    projectId: 'cardtrove-companion',
    storageBucket: 'cardtrove-companion.firebasestorage.app',
    iosBundleId: 'io.cardtrove.companion',
  );
}
