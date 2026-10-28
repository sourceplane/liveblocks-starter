#!/usr/bin/env python3
"""A stand-in for the Liveblocks REST API endpoints the site calls.

    liveblocks-api.py <port-file> <log-file> --key <secret-key>

Serves what apps/web's server actions call through @liveblocks/node:

    POST /v2/identify-user   → {"token": "<id token>"}   (authorizeLiveblocks)
    GET  /v2/rooms?…         → {"data": [], "nextCursor": null}  (the dashboard)
    GET  /v2/rooms/<id>      → 404 ROOM_NOT_FOUND          (a document page)

and refuses, as Liveblocks does (401), any request whose bearer is not the
project's secret key — so the e2e proves the Worker sends the key the deploy
handed it as a Worker secret, not merely that it sent something. Every request
is written to <log-file> as one JSON line (method, path, whether the key
matched, the body). It binds a free port on 127.0.0.1 and writes it to
<port-file>; the site is pointed at it with LIVEBLOCKS_BASE_URL.
"""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ap = argparse.ArgumentParser()
ap.add_argument("port_file")
ap.add_argument("log_file")
ap.add_argument("--key", required=True)
opts = ap.parse_args()
log = open(opts.log_file, "a", buffering=1)


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self, body=b""):
        ok = self.headers.get("authorization", "") == f"Bearer {opts.key}"
        log.write(json.dumps({"method": self.command, "path": self.path, "key": ok,
                              "body": body.decode(errors="replace")}) + "\n")
        if not ok:
            self._send(401, {"error": "UNAUTHORIZED", "message": "Invalid secret key"})
        return ok

    def do_GET(self):
        if not self._authorized():
            return
        if self.path == "/v2/rooms" or self.path.startswith("/v2/rooms?"):
            return self._send(200, {"data": [], "nextCursor": None})
        if self.path.startswith("/v2/rooms/"):
            return self._send(404, {"error": "ROOM_NOT_FOUND", "message": "Room not found"})
        return self._send(404, {"error": "NOT_FOUND"})

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("content-length") or 0))
        if not self._authorized(body):
            return
        if self.path == "/v2/identify-user":
            return self._send(200, {"token": "e2e.id.token"})
        return self._send(404, {"error": "NOT_FOUND"})

    def log_message(self, *args):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(opts.port_file, "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
