[Setup]
AppName=TheCErver Launcher
AppPublisher=TheCErver
UninstallDisplayName=TheCErver
AppVersion=${project.version}
AppSupportURL=https://TheCErver.com
DefaultDirName={localappdata}\TheCErver

; ~30 mb for the repo the launcher downloads
ExtraDiskSpaceRequired=30000000
ArchitecturesAllowed=arm64
PrivilegesRequired=lowest

WizardSmallImageFile=${basedir}/innosetup/runelite_small.bmp
SetupIconFile=${basedir}/favicon.ico
UninstallDisplayIcon={app}\TheCErver.exe

Compression=lzma2
SolidCompression=yes

OutputDir=${basedir}
OutputBaseFilename=TheCErverSetupAArch64

[Tasks]
Name: DesktopIcon; Description: "Create a &desktop icon";

[Files]
Source: "${basedir}\native-win-aarch64\TheCErver.exe"; DestDir: "{app}"
Source: "${basedir}\native-win-aarch64\TheCErver.jar"; DestDir: "{app}"
Source: "${basedir}\native\buildaarch64\Release\launcher_aarch64.dll"; DestDir: "{app}"
Source: "${basedir}\native-win-aarch64\config.json"; DestDir: "{app}"
Source: "${basedir}\native-win-aarch64\jre\*"; DestDir: "{app}\jre"; Flags: recursesubdirs

[Icons]
; start menu
Name: "{userprograms}\TheCErver\TheCErver"; Filename: "{app}\TheCErver.exe"
Name: "{userprograms}\TheCErver\TheCErver (configure)"; Filename: "{app}\TheCErver.exe"; Parameters: "--configure"
Name: "{userprograms}\TheCErver\TheCErver (safe mode)"; Filename: "{app}\TheCErver.exe"; Parameters: "--safe-mode"
Name: "{userdesktop}\TheCErver"; Filename: "{app}\TheCErver.exe"; Tasks: DesktopIcon

[Run]
Filename: "{app}\TheCErver.exe"; Parameters: "--postinstall"; Flags: nowait
Filename: "{app}\TheCErver.exe"; Description: "&Open TheCErver"; Flags: postinstall skipifsilent nowait

[InstallDelete]
; Delete the old jvm so it doesn't try to load old stuff with the new vm and crash
Type: filesandordirs; Name: "{app}\jre"
; previous shortcut
Type: files; Name: "{userprograms}\TheCErver.lnk"

[UninstallDelete]
Type: filesandordirs; Name: "{%USERPROFILE}\.the cerver\repository2"
; includes install_id, settings, etc
Type: filesandordirs; Name: "{app}"

[Code]
#include "upgrade.pas"