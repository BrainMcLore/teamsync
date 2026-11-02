#define AppVersion "1.0.0"
#define ReleaseVersion "1.0.0"
[Setup]
AppId={{7C263DB7-0143-4F56-A85E-5F28AC37E16D}
AppName=TeamSync
AppVersion={#AppVersion}
AppVerName=TeamSync 1.0.0
AppPublisher=TeamSync
DefaultDirName={localappdata}\Programs\TeamSync
DefaultGroupName=TeamSync
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=TeamSync-{#ReleaseVersion}-Windows-Setup
SetupIconFile=..\client\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\teamsync.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
Source: "..\client\build\windows\x64\v08\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\docs\user-guide.md"; DestDir: "{app}"; Flags: ignoreversion

Source: "..\.tools\webview2-bootstrap\MicrosoftEdgeWebview2Setup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\TeamSync"; Filename: "{app}\teamsync.exe"; AppUserModelID: "TeamSync.Desktop"
Name: "{autodesktop}\TeamSync"; Filename: "{app}\teamsync.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\teamsync-reminder"; ValueType: string; ValueData: "URL:TeamSync reminders"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\teamsync-reminder"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\teamsync-reminder\shell\open\command"; ValueType: string; ValueData: """{app}\teamsync.exe"" ""%1"""

[Tasks]
Name: "desktopicon"; Description: "Desktop shortcut / Ярлык на рабочем столе"; Flags: unchecked

[Run]
Filename: "{tmp}\MicrosoftEdgeWebview2Setup.exe"; Parameters: "/silent /install"; Flags: runhidden waituntilterminated; Check: NeedsWebView2
Filename: "{app}\teamsync.exe"; Description: "TeamSync"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\teamsync.exe"; Parameters: "--clear-reminders"; Flags: runhidden waituntilterminated skipifdoesntexist

[Code]
function NeedsWebView2: Boolean;
var Code: Integer;
begin
  if Exec(ExpandConstant('{app}\demo-worker\teamsync-download.exe'), '--check-runtime', '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Result := Code <> 0
  else
    Result := True;
end;

