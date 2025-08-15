import json
from typing import Any, AsyncIterable, Mapping

from signatures import Send, cors_headers, stream_headers

_all_headers = [*stream_headers, *cors_headers]


def _encode_line(field: str, value: str) -> bytes:
    # spec: "field: value\n" (value may be empty); no CRLF, just LF
    return f"{field}: {value}\n".encode("utf-8")


def _frame(
        *,
        event: str | None,
        data: Any = None,
        id: str | None = None,
        retry_ms: int | None = None,
        comment: str | None = None,
) -> bytes:
    """
    Build an SSE frame. If `data` is not a str, it will be JSON-serialized.
    """
    out = bytearray()
    if comment is not None:
        out += _encode_line(":", comment)  # comment lines start with ':'
    if event:
        out += _encode_line("event", event)
    if id:
        out += _encode_line("id", id)
    if retry_ms is not None:
        out += _encode_line("retry", str(retry_ms))
    if data is not None:
        if not isinstance(data, str):
            data = json.dumps(data, ensure_ascii=False)
        # support multi-line payloads
        for line in data.split("\n"):
            out += _encode_line("data", line)

    out += b"\n"  # terminator
    return bytes(out)


async def start_stream(send: Send, headers: Mapping[str, str] = None, status: int = 200) -> None:
    extra = [(k.encode(), v.encode()) for k, v in (headers or {}).items()]
    await send({"type": "http.response.start", "status": status, "headers": _all_headers + extra})


async def send_event(
        send: Send,
        *,
        event: str | None,
        data: Any = None,
        id: str | None = None,
        retry_ms: int | None = None,
        comment: str | None = None,
) -> None:
    await send({
        "type": "http.response.body",
        "body": _frame(event=event, data=data, id=id, retry_ms=retry_ms, comment=comment),
        "more_body": True,
    })


async def send_comment(send: Send, text: str = "ping") -> None:
    await send_event(send, event=None, comment=text)


async def finish_stream(send: Send, *, send_done: bool = True) -> None:
    if send_done:
        await send_event(send, event="done", data={})
    await send({"type": "http.response.body", "body": b"", "more_body": False})


async def stream_iter(send: Send, chunks: AsyncIterable[Any], *, event: str = "message") -> None:
    async for chunk in chunks:
        await send_event(send, event=event, data=chunk)
