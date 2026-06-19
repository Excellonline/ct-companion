import 'package:cardtrove_companion/app.dart';
import 'package:cardtrove_companion/firebase_options.dart';
import 'package:cardtrove_companion/services/credential_store.dart';
import 'package:cardtrove_companion/services/reminder_service.dart';
import 'package:cardtrove_companion/services/team_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final runId = DateTime.now().millisecondsSinceEpoch.toString();
  final email = 'cardtrove-e2e-$runId@example.com';
  const password = String.fromEnvironment('CARDTROVE_E2E_PASSWORD');
  final displayName = 'CardTrove E2E $runId';
  final noteTitle = 'E2E note $runId';
  final noteBody = 'Created by the CardTrove Companion integration smoke test.';
  final taskText = 'E2E task $runId';
  final chatTopic = 'E2E topic $runId';
  final chatMessage = 'E2E message $runId';

  setUpAll(() async {
    if (password.isEmpty) {
      fail(
        'Set CARDTROVE_E2E_PASSWORD with '
        '--dart-define=CARDTROVE_E2E_PASSWORD=<password>.',
      );
    }
    await _initFirebase();
    await CredentialStore.clear();
    await FirebaseAuth.instance.signOut();
  });

  tearDownAll(() async {
    await _cleanupData(
      email: email,
      password: password,
      noteTitle: noteTitle,
      taskText: taskText,
      chatTopic: chatTopic,
    );
    await CredentialStore.clear();
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('sign up and exercise core workspace flows', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CardTroveCompanionApp()),
    );

    await _waitFor(tester, find.text('Sign in'));
    await tester.tap(find.text('No account? Create one'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(_textFieldWithLabel('Name'), displayName);
    await tester.enterText(_textFieldWithLabel('Email'), email);
    await tester.enterText(_textFieldWithLabel('Password'), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));

    await _waitFor(tester, find.text('Notes'),
        timeout: const Duration(seconds: 45));
    _expectNoFlutterException(tester);

    await _openTab(tester, 'Notes');
    await _createNote(tester, noteTitle, noteBody);
    await _waitFor(tester, find.text(noteTitle),
        timeout: const Duration(seconds: 30));
    _expectNoFlutterException(tester);

    await tester.enterText(_textFieldWithHint('Search notes'), noteTitle);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(noteTitle), findsWidgets);
    _expectNoFlutterException(tester);

    await _openTab(tester, 'To-Do');
    await tester.enterText(_textFieldWithHint('Add a task'), taskText);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _waitFor(tester, find.text(taskText),
        timeout: const Duration(seconds: 30));
    _expectNoFlutterException(tester);

    await _openTab(tester, 'Chat');
    await tester.tap(find.byTooltip('New topic'));
    await _waitFor(tester, find.text('New chat topic'));
    await tester.enterText(_textFieldWithHint('Topic name'), chatTopic);
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await _waitFor(tester, find.text(chatTopic),
        timeout: const Duration(seconds: 30));

    await tester.enterText(_textFieldWithHint('Message the team'), chatMessage);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await _waitFor(tester, find.text(chatMessage),
        timeout: const Duration(seconds: 30));
    _expectNoFlutterException(tester);

    await _openTab(tester, 'Files');
    await _waitFor(tester, find.text('Shared Files'));
    expect(find.textContaining('No shared'), findsWidgets);
    _expectNoFlutterException(tester);

    await tester.tap(find.byTooltip('Settings'));
    await _waitFor(tester, find.text('Settings'));
    await _waitFor(tester, find.text(email));
    await tester.tap(find.text('Sign out').last);
    await _waitFor(tester, find.text('Sign out?'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await _waitFor(tester, find.text('Sign in'),
        timeout: const Duration(seconds: 20));
    _expectNoFlutterException(tester);
  });
}

Future<void> _initFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await ReminderService.init();
}

Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await _waitFor(tester, tab);
  await tester.tap(tab.last);
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _createNote(
  WidgetTester tester,
  String title,
  String body,
) async {
  await _waitFor(tester, find.byTooltip('New note (Ctrl+N)'));
  await tester.tap(find.byTooltip('New note (Ctrl+N)'));
  await _waitFor(tester, find.text('New'));
  await tester.enterText(_textFieldWithHint('Title'), title);
  await tester.enterText(_textFieldWithHint('Write something...'), body);
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await _waitFor(tester, _textFieldWithHint('Search notes'),
      timeout: const Duration(seconds: 45));
}

Finder _textFieldWithHint(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
      description: 'TextField with hint "$hint"',
    );

Finder _textFieldWithLabel(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
      description: 'TextField with label "$label"',
    );

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final visibleText = find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .whereType<String>()
      .where((text) => text.trim().isNotEmpty)
      .take(80)
      .join(' | ');
  fail('Timed out waiting for $finder. Visible text: $visibleText');
}

void _expectNoFlutterException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull);
}

Future<void> _cleanupData({
  required String email,
  required String password,
  required String noteTitle,
  required String taskText,
  required String chatTopic,
}) async {
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  } catch (_) {
    // If account creation failed before sign-in, there is nothing to clean up.
  }

  final db = FirebaseFirestore.instance;
  final workspace = db.collection('workspaces').doc(cardTroveWorkspaceId);

  try {
    final notes = await workspace
        .collection('notes')
        .where('title', isEqualTo: noteTitle)
        .get();
    for (final doc in notes.docs) {
      final comments = await doc.reference.collection('comments').get();
      for (final comment in comments.docs) {
        await comment.reference.delete();
      }
      await doc.reference.delete();
    }
  } catch (_) {}

  try {
    final tasks = await workspace
        .collection('todoItems')
        .where('text', isEqualTo: taskText)
        .get();
    for (final doc in tasks.docs) {
      await doc.reference.delete();
    }
  } catch (_) {}

  try {
    final threads = await workspace
        .collection('chatThreads')
        .where('title', isEqualTo: chatTopic)
        .get();
    for (final thread in threads.docs) {
      final messages = await thread.reference.collection('messages').get();
      for (final message in messages.docs) {
        await message.reference.delete();
      }
      await thread.reference.delete();
    }
  } catch (_) {}

  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await workspace.collection('members').doc(uid).delete();
    }
    await FirebaseAuth.instance.currentUser?.delete();
  } catch (_) {}
}
