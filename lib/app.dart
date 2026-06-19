import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/team_provider.dart';
import 'services/credential_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

const cardTroveGreen = Color(0xFF2D862F);
const cardTroveAccent = Color(0xFF45B549);
const cardTroveDark = Color(0xFF090811);
const cardTroveDarkSurface = Color(0xFF11101B);
const cardTroveLightBackground = Color(0xFFFCFBFF);
const cardTroveLightSurface = Color(0xFFF5F3FB);

class CardTroveCompanionApp extends ConsumerWidget {
  const CardTroveCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'CardTrove Companion',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: auth.when(
        data: (user) => user == null ? const LoginScreen() : const _TeamGate(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: dark ? cardTroveAccent : cardTroveGreen,
    brightness: brightness,
    primary: dark ? const Color(0xFF7DD181) : cardTroveGreen,
    secondary: cardTroveAccent,
    surface: dark ? cardTroveDarkSurface : cardTroveLightSurface,
  );
  final outline = dark ? const Color(0xFF2A2638) : const Color(0xFFE2DDED);
  final radius = BorderRadius.circular(8);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? cardTroveDark : cardTroveLightBackground,
    cardColor: dark ? cardTroveDarkSurface : Colors.white,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: dark ? cardTroveDark : cardTroveLightBackground,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? cardTroveDarkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: outline),
      ),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF151320) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        minimumSize: const Size(44, 40),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: outline,
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: dark ? cardTroveDarkSurface : Colors.white,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: outline),
    ),
  );
}

class _TeamGate extends ConsumerWidget {
  const _TeamGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(memberBootstrapProvider);
    return bootstrap.when(
      data: (_) {
        final member = ref.watch(currentMemberProvider);
        return member.when(
          data: (member) {
            if (member == null) {
              return const _WorkspaceAccessScreen(
                title: 'Workspace access removed',
                message:
                    'Your CardTrove account is signed in, but it is not approved for this workspace.',
              );
            }
            if (member.isPending) {
              return const _WorkspaceAccessScreen(
                title: 'Waiting for admin approval',
                message:
                    'Your account was created. An admin needs to approve it before the workspace opens.',
              );
            }
            return const HomeScreen();
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$e', textAlign: TextAlign.center),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: _WorkspaceAccessScreen(
          title: 'Could not join workspace',
          message: _workspaceJoinErrorMessage(e),
          icon: Icons.cloud_off,
        ),
      ),
    );
  }
}

String _workspaceJoinErrorMessage(Object error) {
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Firebase denied access while setting up your workspace profile. Sign out and sign back in. If it still fails, the CardTrove Firestore rules need to be deployed.';
  }
  return text;
}

class _WorkspaceAccessScreen extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _WorkspaceAccessScreen({
    required this.title,
    required this.message,
    this.icon = Icons.hourglass_empty,
  });

  Future<void> _signOut() async {
    await CredentialStore.clear();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
