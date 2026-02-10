@echo off
REM Upload files to Cloudflare R2
REM Usage: upload_r2.bat <FILE_PATH>
REM Example: upload_r2.bat C:\path\to\file.zip
REM
REM Uses wrangler for files under 300MB, AWS CLI for larger files
REM First time setup:
REM   - wrangler login (for small files)
REM   - Set R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY env vars (for large files)

setlocal enabledelayedexpansion

set "R2_BUCKET_NAME=thermion"
set "R2_ACCOUNT_ID=260d4efc65af500536ea376de6452ece"
set "R2_ENDPOINT=https://%R2_ACCOUNT_ID%.r2.cloudflarestorage.com"

if "%~1"=="" (
  echo Usage: %0 ^<FILE_PATH^>
  echo Example: %0 C:\path\to\file.zip
  exit /b 1
)

set "FILE_PATH=%~1"

if not exist "%FILE_PATH%" (
  echo Error: File not found: %FILE_PATH%
  exit /b 1
)

set "DEST_NAME=%~nx1"

REM Get file size in bytes
for %%A in ("%FILE_PATH%") do set "FILE_SIZE=%%~zA"

REM 300 MB = 314572800 bytes
set "MAX_WRANGLER_SIZE=314572800"

echo Uploading %FILE_PATH% to R2...
echo Destination: %R2_BUCKET_NAME%/%DEST_NAME%
echo File size: %FILE_SIZE% bytes

REM Compare file size (use PowerShell for large number comparison)
for /f %%i in ('powershell -Command "if (%FILE_SIZE% -gt %MAX_WRANGLER_SIZE%) { 'large' } else { 'small' }"') do set "SIZE_CHECK=%%i"

if "%SIZE_CHECK%"=="large" (
  echo File exceeds 300MB, using AWS CLI with multipart upload...

  REM Check for AWS CLI
  where aws >nul 2>&1 || (
    echo Error: AWS CLI not found. Install with: winget install Amazon.AWSCLI
    exit /b 1
  )

  REM Check for credentials
  if "%R2_ACCESS_KEY_ID%"=="" (
    echo Error: R2_ACCESS_KEY_ID environment variable not set
    echo Set it with: set R2_ACCESS_KEY_ID=your_access_key_id
    exit /b 1
  )
  if "%R2_SECRET_ACCESS_KEY%"=="" (
    echo Error: R2_SECRET_ACCESS_KEY environment variable not set
    echo Set it with: set R2_SECRET_ACCESS_KEY=your_secret_access_key
    exit /b 1
  )

  set "AWS_ACCESS_KEY_ID=%R2_ACCESS_KEY_ID%"
  set "AWS_SECRET_ACCESS_KEY=%R2_SECRET_ACCESS_KEY%"
  set "AWS_DEFAULT_REGION=auto"

  aws s3 cp "%FILE_PATH%" "s3://%R2_BUCKET_NAME%/%DEST_NAME%" --endpoint-url "%R2_ENDPOINT%" || (
    echo Error: Upload failed
    exit /b 1
  )
) else (
  echo Using wrangler...

  REM Check if Wrangler is available
  where wrangler >nul 2>&1 || (
    echo Error: Wrangler not found in PATH
    echo Install with: npm install -g wrangler
    exit /b 1
  )

  wrangler r2 object put "%R2_BUCKET_NAME%/%DEST_NAME%" --file "%FILE_PATH%" --remote || (
    echo Error: Upload failed
    echo If not logged in, run: wrangler login
    exit /b 1
  )
)

echo.
echo Upload successful!
echo Public URL: https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/%DEST_NAME%

endlocal
