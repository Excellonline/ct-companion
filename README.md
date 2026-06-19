# CardTrove Companion

Shared CardTrove team companion app for Android, iOS, and Windows desktop.

- Mobile: enter notes, checklists, reminders, and shared to-dos on the go.
- Desktop: review notes and manage the shared pipeline board.
- Team workspace: every signed-in user shares one pool of notes, to-dos, chat topics, and pipeline cards.
- Chat: persistent topic list with sender names, timestamps, and Firebase Storage attachments.
- Files: shared docs, references, exports, and team handoffs with admin-only delete.
- Idea inbox: capture rough ideas before promoting them to the pipeline.
- Decisions: record important calls with context so the team has a durable log.
- Activity and notifications: see workspace changes and @mention teammates from chat, comments, and decisions.
- Backup export: admins can generate/copy a JSON workspace backup from Settings.
- Admin controls: admins manage roles and protected destructive actions.

## Stack

- Flutter + Material 3
- Firebase Auth email/password
- Firestore realtime sync/offline cache
- Firebase Storage for chat attachments
- Firebase Storage for shared team files
- Riverpod for app state
- Android, iOS scaffold, and Windows desktop platform folders

## Firebase Setup

1. Create a Firebase project.
2. Enable Firestore Database in production mode.
3. Enable Storage in production mode.
4. Enable Authentication > Email/Password.
5. Run:

```powershell
.\setup.ps1
```

The script installs/uses Firebase CLI and FlutterFire CLI, configures Android, iOS, and Windows, runs `flutter pub get`, and deploys Firestore/Storage rules.

After the first admin signs up, set their role in Firestore:

```text
workspaces/cardtrove-team/members/<uid>.role = "admin"
```

After that, admins can manage roles inside Settings > Team.

Settings also includes Archive restore for notes, and admins get Backup Export.

## Run

```powershell
flutter run -d windows
flutter run -d <android-device-id>
```

iOS files are scaffolded, but iOS build/signing still needs macOS and Xcode.

## Integration Test

```powershell
flutter test integration_test/app_e2e_test.dart --dart-define=CARDTROVE_E2E_PASSWORD=<password>
```

## Data Layout

```text
workspaces/cardtrove-team/
  members/{uid}
  notes/{noteId}
    comments/{commentId}
  folders/{folderId}
  todoItems/{itemId}
  sharedFiles/{fileId}
  decisions/{decisionId}
  activity/{activityId}
  notifications/{notificationId}
  chatThreads/{threadId}/messages/{messageId}

storage:
  workspaces/cardtrove-team/chat/{threadId}/{messageId}/{fileName}
  workspaces/cardtrove-team/shared-files/{fileId}/{fileName}
```

Notes and to-dos keep creator/updater audit fields. Notes also support owner, due date, archive state, inbox state, and comments. Pipeline cards display who created the note, who updated it last, who owns it, and when it is due.
