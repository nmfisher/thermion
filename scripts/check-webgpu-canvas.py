#!/usr/bin/env python3
"""Render the staged WebGPU scene in a top-level Chromium page."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import tempfile
from threading import Event, Thread


PAGE = """<!doctype html>
<meta charset="utf-8">
<canvas id="thermion_canvas" width="64" height="64"></canvas>
<script src="thermion_dart.js"></script>
<script>
window.finishWebGpuCheck = (passed, message) => fetch('/result', {
  method: 'POST', body: JSON.stringify({passed, message}),
});
window.__thermionReady = thermion_dart().then(module => {
  window.thermion_dart = module;
  return module;
});
</script>
<script defer src="app.js"></script>
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site", type=Path)
    parser.add_argument("--chrome", default="google-chrome")
    args = parser.parse_args()
    (args.site / "index.html").write_text(PAGE, encoding="utf-8")
    finished = Event()
    result = {}

    class Handler(SimpleHTTPRequestHandler):
        def end_headers(self):
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
            super().end_headers()

        def do_POST(self):
            if self.path != "/result":
                self.send_error(404)
                return
            result.update(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
            self.send_response(204)
            self.end_headers()
            finished.set()

    with tempfile.TemporaryDirectory(prefix="thermion-webgpu-chrome-") as profile:
        handler = partial(Handler, directory=args.site)
        with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
            Thread(target=server.serve_forever, daemon=True).start()
            log_path = Path(profile) / "chromium.log"
            with log_path.open("wb") as log:
                chrome = subprocess.Popen([
                    args.chrome, "--headless=new", "--no-sandbox", "--no-first-run",
                    "--enable-unsafe-webgpu", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                    "--use-webgpu-adapter=swiftshader", "--enable-logging=stderr",
                    f"--user-data-dir={profile}", f"http://127.0.0.1:{server.server_port}/",
                ], stdout=log, stderr=subprocess.STDOUT)
                try:
                    finished.wait(timeout=40)
                finally:
                    if chrome.poll() is None:
                        chrome.terminate()
                        try:
                            chrome.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            chrome.kill()
                            chrome.wait()
                    server.shutdown()
            print(result.get("message", "Chromium did not report a rendered frame."))
            if result.get("passed") is not True:
                print(log_path.read_text(encoding="utf-8", errors="replace")[-12000:])
                return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
