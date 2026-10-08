#!/usr/bin/env bash
# Сквозные тесты на iOS-симуляторе.
# Использование: tool/integration_ios.sh <udid-симулятора>
set -euo pipefail
cd "$(dirname "$0")/.."

SIM="${1:?Укажите UDID симулятора: xcrun simctl list devices}"
BUNDLE=com.chanceaffair.chanceAffair

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null

# Системный диалог доступа к календарю тест нажать не может, а выдача
# разрешения во время работы приложения его завершает. Поэтому ставим
# приложение и выдаём доступ заранее, а тесты гоняем через `flutter drive`:
# в отличие от `flutter test` он не удаляет приложение и не сбрасывает доступ.
flutter build ios --simulator --debug --dart-define-from-file=secrets.json
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
xcrun simctl privacy "$SIM" grant calendar "$BUNDLE"

flutter drive -d "$SIM" \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  --dart-define-from-file=secrets.json
