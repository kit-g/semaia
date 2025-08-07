import json

import connectors
from errors import EmptyResponse, IncorrectSignature, NotFound, Unauthorized
from utils import camel_to_snake, custom_serializer

_cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Credentials": True,
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "*",
}


def response(status: int = 200, serializer=None, body=None) -> dict:
    match body:
        case d, code if isinstance(code, int) and isinstance(d, dict):
            status = code
            body = d
    payload = {'body': json.dumps(body, default=serializer)} if body else {}
    return {
        'statusCode': status,
        'headers': _cors,
        **payload,
    }


def request(event: dict) -> dict | None:
    """
    Merges all params in the HTTP request
    into a single dictionary.
    Names in that dictionary will be in snake case.

    :param event: API Gateway event
    :return: path, body, and query params merged into a single dict
    """
    match event:
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
    return None


def user_of(event: dict) -> str:
    try:
        match event:
            case {'requestContext': {'authorizer': {'user': raw}}}:
                return json.loads(raw)['id']
            case _:
                raise Unauthorized
    except:
        raise Unauthorized


def router(event: dict) -> dict | tuple[dict | None, int]:
    match event:
        case {
            'path': path,
            'httpMethod': verb,
        } if path:
            payload = request(event)
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

                case _:
                    raise NotFound(path)

    raise ValueError('Malformed request')


def handler(event: dict, _):
    print(event)

    try:
        return response(
            body=router(event),
            serializer=custom_serializer,
        )
    except EmptyResponse:
        return response(status=204)
    except IncorrectSignature as e:
        return response(
            status=400,
            body=e.to_dict(),
        )
    except NotFound as e:
        return response(
            status=404,
            body={'error': f'{e}'},
        )
    except Unauthorized as e:
        return response(
            status=401,
            body={'error': f'{e}'},
        )
    except Exception as e:
        return response(
            status=500,
            body={'error': f'{e}'},
        )


ev = {'resource': '/{proxy+}', 'path': '/connectors/30h7fsBC8bI8DK6CtM7t8j8CA3m/chats', 'httpMethod': 'POST',
      'headers': {'Accept': 'application/json', 'Accept-Encoding': 'gzip',
                  'Authorization': 'Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IjJiN2JhZmIyZjEwY2FlMmIxZjA3ZjM4MTZjNTQyMmJlY2NhNWMyMjMiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiS2l0IEdlcmFzaW1vdiIsInBpY3R1cmUiOiJodHRwczovL2xoMy5nb29nbGV1c2VyY29udGVudC5jb20vYS9BQ2c4b2NJdGpYeHJPUVFaOWdmRm9kM1ZMdmMxSFBmdTlVYTNuU0tCQ1FrMkN2c3AyR2lTVGU0PXM5Ni1jIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL3NlbWFpYSIsImF1ZCI6InNlbWFpYSIsImF1dGhfdGltZSI6MTc1NDAyNzQ1OCwidXNlcl9pZCI6IjFUNVc2eURkQTBQenRaYWswbDc4blB6RVZJSTIiLCJzdWIiOiIxVDVXNnlEZEEwUHp0WmFrMGw3OG5QekVWSUkyIiwiaWF0IjoxNzU0NDI4NzIyLCJleHAiOjE3NTQ0MzIzMjIsImVtYWlsIjoiZ2VyYXNpbW92a2l0QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJmaXJlYmFzZSI6eyJpZGVudGl0aWVzIjp7Imdvb2dsZS5jb20iOlsiMTE0MjMwNjEzODc0NzUzODYwMTU0Il0sImVtYWlsIjpbImdlcmFzaW1vdmtpdEBnbWFpbC5jb20iXX0sInNpZ25faW5fcHJvdmlkZXIiOiJnb29nbGUuY29tIn19.MpCJoGfIyglrTZ59ssIiOxFJYL2eeKj3_nTbvgVe74gvsgxzmXGw34CxBCOaU_Mf86v3itRYHeE5VuWHalj5VvrW_OWuaDs7mMqsHpo99zM724YuUuFfgY6Z1YgGfNQ-4QgEiWlngHo-ORQFFiQXszDt0_s9mNMKRHzUaL4AO_KQJ1hRKs-KcMcv509d5XB0qmM2LmoVmV4k1eL43j-AeivifAO-huQQgF7idy2kLuY3gkBho-VzOCv2Loh9nIYMq5rJBQRNMKvsZ0ZY1uMRtAJ46b8N3VOA2uFS244mT3VuWhRA2hHmHEJ0f1cRUFrt_mPaVxFcfFe0ThZXXB7x6w',
                  'CloudFront-Forwarded-Proto': 'https', 'CloudFront-Is-Desktop-Viewer': 'true',
                  'CloudFront-Is-Mobile-Viewer': 'false', 'CloudFront-Is-SmartTV-Viewer': 'false',
                  'CloudFront-Is-Tablet-Viewer': 'false', 'CloudFront-Viewer-ASN': '812',
                  'CloudFront-Viewer-Country': 'CA', 'content-type': 'application/json', 'Host': 'api.semaia.awry.me',
                  'User-Agent': 'Dart/3.8 (dart:io)',
                  'Via': '1.1 94703ff6f88fa098310f25ad977e6604.cloudfront.net (CloudFront)',
                  'X-Amz-Cf-Id': '6PbTFumYFJYkF0iV83ANG1EUkMFaOi6hYfudl2AJQyEnvMzyzw5p3w==',
                  'X-Amzn-Trace-Id': 'Root=1-68927d75-280ed06b36e2f93f1b7bfd12',
                  'X-Forwarded-For': '173.35.0.74, 15.158.17.47', 'X-Forwarded-Port': '443',
                  'X-Forwarded-Proto': 'https'},
      'multiValueHeaders': {'Accept': ['application/json'], 'Accept-Encoding': ['gzip'], 'Authorization': [
          'Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IjJiN2JhZmIyZjEwY2FlMmIxZjA3ZjM4MTZjNTQyMmJlY2NhNWMyMjMiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiS2l0IEdlcmFzaW1vdiIsInBpY3R1cmUiOiJodHRwczovL2xoMy5nb29nbGV1c2VyY29udGVudC5jb20vYS9BQ2c4b2NJdGpYeHJPUVFaOWdmRm9kM1ZMdmMxSFBmdTlVYTNuU0tCQ1FrMkN2c3AyR2lTVGU0PXM5Ni1jIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL3NlbWFpYSIsImF1ZCI6InNlbWFpYSIsImF1dGhfdGltZSI6MTc1NDAyNzQ1OCwidXNlcl9pZCI6IjFUNVc2eURkQTBQenRaYWswbDc4blB6RVZJSTIiLCJzdWIiOiIxVDVXNnlEZEEwUHp0WmFrMGw3OG5QekVWSUkyIiwiaWF0IjoxNzU0NDI4NzIyLCJleHAiOjE3NTQ0MzIzMjIsImVtYWlsIjoiZ2VyYXNpbW92a2l0QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJmaXJlYmFzZSI6eyJpZGVudGl0aWVzIjp7Imdvb2dsZS5jb20iOlsiMTE0MjMwNjEzODc0NzUzODYwMTU0Il0sImVtYWlsIjpbImdlcmFzaW1vdmtpdEBnbWFpbC5jb20iXX0sInNpZ25faW5fcHJvdmlkZXIiOiJnb29nbGUuY29tIn19.MpCJoGfIyglrTZ59ssIiOxFJYL2eeKj3_nTbvgVe74gvsgxzmXGw34CxBCOaU_Mf86v3itRYHeE5VuWHalj5VvrW_OWuaDs7mMqsHpo99zM724YuUuFfgY6Z1YgGfNQ-4QgEiWlngHo-ORQFFiQXszDt0_s9mNMKRHzUaL4AO_KQJ1hRKs-KcMcv509d5XB0qmM2LmoVmV4k1eL43j-AeivifAO-huQQgF7idy2kLuY3gkBho-VzOCv2Loh9nIYMq5rJBQRNMKvsZ0ZY1uMRtAJ46b8N3VOA2uFS244mT3VuWhRA2hHmHEJ0f1cRUFrt_mPaVxFcfFe0ThZXXB7x6w'],
                            'CloudFront-Forwarded-Proto': ['https'], 'CloudFront-Is-Desktop-Viewer': ['true'],
                            'CloudFront-Is-Mobile-Viewer': ['false'], 'CloudFront-Is-SmartTV-Viewer': ['false'],
                            'CloudFront-Is-Tablet-Viewer': ['false'], 'CloudFront-Viewer-ASN': ['812'],
                            'CloudFront-Viewer-Country': ['CA'], 'content-type': ['application/json'],
                            'Host': ['api.semaia.awry.me'], 'User-Agent': ['Dart/3.8 (dart:io)'],
                            'Via': ['1.1 94703ff6f88fa098310f25ad977e6604.cloudfront.net (CloudFront)'],
                            'X-Amz-Cf-Id': ['6PbTFumYFJYkF0iV83ANG1EUkMFaOi6hYfudl2AJQyEnvMzyzw5p3w=='],
                            'X-Amzn-Trace-Id': ['Root=1-68927d75-280ed06b36e2f93f1b7bfd12'],
                            'X-Forwarded-For': ['173.35.0.74, 15.158.17.47'], 'X-Forwarded-Port': ['443'],
                            'X-Forwarded-Proto': ['https']}, 'queryStringParameters': None,
      'multiValueQueryStringParameters': None,
      'pathParameters': {'proxy': 'connectors/30h7fsBC8bI8DK6CtM7t8j8CA3m/inspect'}, 'stageVariables': None,
      'requestContext': {'resourceId': 'ronoty', 'authorizer': {
          'principalId': 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjJiN2JhZmIyZjEwY2FlMmIxZjA3ZjM4MTZjNTQyMmJlY2NhNWMyMjMiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiS2l0IEdlcmFzaW1vdiIsInBpY3R1cmUiOiJodHRwczovL2xoMy5nb29nbGV1c2VyY29udGVudC5jb20vYS9BQ2c4b2NJdGpYeHJPUVFaOWdmRm9kM1ZMdmMxSFBmdTlVYTNuU0tCQ1FrMkN2c3AyR2lTVGU0PXM5Ni1jIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL3NlbWFpYSIsImF1ZCI6InNlbWFpYSIsImF1dGhfdGltZSI6MTc1NDAyNzQ1OCwidXNlcl9pZCI6IjFUNVc2eURkQTBQenRaYWswbDc4blB6RVZJSTIiLCJzdWIiOiIxVDVXNnlEZEEwUHp0WmFrMGw3OG5QekVWSUkyIiwiaWF0IjoxNzU0NDI4NzIyLCJleHAiOjE3NTQ0MzIzMjIsImVtYWlsIjoiZ2VyYXNpbW92a2l0QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJmaXJlYmFzZSI6eyJpZGVudGl0aWVzIjp7Imdvb2dsZS5jb20iOlsiMTE0MjMwNjEzODc0NzUzODYwMTU0Il0sImVtYWlsIjpbImdlcmFzaW1vdmtpdEBnbWFpbC5jb20iXX0sInNpZ25faW5fcHJvdmlkZXIiOiJnb29nbGUuY29tIn19.MpCJoGfIyglrTZ59ssIiOxFJYL2eeKj3_nTbvgVe74gvsgxzmXGw34CxBCOaU_Mf86v3itRYHeE5VuWHalj5VvrW_OWuaDs7mMqsHpo99zM724YuUuFfgY6Z1YgGfNQ-4QgEiWlngHo-ORQFFiQXszDt0_s9mNMKRHzUaL4AO_KQJ1hRKs-KcMcv509d5XB0qmM2LmoVmV4k1eL43j-AeivifAO-huQQgF7idy2kLuY3gkBho-VzOCv2Loh9nIYMq5rJBQRNMKvsZ0ZY1uMRtAJ46b8N3VOA2uFS244mT3VuWhRA2hHmHEJ0f1cRUFrt_mPaVxFcfFe0ThZXXB7x6w',
          'integrationLatency': 0,
          'user': '{"full_name": "Kit Gerasimov", "id": "1T5W6yDdA0PztZak0l78nPzEVII2", "email": "gerasimovkit@gmail.com", "created_at": null, "updated_at": null, "_first_name": null, "_last_name": null, "profile_picture_uri": "https://lh3.googleusercontent.com/a/ACg8ocItjXxrOQQZ9gfFod3VLvc1HPfu9Ua3nSKBCQk2Cvsp2GiSTe4=s96-c", "accepted_user_policies_at": null, "last_authenticated_at": null, "deleted_at": null}'},
                         'resourcePath': '/{proxy+}', 'httpMethod': 'GET', 'extendedRequestId': 'O2iKWFxqYosEdng=',
                         'requestTime': '05/Aug/2025:21:53:57 +0000',
                         'path': '/connectors/30h7fsBC8bI8DK6CtM7t8j8CA3m/inspect', 'accountId': '583168578067',
                         'protocol': 'HTTP/1.1', 'stage': 'v1', 'domainPrefix': 'api',
                         'requestTimeEpoch': 1754430837001, 'requestId': '10b3fc34-b645-48c9-af84-06c229e116ea',
                         'identity': {'cognitoIdentityPoolId': None, 'accountId': None, 'cognitoIdentityId': None,
                                      'caller': None, 'sourceIp': '173.35.0.74', 'principalOrgId': None,
                                      'accessKey': None, 'cognitoAuthenticationType': None,
                                      'cognitoAuthenticationProvider': None, 'userArn': None,
                                      'userAgent': 'Dart/3.8 (dart:io)', 'user': None},
                         'domainName': 'api.semaia.awry.me', 'deploymentId': 'hwdfg5', 'apiId': 'e8ewylvni6'},
      'body': '{"query": "SELECT * FROM notes;", "prompt": "Describe this table on high-level"}', 'isBase64Encoded': False}

if __name__ == '__main__':
    # handler(ev, 1)
    pass
