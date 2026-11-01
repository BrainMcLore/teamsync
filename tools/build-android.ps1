param([string]$Flutter='', [string]$ApiUrl='https://teamsync-api-ui7n.onrender.com')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
if(-not $Flutter){$Flutter=Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'}
if(-not $env:ANDROID_HOME){$env:ANDROID_HOME=Join-Path $projectRoot '.tools\android-sdk'}
$versionLine=Select-String -Path (Join-Path $projectRoot 'client\pubspec.yaml') -Pattern '^version:\s*([^+\s]+)'
if(-not $versionLine){throw 'Client version is missing.'}
$version=$versionLine.Matches[0].Groups[1].Value
$suffix=if($env:TEAMSYNC_KEYSTORE_PATH){''}else{'-test'}
$dist=Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$target=Join-Path $dist "TeamSync-$version-Android$suffix.apk"
Push-Location (Join-Path $projectRoot 'client')
try {
    # Regenerate plugin registration after integration/debug builds.
    & $Flutter build apk --release "--dart-define=TEAMSYNC_API_URL=$ApiUrl"
    if($LASTEXITCODE -ne 0){throw 'Android build failed.'}
    Copy-Item 'build\app\outputs\flutter-apk\app-release.apk' $target -Force
    $buildTools=Get-ChildItem (Join-Path $env:ANDROID_HOME 'build-tools') -Directory | Sort-Object Name -Descending | Select-Object -First 1
    $certificate=& (Join-Path $buildTools.FullName 'apksigner.bat') verify --verbose --print-certs $target
    if($LASTEXITCODE -ne 0){throw 'APK signature verification failed.'}
    $certificate | Write-Output
    if(-not $suffix){
        $expected=(Get-Content (Join-Path $projectRoot 'packaging\android-signing.sha256') -Raw).Trim()
        if(-not (($certificate -join "`n").Contains("Signer #1 certificate SHA-256 digest: $expected"))){throw 'Unexpected Android signing certificate.'}
    }
} finally {Pop-Location}
