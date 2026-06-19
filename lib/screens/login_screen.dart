import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/credential_store.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  bool _isSignUp = false;
  bool _rememberMe = true;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final email = _email.text.trim();
    final pw = _pw.text;
    try {
      if (_isSignUp) {
        await _createAccount(email, pw);
      } else {
        await _signIn(email, pw);
      }
      if (_rememberMe) {
        await CredentialStore.save(email, pw);
      } else {
        await CredentialStore.clear();
      }
      ref.invalidate(authStateProvider);
    } on FirebaseAuthException catch (e) {
      setState(() => _err = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAccount(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _updateDisplayName(cred.user);
    } on FirebaseAuthException catch (e) {
      if (!_isRecoverableKeychainError(e)) rethrow;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _updateDisplayName(user);
        return;
      }

      // Some macOS Firebase builds create the account but fail while saving the
      // auth token into Keychain. A sign-in retry recovers the in-memory user.
      await _signIn(email, password);
      await _updateDisplayName(FirebaseAuth.instance.currentUser);
    }
  }

  Future<void> _signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (_isRecoverableKeychainError(e) &&
          FirebaseAuth.instance.currentUser != null) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _updateDisplayName(User? user) async {
    final displayName = _name.text.trim();
    if (!_isSignUp || displayName.isEmpty || user == null) return;
    try {
      await user.updateDisplayName(displayName);
    } on FirebaseAuthException catch (e) {
      if (!_isRecoverableKeychainError(e)) rethrow;
    }
  }

  bool _isRecoverableKeychainError(FirebaseAuthException e) {
    if (defaultTargetPlatform != TargetPlatform.macOS) return false;
    final text = '${e.code} ${e.message}'.toLowerCase();
    return text.contains('keychain') ||
        text.contains('firautherrordomain code=17995');
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'That email or password did not match. Check the password, or create the account if this is your first time here.';
      case 'user-not-found':
        return 'No account exists for that email yet. Create it once, then Remember me will keep you signed in.';
      case 'wrong-password':
        return 'That password did not match this account.';
      case 'email-already-in-use':
        return 'That email already has an account. Switch back to sign in.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Use a password with at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute, then try again.';
      case 'network-request-failed':
        return 'Network error. Check the connection and try again.';
      case 'internal-error':
        return _isSignUp
            ? 'Firebase could not create the account. Check the email and password, then try again.'
            : 'Firebase rejected that login. If this is your first time here, create the account once.';
      default:
        return e.message ?? (_isSignUp ? 'Sign-up failed' : 'Sign-in failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordmark = Theme.of(context).brightness == Brightness.dark
        ? 'assets/brand/logo-wordmark-dark.png'
        : 'assets/brand/logo-wordmark-light.png';
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  wordmark,
                  height: 52,
                  errorBuilder: (_, __, ___) => Text(
                    'CardTrove Companion',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: 24),
                if (_isSignUp) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pw,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    helperText: _isSignUp ? 'At least 6 characters' : null,
                  ),
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _rememberMe,
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _rememberMe = value ?? true;
                          });
                        },
                  title: const Text('Remember me on this device'),
                  subtitle: const Text(
                    'Open CardTrove without signing in next time.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _err!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _err = null;
                        }),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign in'
                        : 'No account? Create one',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
