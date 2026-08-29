"""
Noema RC1 Verification — Mock ComfyUI Server
Supports:
  GET  /queue          → empty queue
  GET  /history/<id>  → completed job with mock image
  GET  /view          → returns a 512×512 RGB PNG (valid for FFmpeg)
  GET  /object_info   → ComfyUI node schema for PreflightChecker
  POST /prompt        → queues a job, returns prompt_id
  POST /upload/image  → accepts image upload
  POST /interrupt     → VRAM emergency stop
  POST /free          → VRAM cleanup
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import uuid
import io

try:
    from PIL import Image as PILImage
    def _make_png_512():
        img = PILImage.new('RGB', (512, 512))
        pixels = img.load()
        for i in range(512):
            for j in range(512):
                pixels[i, j] = (i // 2, j // 2, 100 + (i + j) % 100)
        buf = io.BytesIO()
        img.save(buf, format='PNG')
        return buf.getvalue()
    _MOCK_PNG = _make_png_512()
    print(f"[MockComfyUI] Generated 512×512 mock PNG ({len(_MOCK_PNG)} bytes)")
except ImportError:
    # Fallback: minimal valid 8×8 PNG generated via struct
    import struct, zlib
    def _png_chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    def _make_png_8x8():
        sig = b'\x89PNG\r\n\x1a\n'
        ihdr_data = struct.pack('>IIBBBBB', 512, 512, 8, 2, 0, 0, 0)
        ihdr = _png_chunk(b'IHDR', ihdr_data)
        raw_row = b'\x00' + b'\xff\x00\x00' * 512  # filter byte + RGB pixels
        raw = raw_row * 512
        idat = _png_chunk(b'IDAT', zlib.compress(raw))
        iend = _png_chunk(b'IEND', b'')
        return sig + ihdr + idat + iend

    _MOCK_PNG = _make_png_8x8()
    print(f"[MockComfyUI] PIL not available, using struct-generated PNG ({len(_MOCK_PNG)} bytes)")


class MockComfyUI(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress Apache-style access logs

    # ── GET ──────────────────────────────────────────────────────────────────
    def do_GET(self):
        if self.path == '/queue':
            self._json({"queue_running": [], "queue_pending": []})

        elif self.path.startswith('/history'):
            job_id = self.path.rstrip('/').split('/')[-1]
            self._json({
                job_id: {
                    "status": {"status_str": "success", "completed": True},
                    "outputs": {
                        "9": {
                            "images": [{"filename": "mock_output.png",
                                        "subfolder": "",
                                        "type": "output"}]
                        }
                    }
                }
            })

        elif self.path.startswith('/view'):
            # Return a real 512×512 PNG — valid for FFmpeg video compilation
            self.send_response(200)
            self.send_header('Content-type', 'image/png')
            self.send_header('Content-Length', str(len(_MOCK_PNG)))
            self.end_headers()
            self.wfile.write(_MOCK_PNG)

        elif self.path == '/object_info':
            object_info = {
                "ImageOnlyCheckpointLoader": {
                    "input": {
                        "required": {
                            "ckpt_name": [["svd_xt.safetensors",
                                           "svd_xt_1_1.safetensors"]]
                        }
                    }
                },
                "CheckpointLoaderSimple": {
                    "input": {
                        "required": {
                            "ckpt_name": [["sd_xl_base_1.0.safetensors",
                                           "v1-5-pruned-emaonly.safetensors"]]
                        }
                    }
                },
                "IPAdapterUnifiedLoader": {
                    "input": {
                        "required": {
                            "preset": [["LIGHT - SDXL", "PLUS (high strength)"]]
                        }
                    }
                },
                "KSampler": {
                    "input": {
                        "required": {
                            "model": ["MODEL"],
                            "seed":  ["INT", {"default": 0}],
                            "steps": ["INT", {"default": 20}],
                        }
                    }
                }
            }
            self._json(object_info)
            print("[MockComfyUI] GET /object_info → schema returned")

        else:
            self.send_response(404)
            self.end_headers()

    # ── POST ─────────────────────────────────────────────────────────────────
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length > 0:
            self.rfile.read(content_length)

        if self.path == '/prompt':
            prompt_id = str(uuid.uuid4())
            self._json({"prompt_id": prompt_id})
            print(f"[MockComfyUI] POST /prompt → queued {prompt_id[:8]}…")

        elif self.path == '/upload/image':
            self._json({"name": "uploaded_mock.png"})

        elif self.path == '/interrupt':
            self.send_response(200)
            self.end_headers()
            print("[MockComfyUI] POST /interrupt → VRAM emergency stop ✅")

        elif self.path == '/free':
            self.send_response(200)
            self.end_headers()
            print("[MockComfyUI] POST /free → VRAM cleanup ✅")

        else:
            self.send_response(404)
            self.end_headers()

    # ── Helper ───────────────────────────────────────────────────────────────
    def _json(self, data):
        body = json.dumps(data).encode()
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == '__main__':
    server_address = ('', 8188)
    httpd = HTTPServer(server_address, MockComfyUI)
    print("=" * 60)
    print("  Noema RC1 Verification — Mock ComfyUI Server")
    print("  http://127.0.0.1:8188")
    print("  PNG: 512×512 (valid for FFmpeg compilation)")
    print("=" * 60)
    httpd.serve_forever()
