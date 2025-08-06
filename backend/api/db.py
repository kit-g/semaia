import hashlib
from typing import Iterator

import psycopg2
from psycopg2.extras import RealDictCursor

from models import Connector

ForeignKeyViolation = psycopg2.errors.lookup('23503')
UniqueViolation = psycopg2.errors.lookup('23505')
NotNullViolation = psycopg2.errors.lookup('23502')
DatabaseCustomException = psycopg2.errors.lookup('P0001')


def connect(config: Connector):
    return psycopg2.connect(**config.to_connection())


def _empty() -> Iterator:
    """
    empty iterator.

    :return: empty iterator placeholder.
    """
    return iter(())


def run(
        connection,
        query: str,
        params: tuple | dict = None,
        silence_errors=False,
) -> Iterator:
    """
    Runs an SQL query.

    :param connection:
    :param silence_errors: Will not raise psycopg programming errors if true
    :param query: SQL with optional parametrized parameters.
        Positional params syntax is $1, $2, etc.,
        named parameters - %(param_name)s.
        Parameters are passed as a tuple or a dict accordingly.
    :param params: A tuple of positional query parameters or a dict of named ones.
    :return: Lazy iterator of returned row dicts.
    """

    with connection.cursor(cursor_factory=RealDictCursor) as cursor:
        try:
            match params:
                case dict():
                    cursor.execute(query, params)
                case tuple():
                    prepared_query = f'Z{hashlib.md5(query.encode("utf-8")).hexdigest()}'
                    cursor.execute(f"PREPARE {prepared_query} AS {query}")
                    param_types = f' ( {", ".join(["%s"] * len(params))} ) '
                    statement = f'EXECUTE {prepared_query}{param_types}'
                    cursor.execute(statement, params)
                case None:
                    cursor.execute(query)
                case _:
                    raise TypeError('Params must be a tuple, a dict or None')

            connection.commit()
            for record in cursor:
                yield record
        except psycopg2.ProgrammingError as error:
            if silence_errors:
                return _empty()  # noqa
            raise error
        except ForeignKeyViolation as fk_error:
            raise fk_error
        except Exception as error:
            raise error
