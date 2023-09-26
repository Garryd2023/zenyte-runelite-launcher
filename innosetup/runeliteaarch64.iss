[Setup]
AppName=The CErver Launcher
AppPublisher=The CErver
UninstallDisplayName=The CErver
AppVersion=${project.version}
AppSupportURL=https://The CErver.com
DefaultDirName={localappdata}\The CErver

; ~30 mb for the repo the launcher downloads
ExtraDiskSpaceRequired=30000000
ArchitecturesAllowed=arm64
PrivilegesRequired=lowest

WizardSmallImageFile=${basedir}/innosetup/runelite_small.bmp
SetupIconFile=${basedir}/runelite.ico
UninstallDisplayIcon={app}\The CErver.exe

Compression=lzma2
SolidCompression=yes

OutputDir=${basedir}
OutputBaseFilename=The CErverSetupAArch64

[Tasks]
Name: DesktopIcon; Description: "Create a &desktop icon";

[Files]
Source: "${basedir}\native-win-aarch64\The CErver.exe"; DestDir: "{app}"
Source: "${basedir}\native-win-aarch64\The CErver.jar"; DestDir: "{app}"
Source: "${basedir}\native\buildaarch64\Release\launcher_aarch64.dll"; DestDir: "{app}"
Source: "${basedir}\native-win-aarch64\config.json"; DestDir: "{app}"
Source: "${basedir}\native-win-aarch64\jre\*"; DestDir: "{app}\jre"; Flags: recursesubdirs

[Icons]
; start menu
Name: "{userprograms}\The CErver\The CErver"; Filename: "{app}\The CErver.exe"
Name: "{userprograms}\The CErver\The CErver (configure)"; Filename: "{app}\The CErver.exe"; Parameters: "--configure"
Name: "{userprograms}\The CErver\The CErver (safe mode)"; Filename: "{app}\The CErver.exe"; Parameters: "--safe-mode"
Name: "{userdesktop}\The CErver"; Filename: "{app}\The CErver.exe"; Tasks: DesktopIcon

[Run]
Filename: "{app}\The CErver.exe"; Parameters: "--postinstall"; Flags: nowait
Filename: "{app}\The CErver.exe"; Description: "&Open The CErver"; Flags: postinstall skipifsilent nowait

[InstallDelete]
; Delete the old jvm so it doesn't try to load old stuff with the new vm and crash
Type: filesandordirs; Name: "{app}\jre"
; previous shortcut
Type: files; Name: "{userprograms}\The CErver.lnk"

[UninstallDelete]
Type: filesandordirs; Name: "{%USERPROFILE}\.the cerver\repository2"
; includes install_id, settings, etc
Type: filesandordirs; Name: "{app}"

[Code]
#include "upgrade.pas"