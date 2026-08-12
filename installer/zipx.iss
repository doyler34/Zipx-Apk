; Inno Setup script for ZipX Movies (Windows).
; Compiled in CI (build-windows.yml) after `flutter build windows --release`.
; The Release folder path, version and icon are passed in as /D defines:
;   ISCC /DMyAppVersion=1.0.42 /DSourceDir=<Release folder> /DMyAppIcon=<zipx.ico> installer\zipx.iss
; Produces ZipX-Setup.exe - a normal installer (Program Files, Start-menu
; shortcut, optional desktop icon, uninstaller).

#define MyAppName "ZipX Movies"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "ZipX"
#define MyAppExeName "movie_bloc_app.exe"

[Setup]
; Stable AppId so upgrades replace the previous install instead of stacking.
AppId={{8F3A2C1E-9B4D-4E7A-A1F2-3C5D6E7F8A9B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\ZipX Movies
DefaultGroupName=ZipX Movies
DisableProgramGroupPage=yes
UninstallDisplayName={#MyAppName}
OutputBaseFilename=ZipX-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
#ifdef MyAppIcon
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
; Everything Flutter emitted next to the exe (DLLs + data/ folder).
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
