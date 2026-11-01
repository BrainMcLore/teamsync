param([string]$Python = '',[string]$SevenZip = 'C:\Program Files\7-Zip')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
if(-not $Python){$Python=Join-Path $projectRoot '.venv\Scripts\python.exe'}
& (Join-Path $PSScriptRoot 'build-native-download.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Native download engine build failed.' }
Push-Location (Join-Path $projectRoot 'worker')
try {
    & $Python -m PyInstaller --noconfirm --onedir --name teamsync-demo --distpath ../.tools/worker-dist --workpath ../.tools/worker-build --specpath ../.tools --hidden-import demoparser2 --hidden-import pandas --hidden-import pyarrow --hidden-import polars --hidden-import rarfile --collect-all curl_cffi --collect-all certifi --copy-metadata curl_cffi --copy-metadata certifi --copy-metadata demoparser2 --exclude-module matplotlib --exclude-module scipy --exclude-module tkinter demo_worker.py
    if($LASTEXITCODE -ne 0){throw 'Demo worker build failed.'}
    $destination=Join-Path $projectRoot '.tools\worker-dist\teamsync-demo'
    foreach($name in @('7z.exe','7z.dll','License.txt')){
        $source=Join-Path $SevenZip $name
        if(-not(Test-Path -LiteralPath $source)){throw '7-Zip with its license is required for RAR imports.'}
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
    Copy-Item -LiteralPath (Join-Path $projectRoot '.tools\native-download\teamsync-download.exe') -Destination $destination -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'native\download\labels.json') -Destination (Join-Path $destination 'download-labels.json') -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'native\download\WEBVIEW2-SDK-LICENSE.txt') -Destination $destination -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'worker\THIRD_PARTY.md') -Destination $destination -Force
    & $Python (Join-Path $projectRoot 'tools\collect_worker_notices.py')
    if($LASTEXITCODE -ne 0){throw 'Could not collect runtime license notices.'}
}finally{Pop-Location}
