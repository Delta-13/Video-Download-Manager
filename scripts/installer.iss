#define AppVersion "2.0.0"
[Setup]
AppId={{F7C8E34F-C16A-47C2-A412-7E0E43F1C570}
AppName=Video Download Manager 2
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\VDM2
DefaultGroupName=Video Download Manager 2
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\artifacts
OutputBaseFilename=VDM-2.0.0-windows-x64-setup
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\vdm.exe
SetupIconFile=..\desktop\windows\runner\resources\app_icon.ico
CloseApplications=yes
RestartApplications=no

[Files]
Source: "..\artifacts\VDM-2.0.0-windows-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Video Download Manager 2"; Filename: "{app}\vdm.exe"
Name: "{group}\使用说明"; Filename: "{app}\README.md"

[Registry]
Root: HKCU; Subkey: "Software\Google\Chrome\NativeMessagingHosts\io.vdm.bridge"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Edge\NativeMessagingHosts\io.vdm.bridge"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\VDM2"; Flags: uninsdeletekey

[Run]
Filename: "{app}\vdm.exe"; Description: "打开 Video Download Manager 2"; Flags: nowait postinstall skipifsilent
