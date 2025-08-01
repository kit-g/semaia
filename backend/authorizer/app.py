import json
import os
from dataclasses import dataclass, asdict
from typing import Literal

import firebase_admin
from firebase_admin import credentials
from firebase_admin import auth
from firebase_admin.auth import ExpiredIdTokenError

region = os.environ['REGION']
account = os.environ['ACCOUNT']

Effect = Literal['Allow', 'Deny']

_headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
}

cred = credentials.Certificate("fb.json")
firebase_admin.initialize_app(cred)


@dataclass
class User:
    full_name: str
    id: str
    email: str
    created_at: str = None
    updated_at: str = None
    _first_name: str = None
    _last_name: str = None
    profile_picture_uri: str = None
    accepted_user_policies_at: str = None
    last_authenticated_at: str = None
    deleted_at: str = None

    @classmethod
    def from_json(cls, j: dict) -> 'User':
        return cls(
            full_name=j.get('fullName'),
            id=j.get('id'),
            created_at=j.get('createdAt'),
            updated_at=j.get('updatedAt'),
            email=j.get('email'),
            _first_name=j.get('firstName'),
            _last_name=j.get('lastName'),
            profile_picture_uri=j.get('profilePictureUri'),
            accepted_user_policies_at=j.get('acceptedUserPoliciesAt'),
            last_authenticated_at=j.get('lastAuthenticatedAt'),
            deleted_at=j.get('deletedAt')
        )

    @property
    def first_name(self) -> str | None:
        try:
            return self._first_name or self.full_name.split(' ')[0]
        except IndexError:
            return None

    @property
    def last_name(self) -> str | None:
        try:
            return self._last_name or self.full_name.split(' ')[1]
        except IndexError:
            return None


def policy(effect: Effect, api_id: str, stage: str) -> dict:
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "execute-api:Invoke",
                "Effect": effect,
                "Resource": f"arn:aws:execute-api:{region}:{account}:{api_id}/{stage}/*"
            }
        ]
    }


def allow(api_id: str, stage: str) -> dict:
    return policy(
        'Allow',
        stage=stage,
        api_id=api_id
    )


def deny(api_id: str, stage: str) -> dict:
    return policy(
        'Deny',
        stage=stage,
        api_id=api_id
    )


def handler(event: dict, _):
    try:
        print(event)

        match event:
            case {
                'requestContext': {
                    'apiId': api_id,
                    'stage': stage,
                },
                'headers': {
                    'Authorization': bearer,
                },
            } if bearer.startswith('Bearer '):

                token = bearer[len('Bearer '):]
                raw = firebase_admin.auth.verify_id_token(token)

                match raw:
                    case 200, {'data': j}:
                        user = User.from_json(j)

                        return {
                            "principalId": token,
                            "policyDocument": allow(stage=stage, api_id=api_id),
                            "context": {
                                "user": json.dumps(asdict(user)),  # noqa
                            }
                        }
                    case {
                        'email': email,
                        'email_verified': True,
                        'name': name,
                        'picture': picture,
                        'user_id': user_id,
                    }:
                        user = User(
                            full_name=name,
                            id=user_id,
                            profile_picture_uri=picture,
                            email=email,
                        )

                        doc = allow(stage=stage, api_id=api_id)

                        return {
                            "principalId": token,
                            "policyDocument": doc,
                            "context": {
                                "user": json.dumps(asdict(user)),  # noqa
                            }
                        }

                    case _:
                        return {
                            "principalId": token,
                            "policyDocument": deny(stage=stage, api_id=api_id),
                        }
            case _:
                raise Exception('Incorrect authorizer signature')
    except ExpiredIdTokenError as e:
        raise Exception(e.default_message)
    except (BaseException, Exception) as e:
        message = f'Error: {type(e)}, {repr(e)}'
        print(message)
        raise Exception('Unauthorized')

