[Setup]
AppName=TheCErver Launcher
AppPublisher=TheCErver
UninstallDisplayName=TheCErver
AppVersion=${project.version}
AppSupportURL=https://thecerver.com
DefaultDirName={localappdata}\TheCErver

; ~30 mb for the repo the launcher downloads
ExtraDiskSpaceRequired=30000000
ArchitecturesAllowed=x86 x64
PrivilegesRequired=lowest

WizardSmallImageFile=${basedir}/innosetup/runelite_small.bmp
SetupIconFile=${basedir}/runelite.ico
UninstallDisplayIcon={app}\TheCErver.exe

Compression=lzma2
SolidCompression=yes

OutputDir=${basedir}
OutputBaseFilename=TheCErverSetup32

[Tasks]
Name: DesktopIcon; Description: "Create a &desktop icon";

[Files]
Source: "${basedir}\native-win32\TheCErver.exe"; DestDir: "{app}"
Source: "${basedir}\native-win32\TheCErver.jar"; DestDir: "{app}"
Source: "${basedir}\native\build32\Release\launcher_x86.dll"; DestDir: "{app}"
Source: "${basedir}\native-win32\config.json"; DestDir: "{app}"
Source: "${basedir}\native-win32\jre\*"; DestDir: "{app}\jre"; Flags: recursesubdirs

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
Type: filesandordirs; Name: "{%USERPROFILE}\.runelite\repository2"
; includes install_id, settings, etc
Type: filesandordirs; Name: "{app}"

[Code]
#include "upgrade.pas"