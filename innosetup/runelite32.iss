[Setup]
AppName=Near-Reality Launcher
AppPublisher=Near-Reality
UninstallDisplayName=Near-Reality
AppVersion=${project.version}
AppSupportURL=https://near-reality.com/
DefaultDirName={localappdata}\Near-Reality

; ~30 mb for the repo the launcher downloads
ExtraDiskSpaceRequired=30000000
ArchitecturesAllowed=x86 x64
PrivilegesRequired=lowest

WizardSmallImageFile=${basedir}/innosetup/runelite_small.bmp
SetupIconFile=${basedir}/runelite.ico
UninstallDisplayIcon={app}\Near-Reality.exe

Compression=lzma2
SolidCompression=yes

OutputDir=${basedir}
OutputBaseFilename=Near-RealitySetup32

[Tasks]
Name: DesktopIcon; Description: "Create a &desktop icon";

[Files]
Source: "${basedir}\native-win32\Near-Reality.exe"; DestDir: "{app}"
Source: "${basedir}\native-win32\RuneLite.jar"; DestDir: "{app}"
Source: "${basedir}\native-win32\config.json"; DestDir: "{app}"
Source: "${basedir}\native-win32\jre\*"; DestDir: "{app}\jre"; Flags: recursesubdirs
; dependencies of jvm.dll and javaaccessbridge.dll
Source: "${basedir}\native-win32\jre\bin\msvcr120.dll"; DestDir: "{app}"
Source: "${basedir}\native-win32\jre\bin\msvcp120.dll"; DestDir: "{app}"
Source: "${basedir}\native-win32\jre\bin\jawt.dll"; DestDir: "{app}"

[Icons]
; start menu
Name: "{userprograms}\Near-Reality"; Filename: "{app}\Near-Reality.exe"
Name: "{userdesktop}\Near-Reality"; Filename: "{app}\Near-Reality.exe"; Tasks: DesktopIcon

[Run]
Filename: "{app}\Near-Reality.exe"; Description: "&Open Near-Reality"; Flags: postinstall skipifsilent nowait

[InstallDelete]
; Delete the old jvm so it doesn't try to load old stuff with the new vm and crash
Type: filesandordirs; Name: "{app}"

[UninstallDelete]
Type: filesandordirs; Name: "{%USERPROFILE}\.osnr\repository2"