from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import uuid
import time

# RC1 Verification Mock - Supports: /object_info, /prompt, /history, /view,
#   /upload/image, /interrupt, /free, /queue

class MockComfyUI(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default Apache-style logs; print our own
        pass

    def do_GET(self):
        if self.path == '/queue':
            self._json({"queue_running": [], "queue_pending": []})

        elif self.path.startswith('/history'):
            job_id = self.path.split('/')[-1]
            history = {
                job_id: {
                    "status": {"status_str": "success", "completed": True},
                    "outputs": {
                        "9": {
                            "images": [{"filename": "mock_image.png", "subfolder": "", "type": "output"}]
                        }
                    }
                }
            }
            self._json(history)

        elif self.path.startswith('/view'):
            # Return a minimal 1x1 valid PNG
            self.send_response(200)
            self.send_header('Content-type', 'image/png')
            self.end_headers()
            self.wfile.write(
                b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR'
                b'\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00'
                b'\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xfc\xff\xff?\x00'
                b'\x05\xfe\x02\xfe\xa4\xce\x92\x00\x00\x00\x00IEND\xaeB`\x82'
            )

        elif self.path == '/object_info':
            # Simulate the full schema that PreflightChecker expects
            object_info = {
                "ImageOnlyCheckpointLoader": {
                    "input": {
                        "required": {
                            "ckpt_name": [["svd_xt.safetensors", "svd_xt_1_1.safetensors"]]
                        }
                    }
                },
                "CheckpointLoaderSimple": {
                    "input": {
                        "required": {
                            "ckpt_name": [["sd_xl_base_1.0.safetensors", "v1-5-pruned-emaonly.safetensors"]]
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
                            "seed": ["INT", {"default": 0}],
                            "steps": ["INT", {"default": 20}]
                        }
                    }
                }
            }
            self._json(object_info)
            print("[MockComfyUI] GET /object_info → returned schema for 4 nodes")

        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length > 0:
            self.rfile.read(content_length)

        if self.path == '/prompt':
            time.sleep(0.5)  # Simulate brief processing
            prompt_id = str(uuid.uuid4())
            self._json({"prompt_id": prompt_id})
            print(f"[MockComfyUI] POST /prompt → queued job {prompt_id}")

        elif self.path == '/upload/image':
            self._json({"name": "uploaded_mock.png"})
            print("[MockComfyUI] POST /upload/image → accepted")

        elif self.path == '/interrupt':
            self.send_response(200)
            self.end_headers()
            print("[MockComfyUI] POST /interrupt → VRAM emergency stop acknowledged ✅")

        elif self.path == '/free':
            self.send_response(200)
            self.end_headers()
            print("[MockComfyUI] POST /free → VRAM cleanup acknowledged ✅")

        else:
            self.send_response(404)
            self.end_headers()

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
    print("  Listening on http://127.0.0.1:8188")
    print("  Endpoints: /object_info /prompt /history /view")
    print("             /upload/image /interrupt /free /queue")
    print("=" * 60)
    httpd.serve_forever()
