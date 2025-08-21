## Backend README

### Overview
- This backend implements a lightweight, ad‑hoc ASGI application that can run locally with Uvicorn and deploy serverlessly to AWS Lambda with response streaming enabled.
- It exposes a streaming API using Server‑Sent Events (SSE) for real‑time token delivery from LLM calls and other long‑running tasks.
- The code purposefully avoids heavy frameworks. A tiny internal framework provides just the primitives needed for JSON responses, SSE streaming, and request parsing.

### Key components
- ASGI entrypoint: backend/api/app.py
  - app(scope, receive, send): Main ASGI callable.
  - router(...): Simple pattern‑matching router that supports multiple invocation signatures (Uvicorn local, Lambda Function URL, and API Gateway‑style proxy events) and trims a leading /api prefix when requests are fronted by CloudFront.
  - request(...): Normalizes path/query/body across invocation environments.
  - user_of(...): Extracts the authenticated user id from either:
    - Local/dev: x-user-uid header (and x-user-email if present).
    - Cloud: requestContext.authorizer.user JSON (when using API Gateway) or CloudFront viewer‑request Lambda that injects headers.
  - Routes of interest:
    - `/connectors [GET, POST]`
    - `/connectors/{id} [PUT, DELETE]`
    - `/connectors/{id}/inspect [GET]`
    - `/connectors/{id}/query [POST]`
    - `/connectors/{id}/explain [POST]` — may stream
    - `/connectors/{id}/chats [POST]` — streams chat creation tokens
    - `/chats [GET]`
    - `/chats/{chat_id}/messages [POST]` — streams reply tokens
- Minimal ASGI helpers: backend/api/framework.py
  - respond(send, status=200, body=dict, headers=dict): JSON responses with sensible CORS and cache headers.
  - stream(send, events: AsyncIterable[str]): Sends a text/event‑stream with proper headers and back‑to‑back chunks, then terminates.
  - json_body(receive): Reads and decodes request bodies for Uvicorn/Lambda.
  - parse_qs(raw): Parses query strings from ASGI scope.
  - run_blocking(fn): Offloads blocking work (e.g., boto3/Dynamo) to a thread pool.
- SSE utilities: backend/api/sse.py
  - Implements spec‑compliant framing: event:, data:, id:, retry, and comment lines, with LF and double‑LF record separators.
  - start_stream(send, ...), send_event(send, ...), finish_stream(send, ...), and a streaming(...) async contextmanager.
  - Standard events used by the app: token, stored, done, error.
- Domain handlers
  - chats.py: Orchestrates chat lifecycle. When stream=True, emits token events as LLM chunks arrive, then done.
  - connectors.py, models.py, errors.py, utils.py: Connector CRUD, DynamoDB models, error taxonomy, and misc utilities.

Serverless streaming architecture
- Runtime
  - The Lambda uses AWS Lambda Web Adapter (LWA) to run an ASGI server (Uvicorn) inside Lambda.
  - Response streaming is enabled so SSE can flow to clients as tokens are produced.
- Infrastructure (see infrastructure/api/template.yaml)
  - AWS::Serverless::Function (ApiFunction) with:
    - CodeUri: ../../backend/api
    - Handler: run.sh (shell that execs Uvicorn: python -m uvicorn app:app --host 0.0.0.0 --port 8080)
    - Environment:
      - AWS_LAMBDA_EXEC_WRAPPER: /opt/bootstrap
      - AWS_LWA_INVOKE_MODE: RESPONSE_STREAM
      - AWS_LWA_ENABLE_COMPRESSION: "false"
      - GEMINI_API_KEY, TABLE_NAME, PYTHONPATH
    - Layers:
      - Psycopg2 layer (database client)
      - LambdaAdapterLayerX86 (the LWA)
    - FunctionUrlConfig:
      - AuthType: AWS_IAM
      - InvokeMode: RESPONSE_STREAM
  - CloudFront distribution maps /api/* to the Lambda Function URL, using an Origin Access Control (sigv4 signing) and forwarding select headers (x-user-uid, x-user-email) plus all query strings.
  - A viewer‑request Lambda@Edge (semaia-edge-authorizer) runs at CloudFront to authenticate the request and/or enrich headers.
- Data
  - DynamoDB table (WorkoutsDatabase) stores chats, connectors, and messages with a PK/SK schema.

### Lightweight ASGI design notes
- Single file app.py with a match/case router and thin helpers avoids a traditional framework while retaining ASGI compatibility and testability.
- The code normalizes multiple event shapes so the same router works locally and in Lambda behind CloudFront.
- SSE is built with direct ASGI send events, not via a higher‑level library, for maximum control and minimal overhead.

Local development
- Prereqs: Python 3.12, pip, optional uvicorn installed as a module dependency via requirements.
- Start server:
  - cd backend/api
  - ./run.sh
  - Uvicorn will serve on http://localhost:8080
- Auth during local dev:
  - Set the x-user-uid header (and optionally x-user-email) to simulate an authenticated user, e.g. with curl:
    - curl -N -H "x-user-uid: local-user" http://localhost:8080/api/chats
- Test streaming (SSE) with curl:
  - curl -N -H "x-user-uid: local-user" -H "Accept: text/event-stream" \
    -H "Content-Type: application/json" \
    -d '{"message":"Hello"}' \
    http://localhost:8080/api/chats/CHAT_ID/messages

Error handling
- Domain errors map to HTTP status codes:
  - EmptyResponse -> 204
  - IncorrectSignature -> 400
  - NotFound -> 404
  - Unauthorized -> 401
  - Fallback -> 500 with error message
- SSE streams also emit an error event with a message before closing, when exceptions occur mid‑stream.

Request/response and headers
- JSON request/response for non‑streaming endpoints (application/json).
- SSE endpoints return text/event-stream with:
  - cache-control: no-cache, no-transform
  - connection: keep-alive
  - x-accel-buffering: no
- CORS is permissive by default (Access-Control-Allow-Origin: *), suitable for CloudFront‑fronted SPAs.

Path prefix handling
- When fronted by CloudFront, the application may receive paths with an /api prefix. The router strips this prefix before dispatching so route definitions stay clean and environment‑agnostic.

Deployment (high level)
- Requires AWS SAM/CloudFormation. See infrastructure/api/template.yaml for parameters (Env, GeminiApiKey, TableName, LayersBucket).
- Build and deploy typical steps (pseudocode):
  - sam build -t infrastructure/api/template.yaml
  - sam deploy -t infrastructure/api/template.yaml --guided
- The SPA is served from S3 behind CloudFront; /api/* is routed to the Lambda Function URL with response streaming enabled.

Security notes
- Function URL is IAM‑protected; CloudFront uses an Origin Access Control to sign requests to the Function URL. The viewer‑request Lambda@Edge handles authentication and injects user context headers.
- Locally, mock auth via x-user-uid header only; do not use this in production.

Troubleshooting
- If SSE appears buffered in the browser, ensure:
  - content-type is text/event-stream
  - cache-control is no-cache, no-transform
  - x-accel-buffering is no
  - LWA is configured with AWS_LWA_INVOKE_MODE=RESPONSE_STREAM and compression disabled.
- If routes 404 behind CloudFront, verify the /api prefix is being forwarded and stripped by the router.
- If Unauthorized, check CloudFront Lambda@Edge auth and forwarded x-user-* headers locally.
