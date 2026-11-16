# Keepy 플랫폼 폴더 생성 + OCR/카메라 설정 (Windows PowerShell)
#
#   cd C:\Keepy1\app
#   powershell -ExecutionPolicy Bypass -File tool\setup_platforms.ps1
#
# 하는 일
#   1) flutter create 로 android / ios / web 폴더 생성 (lib, test 는 건드리지 않음)
#   2) Android: 한글 OCR 모델 의존성 추가 (google_mlkit_text_recognition 한글)
#      + 인터넷 권한 (MP3 서버 동기화 — 정식 빌드에도 필요)
#   3) iOS: 카메라·사진 권한 문구, 최소 버전 15.5 (ML Kit 요구)
#   4) flutter pub get
# 여러 번 실행해도 같은 내용을 중복으로 넣지 않는다.

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
function Save-Text($path, $text) { [System.IO.File]::WriteAllText($path, $text, $utf8NoBom) }
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "[1/4] flutter create (platform folders)" -ForegroundColor Cyan
flutter create . --project-name keepy --org com.keepy --platforms=android,ios,web
if ($LASTEXITCODE -ne 0) { throw "flutter create 실패" }

Write-Host "[2/4] Android: Korean text recognition dependency" -ForegroundColor Cyan
$koreanDep = "com.google.mlkit:text-recognition-korean:16.0.1"
$kts = Join-Path $root "android\app\build.gradle.kts"
$groovy = Join-Path $root "android\app\build.gradle"
if (Test-Path $kts) {
    $gradle = $kts; $line = "    implementation(`"$koreanDep`")"
} elseif (Test-Path $groovy) {
    $gradle = $groovy; $line = "    implementation '$koreanDep'"
} else {
    throw "android/app/build.gradle(.kts) 를 찾지 못했습니다."
}
$text = Get-Content $gradle -Raw -Encoding UTF8
if ($text -notmatch [regex]::Escape($koreanDep)) {
    if ($text -match "(?m)^dependencies\s*\{") {
        $text = [regex]::Replace($text, "(?m)^dependencies\s*\{", "dependencies {`n$line", 1)
    } else {
        $text = $text.TrimEnd() + "`n`ndependencies {`n$line`n}`n"
    }
    Save-Text $gradle $text
    Write-Host "  + $koreanDep"
} else {
    Write-Host "  (already added)"
}
$manifest = Join-Path $root "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifest) {
    $m = Get-Content $manifest -Raw -Encoding UTF8
    if ($m -notmatch "android.permission.INTERNET") {
        $m = [regex]::Replace($m, "(<manifest[^>]*>)", "`$1`n    <uses-permission android:name=`"android.permission.INTERNET`"/>")
        Save-Text $manifest $m
        Write-Host "  + INTERNET permission (MP3 sync)"
    }
}

Write-Host "[3/4] iOS: camera/photo permission + platform 15.5" -ForegroundColor Cyan
$plist = Join-Path $root "ios\Runner\Info.plist"
if (Test-Path $plist) {
    $p = Get-Content $plist -Raw -Encoding UTF8
    $entries = @{
        "NSCameraUsageDescription"       = "종이 메모를 찍어 할 일로 바꾸려면 카메라 접근이 필요해요. 사진은 인식 후 바로 지워져요.";
        "NSPhotoLibraryUsageDescription" = "앨범의 메모 사진에서 할 일을 가져오려면 사진 접근이 필요해요."
    }
    foreach ($k in $entries.Keys) {
        if ($p -notmatch $k) {
            $insert = "`t<key>$k</key>`n`t<string>$($entries[$k])</string>`n</dict>`n</plist>"
            $p = [regex]::Replace($p, "</dict>\s*</plist>\s*$", $insert)
            Write-Host "  + $k"
        }
    }
    Save-Text $plist $p
}
$podfile = Join-Path $root "ios\Podfile"
if (Test-Path $podfile) {
    $pf = Get-Content $podfile -Raw -Encoding UTF8
    $pf = [regex]::Replace($pf, "(?m)^#?\s*platform :ios, '[0-9.]+'", "platform :ios, '15.5'")
    Save-Text $podfile $pf
}

Write-Host "[4/4] flutter pub get" -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get 실패" }

Write-Host ""
Write-Host "완료! 실행:  flutter run   (웹 미리보기: flutter run -d chrome)" -ForegroundColor Green
