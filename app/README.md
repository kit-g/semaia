# Semaia — Flutter App

This is the front-end Flutter application for Semaia. It is designed to run as a SPA (web) behind CloudFront and also as
a desktop app (macOS). It talks to the backend API over HTTPS and uses Server‑Sent Events (SSE) for streaming responses.

Also see:

- [backend](../backend/README.md) — API design, routes, local dev, and streaming notes
- [infrastructure](../infrastructure) — AWS SAM/CloudFormation templates for the API and CloudFront/S3 hosting

## Overview

- Tech stack: Flutter (web and macOS), Provider for state management
- Auth: Google Sign‑In + Firebase Authentication
- API client: app/shared/api (package: semaia_api) using text/event-stream for long‑running operations
- Shared packages:
    - app/shared/models — common models used by both API and UI
    - app/shared/state — app state (auth, chats, inspector)
    - app/shared/api — HTTP + SSE client used by the app

Backend dependency

- The app expects an HTTPS API gateway host and will issue requests to:
    - https://semaia.awry.me/api/*
- For deployed environments, this is the CloudFront distribution domain that routes /api/* to the Lambda Function URL (
  see infrastructure/api/template.yaml).
- For local development, prefer pointing the app to the deployed API, or use an HTTPS dev proxy in front of your local
  Uvicorn backend.

## Prerequisites

- Flutter (3.22+) and Dart SDK
- For macOS:
    - Xcode, CocoaPods
- For web:
    - A modern browser (Chrome recommended)
- Firebase credentials are embedded via lib/firebase_options.dart.

## Configuration

Configuration is provided via --dart-define at build/run time and read in lib/core/config/config.dart.

Required defines:

- env: one of local, dev, prod
- domain: the public app domain (used for building internal links); for local can be localhost:7537
- appName: optional app name (defaults to Semaia)
- apiGateway: REQUIRED. Hostname (and optional port) of the API gateway without scheme; the client always uses HTTPS for
  requests.

Examples:

- Using the deployed stack from infrastructure/api/template.yaml outputs:
    - --dart-define=env=prod
    - --dart-define=domain=semaia.awry.me
    - --dart-define=apiGateway=semaia.awry.me
- Using a dev stack (replace with your CloudFront domain):
    - --dart-define=env=dev
    - --dart-define=domain=<your-dev-cloudfront-domain>
    - --dart-define=apiGateway=<your-dev-cloudfront-domain>
- Local with HTTPS proxy (advanced):
    - Run backend locally (see backend/README.md), then put an HTTPS proxy (e.g., Caddy/nginx) on https://localhost:8443
      that forwards to http://localhost:8080
    - Pass: --dart-define=env=local --dart-define=domain=localhost:3000 --dart-define=apiGateway=localhost:8443

Notes:

- The API client builds URIs with Uri.https(apiGateway, "/api/..."), so apiGateway must be reachable via HTTPS. For the
  browser to allow requests from http://localhost:xxxx (Flutter dev server) to https://localhost:port, your browser may
  require trusting a local certificate.
- Authorization: After login, the client sets Authorization: Bearer <Firebase ID token>. In production behind
  CloudFront, a viewer‑request Lambda authorizer validates the identity and injects user context for the backend.

## Run (web)

To run in Chrome with hot reload:

flutter run -d chrome \
--dart-define=env=dev \
--dart-define=domain=semaia.awry.me \
--dart-define=apiGateway=semaia.awry.me

For a local HTTPS proxy setup (see above), you might use:

flutter run -d chrome \
--dart-define=env=local \
--dart-define=domain=localhost:7537 \
--dart-define=apiGateway=localhost:8443

## Run (macOS)

flutter run -d macos \
--dart-define=env=dev \
--dart-define=domain=semaia.awry.me \
--dart-define=apiGateway=semaia.awry.me

macOS runs as a desktop app and is not restricted by browser mixed‑content rules; however, the client still uses HTTPS
for API calls.

## Build (web)

Release build:

flutter build web --release \
--dart-define=env=prod \
--dart-define=domain=semaia.awry.me \
--dart-define=apiGateway=semaia.awry.me

The build artifacts will be in app/build/web. To deploy with the provided infrastructure:

- Upload contents of build/web to the S3 bucket created by the stack (see infrastructure/api/template.yaml, output
  bucket name is <AccountId>-semaia-app)
- CloudFront will serve index.html and route /api/* to the API with response streaming enabled.

## Authentication

- Google Sign‑In via package:google_sign_in and Firebase Auth (see app/shared/state/lib/src/auth.dart)
- On the web, ensure your Firebase project allows the app origin (domain) for Google Sign‑In
- On macOS, Google Sign‑In uses the installed app flow; firebase_options.dart includes macOS settings
- After sign‑in, the app obtains a Firebase ID token and sets an Authorization: Bearer header for all API calls

## API usage by the app

The API client (app/shared/api/lib/src/api.dart):

- Adds Accept: text/event-stream and sends SSE POST requests for streaming routes
- Emits token events as they arrive and closes with a done event
- Adds x-amz-content-sha256 header to be compatible with CloudFront Origin Access Control signing expectations

Main routes consumed (see backend/README.md for full details):

- /api/connectors [GET, POST]
- /api/connectors/{id} [PUT, DELETE]
- /api/connectors/{id}/inspect [GET]
- /api/connectors/{id}/query [POST]
- /api/connectors/{id}/explain [POST] — streams
- /api/connectors/{id}/chats [POST] — streams
- /api/chats [GET]
- /api/chats/{chat_id}/messages [POST] — streams

## Troubleshooting

- 401 Unauthorized in prod: Verify CloudFront viewer‑request Lambda authorizer is configured and that your Firebase
  token is valid; on local, you may target a deployed gateway to avoid local auth plumbing.
- SSE stalls or buffers in browser: Ensure the backend is returning text/event-stream with no-cache and no-transform
  headers (see backend/README.md). If using a local HTTPS proxy, disable response buffering.
- CORS errors: The backend returns permissive CORS headers by default. If you still see issues, confirm the proxy or
  CloudFront behavior does not strip CORS headers.
- Google Sign‑In fails on web: Add your app domain to the Authorized JavaScript origins in the Google Cloud Console and
  ensure Firebase Auth providers are enabled.

## Useful paths

- Entry point: app/lib/main.dart
- App scaffold: app/lib/presentation/navigation/app.dart
- Config: app/lib/core/config/config.dart
- API client: app/shared/api/lib/src/api.dart
- Auth state: app/shared/state/lib/src/auth.dart

