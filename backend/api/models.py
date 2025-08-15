import os
from dataclasses import dataclass
from functools import wraps
from typing import Final, Any, Self, TypeVar, Callable, Dict

from dynamo import TypedModelWithSortableKey, Ksuid, db, DynamoModel
from utils import snake_to_camel  # noqa

from errors import NotFound

user_type: Final[str] = 'USER'
connector_type: Final[str] = 'CONNECTOR'
chat_type: Final[str] = 'CHAT'
_max_rows = 250


@dataclass
class Connector(TypedModelWithSortableKey):
    """
    Represents a database connector model and manages related data.

    This class is designed to encapsulate all the necessary properties and methods
    required to manage database connection details, serialization, and key
    management for persistence. It integrates ease of data transformation between
    dictionary and object forms, supports primary and sort key generation, and
    provides public views of its data.

    :ivar host: The database host URL or address.
    :ivar port: The port number for database connection.
    :ivar username: The username used for database access.
    :ivar password: The password used for database access.
    :ivar database: The name of the connected database.
    :ivar user_id: The unique identifier of the user associated with the connector.
    :ivar inspection: Represents optional inspection-related metadata.
    :ivar name: Optional name identifier for the connector.
    """
    host: str
    port: str
    username: str
    password: str
    database: str
    user_id: str
    inspection: str = None
    name: str = None
    _id: Ksuid = None
    _pk: str = None
    _sk: str = None

    def _to_item(self) -> dict[str, Any]:
        return self.item_pk | self.item_sk | self.to_dict()

    @property
    def type(self) -> str:
        return connector_type

    @property
    def pk(self) -> str:
        return self._pk or f'{user_type}#{self.user_id}'

    @property
    def sk(self) -> str:
        return self._sk or f'{self.type}#{self._id}'

    @property
    def id(self) -> Ksuid:
        return self._id

    @id.setter
    def id(self, connector_id: str) -> None:
        self._id = Ksuid.from_base62(connector_id)

    @classmethod
    def from_dict(cls, d: dict, user_id: str) -> Self:
        return cls(
            host=d['host'],
            port=d['port'],
            username=d['user'],
            password=d['password'],
            database=d['database'],
            name=d.get('name'),
            _id=Ksuid(),
            user_id=user_id,
        )

    @classmethod
    def from_item(cls, record: dict) -> Self:
        sk = record['SK']['S']
        _id = sk.split('#')[1]
        pk = record['PK']['S']
        user_id = pk.split('#')[1]
        return cls(
            host=record['host']['S'],
            port=record['port']['N'],
            username=record['user']['S'],
            password=record['password']['S'],
            database=record['database']['S'],
            name=record.get('name', {}).get('S'),
            inspection=record.get('inspection', {}).get('S'),
            _pk=record['PK']['S'],
            _sk=sk,
            _id=_id,
            user_id=user_id,
        )

    def to_connection(self) -> dict[str, Any]:
        return {
            'host': self.host,
            'port': self.port,
            'user': self.username,
            'password': self.password,
            'database': self.database,
        }

    def to_dict(self) -> dict:
        inspection = {'inspection': self.inspection} if self.inspection else {}
        return {
            **self.to_connection(),
            'name': self.name,
            **inspection,
        }

    def public(self) -> dict:
        return self.to_dict() | {'id': self._id}

    @staticmethod
    def key(user_id: str, connector_id: str) -> dict:
        return {
            'PK': {'S': f'{user_type}#{user_id}'},
            'SK': {'S': f'{connector_type}#{connector_id}'},
        }


F = TypeVar('F', bound=Callable[..., dict])
_table = os.environ['TABLE_NAME']


@dataclass
class Message(DynamoModel):
    """
    Represents a Message entity used within a DynamoDB model.

    This class encapsulates a message and its associated response,
    along with a unique identifier (id). It provides methods for
    serialization to and from DynamoDB items, as well as support for
    formatting the data in specific structures such as LLM-compatible
    output.

    :ivar message: The content of the message.
    :ivar response: The content of the associated response.
    :ivar id: A unique identifier for the message, defaulting to
        a new Ksuid instance if not provided.
    """
    message: str
    response: str
    id: Ksuid = None

    def __post_init__(self):
        if self.id is None:
            self.id = Ksuid()

    def _to_item(self) -> Dict[str, Any]:
        return {
            'message': self.message,
            'response': self.response,
            'id': f'{self.id}',
        }

    def to_dict(self) -> dict:
        return self._to_item()

    @classmethod
    def from_item(cls, record: dict) -> Self:
        return cls(
            message=record['message']['S'],
            response=record['response']['S'],
            id=Ksuid.from_base62(record['id']['S']),
        )

    def to_llm(self) -> list[dict[str, str]]:
        return [
            {'role': 'model', 'parts': [{'text': self.response}]},
            {'role': 'user', 'parts': [{'text': self.message}]},
        ]


@dataclass
class Chat(TypedModelWithSortableKey):
    """
    Represents a chat session, encapsulating details about queries, prompts, user associations, and
    messages. This class is designed to store and manage data related to chat interactions, facilitating
    serialization and deserialization for persistence and retrieval.

    This class provides methods to manage chat messages and convert data between different formats,
    such as dictionaries and internal representations, while maintaining the association with its
    user and connector.

    :ivar initial_query: The initial query text associated with the chat session.
    :ivar initial_prompt: The initial prompt text provided during the chat session.
    :ivar connector_id: The identifier linking the chat session to a specific connector.
    :ivar user_id: The identifier of the user associated with the chat session.
    :ivar messages: A list of `Message` objects representing the communication history of the chat.
    :type messages: list[Message] or None
    """
    initial_query: str
    initial_prompt: str
    connector_id: str
    user_id: str
    messages: list[Message] = None
    _id: Ksuid = None
    _pk: str = None
    _sk: str = None

    def _to_item(self) -> dict[str, Any]:
        return self.item_pk | self.item_sk | {
            'connector_id': self.connector_id,
            'user_id': self.user_id,
            'initial_query': self.initial_query,
            'initial_prompt': self.initial_prompt,
            'messages': [
                {'M': each.to_item()} for each in self.messages
            ],
        }

    @classmethod
    def from_dict(cls, d: dict, user_id: str, connector_id: str) -> Self:
        return cls(
            initial_query=d['query'],
            initial_prompt=d['prompt'],
            connector_id=connector_id,
            user_id=user_id,
            _id=Ksuid(),
        )

    @classmethod
    def from_item(cls, record: dict) -> Self:
        sk = record['SK']['S']
        _id = sk.split('#')[1]
        pk = record['PK']['S']
        user_id = pk.split('#')[1]
        messages = record.get('messages', {}).get('L', [])
        return cls(
            _id=_id,
            _pk=pk,
            _sk=sk,
            user_id=user_id,
            initial_query=record['initial_query']['S'],
            initial_prompt=record['initial_prompt']['S'],
            connector_id=record['connector_id']['S'],
            messages=[
                Message.from_item(each['M']) for each in messages
            ]
        )

    def to_dict(self) -> dict:
        return {
            'id': self._id,
            'query': self.initial_query,
            'prompt': self.initial_prompt,
            'messages': [
                each.to_dict() for each in self.messages
            ],
        }

    @property
    def type(self) -> str:
        return chat_type

    @property
    def pk(self) -> str:
        return self._pk or f'{user_type}#{self.user_id}'

    @property
    def sk(self) -> str:
        return self._sk or f'{self.type}#{self._id}'

    @property
    def id(self) -> Ksuid:
        return self._id

    def limited_query(self) -> str:
        sanitized = self.initial_query.strip().rstrip(';')
        return f"WITH q AS ({sanitized}) SELECT * FROM q LIMIT {_max_rows};"

    def add(self, message: Message) -> None:
        if not self.messages:
            self.messages = []
        self.messages.append(message)

    @staticmethod
    def query_pk(user_id: str) -> dict:
        return {
            'PK': {'S': f'{user_type}#{user_id}'},
        }

    @staticmethod
    def key(user_id: str, chat_id: str) -> dict:
        return {
            **Chat.query_pk(user_id),
            'SK': {'S': f'{chat_type}#{chat_id}'},
        }

    def to_history(self) -> list[dict[str, str]]:
        messages = sorted(self.messages or [], key=lambda m: m.id)
        return [
            part for message in messages
            for part in message.to_llm()
        ]


def _get_connector(connector_id: str, user_id: str) -> Connector | None:
    response = db().get_item(
        TableName=_table,
        Key=Connector.key(user_id, connector_id)
    )
    match response:
        case {'Item': item}:
            return Connector.from_item(item)
    return None


def with_connector(func: F) -> F:
    """
    A decorator that wraps a function to provide a connector object to it. The
    decorator retrieves a connector using the given connector ID and user ID,
    and passes the connector as the first argument to the decorated function.
    If the connector does not exist, a NotFound exception is raised.

    :param func: The function to be wrapped by the decorator. It must accept
                 the connector object as its first argument, followed by
                 its original parameters.
    :return: The wrapped function that provides a connector as the first argument.
    """
    @wraps(func)
    def wrapper(connector_id: str, user_id: str, *args, **kwargs) -> dict:
        connector = _get_connector(connector_id, user_id)
        if connector is None:
            raise NotFound(f'connector {connector_id} not found')

        return func(connector, *args, **kwargs)

    return wrapper


def _get_chat(chat_id: str, user_id: str) -> Chat | None:
    response = db().get_item(
        TableName=_table,
        Key=Chat.key(user_id, chat_id)
    )
    match response:
        case {'Item': item}:
            return Chat.from_item(item)
    return None


def with_chat(func: F) -> F:
    """
    A decorator function that provides the fetched chat object as an argument to the
    wrapped function. It ensures the chat object exists before invoking the wrapped
    function and raises an error if the chat object is not found.

    :param func: The function to be wrapped by the decorator.
    :raises NotFound: If the chat object could not be found for the provided `chat_id`.
    :return: The wrapped function that will be called with the fetched chat object
             as its first argument.
    """
    @wraps(func)
    def wrapper(chat_id: str, user_id: str, *args, **kwargs) -> dict:
        chat = _get_chat(chat_id, user_id)
        if chat is None:
            raise NotFound(f'Chat {chat_id} not found')
        return func(chat, *args, **kwargs)

    return wrapper
