#!/usr/bin/env python3
"""Tool mode + moderation handling checks; mock provider, no network."""

import base64
import importlib.util
import io
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import shutil
import tempfile
import threading
from contextlib import redirect_stdout
from unittest import TestCase, mock
import unittest

SCRIPTS = Path(__file__).parents[1] / "scripts"
spec = importlib.util.spec_from_file_location("psd_io", SCRIPTS / "psd_io.py")
psd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(psd)

client_spec = importlib.util.spec_from_file_location("image_client", SCRIPTS / "nana_image2.py")
client = importlib.util.module_from_spec(client_spec)
client_spec.loader.exec_module(client)


def png_bytes(width, height):
    """High-entropy PNG so the base64 payload clears the harvest threshold."""
    tmp = Path(tempfile.mkdtemp())
    try:
        state = 12345
        pixels = bytearray()
        for _ in range(width * height):
            state = (state * 1103515245 + 12345) & 0x7FFFFFFF
            pixels += bytes(((state >> 16) & 0xFF, (state >> 8) & 0xFF, state & 0xFF, 255))
        path = tmp / "x.png"
        psd.write_png(path, width, height, bytes(pixels))
        return path.read_bytes()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


B64_SMALL = base64.b64encode(png_bytes(8, 6)).decode()          # upstream "actual" size 8x6


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_args):
        pass

    def _json(self, code, doc):
        body = json.dumps(doc).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _sse(self, events):
        body = b"".join(b"data: " + json.dumps(event).encode() + b"\n\n" for event in events) + b"data: [DONE]\n\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._json(200, {"data": [{"id": name} for name in self.server.model_list]})

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length)
        self.server.requests.append(raw)
        path = self.path
        if path.endswith("/responses"):
            self._sse([
                {"type": "response.output_item.done",
                 "item": {"type": "image_generation_call", "status": "completed",
                          "model": self.server.echo_model, "size": self.server.echo_size,
                          "quality": "high", "result": B64_SMALL}},
            ])
            return
        if self.server.moderation:
            self._json(400, {"error": {"code": "moderation_blocked",
                                       "message": "Your request was rejected by the safety system."}})
            return
        self._json(200, {"model": self.server.echo_model,
                         "data": [{"b64_json": B64_SMALL, "size": self.server.echo_size}]})


class _Namespace:
    def __init__(self, **kwargs):
        self.__dict__.update(kwargs)


class ToolModeCase(TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        self.server.model_list = ["gpt-6-astra", "gpt-image-2.5-flare", "gpt-image-2.5-sunburst"]
        self.server.echo_model = "gpt-image-2.5-sunburst"
        self.server.echo_size = "auto"
        self.server.moderation = False
        self.server.requests = []
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        port = self.server.server_address[1]
        self.config = self.tmp / "config.toml"
        self.config.write_text(
            f'model_provider = "mock"\n\n[model_providers.mock]\n'
            f'base_url = "http://127.0.0.1:{port}/v1"\nexperimental_bearer_token = "not-a-secret"\n')

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def namespace(self, **kwargs):
        defaults = dict(command="generate", config=str(self.config), provider=None,
                        model="gpt-image-2.5-sunburst", prompt="a cat", size=None, quality="medium",
                        n=1, background=None, output_format="png",
                        out=str(self.tmp / "out.png"), force=True, dry_run=False,
                        stream="off", save_partials=False, image=None, mask=None,
                        fallback=None, no_fallback=False, via="images", driver_model=None)
        defaults.update(kwargs)
        return _Namespace(**defaults)

    def generate(self, **kwargs):
        """Returns (stdout, exit_code); exit_code is None on success."""
        ns = self.namespace(**kwargs)
        buffer = io.StringIO()
        code = None
        try:
            with redirect_stdout(buffer), mock.patch.dict(os.environ, {}, clear=False):
                client.generate(ns)
        except SystemExit as exc:
            code = exc.code if isinstance(exc.code, int) else 1
        return buffer.getvalue(), code


class TestToolMode(ToolModeCase):
    def test_explicit_size_is_locally_corrected(self):
        output, code = self.generate(via="tool", size="1024x1024")
        self.assertIsNone(code)
        saved = self.tmp / "out.png"
        width, height, _ = psd.read_png(saved)
        self.assertEqual((width, height), (1024, 1024))
        notes = [json.loads(line) for line in output.splitlines() if line.startswith("{")]
        correction = next((n for n in notes if "corrected" in n), None)
        self.assertIsNotNone(correction)
        self.assertEqual(correction["corrected"]["upstream_actual"], "8x6")
        # 驱动模型自动选择（列表里没有 gpt-5.2，应选 gpt-6-astra）
        body = json.loads(self.server.requests[-1])
        self.assertEqual(body["model"], "gpt-6-astra")
        self.assertEqual(body["tools"][0]["size"], "1024x1024")
        self.assertEqual(body["tool_choice"], {"type": "image_generation"})

    def test_auto_size_saves_without_correction(self):
        output, code = self.generate(via="tool", size="auto")
        self.assertIsNone(code)
        self.assertTrue((self.tmp / "out.png").exists())
        self.assertFalse([line for line in output.splitlines() if '"corrected"' in line])

    def test_edit_via_tool_sends_reference_image(self):
        source = self.tmp / "in.png"
        psd.write_png(source, 4, 4, bytes((1, 2, 3, 255)) * 16)
        ns = self.namespace(command="edit", via="tool", image=str(source),
                            out=str(self.tmp / "edited.png"))
        with redirect_stdout(io.StringIO()), mock.patch.dict(os.environ, {}, clear=False):
            client.edit(ns)
        body = json.loads(self.server.requests[-1])
        image_parts = [c for c in body["input"][0]["content"] if c["type"] == "input_image"]
        self.assertEqual(len(image_parts), 1)
        self.assertTrue(image_parts[0]["image_url"].startswith("data:image/png;base64,"))


class TestModeration(ToolModeCase):
    def test_moderation_block_is_structured_and_leaves_report(self):
        self.server.moderation = True
        output, code = self.generate()
        self.assertEqual(code, 1)
        payload = json.loads(output)
        self.assertFalse(payload["ok"])
        self.assertEqual(payload["error"]["type"], "moderation_blocked")
        report = self.tmp / "out.error.json"
        self.assertTrue(report.exists())
        doc = json.loads(report.read_text(encoding="utf-8"))
        self.assertEqual(doc["type"], "moderation_blocked")
        self.assertIn("not retried", doc["note"])

    def test_moderation_block_never_retries_with_other_model(self):
        self.server.moderation = True
        output, code = self.generate(model="gpt-image-2")   # 有可用回退目标也不许动
        self.assertEqual(code, 1)
        self.assertEqual(len(self.server.requests), 1)
        self.assertNotIn("fallback", output)


if __name__ == "__main__":
    unittest.main()
