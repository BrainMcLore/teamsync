param([string]$Flutter='', [string]$ApiUrl='https://teamsync-api-ui7n.onrender.com')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
if(-not $Flutter){$Flutter=Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'}
if(-not $env:ANDROID_HOME){$env:ANDROID_HOME=Join-Path $projectRoot '.tools\android-sdk'}
Push-Location (Join-Path $projectRoot 'client')
try {
    # Regenerate release plugin registration after integration/debug builds.
    # --no-pub would retain a registration for the dev-only integration plugin.
    & $Flutter build apk --release "--dart-define=TEAMSYNC_API_URL=$ApiUrl"
    if($LASTEXITCODE -ne 0){throw 'Android build failed.'}
    Copy-Item 'build\app\outputs\flutter-apk\app-release.apk' (Join-Path $projectRoot 'dist\TeamSync-0.8.0-Android-test.apk') -Force
    $buildTools=Get-ChildItem (Join-Path $env:ANDROID_HOME 'build-tools') -Directory | Sort-Object Name -Descending | Select-Object -First 1
    & (Join-Path $buildTools.FullName 'apksigner.bat') verify --verbose (Join-Path $projectRoot 'dist\TeamSync-0.8.0-Android-test.apk')
    if($LASTEXITCODE -ne 0){throw 'APK signature verification failed.'}
} finally {Pop-Location}
