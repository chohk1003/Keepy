#!/usr/bin/env bash
# Keepy 플랫폼 폴더 생성 + OCR/카메라 설정 (macOS / Linux)
#
#   cd Keepy1/app && bash tool/setup_platforms.sh
#
# Windows 는 tool/setup_platforms.ps1 을 쓰세요. 하는 일은 같습니다.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/4] flutter create (platform folders)"
flutter create . --project-name keepy --org com.keepy --platforms=android,ios,web

echo "[2/4] Android: Korean text recognition dependency"
DEP="com.google.mlkit:text-recognition-korean:16.0.1"
if [ -f android/app/build.gradle.kts ]; then
  GRADLE=android/app/build.gradle.kts; LINE="    implementation(\"$DEP\")"
else
  GRADLE=android/app/build.gradle; LINE="    implementation '$DEP'"
fi
if ! grep -q "$DEP" "$GRADLE"; then
  if grep -qE '^dependencies[[:space:]]*\{' "$GRADLE"; then
    python3 - "$GRADLE" "$LINE" <<'PY'
import re, sys
path, line = sys.argv[1], sys.argv[2]
s = open(path, encoding="utf-8").read()
s = re.sub(r"(?m)^dependencies\s*\{", "dependencies {\n" + line, s, count=1)
open(path, "w", encoding="utf-8").write(s)
PY
  else
    printf '\ndependencies {\n%s\n}\n' "$LINE" >> "$GRADLE"
  fi
  echo "  + $DEP"
fi

echo "[3/4] iOS: camera/photo permission + platform 15.5"
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ]; then
  python3 - "$PLIST" <<'PY'
import re, sys
path = sys.argv[1]
s = open(path, encoding="utf-8").read()
entries = {
    "NSCameraUsageDescription": "종이 메모를 찍어 할 일로 바꾸려면 카메라 접근이 필요해요. 사진은 인식 후 바로 지워져요.",
    "NSPhotoLibraryUsageDescription": "앨범의 메모 사진에서 할 일을 가져오려면 사진 접근이 필요해요.",
}
for k, v in entries.items():
    if k not in s:
        s = re.sub(r"</dict>\s*</plist>\s*$", f"\t<key>{k}</key>\n\t<string>{v}</string>\n</dict>\n</plist>\n", s)
        print("  +", k)
open(path, "w", encoding="utf-8").write(s)
PY
fi
if [ -f ios/Podfile ]; then
  sed -i.bak -E "s/^#?[[:space:]]*platform :ios, '[0-9.]+'/platform :ios, '15.5'/" ios/Podfile && rm -f ios/Podfile.bak
fi

echo "[4/4] flutter pub get"
flutter pub get
echo "완료! 실행: flutter run  (웹 미리보기: flutter run -d chrome)"
