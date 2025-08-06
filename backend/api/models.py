import os
from dataclasses import dataclass, asdict
from datetime import datetime
from functools import wraps
from typing import Final, Any, Self, TypeVar, Callable

from dynamo import TypedModelWithSortableKey, Ksuid, db
from utils import snake_to_camel

from errors import NotFound

user_type: Final[str] = 'USER'
connector_type: Final[str] = 'CONNECTOR'


@dataclass
class Connector(TypedModelWithSortableKey):
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
        return {
            **self.to_connection(),
            'name': self.name,
            'inspection': self.inspection,
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
    @wraps(func)
    def wrapper(connector_id: str, user_id: str, *args, **kwargs) -> dict:
        connector = _get_connector(connector_id, user_id)
        if connector is None:
            raise NotFound(f'connector {connector_id} not found')

        return func(connector, *args, **kwargs)

    return wrapper
