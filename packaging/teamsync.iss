#define AppVersion "0.95.0"
#define ReleaseVersion "0.95.0-beta"
[Setup]
AppId={{7C263DB7-0143-4F56-A85E-5F28AC37E16D}
AppName=TeamSync
AppVersion={#AppVersion}
AppVerName=TeamSync 0.95 Beta
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
Name: "{group}\TeamSync"; Filename: "{app}\teamsync.exe"
Name: "{autodesktop}\TeamSync"; Filename: "{app}\teamsync.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Desktop shortcut / Ярлык на рабочем столе"; Flags: unchecked

[Run]
Filename: "{tmp}\MicrosoftEdgeWebview2Setup.exe"; Parameters: "/silent /install"; Flags: runhidden waituntilterminated; Check: NeedsWebView2
Filename: "{app}\teamsync.exe"; Description: "TeamSync"; Flags: nowait postinstall skipifsilent

[Code]
function NeedsWebView2: Boolean;
var Code: Integer;
begin
  if Exec(ExpandConstant('{app}\demo-worker\teamsync-download.exe'), '--check-runtime', '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Result := Code <> 0
  else
    Result := True;
end;

