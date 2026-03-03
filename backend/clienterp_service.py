from __future__ import annotations

import os
import shlex
import subprocess
import sys
import time
from pathlib import Path

import servicemanager
import win32event
import win32service
import win32serviceutil


SERVICE_NAME = "ClientERPService"
SERVICE_DISPLAY = "ClientERP Service"
SERVICE_DESC = "Runs local ClientERP Odoo server"


def _default_server_exe() -> Path:
    """Return bundled server executable path relative to this service binary."""
    base = Path(sys.executable).resolve().parent
    return base / "server" / "clienterp_server.exe"


def _default_config_path() -> Path:
    """Return default Odoo config path from runtime path helpers."""
    from clienterp_runtime.paths import default_odoo_config

    return default_odoo_config()


def _server_command() -> list[str]:
    """Build the subprocess command used to run the guarded server."""
    server_exe = Path(
        os.environ.get("CLIENTERP_SERVER_EXE", str(_default_server_exe()))
    ).resolve()
    config_path = Path(
        os.environ.get("CLIENTERP_CONFIG", str(_default_config_path()))
    ).resolve()
    extra_args = shlex.split(os.environ.get("CLIENTERP_SERVER_ARGS", ""))
    return [str(server_exe), "-c", str(config_path), *extra_args]


class ClientERPService(win32serviceutil.ServiceFramework):
    """Windows Service host that supervises the guarded Odoo process."""

    _svc_name_ = SERVICE_NAME
    _svc_display_name_ = SERVICE_DISPLAY
    _svc_description_ = SERVICE_DESC

    def __init__(self, args):
        """Initialize service state and stop synchronization primitive."""
        super().__init__(args)
        self.stop_event = win32event.CreateEvent(None, 0, 0, None)
        self.server_process: subprocess.Popen[str] | None = None

    def _start_server(self) -> None:
        """Start guarded server process with no attached console streams."""
        command = _server_command()
        servicemanager.LogInfoMsg(f"{SERVICE_NAME}: starting server: {' '.join(command)}")
        self.server_process = subprocess.Popen(
            command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )

    def _stop_server(self) -> None:
        """Gracefully stop the server process and force kill on timeout."""
        if not self.server_process:
            return
        if self.server_process.poll() is None:
            self.server_process.terminate()
            try:
                self.server_process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                self.server_process.kill()
        self.server_process = None

    def SvcStop(self):
        """Service Control Manager stop handler."""
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.stop_event)
        self._stop_server()
        self.ReportServiceStatus(win32service.SERVICE_STOPPED)

    def SvcDoRun(self):
        """Service main loop; restarts server if it exits unexpectedly."""
        servicemanager.LogInfoMsg(f"{SERVICE_NAME}: service started")
        self._start_server()
        try:
            while True:
                wait = win32event.WaitForSingleObject(self.stop_event, 2000)
                if wait == win32event.WAIT_OBJECT_0:
                    break
                if self.server_process and self.server_process.poll() is not None:
                    servicemanager.LogErrorMsg(
                        f"{SERVICE_NAME}: server exited unexpectedly, restarting in 5s"
                    )
                    time.sleep(5)
                    self._start_server()
        finally:
            self._stop_server()
            servicemanager.LogInfoMsg(f"{SERVICE_NAME}: service stopped")


if __name__ == "__main__":
    win32serviceutil.HandleCommandLine(ClientERPService)
