#!/usr/bin/env bash
# Usage:  ./build_apk.sh http://192.168.1.10:8000
set -e
API_URL="$1"
if [ -z "$API_URL" ]; then echo "Give the API address, e.g.  ./build_apk.sh http://10.29.80.74:8000"; exit 1; fi
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/frontend"
[ -d android ] || flutter create --platforms=android --org com.kopragrade --project-name kopragrade .
python3 "$ROOT/tools/prepare_android.py" "$API_URL"
flutter clean
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build apk --release --dart-define=API_BASE_URL="$API_URL"
echo "DONE. APK: $ROOT/frontend/build/app/outputs/flutter-apk/app-release.apk"
