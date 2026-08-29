from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import uuid
import time

class MockComfyUI(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/queue':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"queue_running": [], "queue_pending": []}).encode())
            
        elif self.path.startswith('/history'):
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            job_id = self.path.split('/')[-1]
            
            history = {
                job_id: {
                    "status": {"status_str": "success", "completed": True},
                    "outputs": {
                        "9": {
                            "images": [{"filename": "mock_image.png"}]
                        }
                    }
                }
            }
            self.wfile.write(json.dumps(history).encode())
            
        elif self.path.startswith('/view'):
            self.send_response(200)
            self.send_header('Content-type', 'image/png')
            self.end_headers()
            self.wfile.write(b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xfc\xff\xff?\x00\x05\xfe\x02\xfe\xa4\xce\x92\x00\x00\x00\x00IEND\xaeB`\x82')
            
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length > 0:
            self.rfile.read(content_length)
            
        if self.path == '/prompt':
            # Simulate some processing time so the job runs long enough to be cancelled
            time.sleep(1)
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"prompt_id": str(uuid.uuid4())}).encode())
        elif self.path == '/upload/image':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"name": "uploaded_mock.png"}).encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server_address = ('', 8188)
    httpd = HTTPServer(server_address, MockComfyUI)
    print("Starting Mock ComfyUI on port 8188...")
    httpd.serve_forever()
