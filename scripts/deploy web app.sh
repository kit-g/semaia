set -e

# for local deployment
# needs PROFILE (AWS local profile), S3_BUCKET, ENV_FILE and DISTRIBUTION (CloudFront) env vars
function is_bucket_valid() {
    if aws s3api head-bucket --bucket "$S3_BUCKET" --profile "$PROFILE" 2>/dev/null; then
      echo "Bucket $S3_BUCKET exists"
    else
      echo "S3 bucket $S3_BUCKET does not exist"
      exit 1
    fi
}

function clean() {
    flutter clean
}

function build() {
  echo "Building from $ENV_FILE"
  flutter build web \
    --dart-define-from-file="$ENV_FILE" \
    --release
}

function deploy() {
    echo "Emptying the bucket"
    aws s3 rm "s3://$S3_BUCKET" --recursive --profile "$PROFILE"
    echo "Copying web assets to bucket"
    aws s3 cp "build/web" "s3://$S3_BUCKET" --recursive --profile "$PROFILE"
}

function invalidate_cache() {
    aws cloudfront create-invalidation \
      --distribution-id "$DISTRIBUTION" \
      --paths "/*" \
      --profile "$PROFILE" >/dev/null
    echo "Cache in distribution $DISTRIBUTION invalidated"
}


if is_bucket_valid; then
  clean
  build
  deploy
  invalidate_cache
fi
