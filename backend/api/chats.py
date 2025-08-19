import json
import os
import random
import string
import time
from typing import AsyncIterator

from dynamo import db

import llm
import prompts
from utils import custom_serializer, run_query  # noqa

from sse import send_event, finish_stream, start_stream
from signatures import Send
from framework import run_blocking
from errors import EmptyResponse
from models import Chat, Connector, Message, with_connector, with_chat, chat_type
from db import connect

_table = os.environ['TABLE_NAME']


@with_connector
async def start_chat(
        connector: Connector,
        send: Send,
        params: dict,
        stream: bool,
) -> tuple[str, AsyncIterator[str] | None] | dict:
    await start_stream(send)

    chat = Chat.from_dict(params, connector.user_id, f'{connector.id}')
    await send_event(send, event="stored", data={"chat_id": f'{chat.id}'})

    connection = connect(connector)
    results = run_query(connection, chat.limited_query())

    chat.query_results = results

    prompt = prompts.initial_prompt.format(
        prompt=chat.initial_prompt,
        data=json.dumps(results, indent=2, default=custom_serializer)
    )

    parts: list[str] = []

    try:
        if stream:
            def s():
                return llm.stream(
                    prompt=prompt,
                    history=chat.to_history(),
                )

            async def on_complete(text: str) -> None:
                m = Message(message=chat.initial_prompt, response=text)
                chat.add(m)
                await run_blocking(lambda: chat.save_as_full_item_if_not_exists(table=_table))

            for chunk in s():
                parts.append(chunk)
                await send_event(send, event="token", data={"t": chunk})

            await on_complete("".join(parts))

            return 'sse', None
    except Exception as e:
        await send_event(send, event="error", data={"message": str(e)})
    finally:
        await finish_stream(send)

    response = llm.call(prompt=prompt)
    first_message = Message(
        message=chat.initial_prompt,
        response=response,
    )
    chat.add(first_message)
    chat.save_as_full_item_if_not_exists(table=_table)
    return chat.to_dict()


@with_chat
async def add_message(
        chat: Chat,
        send: Send,
        params: dict,
        stream: bool,
) -> tuple[str, AsyncIterator[str] | None] | dict:
    """
    :param chat: Chat we're sending a message to.
    :param send: Callable function to send real-time updates to the client.
    :param params: Request body
    :param stream: Whether to stream the response or not
    :return: Either a nullable iterator of strings or None, if `stream` is True and all messages were sent.
        Otherwise, a regular Message JSON object is returned.
    """
    follow_up = params['message']
    await start_stream(send)

    parts: list[str] = []

    if stream:
        try:
            def s():
                return llm.stream(
                    prompt=follow_up,
                    history=chat.to_history(),
                )

            async def on_complete(text: str) -> None:
                m = Message(message=follow_up, response=text)
                chat.add(m)
                await run_blocking(lambda: _append_message(chat, m))

            for chunk in s():
                parts.append(chunk)
                await send_event(send, event="token", data={"t": chunk})

            await on_complete("".join(parts))

            return "sse", None
        except Exception as e:
            await send_event(send, event="error", data={"message": str(e)})
        finally:
            await finish_stream(send)

    full_text = "".join(llm.stream(prompt=follow_up, history=chat.to_history()))
    message = Message(message=follow_up, response=full_text)
    chat.add(message)
    _append_message(chat, message)
    return message.to_dict()


def list_chats(user_id: str) -> dict:
    response = db().query(
        TableName=_table,
        KeyConditionExpression=f'#PK = :PK AND begins_with(#SK, :prefix)',
        ExpressionAttributeNames={
            '#PK': 'PK',
            '#SK': 'SK',
        },
        ExpressionAttributeValues={
            **Chat.query_pk(user_id),
            ':prefix': {'S': chat_type},
        }
    )

    match response:
        case {'Items': items}:
            chats = [Chat.from_item(item).to_dict() for item in items]
            return {'chats': chats}

    return {'chats': None}


def delete_chat(chat_id: str, user_id: str):
    _ = db().delete_item(
        TableName=_table,
        Key=Chat.key(user_id, chat_id)
    )
    raise EmptyResponse


def _append_message(chat: Chat, message: Message) -> dict:
    return db().update_item(
        TableName=_table,
        Key=chat.primary_key,
        UpdateExpression='SET #messages = list_append(if_not_exists(#messages, :empty), :message)',
        ExpressionAttributeNames={
            '#messages': 'messages',
        },
        ExpressionAttributeValues={
            ':message': {'L': [{'M': message.to_item()}]},
            ':empty': {'L': []},
        }
    )
