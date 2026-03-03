# Windows Local Deployment (Appendix)

Canonical documentation moved to root `README.md`.

Use this file only for quick technical references that complement the master guide.

## Canonical Source

- Root guide: `README.md`

## Appendix Notes

### One-command release (recommended)

```powershell
.\build\windows\get_webview2_runtime.ps1
.\build\windows\release_windows.ps1 -Clean -InstallDesktopDeps
```

### Manual commands (if needed)

```powershell
.\build\windows\build_windows.ps1 -Clean -InstallDesktopDeps
.\build\windows\stage_installer.ps1
.\build\windows\build_installer.ps1
```

### Key runtime paths on client machine

- `%ProgramData%\ClientERP\config\odoo.conf`
- `%ProgramData%\ClientERP\license\license.json`
- `%ProgramData%\ClientERP\license\public_key.pem`
- `%ProgramData%\ClientERP\logs\`
- `%ProgramData%\ClientERP\migration\`

### Security reminders

- Do not ship vendor private key.
- Do not ship installer with unresolved placeholder defaults.
- Do not stage installer if `installer/windows/templates/public_key.pem` still has placeholder text.
