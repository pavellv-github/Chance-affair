#!/usr/bin/env bash
# Сквозные тесты на Android-эмуляторе/устройстве.
# Использование: tool/integration_android.sh [device-id]
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-emulator-5554}"
PKG=com.chanceaffair.chance_affair
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

# flutter test удаляет приложение после прогона, поэтому перед каждым
# запуском ставим debug-сборку заново и выдаём разрешения заранее —
# системные диалоги тест нажать не может.
flutter build apk --debug --dart-define-from-file=secrets.json
"$ADB" -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk
for p in READ_CALENDAR WRITE_CALENDAR POST_NOTIFICATIONS; do
  "$ADB" -s "$DEVICE" shell pm grant "$PKG" "android.permission.$p"
done

flutter test integration_test -d "$DEVICE" --dart-define-from-file=secrets.json
