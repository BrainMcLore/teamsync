param([string]$Flutter = '', [switch]$Installer, [string]$ApiUrl = 'https://teamsync-api-ui7n.onrender.com', [string]$InnoCompiler = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $Flutter) { $Flutter = Join-Path $projectRoot '.tools\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $Flutter)) { throw 'Install Flutter 3.47.8 or pass -Flutter with its full path.' }
Push-Location (Join-Path $projectRoot 'client')
try {
    $pubOutput = & $Flutter pub get 2>&1
    $pubStatus = $LASTEXITCODE
    $pubOutput | Write-Output
    if ($pubStatus -ne 0 -and (($pubOutput -join "`n") -notmatch 'symlink support')) { throw 'Dependency resolution failed.' }
    # Directory junctions avoid requiring a global Developer Mode change on Windows.
    $plugins = Get-Content '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
    $links = Join-Path (Get-Location) 'windows\flutter\ephemeral\.plugin_symlinks'
    New-Item -ItemType Directory -Path $links -Force | Out-Null
    foreach ($plugin in $plugins.plugins.windows) {
        $link = Join-Path $links $plugin.name
        if (-not (Test-Path -LiteralPath $link)) { New-Item -ItemType Junction -Path $link -Target $plugin.path | Out-Null }
    }
    & $Flutter gen-l10n
    if ($LASTEXITCODE -ne 0) { throw 'Localization generation failed.' }
    & $Flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
    & $Flutter test --no-pub --concurrency=2 --timeout=2m
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    & $Flutter build windows --release --flavor v08 --no-pub "--dart-define=TEAMSYNC_API_URL=$ApiUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
    $workerRoot=Join-Path $projectRoot '.tools\worker-dist\teamsync-demo'
    if(-not(Test-Path -LiteralPath (Join-Path $workerRoot 'teamsync-demo.exe'))){throw 'Build the native demo companion with tools/build-demo-worker.ps1 first.'}
    $workerTarget=Join-Path (Get-Location) 'build\windows\x64\v08\runner\Release\demo-worker'
    New-Item -ItemType Directory -Path $workerTarget -Force | Out-Null
    Copy-Item -Path (Join-Path $workerRoot '*') -Destination $workerTarget -Recurse -Force
    $redistBase = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC'
    if (-not (Test-Path -LiteralPath $redistBase)) {
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (Test-Path -LiteralPath $vswhere) {
            $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
            if ($installation) { $redistBase = Join-Path $installation 'VC\Redist\MSVC' }
        }
    }
    if (Test-Path -LiteralPath $redistBase) {
        $crt = Get-ChildItem -LiteralPath $redistBase -Directory | Where-Object Name -Match '^\d' | Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($crt) { Get-ChildItem -LiteralPath $crt -Filter '*.dll' | Copy-Item -Destination 'build\windows\x64\v08\runner\Release' }
        else { throw 'MSVC runtime files were not found.' }
    }
    else { throw 'MSVC runtime directory was not found.' }
    if ($Installer) {
        $compiler = if ($InnoCompiler) { $InnoCompiler } else { Join-Path $projectRoot '.tools\inno\ISCC.exe' }
        if (-not (Test-Path -LiteralPath $compiler)) { throw 'Inno Setup is required at .tools\inno\ISCC.exe.' }
        & $compiler (Join-Path $projectRoot 'packaging\teamsync.iss')
        if ($LASTEXITCODE -ne 0) { throw 'Installer build failed.' }
    }
} finally { Pop-Location }

