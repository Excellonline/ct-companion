<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/logo-wordmark-light.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/brand/logo-wordmark-dark.png">
    <img alt="CardTrove Companion" src="assets/brand/logo-wordmark-dark.png" width="420">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/Excellonline/ct-companion/actions/workflows/flutter-ci.yml">
    <img alt="Flutter CI" src="https://github.com/Excellonline/ct-companion/actions/workflows/flutter-ci.yml/badge.svg">
  </a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white">
  <img alt="Firebase" src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage-FFCA28?logo=firebase&logoColor=111111">
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows-2D862F">
</p>

# CardTrove Companion

CardTrove Companion is a shared team workspace app for notes, checklists, reminders, files, chat, decisions, and pipeline work. It is built with Flutter and Firebase so the team can capture work from mobile, review it on desktop, and keep one synced operational record.

## Highlights

| Area | What it supports |
| --- | --- |
| Notes | Rich team notes with folders, owners, due dates, archive state, image markup, comments, and search |
| Pipeline | Shared board views for active work, ownership, status, priority, and due dates |
| To-Do | Lightweight team checklist items with realtime sync |
| Chat | Persistent topics, sender metadata, timestamps, and Firebase Storage attachments |
| Files | Shared references, exports, and handoffs with admin-only delete controls |
| Decisions | Durable decision records with context and audit metadata |
| Activity | Workspace activity feed and notifications, including @mention handling |
| Admin | Role management, protected destructive actions, archive restore, and JSON backup export |

## Tech Stack

- Flutter stable + Material 3
- Riverpod for app state
- Firebase Auth with email/password sign-in
- Cloud Firestore for realtime data and offline cache
- Firebase Storage for note images, chat attachments, and shared files
- Local notifications for reminders
- Android, iOS, macOS, and Windows project scaffolds

## Repository Layout

```text
lib/
  models/       Data models and Firestore serialization
  providers/    Riverpod providers
  screens/      App screens and workflows
  services/     Firebase, storage, export, search, update, and notification services
  widgets/      Reusable UI components
test/           Unit and widget tests
integration_test/
firebase.json   Firebase project config
firestore.rules Firestore security rules
storage.rules   Storage security rules
deploy/         Public update manifest metadata
```

## Prerequisites

- Flutter 3.41.9 stable for matching CI formatting
- Firebase CLI
- FlutterFire CLI
- Node.js and npm, used by Firebase CLI setup
- Visual Studio with Desktop development for C++ for Windows builds
- macOS and Xcode for iOS/macOS signing and distribution

## Getting Started

Clone the repo and install dependencies:

```powershell
git clone https://github.com/Excellonline/ct-companion.git
cd ct-companion
flutter pub get
```

Configure Firebase and deploy the rules:

```powershell
.\setup.ps1
```

The setup script installs or uses Firebase CLI and FlutterFire CLI, configures Android, iOS, macOS, and Windows, runs `flutter pub get`, and deploys Firestore and Storage rules.

After the first admin signs up, set their role in Firestore:

```text
workspaces/cardtrove-team/members/<uid>.role = "admin"
```

After that, admins can manage roles from Settings > Team.

## Running Locally

```powershell
flutter run -d windows
flutter run -d <android-device-id>
```

iOS and macOS projects are scaffolded, but signing and release builds still need macOS and Xcode.

## Testing

Run the main test suite:

```powershell
flutter test
```

Run the integration smoke test with a generated account password supplied at build time:

```powershell
flutter test integration_test/app_e2e_test.dart --dart-define=CARDTROVE_E2E_PASSWORD=<password>
```

The E2E test creates a temporary Firebase Auth user, exercises the core workspace flows, and cleans up the test data it created.

## Firebase Data Model

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
  workspaces/cardtrove-team/notes/{noteId}/{attachmentId}/{fileName}
```

Notes and to-dos keep creator and updater audit fields. Notes also support owner, due date, archive state, inbox state, checklist items, image attachments, and comments. Pipeline cards surface who created the note, who updated it last, who owns it, and when it is due.

## Security Notes

Firebase client configuration files are intentionally committed because they identify the Firebase project for client apps. Do not commit private keys, service account JSON, keystores, signing certificates, local `.env` files, or reusable test credentials.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the local workflow, testing checklist, and pull request expectations.

## License

No open source license has been selected yet. Until a license is added, all rights are reserved by the repository owner.
