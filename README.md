# ClientERP Windows Desktop (Odoo) - Master Build, Security, and Delivery Guide

This repository packages Odoo as a local Windows desktop application with:

- a Windows service (`ClientERPService`) that runs the protected Odoo server
- offline machine-bound licensing (signed Ed25519 license file)
- an activation tool for offline issuance/install
- a desktop launcher that opens Odoo in an embedded WebView2 window
- an Inno Setup installer pipeline for client delivery

This document is the canonical guide for current and future projects using this architecture.

## 1. What This App Is (Plain Language)

ClientERP is a desktop application for Windows. The user installs one setup file, activates once with a signed license file, and then opens the app from a desktop shortcut.

The user does not need a browser tab. The app opens in its own window.

## 2. How It Works (Diagram in Words)

1. User launches `clienterp_launcher.exe`.
2. Launcher checks WebView2 runtime, ensures `ClientERPService` is running, and waits for `http://127.0.0.1:8069/web/login`.
3. Service runs `clienterp_server.exe` (protected Odoo entrypoint).
4. Server enforces license before Odoo starts.
5. Launcher opens an embedded desktop window using `pywebview` + WebView2.
6. If license is missing/invalid, activation request JSON is generated and startup is blocked.

## 3. Audience Quick Index

- Non-technical user: see Section 4.
- New engineer: see Section 5.
- Build/release engineer: see Section 6 onward.
- Future Odoo project team: see Section 10.

## 4. Non-Technical User Guide

### Install

1. Run `ClientERP-Setup.exe` as Administrator.
2. Wait until setup completes.
3. Keep internet disconnected if required; this installer is designed for offline use.

### Activate

1. Open `ClientERP Activation Tool` from Start Menu.
2. Generate activation request.
3. Send the generated JSON file to your vendor.
4. Receive signed license JSON.
5. Install license using activation tool.

### Open App

1. Double-click `ClientERP` desktop icon.
2. App opens in a desktop window (not external browser).

### If You Change PC

1. Old license cannot be reused automatically on new hardware.
2. Generate a new activation request on the new machine.
3. Vendor issues a new signed license bound to the new fingerprint.

### Common Errors and Who to Contact

- `license check failed`: contact vendor for activation/license reissue.
- `WebView2 runtime is missing`: rerun installer or ask vendor for setup package that includes WebView2 runtime.
- `service is not installed`: reinstall app using official setup package.
- Database errors: contact deployment engineer/vendor.

## 5. New Engineer Guide (Components and Why They Exist)

### Core executables

- `clienterp_server.exe`: runs Odoo, enforces license before startup.
- `clienterp_service.exe`: Windows Service wrapper; keeps server running.
- `clienterp_launcher.exe`: desktop shell launcher (service bootstrap + embedded WebView).
- `clienterp_activate.exe`: customer-facing offline activation tool.
- `clienterp_license_vendor.exe` (optional build): vendor-only signing utility.

### Why each exists

- Service: decouples server lifetime from user session and gives recoverable startup behavior.
- License guard: blocks unauthorized execution even if binaries are copied.
- Activation CLI: supports fully offline customer/vendor exchange.
- Installer scripts: automate DB, config, service install, migration, and runtime dependencies.
- WebView2 shell: gives desktop experience without browser dependency.

### Security boundaries and limitations

- Strong hardening, not absolute tamper-proofing against a determined local admin.
- Private signing key must never ship to customer.
- Public key is safe to ship and required for signature verification.
- Machine binding is based on hardware fingerprint; hardware changes can invalidate license.

## 6. Repository Map (Windows Packaging Path)

- `backend/clienterp_server.py`: guarded server entrypoint.
- `backend/clienterp_service.py`: Windows service host.
- `backend/clienterp_launcher.py`: embedded desktop launcher.
- `backend/clienterp_activate.py`: activation CLI wrapper.
- `backend/clienterp_vendor_license.py`: vendor signing CLI wrapper.
- `backend/clienterp_runtime/`: licensing, hardware fingerprinting, runtime paths.
- `build/windows/build_windows.ps1`: builds protected executables with Nuitka.
- `build/windows/stage_installer.ps1`: assembles installer staging package.
- `build/windows/build_installer.ps1`: compiles Inno installer with ISCC.
- `build/windows/release_windows.ps1`: one-command release pipeline (build/stage/compile/checksum).
- `installer/windows/clienterp.iss`: installer definition.
- `installer/windows/scripts/*.ps1`: setup/migration/service/runtime scripts.
- `installer/windows/templates/*`: shipped templates (odoo config/public key).

## 7. Build Pipeline (Reproducible Commands)

Run all commands from repo root (`c:\clientERP`).

### 7.1 Prerequisites on build machine

- Windows x64
- Python 3.12 venv at `backend\\venv`
- Nuitka in venv
- Visual Studio Build Tools (C++ workload)
- Inno Setup 6 (`ISCC.exe`)
- Offline WebView2 runtime installer at:
  - `third_party\\webview2\\MicrosoftEdgeWebView2RuntimeInstallerX64.exe`
- Optional PostgreSQL installer at:
  - `third_party\\postgresql\\postgresql-installer.exe`

If `third_party` does not exist yet, create it and place the installer using the exact filename above.

Preflight checks before a long build:

```powershell
.\build\windows\get_webview2_runtime.ps1
Test-Path .\third_party\webview2\MicrosoftEdgeWebView2RuntimeInstallerX64.exe
Get-Content .\installer\windows\templates\public_key.pem -Raw
```

The public key file must be a real PEM key block (`-----BEGIN PUBLIC KEY----- ... -----END PUBLIC KEY-----`), not a placeholder string.

### 7.2 One-time key generation

```powershell
backend\venv\Scripts\python.exe .\backend\clienterp_vendor_license.py generate-keys `
  --private-out .\secrets\clienterp_private.pem `
  --public-out .\installer\windows\templates\public_key.pem
```

Rules:

- Keep `.\secrets\clienterp_private.pem` offline and vendor-only.
- Never include private key in installer package.
- Public key template must not contain `REPLACE_WITH_VENDOR_PUBLIC_KEY` when staging.

### 7.3 One-command release (recommended)

```powershell
.\build\windows\release_windows.ps1 -Clean -InstallDesktopDeps
```

Output:

- installer EXE in `artifacts\windows\package`
- SHA256 checksum file beside the installer (`.sha256`)

### 7.4 Step-by-step (manual)

```powershell
.\build\windows\build_windows.ps1 -Clean -InstallDesktopDeps
.\build\windows\stage_installer.ps1
.\build\windows\build_installer.ps1
```

## 8. Installer and Activation Workflow

### 8.1 Before compiling installer (`clienterp.iss`)

Set per-client values:

- `PgSuperPassword`
- `DbUser`
- `DbPassword`
- `DbName`
- `OdooAdminPassword`
- `PgInstallDir`
- `PgBinPath` (must match `PgInstallDir\bin`)

Validation now exists in two places:

- compile-time checks in Inno preprocessor (`#error` if unresolved default placeholders are used)
- install-time checks in `[Code]` as a second guard

### 8.2 What installer does (high level)

1. `migrate_export.ps1`
2. optional `install_postgres.ps1`
3. `install_webview2.ps1`
4. `install_public_key.ps1`
5. `configure_odoo.ps1`
6. `init_database.ps1`
7. `migrate_import.ps1`
8. `install_service.ps1`
9. optional app launch

### 8.3 Customer activation flow

On customer machine:

```powershell
clienterp_activate.exe request --out C:\temp\activation_request.json
```

On vendor machine:

```powershell
backend\venv\Scripts\python.exe .\backend\clienterp_vendor_license.py issue-license `
  --private-key .\secrets\clienterp_private.pem `
  --request-file C:\temp\activation_request.json `
  --out C:\temp\license.json `
  --customer "Client Name"
```

Back on customer machine:

```powershell
clienterp_activate.exe activate --license-file C:\temp\license.json
```

## 9. Exporting/Securing the Project for Delivery

Use this release directory model for each client handoff:

- `ClientERP-Setup.exe` (installer output)
- `ClientERP-Setup.exe.sha256` (generated checksum)
- release notes (version/date/hash)
- activation instructions (short PDF/text)

Never include in customer handoff:

- private key PEM
- vendor signing tool (unless explicitly needed in controlled environment)
- source code / build workspace
- internal CI credentials

Recommended vendor-side controls:

- keep private key on offline signing machine
- rotate keys per product line if policy requires
- archive issued license JSON per customer and date
- record machine fingerprint and license id mapping

## 10. Template for Future Odoo Windows Projects

### 10.1 Project variable table

| Variable          | Current Value                                       | Where Used                           |
| ----------------- | --------------------------------------------------- | ------------------------------------ |
| `APP_NAME`        | `ClientERP`                                         | Paths, UI labels, installer branding |
| `SERVICE_NAME`    | `ClientERPService`                                  | Launcher/service scripts/runtime     |
| `DB_NAME`         | `clienterp`                                         | DB init/migration/config             |
| `PORT`            | `8069`                                              | launcher URL + odoo config           |
| `MODULE_NAMES`    | `base,web,custom_license`                           | `server_wide_modules`                |
| `INSTALLER_APPID` | `{2F4A5D59-56AF-4A19-B042-6E911A7A1468}`            | Inno setup identity                  |
| `PG_INSTALL_DIR`  | `C:\Program Files\PostgreSQL\18`                    | Bundled PostgreSQL install target    |
| `PUBLIC_KEY_PATH` | `%ProgramData%\\ClientERP\\license\\public_key.pem` | License verification                 |

### 10.2 Clone process

1. Copy repository to new project folder.
2. Replace names/identifiers (app/service/db/installer appid/paths).
3. Create new signing keypair for new product/client policy.
4. Update templates and installer defaults.
5. Rebuild binaries and installer.
6. Validate clean machine install + activation + launch.

### 10.3 Safe identifier replacement checklist

- rename app strings in launcher/service/runtime paths
- update installer script constants and icon labels
- verify service name in PowerShell scripts and launcher
- verify ProgramData subfolder names
- verify activation product code (`PRODUCT_CODE`)
- verify no stale old-name leftovers:

```powershell
rg -n "ClientERP|ClientERPService|clienterp" backend build installer docs
```

## 11. Testing Checklist

### Functional

- Launcher opens embedded Odoo window.
- Service starts automatically on launch if stopped.
- Activation tool can request/install license offline.
- Setup on clean VM completes without manual fixes.

### Security

- No startup with missing/invalid/wrong-machine license.
- Placeholder public key fails staging/install.
- Private key absent from staged package and installer output.
- Placeholder defaults are blocked at compile-time and install-time.

### Reinstall/Migration

- Reinstall exports and restores DB + filestore.
- Existing data remains accessible after reinstall.
- Service reinstalled and running after upgrade.

### Machine-transfer licensing

- Old license rejected on different machine.
- New activation request generated on target machine.

## 12. Shipping Checklist (Per Client)

1. Set client-specific secrets in `installer/windows/clienterp.iss`.
2. Ensure real public key is present in `installer/windows/templates/public_key.pem`.
3. Run one-command release (`release_windows.ps1`) or manual build/stage/compile.
4. Validate on clean Windows VM:
   - install
   - activate
   - launch
   - restart machine and relaunch
5. Deliver setup package and checksum file.
6. Receive activation request JSON from client.
7. Issue signed license offline.
8. Send license JSON back to client.
9. Confirm client activation and first successful run.

## 13. Troubleshooting

### Launcher does not open

- Check Windows service exists: `sc query ClientERPService`
- Check Odoo URL is reachable locally: `http://127.0.0.1:8069/web/login`
- Check WebView2 runtime installed.

### Service stopped

- Reinstall service via installer rerun or script.
- Check `%ProgramData%\\ClientERP\\logs` and Windows Event Viewer.

### License invalid

- Run `clienterp_activate.exe status`
- Verify installed public key and license file paths in `%ProgramData%\\ClientERP\\license`
- Regenerate activation request and reissue license.

### WebView2 missing

- Verify setup package included `MicrosoftEdgeWebView2RuntimeInstallerX64.exe`
- Rerun installer as Administrator.

### DB connection issues

- Verify `PgBinPath` and PostgreSQL service state.
- Confirm `odoo.conf` DB credentials and database existence.

## 14. Do This Now (Quick Paths)

### Immediate actions now

```powershell
backend\venv\Scripts\python.exe .\backend\clienterp_vendor_license.py generate-keys `
  --private-out .\secrets\clienterp_private.pem `
  --public-out .\installer\windows\templates\public_key.pem

.\build\windows\release_windows.ps1 -Clean -InstallDesktopDeps
```

### First clean-VM full test

1. Copy installer EXE to clean VM.
2. Install.
3. Generate activation request.
4. Issue/install license.
5. Launch app and validate embedded window.
6. Reboot VM and relaunch.

### Per-client release routine

1. Update `clienterp.iss` values.
2. Confirm public key template is real.
3. Run `release_windows.ps1`.
4. Clean VM validation.
5. Deliver setup + checksum.
6. Complete offline activation handoff.

### Future-project bootstrap mini-playbook

1. Clone this repo as template.
2. Replace identifiers from Section 10 table.
3. Generate fresh keys.
4. Build and validate on clean VM.
5. Freeze the new project README as canonical SOP.

## 15. Appendix Pointer

`docs/WINDOWS_LOCAL_DEPLOYMENT.md` is now a short technical appendix.
Use this root `README.md` as the single source of truth.

terminal build command : .\build\windows\release_windows.ps1 -Clean -InstallDesktopDeps -StopStaleBuildProcesses
