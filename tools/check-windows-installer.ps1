param([Parameter(Mandatory=$true)][string]$Candidate,
      [Parameter(Mandatory=$true)][string]$Baseline)
$ErrorActionPreference = 'Stop'
# This operates on the hosted runner's real per-user installation registry.
# Never run it on a developer/user profile.
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Installer acceptance is restricted to disposable GitHub-hosted runners.'
}
$profileData = Join-Path $env:APPDATA 'app.teamsync\teamsync'
if (Test-Path -LiteralPath $profileData) { throw 'Refusing a profile with pre-existing TeamSync data.' }
$protocol = 'HKCU:\Software\Classes\teamsync-reminder'
if (Test-Path -LiteralPath $protocol) { throw 'Refusing an existing TeamSync registration.' }
$target = Join-Path $env:RUNNER_TEMP 'TeamSyncInstallerAcceptance'
if (Test-Path -LiteralPath $target) { throw 'Acceptance install directory already exists.' }
$exe = Join-Path $target 'teamsync.exe'
$helper = Join-Path $PSScriptRoot 'check_installer_data.py'
function Check-Data([int]$Schema) {
    python $helper check $profileData --schema $Schema
    if ($LASTEXITCODE -ne 0) { throw 'User data preservation check failed.' }
}
function Install([string]$Setup) {
    $process = Start-Process -FilePath (Resolve-Path -LiteralPath $Setup).Path -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/DIR=`"$target`"") -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Installer failed with exit code $($process.ExitCode)." }
    if (-not (Test-Path -LiteralPath $exe)) { throw 'Application executable missing after install.' }
}
python $helper seed $profileData
if ($LASTEXITCODE -ne 0) { throw 'Fixture preparation failed.' }
Install $Baseline
Check-Data 1
Install $Candidate
Check-Data 1
if (-not (Test-Path -LiteralPath $protocol)) { throw 'Reminder protocol registration missing.' }
$command = (Get-ItemProperty -LiteralPath "$protocol\shell\open\command").'(default)'
if (-not $command.Contains($exe)) { throw 'Protocol points to another installation.' }
$application = Start-Process -FilePath $exe -PassThru
try {
    $migrated = $false
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
        if ($application.HasExited) { throw 'Installed app exited during startup.' }
        python $helper check $profileData --schema 7 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $migrated = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $migrated) { throw 'Installed app did not migrate the seeded database.' }
} finally {
    if (-not $application.HasExited) {
        $null = $application.CloseMainWindow()
        if (-not $application.WaitForExit(10000)) { $application.Kill(); $application.WaitForExit() }
    }
}
Check-Data 7
$uninstaller = Join-Path $target 'unins000.exe'
$remove = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -Wait -PassThru
if ($remove.ExitCode -ne 0) { throw 'Uninstall failed.' }
if (Test-Path -LiteralPath $exe) { throw 'Application executable remained after uninstall.' }
if (Test-Path -LiteralPath $protocol) { throw 'Reminder protocol remained after uninstall.' }
Check-Data 7
Write-Output 'Windows baseline install, candidate upgrade/startup/migration and uninstall preservation: passed.'
