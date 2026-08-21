#!/usr/bin/env python3
"""Local preview server for `make serve`, with caching disabled.

`python3 -m http.server` sends no `Cache-Control` and no `ETag` — only
`Last-Modified`. With no explicit freshness directive, browsers fall back to the
heuristic in RFC 9111 and treat a response as fresh for roughly 10% of its age
at fetch time. Because docs/ is only rebuilt when something changes, a figure
last built weeks ago is served with a weeks-old `Last-Modified`, so the browser
caches it for days and never revalidates. Replacing the file in src/, rebuilding,
even `make clean` — none of it can reach into the browser's disk cache, so the
page goes on showing the old asset while the server is happily handing out the
new one. This actually happened with src/images/fig*.svg.

Two headers fix it, and both are needed:

- `Cache-Control: no-store` forbids storing the response at all, which kills the
  heuristic and the in-memory cache a soft reload would otherwise reuse.
- Dropping `Last-Modified` (and refusing to honor `If-Modified-Since`) means a
  browser holding a stale entry from before this server existed cannot get a 304
  that revives it.

Stdlib only, and deliberately invoked as plain `python3` rather than `uv run`:
the Makefile backgrounds this process and kills it by PID on exit, and going
through `uv run` would put a parent process on that PID and risk orphaning the
server on the port.
"""

import argparse
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler


class NoCacheHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        # SimpleHTTPRequestHandler answers 304 when this header is present and
        # the file is older. A stale entry must never be revived here.
        # `del` on an email.message.Message is a no-op when the header is
        # absent; replace_header() would raise KeyError.
        del self.headers["If-Modified-Since"]
        del self.headers["If-None-Match"]
        return super().send_head()

    def send_header(self, keyword, value):
        if keyword.lower() == "last-modified":
            return
        super().send_header(keyword, value)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--directory", required=True, help="document root to serve")
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--bind", default="localhost")
    args = ap.parse_args()

    handler = partial(NoCacheHandler, directory=args.directory)
    server = HTTPServer((args.bind, args.port), handler)
    host, port = server.server_address[:2]
    # flush=True: stdout is block-buffered when make redirects it, and the
    # banner is worthless if it only lands after the server is killed.
    print(f"Serving {args.directory} at http://{args.bind}:{port}/ (caching disabled)", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
