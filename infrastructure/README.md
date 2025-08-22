# Semaia — Infrastructure 

This directory contains the AWS SAM/CloudFormation templates and assets used to deploy the Semaia stack: a static SPA on S3 behind CloudFront, and a streaming serverless API on Lambda exposed through a CloudFront origin.

See also:
- [backend](../backend/README.md) — Backend API internals and streaming notes
- [app](../app/README.md) — Flutter app configuration and deployment tips


## Architecture overview
![Architecture](architecture.png)
- SPA hosting
  - S3 bucket for the built Flutter web app
  - CloudFront distribution with the S3 bucket as the default origin
  - Custom domain + ACM certificate (in us-east-1) for TLS
- API
  - AWS Lambda (Python 3.12) running an ASGI server via AWS Lambda Web Adapter (LWA) with RESPONSE_STREAM enabled for SSE
  - Function URL protected by IAM; CloudFront calls the Function URL through an Origin Access Control (OAC) with SigV4 signing
  - DynamoDB table for connectors, chats, and messages
  - psycopg2 Lambda Layer (from a provided S3 bucket)
  - CloudFront cache behavior mapping /api/* to the Lambda Function URL origin
- Authentication/Authorization
  - CloudFront viewer-request Lambda@Edge (Node.js) validates Firebase ID tokens (Google Sign-In) and injects user context headers (x-user-uid, x-user-email)
  - Origin Request Policy forwards x-user-uid and x-user-email headers and all query strings to the API


## Stacks and templates
- infrastructure/api/template.yaml
  - Resources:
    - WorkoutsDatabase: DynamoDB table with PK/SK schema (PAY_PER_REQUEST)
    - PsycopgLayer: Lambda Layer for psycopg2, public permission included
    - ApiFunction: SAM Function running backend/api via run.sh (Uvicorn under LWA)
      - Env vars: AWS_LWA_INVOKE_MODE=RESPONSE_STREAM, compression disabled, TABLE_NAME, GEMINI_API_KEY (from Secrets Manager), PYTHONPATH
      - FunctionUrlConfig: AuthType=AWS_IAM, InvokeMode=RESPONSE_STREAM
      - Layers: psycopg layer + LWA layer arn:aws:lambda:${Region}:753240598075:layer:LambdaAdapterLayerX86:25
      - Role: DynamoDB CRUD permissions limited to the table
    - SiteHostingBucket: S3 bucket named ${AccountId}-semaia-app
    - CloudFrontOriginIdentity: OAI for S3
    - BucketPolicy: grants OAI read access to the bucket
    - ApiOAC: Origin Access Control for the Lambda Function URL origin (signing: sigv4)
    - OriginRequestPolicyAuth: forwards x-user-uid, x-user-email; cookies none; query strings all
    - CloudFrontDistribution:
      - Default origin: S3 (serves index.html)
      - CacheBehavior "/api/*": routes to the Lambda Function URL origin, HTTPS only, no caching, viewer-request Lambda@Edge authorizer association
      - Aliases + ViewerCertificate from parameters
    - ApiFunctionUrlPermissionForCF: permits CloudFront to invoke the Function URL (IAM)
  - Parameters:
    - Env (String)
    - GeminiApiKey (String, NoEcho) — name/ARN of a Secrets Manager secret that contains key GEMINI_API_KEY
    - TableName (String, default semaia-db)
    - LayersBucket (String, default 583168578067-lambda-layers) — holds the psycopg layer zip
    - CloudFrontCertificate (String, default prod ACM arn in us-east-1)
    - CloudFrontDomainName (String, default semaia.awry.me)
  - Outputs:
    - FunctionUrl — the API Function URL
    - Distribution — the CloudFront distribution domain name

- infrastructure/authorizer/auth.yaml
  - Resources:
    - AuthFunctionRole — IAM role allowing Lambda + EdgeLambda assume and basic execution
    - AuthFunction — SAM Function (Node.js 22.x) with AutoPublishAlias=live, code at backend/auth
  - Outputs:
    - AuthFunctionVersionArn — versioned ARN suitable for CloudFront association (required by Lambda@Edge)


## Region and ordering notes
- CloudFront and Lambda@Edge functions must be deployed in us-east-1.
- The authorizer stack (infrastructure/authorizer/auth.yaml) should be deployed first in us-east-1 to obtain the versioned function ARN (Outputs.AuthFunctionVersionArn).
- The API/Site stack (infrastructure/api/template.yaml) can be deployed in your chosen region, but its CloudFront distribution (a global service) references the Lambda@Edge function version ARN. Update the template to use the latest version ARN if you redeploy the authorizer.


## Secrets Manager setup (Gemini API key)
- Create a secret in AWS Secrets Manager that contains the key GEMINI_API_KEY with your value. Example secret value JSON:
  {
    "GEMINI_API_KEY": "<your-api-key>"
  }
- Pass the secret name or full ARN as the GeminiApiKey parameter when deploying the API stack. The template resolves it with {{resolve:secretsmanager:...:SecretString:GEMINI_API_KEY}}.


## Deploy — Authorizer (us-east-1)
1) Build and deploy the Lambda@Edge authorizer:

sam build -t infrastructure/authorizer/auth.yaml
sam deploy -t infrastructure/authorizer/auth.yaml \
  --stack-name semaia-edge-authorizer \
  --region us-east-1 \
  --capabilities CAPABILITY_IAM

2) Capture the Outputs.AuthFunctionVersionArn. You will reference this in the API stack's CloudFront LambdaFunctionAssociations entry (viewer-request). The current template contains a hard-coded version; update it to the latest version ARN when needed.


## Deploy — API + Site
1) Build the backend (SAM) and deploy the stack:

sam build -t infrastructure/api/template.yaml
sam deploy -t infrastructure/api/template.yaml \
  --stack-name semaia-app \
  --guided \
  --capabilities CAPABILITY_NAMED_IAM

Guided deploy will prompt you for parameters. Typical values:
- Env: prod or dev
- GeminiApiKey: <name or ARN of the secret with GEMINI_API_KEY>
- TableName: semaia-db (or another name)
- LayersBucket: <your layers bucket containing psycopg-py3.12-layer.zip>
- CloudFrontCertificate: ACM cert ARN in us-east-1
- CloudFrontDomainName: your app domain (e.g., semaia.awry.me)

2) Upload the built SPA to S3 (after building the Flutter app, see app/README.md):

aws s3 sync app/build/web s3://<AccountId>-semaia-app/ --delete

3) Invalidate CloudFront to roll out new assets quickly:

aws cloudfront create-invalidation --distribution-id <DIST_ID> --paths "/*"


## How the streaming API works through CloudFront
- Lambda runs an embedded ASGI server via LWA with AWS_LWA_INVOKE_MODE=RESPONSE_STREAM and compression disabled. This enables Server-Sent Events to stream progressively to clients.
- CloudFront routes /api/* to the Lambda Function URL origin secured by an OAC (SigV4). The client must include x-amz-content-sha256 for signed requests (the Flutter client does this automatically).
- The viewer-request Lambda@Edge validates the Firebase ID token from Authorization: Bearer and injects x-user-uid (and x-user-email). The origin request policy whitelists these headers so they reach the API.


## Expected request/response characteristics
- SSE endpoints return text/event-stream with:
  - cache-control: no-cache, no-transform
  - connection: keep-alive
  - x-accel-buffering: no
- Non-streaming endpoints return application/json.


## Operations and maintenance
- DynamoDB table (WorkoutsDatabase) uses PAY_PER_REQUEST with Retain policy; delete resources explicitly if needed.
- The S3 bucket is retained on stack deletion; empty it manually if you want to fully remove it.
- The psycopg2 layer is fetched from your LayersBucket; update the S3 key to rotate versions.
- To update the Lambda@Edge authorizer, deploy a new version; copy its versioned ARN into the API template before updating the CloudFront distribution.


## Troubleshooting
- 401 Unauthorized at /api/*:
  - Ensure the viewer-request Lambda@Edge is associated and the ARN points to an active version in us-east-1.
  - Confirm the client sends Authorization: Bearer <Firebase ID token>.
- 403 from S3 paths (single-page app deep links):
  - The distribution’s custom error responses map 403/404 to /index.html. Verify the SPA files exist in the bucket and caching has been invalidated.
- SSE appears buffered or not streaming:
  - Verify LWA is in RESPONSE_STREAM mode and compression disabled; check backend headers (see backend/README.md).
  - Ensure CloudFront behavior for /api/* uses the no-cache policy (Managed-CachingDisabled) and that proxies/CDNs in front aren’t buffering.
- 502 on query routes:
  - Backend may surface domain-specific errors (e.g., ExcessiveQuery). Check CloudWatch logs for the ApiFunction.
- Signature or access errors calling the Function URL via CloudFront:
  - Ensure OAC is attached to the origin and clients include x-amz-content-sha256 (the app does). The template includes Lambda permission for CloudFront to invoke the Function URL.
- Certificate or domain issues:
  - ACM certificate must be in us-east-1 for CloudFront. Verify domain validation and that the Aliases parameter matches your domain.


## Useful references
- infrastructure/api/template.yaml — full stack definition
- infrastructure/authorizer/auth.yaml — Lambda@Edge authorizer stack
- backend/auth/app.js — authorizer implementation (JWT verification against Google Secure Token)
- backend/api/app.py — ASGI app and router (SSE and JSON)
