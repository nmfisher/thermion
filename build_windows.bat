@echo off
REM Windows build script for Filament
REM Usage: build_windows.bat <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [options]
REM Example: build_windows.bat C:\path\to\filament v1.69.0 C:\path\to\output
REM          build_windows.bat C:\path\to\filament v1.69.0 C:\path\to\output --clean
REM          build_windows.bat C:\path\to\filament v1.69.0 C:\path\to\output --release

setlocal enabledelayedexpansion

REM Save script directory
set "SCRIPT_DIR=%~dp0"

REM Validate arguments
if "%~3"=="" (
  echo Usage: %0 ^<FILAMENT_BASE_DIR^> ^<FILAMENT_VERSION^> ^<OUTPUT_BASE_DIR^> [options]
  echo Example: %0 C:\path\to\filament v1.69.0 C:\path\to\output
  echo          %0 C:\path\to\filament v1.69.0 C:\path\to\output --clean
  echo          %0 C:\path\to\filament v1.69.0 C:\path\to\output --release
  echo.
  echo Options:
  echo   --clean         Remove existing target directories before building
  echo   --release       Build release only
  echo   --debug         Build debug only
  echo   ^(default^)       Build both release and debug
  exit /b 1
)

set "FILAMENT_BASE_DIR=%~1"
set "FILAMENT_VERSION=%~2"
set "OUTPUT_BASE_DIR=%~3"

REM Parse optional flags
set "CLEAN_FLAG="
set "BUILD_RELEASE=true"
set "BUILD_DEBUG=true"

:parse_args
if "%~4"=="" goto :done_args
if "%~4"=="--clean" (
  set "CLEAN_FLAG=--clean"
) else if "%~4"=="--release" (
  set "BUILD_DEBUG=false"
) else if "%~4"=="--debug" (
  set "BUILD_RELEASE=false"
) else (
  echo Unknown option: %~4
  exit /b 1
)
shift /4
goto :parse_args
:done_args

REM Validate OUTPUT_BASE_DIR exists
if not exist "%OUTPUT_BASE_DIR%" (
  echo Error: Output base directory does not exist: %OUTPUT_BASE_DIR%
  exit /b 1
)

REM Validate FILAMENT_BASE_DIR exists
if not exist "%FILAMENT_BASE_DIR%" (
  echo Error: Filament base directory does not exist: %FILAMENT_BASE_DIR%
  exit /b 1
)

REM Check if target directories already exist
set "TARGET_RELEASE_DIR=%OUTPUT_BASE_DIR%\%FILAMENT_VERSION%\windows\release"
set "TARGET_DEBUG_DIR=%OUTPUT_BASE_DIR%\%FILAMENT_VERSION%\windows\debug"

if "!BUILD_RELEASE!"=="true" if exist "%TARGET_RELEASE_DIR%" (
  if "!CLEAN_FLAG!"=="--clean" (
    echo Removing existing release target directory...
    rmdir /s /q "%TARGET_RELEASE_DIR%"
  ) else (
    echo Error: Release target directory already exists: %TARGET_RELEASE_DIR%
    echo Please remove it first or use --clean to rebuild.
    exit /b 1
  )
)

if "!BUILD_DEBUG!"=="true" if exist "%TARGET_DEBUG_DIR%" (
  if "!CLEAN_FLAG!"=="--clean" (
    echo Removing existing debug target directory...
    rmdir /s /q "%TARGET_DEBUG_DIR%"
  ) else (
    echo Error: Debug target directory already exists: %TARGET_DEBUG_DIR%
    echo Please remove it first or use --clean to rebuild.
    exit /b 1
  )
)

REM Change to Filament directory and checkout branch
REM Change to Filament directory and checkout branch
cd /d "%FILAMENT_BASE_DIR%" || exit /b 1
call git stash
call git reset --hard
echo Checking out tag: v1.69.1
call git checkout v1.69.1 || (
  echo Error: Failed to checkout tag v1.69.1
  exit /b 1
)

REM Create build directory
echo Creating build directory...
if not exist out mkdir out
cd /d "%FILAMENT_BASE_DIR%\out" || exit /b 1

REM Run CMake configuration
echo Configuring Filament for Windows...
cmake -DUSE_STATIC_CRT=OFF -DFILAMENT_SUPPORTS_VULKAN=ON -DFILAMENT_SKIP_SAMPLES=ON -DCMAKE_BUILD_TYPE=Release -DFILAMENT_SHORTEN_MSVC_COMPILATION=OFF .. || (
  echo Error: CMake configuration failed
  exit /b 1
)

REM Build release
if "!BUILD_RELEASE!"=="true" (
  echo Building Filament for Windows ^(release^)...
  cmake --build . --config Release || (
    echo Error: Filament release build failed
    exit /b 1
  )

  REM Build third-party libraries for release
  echo Building third-party libraries for release...
  cmake --build . --target tinyexr --config Release || (
    echo Warning: tinyexr release build failed
  )
  cmake --build . --target imageio --config Release || (
    echo Warning: imageio release build failed
  )

  REM Install release to get headers in a known location
  echo Installing release...
  cmake --install . --config Release --prefix "%FILAMENT_BASE_DIR%\out\install-release" || (
    echo Error: Filament release install failed
    exit /b 1
  )
)

REM Build debug
if "!BUILD_DEBUG!"=="true" (
  echo Building Filament for Windows ^(debug^)...
  cmake --build . --config Debug || (
    echo Error: Filament debug build failed
    exit /b 1
  )

  REM Build third-party libraries for debug
  echo Building third-party libraries for debug...
  cmake --build . --target tinyexr --config Debug || (
    echo Warning: tinyexr debug build failed
  )
  cmake --build . --target imageio --config Debug || (
    echo Warning: imageio debug build failed
  )

  REM Install debug to get headers in a known location
  echo Installing debug...
  cmake --install . --config Debug --prefix "%FILAMENT_BASE_DIR%\out\install-debug" || (
    echo Error: Filament debug install failed
    exit /b 1
  )
)

REM Create target directories and copy libraries
echo Copying libraries...

if "!BUILD_RELEASE!"=="true" (
  mkdir "%TARGET_RELEASE_DIR%" 2>nul
  if not exist "%TARGET_RELEASE_DIR%" (
    echo Error: Failed to create target directory: %TARGET_RELEASE_DIR%
    exit /b 1
  )
)

if "!BUILD_DEBUG!"=="true" (
  mkdir "%TARGET_DEBUG_DIR%" 2>nul
  if not exist "%TARGET_DEBUG_DIR%" (
    echo Error: Failed to create target directory: %TARGET_DEBUG_DIR%
    exit /b 1
  )
)

REM Copy release libraries
if "!BUILD_RELEASE!"=="true" (
  echo Copying release libraries...
  REM Copy .lib files from Release subdirectories
  for /r "%FILAMENT_BASE_DIR%\out" %%f in (*.lib) do (
    echo %%f | findstr /i "\\Release\\" >nul && (
      copy /Y "%%f" "%TARGET_RELEASE_DIR%\" >nul 2>&1
    )
  )

  REM Verify at least some libraries were copied
  if not exist "%TARGET_RELEASE_DIR%\*.lib" (
    echo Error: No release libraries found. Check build output structure.
    echo Expected libraries in subdirectories of: %FILAMENT_BASE_DIR%\out
    exit /b 1
  )
)

REM Copy debug libraries
if "!BUILD_DEBUG!"=="true" (
  echo Copying debug libraries...
  for /r "%FILAMENT_BASE_DIR%\out" %%f in (*.lib) do (
    echo %%f | findstr /i "\\Debug\\" >nul && (
      copy /Y "%%f" "%TARGET_DEBUG_DIR%\" >nul 2>&1
    )
  )

  REM Verify at least some libraries were copied
  if not exist "%TARGET_DEBUG_DIR%\*.lib" (
    echo Error: No debug libraries found. Check build output structure.
    echo Expected libraries in subdirectories of: %FILAMENT_BASE_DIR%\out
    exit /b 1
  )
)

REM Copy header files to thermion_dart
set "COPY_HEADERS_OPTS="
if "!BUILD_RELEASE!"=="true" if "!BUILD_DEBUG!"=="false" set "COPY_HEADERS_OPTS=--release"
if "!BUILD_DEBUG!"=="true" if "!BUILD_RELEASE!"=="false" set "COPY_HEADERS_OPTS=--debug"

call "%SCRIPT_DIR%copy_headers.bat" "%FILAMENT_BASE_DIR%" !COPY_HEADERS_OPTS! || (
  echo Error: Failed to copy headers
  exit /b 1
)

REM Download vulkan-1.lib from v1.58.0 (reusable across versions)
set "VULKAN_LIB_URL=https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/filament-v1.58.0-windows-release.zip"
set "VULKAN_LIB_ZIP=%OUTPUT_BASE_DIR%\vulkan-1-temp.zip"
set "VULKAN_LIB_EXTRACT=%OUTPUT_BASE_DIR%\vulkan-1-temp"

if not exist "%OUTPUT_BASE_DIR%\vulkan-1.lib" (
  echo Downloading filament v1.58.0 to extract vulkan-1.lib...
  powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%VULKAN_LIB_URL%' -OutFile '%VULKAN_LIB_ZIP%'" || (
    echo Error: Failed to download filament v1.58.0 zip
    exit /b 1
  )

  echo Extracting vulkan-1.lib from zip...
  if exist "%VULKAN_LIB_EXTRACT%" rmdir /s /q "%VULKAN_LIB_EXTRACT%"
  mkdir "%VULKAN_LIB_EXTRACT%"
  powershell -Command "Expand-Archive -Path '%VULKAN_LIB_ZIP%' -DestinationPath '%VULKAN_LIB_EXTRACT%' -Force" || (
    echo Error: Failed to extract filament v1.58.0 zip
    exit /b 1
  )

  REM Copy vulkan-1.lib to output base for reuse
  if exist "%VULKAN_LIB_EXTRACT%\vulkan-1.lib" (
    copy /Y "%VULKAN_LIB_EXTRACT%\vulkan-1.lib" "%OUTPUT_BASE_DIR%\vulkan-1.lib" >nul
  ) else (
    echo Error: vulkan-1.lib not found in v1.58.0 zip
    echo Contents of extracted zip:
    dir /b "%VULKAN_LIB_EXTRACT%"
    exit /b 1
  )

  REM Cleanup temp files
  del /q "%VULKAN_LIB_ZIP%" 2>nul
  rmdir /s /q "%VULKAN_LIB_EXTRACT%" 2>nul
  echo vulkan-1.lib cached at: %OUTPUT_BASE_DIR%\vulkan-1.lib
) else (
  echo Using cached vulkan-1.lib from: %OUTPUT_BASE_DIR%\vulkan-1.lib
)

REM Copy vulkan-1.lib to target directories
if "!BUILD_RELEASE!"=="true" (
  copy /Y "%OUTPUT_BASE_DIR%\vulkan-1.lib" "%TARGET_RELEASE_DIR%\vulkan-1.lib" >nul
  echo Copied vulkan-1.lib to release directory
)
if "!BUILD_DEBUG!"=="true" (
  copy /Y "%OUTPUT_BASE_DIR%\vulkan-1.lib" "%TARGET_DEBUG_DIR%\vulkan-1.lib" >nul
  echo Copied vulkan-1.lib to debug directory
)

REM Create zip files (using PowerShell)
if "!BUILD_RELEASE!"=="true" (
  echo Creating release zip...
  powershell -Command "Compress-Archive -Path '%TARGET_RELEASE_DIR%\*' -DestinationPath '%OUTPUT_BASE_DIR%\filament-%FILAMENT_VERSION%-windows-release.zip' -Force" 2>nul || (
    echo Warning: Failed to create release zip. PowerShell Compress-Archive not available.
  )
)

if "!BUILD_DEBUG!"=="true" (
  echo Creating debug zip...
  powershell -Command "Compress-Archive -Path '%TARGET_DEBUG_DIR%\*' -DestinationPath '%OUTPUT_BASE_DIR%\filament-%FILAMENT_VERSION%-windows-debug.zip' -Force" 2>nul || (
    echo Warning: Failed to create debug zip. PowerShell Compress-Archive not available.
  )
)

echo Build completed successfully!
if "!BUILD_RELEASE!"=="true" (
  echo Release libraries: %TARGET_RELEASE_DIR%
  echo Release zip: %OUTPUT_BASE_DIR%\filament-%FILAMENT_VERSION%-windows-release.zip
)
if "!BUILD_DEBUG!"=="true" (
  echo Debug libraries: %TARGET_DEBUG_DIR%
  echo Debug zip: %OUTPUT_BASE_DIR%\filament-%FILAMENT_VERSION%-windows-debug.zip
)

REM Upload zip files to Cloudflare R2
echo.
echo Uploading zip files to Cloudflare R2...
if "!BUILD_RELEASE!"=="true" (
  call "%SCRIPT_DIR%upload_r2.bat" "%OUTPUT_BASE_DIR%\filament-%FILAMENT_VERSION%-windows-release.zip" || (
    echo Warning: Failed to upload release zip
  )
)
if "!BUILD_DEBUG!"=="true" (
  call "%SCRIPT_DIR%upload_r2.bat" "%OUTPUT_BASE_DIR%\filament-%FILAMENT_VERSION%-windows-debug.zip" || (
    echo Warning: Failed to upload debug zip
  )
)

endlocal
