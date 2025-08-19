from typing import Callable, Awaitable

Scope = dict[str, object]
Receive = Callable[[], Awaitable[dict[str, object]]]
Send = Callable[[dict[str, object]], Awaitable[None]]

stream_headers = [
    (b'content-type', b'text/event-stream'),
    (b'cache-control', b'no-cache, no-transform'),
    (b'connection', b'keep-alive'),
    (b'x-accel-buffering', b'no'),
]

cors_headers = {
    (b'access-control-allow-origin', b'*'),
    (b'access-control-allow-credentials', b"true"),
    (b'access-control-allow-headers', b'*'),
    (b'access-control-allow-methods', b'*'),
}
