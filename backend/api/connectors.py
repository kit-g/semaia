import json
import os
from textwrap import dedent

from dynamo import db
from utils import custom_serializer, run_query

import q as queries
from db import run, connect
from errors import EmptyResponse, IncorrectSignature
from models import user_type, connector_type, Connector, with_connector

_table = os.environ['TABLE_NAME']


def get(user_id: str) -> dict:
    """
    Fetches connectors for a given user from the database.

    This function queries a DynamoDB table to retrieve connector items for a specific user. It filters
    the results based on the user ID and the connector type. If matching connector items are found, they
    are parsed and returned. Otherwise, it returns a dictionary with a `None` value for connectors.

    :param user_id: The unique identifier for the user.
    :return: A dictionary containing a list of connectors if found, otherwise `None`.
    """
    response = db().query(
        TableName=_table,
        KeyConditionExpression=f'#PK = :PK AND begins_with(#SK, :prefix)',
        ExpressionAttributeNames={
            '#PK': 'PK',
            '#SK': 'SK',
        },
        ExpressionAttributeValues={
            ':PK': {'S': f'{user_type}#{user_id}'},
            ':prefix': {'S': connector_type},
        }
    )

    match response:
        case {'Items': items}:
            connectors = [Connector.from_item(item) for item in items]
            return {
                'connectors': [
                    each.public() for each in connectors
                ],
            }

    return {'connectors': None}


def make(request: dict, user_id: str) -> dict:
    try:
        connector = Connector.from_dict(request, user_id)
        connector.save_as_full_item_if_not_exists(table=_table)
        return {'connector': connector.to_dict()}
    except KeyError:
        raise IncorrectSignature(
            ['host', 'port', 'database', 'user', 'password'],
        )


def edit(connector_id: str, user_id: str, params: dict) -> dict:
    try:
        connector = Connector.from_dict(params, user_id)
        connector.id = connector_id
        connector.save_as_full_item(table=_table, condition='attribute_exists(PK) AND attribute_exists(SK)')
        return {'connector': connector.to_dict()}
    except KeyError:
        raise IncorrectSignature(
            ['host', 'port', 'database', 'user', 'password'],
        )


def delete(connector_id: str, user_id: str) -> dict:
    _ = db().delete_item(
        TableName=_table,
        Key=Connector.key(user_id, connector_id)
    )
    raise EmptyResponse


@with_connector
def inspect(connector: Connector, params: dict) -> dict:
    connection = connect(connector)
    match params:
        case {'type': 'trigger', 'schema': _, 'table': _, 'trigger': _} as args:
            row = _query(connection, 'trigger', dict(args))
            inspection = _make_trigger(row)
        case {'type': 'routine', 'schema': _, 'routine': _} as args:
            inspection = _query(connection, 'routine', dict(args))
        case _:
            inspection = _query(connection, 'inspect', {'schemata': None})
            connector.inspection = json.dumps(inspection)
            connector.save_attributes(table=_table, attrs=['inspection'])

    return inspection


@with_connector
def query(connector: Connector, params: dict) -> dict:
    q = params['query']
    connection = connect(connector)
    columns, rows = run_query(connection, q)
    return {
        'query': q,
        'columns': columns,
        'rows': [
            dict(zip(columns, row)) for row in rows
        ]
    }


def _query(connection, name: str, params: dict = None) -> dict:
    q = getattr(queries, name)
    return list(run(connection, q, params))[0]


def _make_trigger(row: dict) -> dict:
    match row:
        case {
            'trigger_name': trigger,
            'event_object_schema': table_schema,
            'event_object_table': table,
            'action_timing': timing,
            'event_manipulation': action,
            'action_orientation': orientation,
            'action_statement': statement
        }:
            definition = f"""
            CREATE TRIGGER {trigger}
                {timing} {action}
                ON {table_schema}.{table}
                FOR EACH {orientation}
            {statement}
            ;
            """
            return {
                'runsWhen': f'{timing} {action}',
                'triggerName': trigger,
                'executesProcedure': statement,
                'definition': dedent(definition)
            }
        case _:
            raise IncorrectSignature
