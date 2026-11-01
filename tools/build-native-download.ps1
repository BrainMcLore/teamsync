param([string]$Msvc = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207', [string]$SdkVersion = '10.0.26100.0')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
$package = Join-Path $projectRoot '.tools\webview2-sdk'
$pin = Get-Content (Join-Path $projectRoot 'native\download\SDK.json') -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath (Join-Path $package 'build\native\include\WebView2.h'))) {
  New-Item -ItemType Directory -Path $package -Force | Out-Null
  $archive = Join-Path $package 'sdk.zip'
  Invoke-WebRequest -Uri $pin.url -OutFile $archive
  if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pin.sha256) { throw 'WebView2 SDK checksum mismatch.' }
  Expand-Archive -LiteralPath $archive -DestinationPath $package -Force
}
$target = Join-Path $projectRoot '.tools\native-download'
New-Item -ItemType Directory -Path $target -Force | Out-Null
$env:INCLUDE = "$Msvc\include;$sdkRoot\Include\$SdkVersion\ucrt;$sdkRoot\Include\$SdkVersion\shared;$sdkRoot\Include\$SdkVersion\um;$sdkRoot\Include\$SdkVersion\winrt;$package\build\native\include"
$env:LIB = "$Msvc\lib\x64;$sdkRoot\Lib\$SdkVersion\ucrt\x64;$sdkRoot\Lib\$SdkVersion\um\x64"
& "$Msvc\bin\Hostx64\x64\cl.exe" /nologo /std:c++17 /utf-8 /EHsc /MT /W4 /WX /DUNICODE /D_UNICODE (Join-Path $projectRoot 'native\download\main.cpp') "/Fo$target\main.obj" "/Fe$target\teamsync-download.exe" "$package\build\native\x64\WebView2LoaderStatic.lib" user32.lib ole32.lib oleaut32.lib shlwapi.lib version.lib advapi32.lib shell32.lib /link /SUBSYSTEM:CONSOLE
if ($LASTEXITCODE -ne 0) { throw 'Native downloader build failed.' }
$bootstrap = Join-Path $projectRoot '.tools\webview2-bootstrap\MicrosoftEdgeWebview2Setup.exe'
if (-not (Test-Path -LiteralPath $bootstrap)) {
  New-Item -ItemType Directory -Path (Split-Path $bootstrap) -Force | Out-Null
  Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $bootstrap
}
$signature = Get-AuthenticodeSignature -LiteralPath $bootstrap
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') { throw 'WebView2 bootstrapper signature invalid.' }
