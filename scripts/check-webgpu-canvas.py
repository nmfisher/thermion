#!/usr/bin/env python3
"""Run the staged WebGPU scene test in a top-level Chromium page.

The site directory must hold thermion_dart.js/.wasm and app.js — the dart2js
output of tool/webgpu_scene_harness.dart, which hosts the same
package:test suite CI runs (test/chrome_webgpu_scene_test.dart) and POSTs
{passed, message} to /result. The page mirrors the engine host wrapper
tool/web_test_runner.dart generates (canvas + __thermionReady). A failing
(or missing) report fails the check.
"""

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
                    "--enable-unsafe-webgpu", "--enable-unsafe-swiftshader", "--use-angle=swiftshader",
                    "--use-webgpu-adapter=swiftshader", "--enable-logging=stderr",
                    f"--user-data-dir={profile}", f"http://127.0.0.1:{server.server_port}/",
                ], stdout=log, stderr=subprocess.STDOUT)
                try:
                    finished.wait(timeout=120)
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
