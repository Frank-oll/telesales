import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
import http.server
import socketserver

PORT = 4173
Handler = http.server.SimpleHTTPRequestHandler
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Serving at http://localhost:{PORT}")
    httpd.serve_forever()
