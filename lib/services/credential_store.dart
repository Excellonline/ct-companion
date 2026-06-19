import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's email + password in OS-encrypted storage so the app
/// can silently re-sign-in on each launch. Wiped only when the user
/// explicitly signs out.
///
/// Android: backed by EncryptedSharedPreferences (Android Keystore).
/// Windows: backed by Credential Locker (DPAPI).
class CredentialStore {
  static const _emailKey = 'auth_email';
  static const _passwordKey = 'auth_password';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> save(String email, String password) async {
    try {
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(key: _passwordKey, value: password);
    } catch (_) {
      // Auto sign-in is a convenience. A platform keychain error should not
      // turn a successful Firebase sign-in into a failed login.
    }
  }

  static Future<(String email, String password)?> read() async {
    try {
      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);
      if (email == null || password == null) return null;
      return (email, password);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {
      // best-effort
    }
  }
}
