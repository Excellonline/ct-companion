# Contributing

Thanks for helping keep CardTrove Companion sharp. This project is a Flutter/Firebase app, so most changes should be easy to review when they stay focused and include a small verification note.

## Local Setup

```powershell
flutter pub get
flutter test
```

For Firebase setup and rules deployment, use:

```powershell
.\setup.ps1
```

## Development Workflow

1. Create a branch from `main`.
2. Keep changes scoped to one feature, bug fix, or documentation update.
3. Run formatting and tests before opening a pull request.
4. Include screenshots or screen recordings for visible UI changes.
5. Note any Firebase rules, indexes, or data-shape changes in the pull request.

## Checks

```powershell
dart format --set-exit-if-changed lib test integration_test
flutter test
```

Integration tests require a runtime password:

```powershell
flutter test integration_test/app_e2e_test.dart --dart-define=CARDTROVE_E2E_PASSWORD=<password>
```

## Secrets

Do not commit private keys, service account JSON, keystores, signing certificates, `.env` files, or reusable credentials. Firebase client config is expected in the app, but privileged credentials belong outside the repo.

## Pull Request Checklist

- The change has a clear summary.
- Tests or manual verification are listed.
- User-facing copy is intentional and concise.
- Firebase rule/index changes are called out.
- New files are covered by `.gitignore` when they are local, generated, or secret.
