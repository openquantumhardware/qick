#!/usr/bin/env python3

import http.server
import socketserver

PORT = 8000

socketserver.TCPServer.allow_reuse_address = True

class DummyServer(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        self.send_response(200, "OK")
        self.end_headers()

    def do_PUT(self):
        """
        path = self.translate_path(self.path)
        if path.endswith('/'):
            self.send_response(405, "Method Not Allowed")
            self.wfile.write("PUT not allowed on a directory\n".encode())
            return
        else:
            try:
                os.makedirs(os.path.dirname(path))
            except FileExistsError: pass
            length = int(self.headers['Content-Length'])
            with open(path, 'wb') as f:
                f.write(self.rfile.read(length))
        """
        self.send_response(201, "Created")
        self.end_headers()


Handler = DummyServer

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print("serving at port", PORT)
    httpd.serve_forever()
