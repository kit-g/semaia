from dataclasses import dataclass
from typing import Any


class EmptyResponse(Exception):
    pass


@dataclass
class IncorrectSignature(Exception):
    required: list[str] = None

    def to_dict(self) -> dict[str, Any]:
        return {
            'required': self.required,
        }


class Unauthorized(Exception):
    def __str__(self):
        return 'Unauthorized'


@dataclass
class NotFound(Exception):
    path: str = None

    def __str__(self):
        return f'Not found: {self.path}'
