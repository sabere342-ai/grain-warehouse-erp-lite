; Inno Setup installer source for غلال (Grala) — Grain Warehouse Management
; Phase 98 — Client Demo Release Packaging
;
; This script is validated statically. Compilation requires ISCC.exe (Inno Setup Compiler).
; Run: iscc.exe ghalal.iss
; Output will be in windows\installer\Output\

#define MyAppNameArabic "غلال"
#define MyAppNameEnglish "Grala"
#define MyAppName "Grala - Grain Warehouse Management"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Grala"
#define MyAppExeName "grain_warehouse_erp_lite.exe"
#define MyAppSourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Grala\Ghalal
DefaultGroupName={#MyAppNameArabic}
OutputDir=Output
OutputBaseFilename=ghalal-setup-v{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
; Per-user installation (no admin required)
PrivilegesRequired=lowest
PrivilegesRequiredOverriddenOwned=yes
; Visual style
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
; Uninstall display name (Arabic)
UninstallDisplayName={#MyAppNameArabic} - {#MyAppNameEnglish}
; License
LicenseFile=..\..\docs\CLIENT-KNOWN-LIMITATIONS-AR.md
; Wizard style
WizardStyle=modern
WizardSizePercent=110
; Welcome message
WelcomeWindowTitle=تثبيت {#MyAppNameArabic}
; Version info
VersionInfoVersion=1.0.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppVersion}
VersionInfoProductName={#MyAppNameArabic}
VersionInfoProductVersion={#MyAppVersion}
; Window appearance
WindowResizable=no
WindowShowCaption=yes
WindowVisible=no

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "إنشاء اختصار على سطح المكتب"; GroupDescription: "خيارات إضافية:"; Flags: unchecked

[Files]
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppNameArabic}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\إلغاء التثبيت"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppNameArabic}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "تشغيل {#MyAppNameArabic}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\*.log"
; NOTE: Do NOT delete {app}\*.sqlite3 — user data must be preserved
; The user is responsible for backing up and cleaning data manually

[Code]
// Preserve user data during uninstall:
// The application database is stored in %APPDATA%\com.example\grain_warehouse_erp_lite\
// This is OUTSIDE the {app} directory, so it is NOT affected by uninstall.
// The installer only removes files in {app}, which are program files only.

function InitializeSetup: Boolean;
begin
  Result := True;
end;
