#!/bin/zsh
# ──────────────────────────────────────────────────────────
# Vizo Release Script (GitHub Releases + Firestore)
# Одна команда — собирает, загружает, обновляет всё.
# Использование: ./release.sh 1.3.0
# ──────────────────────────────────────────────────────────

set -e

VERSION="$1"
if [[ -z "$VERSION" ]]; then
  echo "❌ Укажи версию: ./release.sh 1.3.0"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

GITHUB_REPO="Bilalikus/vizo-releases"

echo ""
echo "🚀 Релиз Vizo v${VERSION}"
echo "────────────────────────────────"

# ── 1. Обновить версию в коде ──
echo "📝 Обновляю версию..."

BUILD_NUM=$(grep -oE '\+[0-9]+' pubspec.yaml | head -1 | tr -d '+')
BUILD_NUM=${BUILD_NUM:-0}
BUILD_NUM=$((BUILD_NUM + 1))
sed -i '' "s/^version: .*/version: ${VERSION}+${BUILD_NUM}/" pubspec.yaml

sed -i '' "s/const String _appVersion = '.*'/const String _appVersion = '${VERSION}'/" lib/screens/shell/app_shell.dart

echo "   ✅ pubspec.yaml → ${VERSION}+${BUILD_NUM}"
echo "   ✅ app_shell.dart → ${VERSION}"

# ── 2. Анализ ──
echo ""
echo "🔍 Проверяю код..."
dart analyze lib --no-fatal-warnings
echo "   ✅ Ошибок нет"

# ── 3. Сборка APK ──
echo ""
echo "📦 Собираю APK..."
flutter build apk --release -q
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
echo "   ✅ APK готов ($(du -h "$APK_PATH" | cut -f1 | xargs))"

# ── 4. Сборка macOS ──
echo ""
echo "🍎 Собираю macOS..."
flutter build macos --release -q 2>/dev/null
echo "   ✅ macOS готов"

# ── 5. Создать DMG ──
echo ""
echo "💿 Создаю DMG..."
DMG_PATH="build/Vizo-${VERSION}.dmg"
hdiutil create -volname "Vizo" \
  -srcfolder build/macos/Build/Products/Release/Vizo.app \
  -ov -format UDZO "$DMG_PATH" -quiet
echo "   ✅ DMG готов ($(du -h "$DMG_PATH" | cut -f1 | xargs))"

# ── 6. Копировать на рабочий стол ──
echo ""
echo "🖥  Копирую на рабочий стол..."
cp "$APK_PATH" ~/Desktop/Vizo.apk
cp "$DMG_PATH" ~/Desktop/Vizo.dmg
echo "   ✅ ~/Desktop/Vizo.apk"
echo "   ✅ ~/Desktop/Vizo.dmg"

# ── 7. Загрузить на GitHub Releases ──
echo ""
echo "☁️  Загружаю на GitHub Releases..."

# Удалить старый релиз этой версии если есть
gh release delete "v${VERSION}" --repo "$GITHUB_REPO" --yes 2>/dev/null || true

# Создать новый релиз с файлами
gh release create "v${VERSION}" \
  ~/Desktop/Vizo.apk \
  ~/Desktop/Vizo.dmg \
  --repo "$GITHUB_REPO" \
  --title "Vizo v${VERSION}" \
  --notes "Vizo v${VERSION}"

APK_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/Vizo.apk"
DMG_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/Vizo.dmg"
echo "   ✅ Загружено на GitHub"

# ── 8. Обновить Firestore ──
echo ""
echo "🔥 Обновляю Firestore..."

FIREBASE_CONFIG="$HOME/.config/configstore/firebase-tools.json"
if [[ ! -f "$FIREBASE_CONFIG" ]]; then
  echo "   ❌ Firebase CLI не залогинен. Выполни: firebase login"
  exit 1
fi

node <<FIRESTORE_EOF
const fs = require('fs');
const https = require('https');

const config = JSON.parse(fs.readFileSync('${FIREBASE_CONFIG}'));
const refreshToken = config.tokens.refresh_token;

const postData = 'grant_type=refresh_token'
  + '&refresh_token=' + encodeURIComponent(refreshToken)
  + '&client_id=563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com'
  + '&client_secret=j9iVZfS8kkCEFUPaAeJV0sAi';

const req = https.request({
  hostname: 'oauth2.googleapis.com',
  path: '/token',
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
}, (res) => {
  let data = '';
  res.on('data', (c) => data += c);
  res.on('end', () => {
    const token = JSON.parse(data).access_token;
    if (!token) { console.error('   Не удалось получить токен'); process.exit(1); }

    const body = JSON.stringify({
      fields: {
        latest:  { stringValue: '${VERSION}' },
        apkUrl:  { stringValue: '${APK_URL}' },
        dmgUrl:  { stringValue: '${DMG_URL}' }
      }
    });

    const fsReq = https.request({
      hostname: 'firestore.googleapis.com',
      path: '/v1/projects/vizo-app-8e1cf/databases/(default)/documents/app_config/version',
      method: 'PATCH',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
      }
    }, (fsRes) => {
      let d = '';
      fsRes.on('data', (c) => d += c);
      fsRes.on('end', () => {
        if (fsRes.statusCode === 200) {
          console.log('   Firestore updated');
        } else {
          console.error('   Firestore error:', fsRes.statusCode, d);
          process.exit(1);
        }
        process.exit(0);
      });
    });
    fsReq.write(body);
    fsReq.end();
  });
});
req.write(postData);
req.end();
FIRESTORE_EOF

echo "   ✅ Firestore обновлён"

# ── Готово ──
echo ""
echo "────────────────────────────────"
echo "✅ Vizo v${VERSION} выпущен!"
echo ""
echo "📱 APK: ${APK_URL}"
echo "💻 DMG: ${DMG_URL}"
echo "────────────────────────────────"
echo ""
