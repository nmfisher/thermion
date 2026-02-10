@echo off
REM Copy Filament header files to thermion_dart\native\include\filament (Windows)
REM All shared headers go to the output directory.
REM Only uberarchive.h differs between debug/release, copied to debug\ and release\ subdirs.
REM Usage: copy_headers.bat <FILAMENT_BASE_DIR> [options]
REM Example: copy_headers.bat C:\path\to\filament
REM          copy_headers.bat C:\path\to\filament --release
REM          copy_headers.bat C:\path\to\filament --debug

setlocal enabledelayedexpansion

REM Save script directory
set "SCRIPT_DIR=%~dp0"

REM Validate arguments
if "%~1"=="" (
  echo Usage: %0 ^<FILAMENT_BASE_DIR^> [options]
  echo Example: %0 C:\path\to\filament
  echo          %0 C:\path\to\filament --release
  echo          %0 C:\path\to\filament --debug
  echo.
  echo Options:
  echo   --release       Copy release headers only
  echo   --debug         Copy debug headers only
  echo   ^(default^)       Copy both release and debug headers
  exit /b 1
)

set "FILAMENT_BASE_DIR=%~1"
set "OUTPUT_INCLUDE_DIR=%SCRIPT_DIR%thermion_dart\native\include\filament"

REM Parse optional flags
set "BUILD_RELEASE=true"
set "BUILD_DEBUG=true"

:parse_args
if "%~2"=="" goto :done_args
if "%~2"=="--release" (
  set "BUILD_DEBUG=false"
) else if "%~2"=="--debug" (
  set "BUILD_RELEASE=false"
) else (
  echo Unknown option: %~2
  exit /b 1
)
shift /2
goto :parse_args
:done_args

REM Validate FILAMENT_BASE_DIR exists
if not exist "%FILAMENT_BASE_DIR%" (
  echo Error: Filament base directory does not exist: %FILAMENT_BASE_DIR%
  exit /b 1
)

REM Determine header source directory (prefer release, fall back to debug)
if "!BUILD_RELEASE!"=="true" (
  set "HEADER_SOURCE=%FILAMENT_BASE_DIR%\out\install-release\include"
) else if "!BUILD_DEBUG!"=="true" (
  set "HEADER_SOURCE=%FILAMENT_BASE_DIR%\out\install-debug\include"
)

REM Clean and recreate output directory
echo Copying Filament header files to %OUTPUT_INCLUDE_DIR%...
if exist "%OUTPUT_INCLUDE_DIR%" rmdir /s /q "%OUTPUT_INCLUDE_DIR%"
mkdir "%OUTPUT_INCLUDE_DIR%"

REM Copy all shared headers
xcopy /E /I /Y "!HEADER_SOURCE!\*" "%OUTPUT_INCLUDE_DIR%\" >nul || (
  echo Error: Failed to copy Filament headers
  exit /b 1
)

REM Copy imageio headers (not included in main include dir)
xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\imageio\include\*" "%OUTPUT_INCLUDE_DIR%\" >nul || (
  echo Error: Failed to copy imageio headers
  exit /b 1
)

REM Copy bluevk headers (not included in main include dir)
mkdir "%OUTPUT_INCLUDE_DIR%\bluevk" 2>nul
xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\bluevk\include\bluevk\*" "%OUTPUT_INCLUDE_DIR%\bluevk\" >nul || (
  echo Error: Failed to copy bluevk headers
  exit /b 1
)

REM Copy vulkan headers (not included in main include dir)
mkdir "%OUTPUT_INCLUDE_DIR%\vulkan" 2>nul
xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\bluevk\include\vulkan\*" "%OUTPUT_INCLUDE_DIR%\vulkan\" >nul || (
  echo Error: Failed to copy vulkan headers
  exit /b 1
)

REM Copy vk_video headers (not included in main include dir)
mkdir "%OUTPUT_INCLUDE_DIR%\vk_video" 2>nul
xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\bluevk\include\vk_video\*" "%OUTPUT_INCLUDE_DIR%\vk_video\" >nul || (
  echo Error: Failed to copy vk_video headers
  exit /b 1
)

REM Copy stb_image.h (third-party header used by TTexture.cpp)
mkdir "%OUTPUT_INCLUDE_DIR%\third_party\stb" 2>nul
copy /Y "%FILAMENT_BASE_DIR%\third_party\stb\stb_image.h" "%OUTPUT_INCLUDE_DIR%\third_party\stb\" >nul || (
  echo Error: Failed to copy stb_image.h
  exit /b 1
)

REM Copy release-specific uberarchive.h
if "!BUILD_RELEASE!"=="true" (
  mkdir "%OUTPUT_INCLUDE_DIR%\release\gltfio\materials" 2>nul
  copy /Y "%FILAMENT_BASE_DIR%\out\install-release\include\gltfio\materials\uberarchive.h" "%OUTPUT_INCLUDE_DIR%\release\gltfio\materials\" >nul || (
    echo Error: Failed to copy release uberarchive.h
    exit /b 1
  )
)

REM Copy debug-specific uberarchive.h
if "!BUILD_DEBUG!"=="true" (
  mkdir "%OUTPUT_INCLUDE_DIR%\debug\gltfio\materials" 2>nul
  copy /Y "%FILAMENT_BASE_DIR%\out\install-debug\include\gltfio\materials\uberarchive.h" "%OUTPUT_INCLUDE_DIR%\debug\gltfio\materials\" >nul || (
    echo Error: Failed to copy debug uberarchive.h
    exit /b 1
  )
)

echo Headers copied to: %OUTPUT_INCLUDE_DIR%

endlocal
