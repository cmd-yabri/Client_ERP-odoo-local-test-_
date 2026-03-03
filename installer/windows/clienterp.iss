#define MyAppName "ClientERP"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "ClientERP"
#define MyAppExeName "clienterp_launcher.exe"

; Build-time defaults. Change before compiling installer.
#define PgSuperPassword "1234"
#define DbUser "feras"
#define DbPassword "123456"
#define DbName "clienterp"
#define OdooAdminPassword "123456"
#define PgInstallDir "C:\Program Files\PostgreSQL\18"
#define PgBinPath "C:\Program Files\PostgreSQL\18\bin"
#define WebView2MinVersion "0.0.0.0"

#if !FileExists("MicrosoftEdgeWebView2RuntimeInstallerX64.exe")
  #error WebView2 offline installer is missing from stage package. Place MicrosoftEdgeWebView2RuntimeInstallerX64.exe in third_party\webview2 and restage.
#endif

#if "{#PgSuperPassword}" == "ChangeMe_PgSuper_123!"
  #error PgSuperPassword still uses placeholder value.
#endif
#if "{#DbPassword}" == "ChangeMe_Db_123!"
  #error DbPassword still uses placeholder value.
#endif
#if "{#OdooAdminPassword}" == "ChangeMe_Odoo_123!"
  #error OdooAdminPassword still uses placeholder value.
#endif

[Setup]
AppId={{2F4A5D59-56AF-4A19-B042-6E911A7A1468}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\ClientERP
DefaultGroupName=ClientERP
DisableProgramGroupPage=yes
OutputBaseFilename=ClientERP-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "templates\*"; DestDir: "{commonappdata}\ClientERP\templates"; Flags: ignoreversion recursesubdirs createallsubdirs
#if FileExists("postgresql-installer.exe")
Source: "postgresql-installer.exe"; DestDir: "{app}"; Flags: ignoreversion
#endif
#if FileExists("MicrosoftEdgeWebView2RuntimeInstallerX64.exe")
Source: "MicrosoftEdgeWebView2RuntimeInstallerX64.exe"; DestDir: "{app}"; Flags: ignoreversion
#endif

[Icons]
Name: "{autodesktop}\ClientERP"; Filename: "{app}\clienterp_launcher.exe"
Name: "{group}\ClientERP"; Filename: "{app}\clienterp_launcher.exe"
Name: "{group}\ClientERP Activation Tool"; Filename: "{app}\clienterp_activate.exe"
Name: "{group}\Uninstall ClientERP"; Filename: "{uninstallexe}"

[Run]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\migrate_export.ps1"" -PgBinPath ""{#PgBinPath}"" -DbName ""{#DbName}"" -SuperPassword ""{#PgSuperPassword}"""; Flags: runhidden waituntilterminated
#if FileExists("postgresql-installer.exe")
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\install_postgres.ps1"" -InstallerPath ""{app}\postgresql-installer.exe"" -SuperPassword ""{#PgSuperPassword}"" -InstallDir ""{#PgInstallDir}"""; Flags: runhidden waituntilterminated
#endif
#if FileExists("MicrosoftEdgeWebView2RuntimeInstallerX64.exe")
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\install_webview2.ps1"" -InstallerPath ""{app}\MicrosoftEdgeWebView2RuntimeInstallerX64.exe"" -MinVersion ""{#WebView2MinVersion}"""; Flags: runhidden waituntilterminated
#endif
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\install_public_key.ps1"" -SourcePath ""{commonappdata}\ClientERP\templates\public_key.pem"""; Flags: runhidden waituntilterminated
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\configure_odoo.ps1"" -TemplatePath ""{commonappdata}\ClientERP\templates\odoo.conf.template"" -OutPath ""{commonappdata}\ClientERP\config\odoo.conf"" -InstallDir ""{app}"" -DbUser ""{#DbUser}"" -DbPassword ""{#DbPassword}"" -DbName ""{#DbName}"" -AdminPassword ""{#OdooAdminPassword}"" -PgBinPath ""{#PgBinPath}"""; Flags: runhidden waituntilterminated
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\init_database.ps1"" -PgBinPath ""{#PgBinPath}"" -DbName ""{#DbName}"" -DbUser ""{#DbUser}"" -DbPassword ""{#DbPassword}"" -SuperPassword ""{#PgSuperPassword}"""; Flags: runhidden waituntilterminated
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\migrate_import.ps1"" -PgBinPath ""{#PgBinPath}"" -DbName ""{#DbName}"" -DbUser ""{#DbUser}"" -DbPassword ""{#DbPassword}"" -SuperPassword ""{#PgSuperPassword}"""; Flags: runhidden waituntilterminated
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\install_service.ps1"" -InstallDir ""{app}"" -ConfigPath ""{commonappdata}\ClientERP\config\odoo.conf"""; Flags: runhidden waituntilterminated
Filename: "{app}\clienterp_launcher.exe"; Description: "Launch ClientERP"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\remove_service.ps1"" -InstallDir ""{app}"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveClientERPService"

[Code]
function HasPlaceholder(const Value: string): Boolean;
begin
  Result := Pos('ChangeMe_', Value) = 1;
end;

function InitializeSetup(): Boolean;
var
  ErrorMsg: string;
begin
  ErrorMsg := '';

  if HasPlaceholder('{#PgSuperPassword}') then
    ErrorMsg := ErrorMsg + 'PgSuperPassword is still using a placeholder value.' + #13#10;
  if HasPlaceholder('{#DbPassword}') then
    ErrorMsg := ErrorMsg + 'DbPassword is still using a placeholder value.' + #13#10;
  if HasPlaceholder('{#OdooAdminPassword}') then
    ErrorMsg := ErrorMsg + 'OdooAdminPassword is still using a placeholder value.' + #13#10;

  if ErrorMsg <> '' then
  begin
    MsgBox(
      'Installer is not customized for this client:' + #13#10 + ErrorMsg + #13#10 +
      'Update clienterp.iss values and rebuild before delivery.',
      mbCriticalError,
      MB_OK
    );
    Result := False;
    exit;
  end;

  Result := True;
end;
