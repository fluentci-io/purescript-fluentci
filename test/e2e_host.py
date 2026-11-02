"""Run the compiled PureScript SDK against a release engine locally and over HTTP."""
import os
from pathlib import Path
import secrets
import signal
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BINARY = Path(os.environ.get("FLUENTCI_ENGINE_BIN", ROOT.parent / "fluentci-engine/target/release/fluentci-engine")).resolve()
with tempfile.TemporaryDirectory(prefix="fluentci-purs-e2e-") as directory:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    env = {k:v for k,v in os.environ.items() if not k.startswith("OTEL_")}
    env.update(FLUENTCI_RUN_TOKEN=secrets.token_urlsafe(32), FLUENTCI_TEST_SERVER=base,
               FLUENTCI_TEST_CWD=directory, FLUENTCI_TEST_ENGINE=str(BINARY))
    manager = {"Darwin":"macports", "Linux":"homebrew", "FreeBSD":"freebsd", "NetBSD":"netbsd", "OpenBSD":"openbsd"}.get(os.uname().sysname, "")
    if manager == "homebrew" and os.uname().machine != "x86_64":
        manager = ""
    fixture = Path(directory) / "fixture-package-manager"
    fixture.write_text("#!/bin/sh\nprintf '%s\\n' \"$@\" > package-args\necho fixture-installed\n")
    fixture.chmod(0o700)
    env.update(FLUENTCI_TEST_PACKAGE_MANAGER=manager, FLUENTCI_TEST_PACKAGE_EXECUTABLE=str(fixture))
    server = subprocess.Popen([str(BINARY), "serve-runs", "--listen", f"127.0.0.1:{port}", "--data-dir", directory + "/server"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 10
        while True:
            if server.poll() is not None:
                raise RuntimeError(server.stderr.read().decode())
            try:
                urllib.request.urlopen(base + "/v1/runs/missing", timeout=1)
            except urllib.error.HTTPError as error:
                if error.code == 401:
                    break
            except OSError:
                pass
            if time.monotonic() >= deadline:
                raise RuntimeError("server did not become ready")
            time.sleep(0.02)
        subprocess.run(["spago", "test"], cwd=ROOT, env=env, check=True, timeout=60)
    finally:
        if server.poll() is None:
            server.send_signal(signal.SIGINT)
            try:
                server.wait(timeout=15)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
                raise RuntimeError("server did not cleanly shut down")
        server.stderr.close()
