import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/credential_store.dart';
import 'services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  // Enable offline persistence on every platform.
  // Android/iOS default to on; Windows/macOS/Linux do not.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await ReminderService.init();
  await _tryAutoSignIn();
  runApp(const ProviderScope(child: CardTroveCompanionApp()));
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

/// If we've previously signed in successfully, replay the stored credentials
/// so the app jumps straight to the home screen on launch. Times out fast
/// (5s) so a flaky network never blocks startup — falls through to login.
Future<void> _tryAutoSignIn() async {
  if (FirebaseAuth.instance.currentUser != null) return;
  final creds = await CredentialStore.read();
  if (creds == null) return;
  final (email, password) = creds;
  try {
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password)
        .timeout(const Duration(seconds: 5));
  } on FirebaseAuthException catch (e) {
    // Bad credentials — wipe them so we don't keep retrying forever.
    const fatal = {
      'wrong-password',
      'invalid-credential',
      'user-not-found',
      'invalid-email',
      'user-disabled',
    };
    if (fatal.contains(e.code)) {
      await CredentialStore.clear();
    }
  } catch (_) {
    // Network/timeout/etc — keep creds, user will retry next launch.
  }
}
