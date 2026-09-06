#!/usr/bin/env python3
import hmac
import os
import subprocess
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


PROJECT_DIR = Path(os.environ.get("PROJECT_DIR", "/project"))
LOG_FILE = Path("/tmp/media-update.log")
COMPOSE_ARGS = [
    "--env-file",
    ".env",
    "-f",
    "docker-compose.yml",
    "-f",
    "docker-compose.gpu.yml",
]
SELF_SERVICE = os.environ.get("SELF_SERVICE", "updater")

state_lock = threading.Lock()
state = {
    "running": False,
    "exit_code": "",
}


def now_iso():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def append_log(line):
    with LOG_FILE.open("a", encoding="utf-8") as log:
        log.write(line)
        if not line.endswith("\n"):
            log.write("\n")


def run_command(command, title):
    append_log(f"\n{title}\n")
    append_log(f"$ {' '.join(command)}\n")

    process = subprocess.Popen(
        command,
        cwd=PROJECT_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=os.environ.copy(),
    )

    assert process.stdout is not None
    for line in process.stdout:
        append_log(line)

    return process.wait()


def compose_command(*args):
    return ["docker", "compose", *COMPOSE_ARGS, *args]


def command_output(command):
    return subprocess.check_output(
        command,
        cwd=PROJECT_DIR,
        stderr=subprocess.STDOUT,
        text=True,
        env=os.environ.copy(),
    )


def resolve_update_services():
    configured_services = os.environ.get("UPDATE_SERVICES", "").split()
    if configured_services:
        return configured_services

    output = command_output(compose_command("config", "--services"))
    return [
        service.strip()
        for service in output.splitlines()
        if service.strip() and service.strip() != SELF_SERVICE
    ]


def run_update():
    exit_code = 0

    LOG_FILE.write_text(
        f"Media server update started at {now_iso()}\n",
        encoding="utf-8",
    )

    try:
        services = resolve_update_services()
        append_log(f"Services: {' '.join(services)}\n")

        commands = [
            (
                compose_command("config", "--quiet"),
                "Validating Docker Compose configuration...",
            ),
            (
                compose_command("pull", "--ignore-buildable", *services),
                "Pulling configured images...",
            ),
            (
                compose_command("up", "-d", "--no-deps", "--build", "--remove-orphans", *services),
                "Recreating containers...",
            ),
            (
                compose_command("ps"),
                "Container status...",
            ),
        ]

        for command, title in commands:
            exit_code = run_command(command, title)
            if exit_code != 0:
                break
    except Exception as error:
        exit_code = 1
        append_log(f"\nUpdater error: {error}\n")

    append_log(f"\nMedia server update finished at {now_iso()}\n")
    append_log(f"Exit code: {exit_code}\n")

    with state_lock:
        state["running"] = False
        state["exit_code"] = str(exit_code)


class UpdateHandler(BaseHTTPRequestHandler):
    server_version = "MediaUpdater/1.0"

    def log_message(self, format, *args):
        return

    def send_text(self, status, body, headers=None):
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(encoded)))
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(encoded)

    def authorized(self):
        token = os.environ.get("UPDATE_TOKEN", "")
        if not token:
            return True

        supplied = self.headers.get("X-Update-Token", "")
        if not hmac.compare_digest(supplied, token):
            self.send_text(401, "Update token rejected.\n")
            return False

        return True

    def do_GET(self):
        if self.path == "/health":
            self.send_text(200, "ok\n")
            return

        if self.path != "/update/status":
            self.send_text(404, "Not found.\n")
            return

        if not self.authorized():
            return

        with state_lock:
            running = state["running"]
            exit_code = state["exit_code"]

        if LOG_FILE.exists():
            lines = LOG_FILE.read_text(encoding="utf-8", errors="replace").splitlines()
            body = "\n".join(lines[-120:]) + "\n"
        else:
            body = "No update has run yet.\n"

        self.send_text(
            200,
            body,
            {
                "X-Update-Running": "true" if running else "false",
                "X-Update-Exit-Code": exit_code,
            },
        )

    def do_POST(self):
        if self.path != "/update":
            self.send_text(404, "Not found.\n")
            return

        if not self.authorized():
            return

        with state_lock:
            if state["running"]:
                self.send_text(409, "An update is already running.\n")
                return

            state["running"] = True
            state["exit_code"] = ""

        thread = threading.Thread(target=run_update, daemon=True)
        thread.start()

        self.send_text(202, "Update started.\n")


def main():
    server = ThreadingHTTPServer(("0.0.0.0", 8080), UpdateHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
