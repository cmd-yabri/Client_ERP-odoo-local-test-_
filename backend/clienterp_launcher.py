from __future__ import annotations

import argparse
import ctypes
import subprocess
import time
import urllib.error
import urllib.request
import winreg


SERVICE_NAME = "ClientERPService"
DEFAULT_URL = "http://127.0.0.1:8069/web/login"
WEBVIEW2_GUID = "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
WEBVIEW2_REG_PATHS = (
    (winreg.HKEY_LOCAL_MACHINE, rf"SOFTWARE\Microsoft\EdgeUpdate\Clients\{WEBVIEW2_GUID}"),
    (winreg.HKEY_LOCAL_MACHINE, rf"SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{WEBVIEW2_GUID}"),
    (winreg.HKEY_CURRENT_USER, rf"SOFTWARE\Microsoft\EdgeUpdate\Clients\{WEBVIEW2_GUID}"),
)


def _message_box(text: str, title: str, icon: int = 0x10) -> None:
    """Show a blocking native Windows message box for user-facing errors."""
    ctypes.windll.user32.MessageBoxW(0, text, title, icon)


def _get_reg_string(hive: int, path: str, name: str) -> str:
    """Read a registry string value and return an empty string on failure."""
    try:
        with winreg.OpenKey(hive, path) as key:
            value, _ = winreg.QueryValueEx(key, name)
        return str(value).strip()
    except OSError:
        return ""


def _webview2_version() -> str:
    """Return installed WebView2 runtime version, or empty when unavailable."""
    for hive, path in WEBVIEW2_REG_PATHS:
        version = _get_reg_string(hive, path, "pv")
        if version:
            return version
    return ""


def _ensure_webview2_runtime() -> None:
    """Fail fast when WebView2 runtime is missing on the client machine."""
    if _webview2_version():
        return
    raise RuntimeError(
        "Microsoft Edge WebView2 Runtime is missing. "
        "Reinstall ClientERP or run the bundled WebView2 runtime installer."
    )


def _service_state() -> str:
    """Read ClientERP Windows service state via `sc query`."""
    cmd = ["sc", "query", SERVICE_NAME]
    completed = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        return "MISSING"
    for line in completed.stdout.splitlines():
        if "STATE" in line:
            # Example: STATE              : 4  RUNNING
            parts = line.split()
            if parts:
                return parts[-1].strip().upper()
    return "UNKNOWN"


def _start_service_if_needed() -> None:
    """Start the service when present but not running."""
    state = _service_state()
    if state == "RUNNING":
        return
    if state == "MISSING":
        raise RuntimeError(
            "ClientERP service is not installed. Please reinstall ClientERP."
        )
    start = subprocess.run(
        ["sc", "start", SERVICE_NAME],
        capture_output=True,
        text=True,
        check=False,
    )
    if start.returncode != 0:
        raise RuntimeError(start.stdout.strip() or start.stderr.strip() or "failed to start service")


def _wait_http(url: str, timeout_seconds: int = 120) -> None:
    """Poll the local HTTP endpoint until it becomes reachable."""
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=4) as resp:  # noqa: S310
                if 200 <= resp.status < 500:
                    return
        except (urllib.error.URLError, TimeoutError):
            pass
        time.sleep(2)
    raise RuntimeError("Odoo server did not become ready in time")


def _open_embedded_window(url: str) -> None:
    """Open the local app in an embedded WebView2 desktop window."""
    try:
        import webview
    except Exception as exc:
        raise RuntimeError(
            "Desktop UI dependency is missing (pywebview). Rebuild or reinstall ClientERP."
        ) from exc

    try:
        webview.create_window(
            "ClientERP",
            url=url,
            width=1280,
            height=850,
            resizable=True,
            min_size=(1024, 700),
        )
        webview.start(gui="edgechromium")
    except Exception as exc:
        raise RuntimeError(
            "Failed to start embedded desktop window (WebView2). "
            "Verify WebView2 runtime installation."
        ) from exc


def main(argv: list[str] | None = None) -> int:
    """CLI entrypoint for launcher startup flow."""
    parser = argparse.ArgumentParser(description="Launch ClientERP desktop app")
    parser.add_argument("--url", default=DEFAULT_URL, help="Local ClientERP URL")
    args = parser.parse_args(argv)

    try:
        _ensure_webview2_runtime()
        _start_service_if_needed()
        _wait_http(args.url)
    except Exception as exc:
        _message_box(str(exc), "ClientERP", icon=0x10)
        return 1

    try:
        _open_embedded_window(args.url)
    except Exception as exc:
        _message_box(str(exc), "ClientERP", icon=0x10)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
