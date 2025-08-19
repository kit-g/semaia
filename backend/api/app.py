import json

import chats
import connectors
from signatures import Scope, Send, Receive
from framework import parse_qs

from errors import EmptyResponse, IncorrectSignature, NotFound, Unauthorized
from utils import camel_to_snake, custom_serializer
from framework import respond, json_body, stream

_cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Credentials": True,
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "*",
}


async def request(event: dict, receive: Receive) -> dict | None:
    match event:
        case {  # uvicorn signature
            'query_string': query_params,
        }:
            q = parse_qs(query_params)
            j = await json_body(receive)
            print(f'j: {j}')
            return {
                camel_to_snake(k): v
                for k, v in {
                    **(q or {}),
                    **j,
                }.items()
            }

        case {
            'pathParameters': path,
            'body': body,
            'queryStringParameters': query_params,
        }:
            body = json.loads(body) if body else {}
            return {
                camel_to_snake(k): v
                for k, v in {
                    **(path or {}),
                    **(query_params or {}),
                    **body,
                }.items()
            }


def user_of(event: dict) -> str:
    try:
        match event:
            case {"headers": headers}:
                for each in headers:
                    match each:
                        case (b'x-user-uid', user_id) if isinstance(user_id, bytes):  # uvicorn
                            return user_id.decode()
                raise Unauthorized
            case {'requestContext': {'authorizer': {'user': raw}}}:  # API Gateway
                return json.loads(raw)['id']
            case _:
                raise Unauthorized
    except KeyError:
        raise Unauthorized
    except Unauthorized:
        raise


async def router(event: dict[str, object], send: Send, receive: Receive) -> dict | tuple[dict | None, int]:
    match event:
        case {  # uvicorn event
                 'path': path,
                 'method': verb,
             } | {  # API proxy request signature
                 'path': path,
                 'httpMethod': verb,
             } | {  # function URL signature
                 'requestContext': {
                     'http': {
                         'path': path,
                         'method': verb,
                     }
                 }
             } if path:

            if path.startswith('/api'):
                path = path[len('/api'):]
            payload = await request(event, receive)

            user = user_of(event)
            match path.split('/'), f'{verb}'.upper():
                case ['', 'connectors'], 'GET':
                    return connectors.get(user)
                case ['', 'connectors'], 'POST':
                    return connectors.make(payload, user)
                case ['', 'connectors', connector_id], 'PUT':
                    return connectors.edit(connector_id, user, payload)
                case ['', 'connectors', connector_id], 'DELETE':
                    return connectors.delete(connector_id, user)
                case ['', 'connectors', connector_id, 'inspect'], 'GET':
                    return connectors.inspect(connector_id, user, payload)
                case ['', 'connectors', connector_id, 'query'], 'POST':
                    return connectors.query(connector_id, user, payload)

                case ['', 'connectors', connector_id, 'chats'], 'POST':
                    return await chats.start_chat(connector_id, user, send, payload, stream=True)
                case ['', 'chats', chat_id, 'messages'], 'POST':
                    return await chats.add_message(chat_id, user, send, payload, stream=True)
                case ['', 'chats'], 'GET':
                    return chats.list_chats(user)
                case ['', 'chats', chat_id], 'DELETE':
                    return chats.delete_chat(chat_id, user)
                case _:
                    raise NotFound(path)

    raise ValueError(f'Malformed request: {event}')


async def sse(send, agen):
    headers = [
        (b"content-type", b"text/event-stream"),
        (b"cache-control", b"no-cache, no-transform"),
        (b"connection", b"keep-alive"),
        (b"x-accel-buffering", b"no"),
    ]
    await send({"type": "http.response.start", "status": 200, "headers": headers})
    async for msg in agen:
        await send({"type": "http.response.body", "body": msg.encode(), "more_body": True})
    await send({"type": "http.response.body", "body": b"", "more_body": False})


async def app(scope: Scope, receive: Receive, send: Send) -> None:
    print(scope)
    try:
        r = await router(scope, send, receive)
        match r:
            case 'sse', None:
                pass  # stream is finished before
            case 'sse', agen if agen is not None:
                return await stream(send, agen)
            case body, code if isinstance(code, int) and isinstance(body, dict):
                await respond(send, body=body, status=code)
            case dict():
                await respond(send, body=r, status=200)
    except EmptyResponse:
        await respond(send, status=204)
    except IncorrectSignature as e:
        await respond(send, status=400, body=e.to_dict())
    except NotFound as e:
        await respond(send, status=404, body={'error': f'{e}'})
    except Unauthorized as e:
        await respond(send, status=401, body={'error': f'{e}'})
    except Exception as e:
        print(f'{type(e).__name__}: {e}')
        from traceback import print_exc
        print_exc()
        await respond(send, status=500, body={'error': f'{e}'})
