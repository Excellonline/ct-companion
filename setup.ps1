# CardTrove Companion setup helper
#
# Runs the pieces that can be automated:
#   - confirms Flutter is on PATH
#   - installs the Firebase CLI + FlutterFire CLI if missing
#   - runs `flutterfire configure` for Android, iOS, and Windows
#   - deploys Firestore and Storage rules
#
# One-time Firebase console steps:
#   1. Use the CardTrove Companion Firebase project: cardtrove-companion.
#   2. Firestore Database should be enabled in production mode.
#   3. Enable Authentication > Email/Password.
#   4. Upgrade to Blaze before enabling Cloud Storage for Firebase.
#   5. After the first admin signs up, set their member document role to `admin`:
#      workspaces/cardtrove-team/members/<uid>.role = "admin"

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Need-Cmd($cmd) {
    return -not (Get-Command $cmd -ErrorAction SilentlyContinue)
}

Write-Host "=== CardTrove Companion setup ===" -ForegroundColor Cyan

if (Need-Cmd "flutter") {
    Write-Host "Flutter not on PATH." -ForegroundColor Yellow
    if (Test-Path "$env:USERPROFILE\flutter\bin\flutter.bat") {
        $env:Path = "$env:USERPROFILE\flutter\bin;$env:Path"
        Write-Host "  Added $env:USERPROFILE\flutter\bin to this session's PATH."
    } else {
        Write-Host "  Flutter SDK not found at $env:USERPROFILE\flutter. Install Flutter and try again." -ForegroundColor Red
        exit 1
    }
}
flutter --version

if (Need-Cmd "npm") {
    Write-Host "npm not found. Install Node.js from https://nodejs.org first, then re-run this script." -ForegroundColor Red
    exit 1
}

if (Need-Cmd "firebase") {
    Write-Host "`nInstalling firebase-tools globally (one time)..." -ForegroundColor Cyan
    npm install -g firebase-tools
}

if (Need-Cmd "flutterfire") {
    Write-Host "`nActivating flutterfire_cli (one time)..." -ForegroundColor Cyan
    dart pub global activate flutterfire_cli
    $pubBin = "$env:USERPROFILE\AppData\Local\Pub\Cache\bin"
    if (-not ($env:Path -like "*$pubBin*")) {
        $env:Path = "$pubBin;$env:Path"
        Write-Host "  Added $pubBin to this session's PATH." -ForegroundColor Yellow
    }
}

Write-Host "`n=== Firebase login ===" -ForegroundColor Cyan
Write-Host "A browser will open. Sign in with the Google account that owns the CardTrove Firebase project."
firebase login

Write-Host "`n=== Connecting this app to Firebase ===" -ForegroundColor Cyan
Write-Host "When prompted:"
Write-Host "  - use the CardTrove Companion Firebase project: cardtrove-companion"
Write-Host "  - tick Android, iOS, macOS, and Windows"
Write-Host "  - use package/bundle id io.cardtrove.companion"
flutterfire configure --project=cardtrove-companion --platforms=android,ios,macos,windows --android-package-name=io.cardtrove.companion --ios-bundle-id=io.cardtrove.companion --macos-bundle-id=io.cardtrove.companion

flutter pub get

Write-Host "`n=== Deploying Firestore rules ===" -ForegroundColor Cyan
firebase deploy --project cardtrove-companion --only firestore:rules

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Run the app:"
Write-Host "  flutter run -d windows      (needs Visual Studio + Developer Mode)"
Write-Host "  flutter run -d <device-id>  (Android phone in USB debug mode)"
Write-Host ""
Write-Host "Build release versions:"
Write-Host "  flutter build apk --release"
Write-Host "  flutter build windows --release"
