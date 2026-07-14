#!/bin/bash
# Upload files to Cloudflare R2
# Usage: upload_r2.sh <FILE_PATH>
# Example: upload_r2.sh /path/to/file.zip
#
# Uses wrangler for files under 300MB, AWS CLI for larger files
# First time setup:
#   - wrangler login (for small files)
#   - Set R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY env vars (for large files)

R2_BUCKET_NAME="thermion"
R2_ACCOUNT_ID="260d4efc65af500536ea376de6452ece"
R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

if [ -z "$1" ]; then
  echo "Usage: $0 <FILE_PATH>"
  echo "Example: $0 /path/to/file.zip"
  exit 1
fi

FILE_PATH="$1"

if [ ! -f "$FILE_PATH" ]; then
  echo "Error: File not found: $FILE_PATH"
  exit 1
fi

DEST_NAME=$(basename "$FILE_PATH")

# Get file size in bytes
FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null)

# 300 MB = 314572800 bytes
MAX_WRANGLER_SIZE=314572800

echo "Uploading $FILE_PATH to R2..."
echo "Destination: $R2_BUCKET_NAME/$DEST_NAME"
echo "File size: $FILE_SIZE bytes"

if [ "$FILE_SIZE" -gt "$MAX_WRANGLER_SIZE" ]; then
  echo "File exceeds 300MB, using AWS CLI with multipart upload..."

  # Check for AWS CLI
  if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI not found. Install it first."
    exit 1
  fi

  # Check for credentials
  if [ -z "$R2_ACCESS_KEY_ID" ]; then
    echo "Error: R2_ACCESS_KEY_ID environment variable not set"
    echo "Set it with: export R2_ACCESS_KEY_ID=your_access_key_id"
    exit 1
  fi
  if [ -z "$R2_SECRET_ACCESS_KEY" ]; then
    echo "Error: R2_SECRET_ACCESS_KEY environment variable not set"
    echo "Set it with: export R2_SECRET_ACCESS_KEY=your_secret_access_key"
    exit 1
  fi

  export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
  export AWS_DEFAULT_REGION="auto"

  aws s3 cp "$FILE_PATH" "s3://$R2_BUCKET_NAME/$DEST_NAME" --endpoint-url "$R2_ENDPOINT" || {
    echo "Error: Upload failed"
    exit 1
  }
else
  echo "Using wrangler..."

  # Check if Wrangler is available
  if ! command -v wrangler &> /dev/null; then
    echo "Error: Wrangler not found in PATH"
    echo "Install with: npm install -g wrangler"
    exit 1
  fi

  wrangler r2 object put "$R2_BUCKET_NAME/$DEST_NAME" --file "$FILE_PATH" --remote || {
    echo "Error: Upload failed"
    echo "If not logged in, run: wrangler login"
    exit 1
  }
fi

echo ""
echo "Upload successful!"
echo "Public URL: https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/$DEST_NAME"
