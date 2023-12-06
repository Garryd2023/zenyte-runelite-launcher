[Setup]
AppName=TheNightmatez Launcher
AppPublisher=TheNightmatez
UninstallDisplayName=TheNightmatez
AppVersion=${project.version}
AppSupportURL=https://TheNightmatez.com
DefaultDirName={localappdata}\TheNightmatez

; ~30 mb for the repo the launcher downloads
ExtraDiskSpaceRequired=30000000
ArchitecturesAllowed=arm64
PrivilegesRequired=lowest

WizardSmallImageFile=${basedir}/innosetup/runelite_small.bmp
SetupIconFile=${basedir}/favicon.ico
UninstallDisplayIcon={app}\TheNightmatez.exe

Compression=lzma2
SolidCompression=yes

OutputDir=${basedir}
OutputBaseFilename=TheNightmatezSetupAArch64

[Tasks]
Name: DesktopIcon; Description: "Create a &desktop icon";

[Files]
Source: "${basedir}\native-win-aarch64\TheNightmatez.exe"; DestDir: "{app}"
Source: "${basedir}\native-win-aarch64\TheNightmatez.jar"; DestDir: "{app}"
Source: "${basedir}\native\buildaarch64\Release\launcher_aarch64.dll"; DestDir: "{app}"
Source: "${basedir}\native-win-aarch64\config.json"; DestDir: "{app}"
Source: "${basedir}\native-win-aarch64\jre\*"; DestDir: "{app}\jre"; Flags: recursesubdirs

[Icons]
; start menu
Name: "{userprograms}\TheNightmatez\TheNightmatez"; Filename: "{app}\TheNightmatez.exe"
Name: "{userprograms}\TheNightmatez\TheNightmatez (configure)"; Filename: "{app}\TheNightmatez.exe"; Parameters: "--configure"
Name: "{userprograms}\TheNightmatez\TheNightmatez (safe mode)"; Filename: "{app}\TheNightmatez.exe"; Parameters: "--safe-mode"
Name: "{userdesktop}\TheNightmatez"; Filename: "{app}\TheNightmatez.exe"; Tasks: DesktopIcon

[Run]
Filename: "{app}\TheNightmatez.exe"; Parameters: "--postinstall"; Flags: nowait
Filename: "{app}\TheNightmatez.exe"; Description: "&Open TheNightmatez"; Flags: postinstall skipifsilent nowait

[InstallDelete]
; Delete the old jvm so it doesn't try to load old stuff with the new vm and crash
Type: filesandordirs; Name: "{app}\jre"
; previous shortcut
Type: files; Name: "{userprograms}\TheNightmatez.lnk"

[UninstallDelete]
Type: filesandordirs; Name: "{%USERPROFILE}\.the cerver\repository2"
; includes install_id, settings, etc
Type: filesandordirs; Name: "{app}"

[Code]
#include "upgrade.pas"