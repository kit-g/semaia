import json
from typing import Callable, Awaitable, Mapping, AsyncIterable, Any
from urllib.parse import parse_qs as _parse_qs

Scope = dict[str, object]
Receive = Callable[[], Awaitable[dict[str, object]]]
Send = Callable[[dict[str, object]], Awaitable[None]]


async def respond(send: Send, status: int = 200, body: Mapping = None, headers: Mapping = None) -> None:
    """
    Send an HTTP response with a JSON payload. The HTTP response can include a custom
    status code, headers, and a JSON object as the response body. By default, it sets
    content type as 'application/json', disables caching, and enforces CORS headers
    for common HTTP methods and authorization/content-type headers.

    :param send: An ASGI send function used for sending HTTP response events.
    :param status: HTTP status code for the response. Defaults to 200.
    :param body: A dictionary or mapping to serialize into a JSON payload. Defaults to an
        empty dictionary.
    :param headers: A dictionary or mapping of additional headers to include in the response.
        The headers' keys and values will be encoded as bytes.
    :return: None
    """
    payload = json.dumps(body or {}).encode()
    if headers is None:
        headers = {}
    base = [
        (b'content-type', b'application/json'),
        (b'cache-control', b'no-store'),
        (b'access-control-allow-origin', b'*'),
        (b'access-control-allow-headers', b'authorization,content-type'),
        (b'access-control-allow-methods', b'GET,POST,PUT,DELETE,OPTIONS'),
        *((k.encode(), v.encode()) for k, v in headers.items()),
    ]
    await send({'type': 'http.response.start', 'status': status, 'headers': base})
    await send({'type': 'http.response.body', 'body': payload})


async def stream(send: Send, events: AsyncIterable[str]) -> None:
    """
    Asynchronous function that streams Server-Sent Events (SSE) to a client. The function
    sends HTTP headers required for establishing an SSE connection, and iteratively transmits
    data from the given asynchronous iterable of events. Each event is sent as a new SSE
    message, maintaining the connection until the iterable of events is exhausted.

    :param send: A callable for sending messages to the client in ASGI format.
    :param events: An asynchronous iterable of strings representing the messages to be
        sent to the client as SSE events.
    :return: None
    """
    headers = [
        (b'content-type', b'text/event-stream'),
        (b'cache-control', b'no-cache, no-transform'),
        (b'connection', b'keep-alive'),
        (b'x-accel-buffering', b'no'),
    ]
    await send({'type': 'http.response.start', 'status': 200, 'headers': headers})

    async for each in events:
        await send({'type': 'http.response.body', 'body': each.encode(), 'more_body': True})

    await send({'type': 'http.response.body', 'body': b'', 'more_body': False})


def parse_qs(raw: bytes) -> dict[str, str | list[str]]:
    """
    Parse query string bytes into a dict.
    Values are lists if there are repeated keys.
    """
    qs = _parse_qs(raw.decode('utf-8'))
    return {k: v if len(v) > 1 else v[0] for k, v in qs.items()}


async def json_body(receive: Receive) -> dict[str, Any]:
    """
    Parses the JSON body of an HTTP request received asynchronously.

    This function processes incoming HTTP request messages through the
    `receive` callable. It accumulates the body content until no more
    data is available. If the body is empty or an error occurs while
    decoding the content, an empty dictionary is returned. Otherwise,
    it attempts to decode the accumulated body as a JSON object and
    returns it.

    :param receive: An asynchronous callable that retrieves HTTP request
        messages. Each message is expected to be a dictionary containing
        a "type" (str) and optionally "body" (bytes) and "more_body"
        (bool) keys.
    :return: A dictionary representing the parsed JSON body of the HTTP
        request. Returns an empty dictionary if the request body is empty
        or if a decoding error occurs.
    """
    body = b""
    more = True
    while more:
        msg = await receive()
        if msg["type"] != "http.request":
            break
        if b := msg.get("body"):
            body += b
        more = msg.get("more_body", False)
    if not body:
        return {}
    try:
        return json.loads(body.decode("utf-8"))
    except Exception:
        return {}
