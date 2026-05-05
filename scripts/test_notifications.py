#!/usr/bin/env python3
from __future__ import annotations

import inspect
import json
import importlib
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from rig_cli.main import RigHelpers
from rig_tools import notifications
rig_main = importlib.import_module("rig_cli.main")


def run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(REPO_ROOT / "scripts" / "rig.py"), *args], cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def test_osascript_command_construction() -> None:
    cmd = notifications.build_osascript_command(title='Rig "Title"', subtitle="Sub\nTitle", message='Line 1\rLine 2 \\ test')
    assert cmd[0] == "osascript"
    assert cmd[1:] == ["-e", 'display notification "Line 1 Line 2 \\\\ test" with title "Rig \\"Title\\"" subtitle "Sub Title"']


def test_sanitization_and_shell_usage() -> None:
    source = inspect.getsource(notifications.send_notification)
    assert "shell=True" not in source
    sanitized = notifications._sanitize("A\nB\rC" * 100)
    assert "\n" not in sanitized
    assert "\r" not in sanitized
    assert len(sanitized) == 200
    assert sanitized.startswith("A B C")


def test_missing_backends_report_tool_missing_cleanly() -> None:
    original_which = notifications.shutil.which
    try:
        notifications.shutil.which = lambda name: None
        osascript = notifications.send_notification(title="Rig", message="Test notification", backend="osascript")
        terminal = notifications.send_notification(title="Rig", message="Test notification", backend="terminal-notifier")
        assert osascript.status == "tool_missing"
        assert "osascript" in (osascript.error or "")
        assert terminal.status == "tool_missing"
        assert "terminal-notifier" in (terminal.error or "")
    finally:
        notifications.shutil.which = original_which


def test_notification_failure_does_not_fail_run() -> None:
    original_run = notifications.subprocess.run
    original_which = notifications.shutil.which
    try:
        notifications.shutil.which = lambda name: "/usr/bin/osascript" if name == "osascript" else None

        def fake_run(cmd, **kwargs):
            assert kwargs.get("shell") is not True
            return subprocess.CompletedProcess(cmd, 1, stdout="", stderr="simulated failure")

        notifications.subprocess.run = fake_run
        result = notifications.send_notification(title="Rig", message="Test", backend="osascript")
        assert result.status == "failed"
        assert result.error == "simulated failure"
    finally:
        notifications.subprocess.run = original_run
        notifications.shutil.which = original_which


def test_final_result_includes_notification_status() -> None:
    tmp = Path(tempfile.mkdtemp(prefix="rig-notify-test-"))
    helpers = RigHelpers(repo_root=tmp)
    original_which = rig_main.choose_backend
    original_send = rig_main.send_notification
    try:
        rig_main.choose_backend = lambda preferred=None: "none"
        rig_main.send_notification = lambda **kwargs: notifications.NotificationResult(requested=True, backend="none", status="skipped")
        helpers.notify_trigger = "finish"
        payload = {"status": "passed", "task": "task-1", "command": "rig pipeline run", "summary": {"command_summary": "ok"}}
        out = helpers._apply_notification(payload)
        assert out["notification_requested"] is True
        assert out["notification_backend"] == "none"
        assert out["notification_status"] == "skipped"
        assert out["notification_error"] is None
    finally:
        rig_main.choose_backend = original_which
        rig_main.send_notification = original_send


def test_should_notify_mappings() -> None:
    assert notifications.should_notify("finish", "passed")
    assert notifications.should_notify("finish", "failed")
    assert notifications.should_notify("finish", "known_blocked")
    assert notifications.should_notify("finish", "blocked")
    assert notifications.should_notify("finish", "ready_to_commit")
    assert notifications.should_notify("failure", "failed")
    assert not notifications.should_notify("failure", "passed")
    assert notifications.should_notify("known-blocked", "known_blocked")
    assert notifications.should_notify("blocked", "blocked")
    assert notifications.should_notify("ready", "ready_to_commit")


def test_json_mode_stays_clean_when_notification_disabled() -> None:
    result = run_cli("--json", "notify", "status")
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert "backends" in payload
    assert "notification" not in result.stdout.lower()


def test_notify_status_and_send_commands_exist() -> None:
    status = run_cli("notify", "status")
    assert status.returncode == 0, status.stderr
    payload = json.loads(status.stdout)
    assert "backends" in payload
    send = run_cli("notify", "send", "--title", "Rig", "--message", "Notification test", "--backend", "none")
    assert send.returncode == 0, send.stderr
    payload = json.loads(send.stdout)
    assert payload["notification_status"] == "skipped"


def main() -> int:
    test_osascript_command_construction()
    test_sanitization_and_shell_usage()
    test_missing_backends_report_tool_missing_cleanly()
    test_notification_failure_does_not_fail_run()
    test_final_result_includes_notification_status()
    test_should_notify_mappings()
    test_json_mode_stays_clean_when_notification_disabled()
    test_notify_status_and_send_commands_exist()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
