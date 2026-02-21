import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

SERVICE = os.getenv("SERVICE_NAME", "service")
PORT = int(os.getenv("PORT", "5000"))

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        hostname = socket.gethostname()
        body = f"Hello from {SERVICE} ({hostname})\n".encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', PORT), Handler)
    print(f"Serving {SERVICE} on port {PORT}")
    server.serve_forever()
