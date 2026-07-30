@echo off
REM Windows build script for Filament
REM Usage: build_windows.bat <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [options]
REM Example: build_windows.bat C:\path\to\filament v1.74.0 C:\path\to\output
REM          build_windows.bat C:\path\to\filament v1.74.0 C:\path\to\output --clean
REM          build_windows.bat C:\path\to\filament v1.74.0 C:\path\to\output --release

setlocal enabledelayedexpansion

REM Save script directory
set "SCRIPT_DIR=%~dp0"

REM Validate arguments
if "%~3"=="" (
  echo Usage: %0 ^<FILAMENT_BASE_DIR^> ^<FILAMENT_VERSION^> ^<OUTPUT_BASE_DIR^> [options]
  echo Example: %0 C:\path\to\filament v1.74.0 C:\path\to\output
  echo          %0 C:\path\to\filament v1.74.0 C:\path\to\output --clean
  echo          %0 C:\path\to\filament v1.74.0 C:\path\to\output --release
  echo.
  echo Options:
  echo   --clean         Remove existing target directories before building
  echo   --release       Build release only
  echo   --debug         Build debug only
  echo   ^(default^)       Build both release and debug
  exit /b 1
)

set "FILAMENT_BASE_DIR=%~f1"
set "FILAMENT_VERSION=%~2"
set "OUTPUT_BASE_DIR=%~f3"

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
echo Checking out tag: %FILAMENT_VERSION%
call git checkout %FILAMENT_VERSION% || (
  echo Error: Failed to checkout tag %FILAMENT_VERSION%
  exit /b 1
)

REM Patch the libassimp tnt overlay to enable STL/PLY import + glTF2/FBX export.
REM Must run AFTER the checkout so it patches the checked-out tag. Idempotent.
python "%SCRIPT_DIR%patch_libassimp_tnt.py" "%FILAMENT_BASE_DIR%"

REM Patch FFilamentAsset.h to allow overriding GLTFIO_USE_FILESYSTEM at compile time
echo Patching FFilamentAsset.h to disable GLTFIO_USE_FILESYSTEM...
set "GLTFIO_HEADER=%FILAMENT_BASE_DIR%\libs\gltfio\src\FFilamentAsset.h"
powershell -Command "$f = Get-Content '%GLTFIO_HEADER%' -Raw; $old = '#if defined(__EMSCRIPTEN__) || defined(__ANDROID__) || defined(FILAMENT_IOS)'; $new = '#ifndef GLTFIO_USE_FILESYSTEM' + \"`n\" + $old; $f = $f.Replace($old, $new); $tail = '#define GLTFIO_USE_FILESYSTEM 1' + \"`r`n\" + '#endif'; $f = $f.Replace($tail, $tail + \"`r`n\" + '#endif'); Set-Content '%GLTFIO_HEADER%' $f -NoNewline; Write-Host 'Patch applied. Verifying...'; $check = Get-Content '%GLTFIO_HEADER%' -Raw; if ($check -match 'ifndef GLTFIO_USE_FILESYSTEM') { Write-Host 'SUCCESS: Guard found in patched file' } else { Write-Host 'FAILED: Guard NOT found'; exit 1 }"

REM Inject -DGLTFIO_USE_FILESYSTEM=0 into gltfio's compile definitions
echo target_compile_definitions(gltfio_core PRIVATE GLTFIO_USE_FILESYSTEM=0)>> "%FILAMENT_BASE_DIR%\libs\gltfio\CMakeLists.txt"

REM Create build directory
echo Creating build directory...
if not exist out mkdir out
cd /d "%FILAMENT_BASE_DIR%\out" || exit /b 1

REM Run CMake configuration
echo Configuring Filament for Windows...
cmake -G "Visual Studio 17 2022" -T v142 -DUSE_STATIC_CRT=OFF -DFILAMENT_SUPPORTS_VULKAN=ON -DFILAMENT_SKIP_SAMPLES=ON -DFILAMENT_SHORTEN_MSVC_COMPILATION=OFF .. || (
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

  REM Build libassimp for release
  echo Building libassimp for release...
  cd "%FILAMENT_BASE_DIR%\out"
  if not exist "cmake-release-assimp" mkdir cmake-release-assimp
  cd cmake-release-assimp
  cmake -G "Visual Studio 17 2022" -T v142 ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_CXX_STANDARD=17 ^
    -DCMAKE_C_FLAGS=/I%FILAMENT_BASE_DIR%\third_party\libz ^
    -DCMAKE_CXX_FLAGS=/I%FILAMENT_BASE_DIR%\third_party\libz ^
    -DASSIMP_BUILD_ASSIMP_TOOLS=OFF ^
    -DASSIMP_BUILD_TESTS=OFF ^
    -DASSIMP_BUILD_SAMPLES=OFF ^
    -DASSIMP_WARNINGS_AS_ERRORS=OFF ^
    "%FILAMENT_BASE_DIR%\third_party\libassimp\tnt" || (
    echo Error: libassimp release cmake configuration failed
    exit /b 1
  )
  cmake --build . --config Release || (
    echo Error: libassimp release build failed
    exit /b 1
  )
  cd "%FILAMENT_BASE_DIR%\out"

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

  REM Build libassimp for debug
  echo Building libassimp for debug...
  cd "%FILAMENT_BASE_DIR%\out"
  if not exist "cmake-debug-assimp" mkdir cmake-debug-assimp
  cd cmake-debug-assimp
  cmake -G "Visual Studio 17 2022" -T v142 ^
    -DCMAKE_BUILD_TYPE=Debug ^
    -DCMAKE_CXX_STANDARD=17 ^
    -DCMAKE_C_FLAGS=/I%FILAMENT_BASE_DIR%\third_party\libz ^
    -DCMAKE_CXX_FLAGS=/I%FILAMENT_BASE_DIR%\third_party\libz ^
    -DASSIMP_BUILD_ASSIMP_TOOLS=OFF ^
    -DASSIMP_BUILD_TESTS=OFF ^
    -DASSIMP_BUILD_SAMPLES=OFF ^
    -DASSIMP_WARNINGS_AS_ERRORS=OFF ^
    "%FILAMENT_BASE_DIR%\third_party\libassimp\tnt" || (
    echo Error: libassimp debug cmake configuration failed
    exit /b 1
  )
  cmake --build . --config Debug || (
    echo Error: libassimp debug build failed
    exit /b 1
  )
  cd "%FILAMENT_BASE_DIR%\out"

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

REM Copy header files to target directories (for inclusion in R2 upload zips)
echo Copying header files to target directories...

if "!BUILD_RELEASE!"=="true" (
  echo Copying headers to %TARGET_RELEASE_DIR%\include...
  mkdir "%TARGET_RELEASE_DIR%\include" 2>nul

  REM Copy all headers from install directory
  xcopy /E /I /Y "%FILAMENT_BASE_DIR%\out\install-release\include\*" "%TARGET_RELEASE_DIR%\include\" || (
    echo Error: Failed to copy release headers to target
    exit /b 1
  )

  REM Copy imageio headers
  xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\imageio\include\*" "%TARGET_RELEASE_DIR%\include\imageio\" || (
    echo Error: Failed to copy imageio headers to target
    exit /b 1
  )

  REM Copy bluevk headers (Windows-specific)
  if exist "%FILAMENT_BASE_DIR%\libs\bluevk\include\bluevk" (
    mkdir "%TARGET_RELEASE_DIR%\include\bluevk" 2>nul
    xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\bluevk\include\bluevk\*" "%TARGET_RELEASE_DIR%\include\bluevk\" 2>nul
  )

  REM Copy vulkan headers (Windows-specific)
  if exist "%FILAMENT_BASE_DIR%\libs\bluevk\include\vulkan" (
    mkdir "%TARGET_RELEASE_DIR%\include\vulkan" 2>nul
    xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\bluevk\include\vulkan\*" "%TARGET_RELEASE_DIR%\include\vulkan\" 2>nul
  )

  REM Copy vk_video headers (Windows-specific)
  if exist "%FILAMENT_BASE_DIR%\libs\bluevk\include\vk_video" (
    mkdir "%TARGET_RELEASE_DIR%\include\vk_video" 2>nul
    xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\bluevk\include\vk_video\*" "%TARGET_RELEASE_DIR%\include\vk_video\" 2>nul
  )

  REM Copy stb_image.h
  mkdir "%TARGET_RELEASE_DIR%\include\third_party\stb" 2>nul
  copy /Y "%FILAMENT_BASE_DIR%\third_party\stb\stb_image.h" "%TARGET_RELEASE_DIR%\include\third_party\stb\" || (
    echo Error: Failed to copy stb_image.h to target
    exit /b 1
  )

  REM Copy libassimp headers
  mkdir "%TARGET_RELEASE_DIR%\include\third_party\libassimp\include" 2>nul
  xcopy /E /I /Y "%FILAMENT_BASE_DIR%\third_party\libassimp\include\assimp" "%TARGET_RELEASE_DIR%\include\third_party\libassimp\include\assimp\" || (
    echo Error: Failed to copy assimp headers to target
    exit /b 1
  )

  REM Copy uberarchive.h for release
  mkdir "%TARGET_RELEASE_DIR%\include\release\gltfio\materials" 2>nul
  copy /Y "%FILAMENT_BASE_DIR%\out\install-release\include\gltfio\materials\uberarchive.h" "%TARGET_RELEASE_DIR%\include\release\gltfio\materials\" 2>nul
)

if "!BUILD_DEBUG!"=="true" (
  echo Copying headers to %TARGET_DEBUG_DIR%\include...
  mkdir "%TARGET_DEBUG_DIR%\include" 2>nul

  REM Copy all headers from install directory
  xcopy /E /I /Y "%FILAMENT_BASE_DIR%\out\install-debug\include\*" "%TARGET_DEBUG_DIR%\include\" || (
    echo Error: Failed to copy debug headers to target
    exit /b 1
  )

  REM Copy imageio headers
  xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\imageio\include\*" "%TARGET_DEBUG_DIR%\include\imageio\" || (
    echo Error: Failed to copy imageio headers to target
    exit /b 1
  )

  REM Copy bluevk headers (Windows-specific)
  if exist "%FILAMENT_BASE_DIR%\libs\bluevk\include\bluevk" (
    mkdir "%TARGET_DEBUG_DIR%\include\bluevk" 2>nul
    xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\bluevk\include\bluevk\*" "%TARGET_DEBUG_DIR%\include\bluevk\" 2>nul
  )

  REM Copy vulkan headers (Windows-specific)
  if exist "%FILAMENT_BASE_DIR%\libs\bluevk\include\vulkan" (
    mkdir "%TARGET_DEBUG_DIR%\include\vulkan" 2>nul
    xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\bluevk\include\vulkan\*" "%TARGET_DEBUG_DIR%\include\vulkan\" 2>nul
  )

  REM Copy vk_video headers (Windows-specific)
  if exist "%FILAMENT_BASE_DIR%\libs\bluevk\include\vk_video" (
    mkdir "%TARGET_DEBUG_DIR%\include\vk_video" 2>nul
    xcopy /E /I /Y "%FILAMENT_BASE_DIR%\libs\bluevk\include\vk_video\*" "%TARGET_DEBUG_DIR%\include\vk_video\" 2>nul
  )

  REM Copy stb_image.h
  mkdir "%TARGET_DEBUG_DIR%\include\third_party\stb" 2>nul
  copy /Y "%FILAMENT_BASE_DIR%\third_party\stb\stb_image.h" "%TARGET_DEBUG_DIR%\include\third_party\stb\" || (
    echo Error: Failed to copy stb_image.h to target
    exit /b 1
  )

  REM Copy libassimp headers
  mkdir "%TARGET_DEBUG_DIR%\include\third_party\libassimp\include" 2>nul
  xcopy /E /I /Y "%FILAMENT_BASE_DIR%\third_party\libassimp\include\assimp" "%TARGET_DEBUG_DIR%\include\third_party\libassimp\include\assimp\" || (
    echo Error: Failed to copy assimp headers to target
    exit /b 1
  )

  REM Copy uberarchive.h for debug
  mkdir "%TARGET_DEBUG_DIR%\include\debug\gltfio\materials" 2>nul
  copy /Y "%FILAMENT_BASE_DIR%\out\install-debug\include\gltfio\materials\uberarchive.h" "%TARGET_DEBUG_DIR%\include\debug\gltfio\materials\" 2>nul
)

REM Copy header files to thermion_dart
set "COPY_HEADERS_OPTS="
if "!BUILD_RELEASE!"=="true" if "!BUILD_DEBUG!"=="false" set "COPY_HEADERS_OPTS=--release"
if "!BUILD_DEBUG!"=="true" if "!BUILD_RELEASE!"=="false" set "COPY_HEADERS_OPTS=--debug"

call "%SCRIPT_DIR%copy_headers.bat" "%FILAMENT_BASE_DIR%" !COPY_HEADERS_OPTS! || (
  echo Error: Failed to copy headers
  exit /b 1
)

REM Obtain vulkan-1.lib (Vulkan loader import lib; version-independent, not
REM Filament-specific). The Filament build above already linked against the
REM runner's Vulkan SDK (-DFILAMENT_SUPPORTS_VULKAN=ON), so prefer copying
REM vulkan-1.lib from that SDK. Fall back to a cached R2 vulkan zip only if the
REM SDK is absent -- the version-specific zip does not exist for a first-time
REM version build, so the download alone cannot bootstrap a new Filament version.
set "VULKAN_LIB_URL=https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/filament-v1.74.0-windows-release-vulkan.zip"
set "VULKAN_LIB_ZIP=%OUTPUT_BASE_DIR%\vulkan-1-temp.zip"
set "VULKAN_LIB_EXTRACT=%OUTPUT_BASE_DIR%\vulkan-1-temp"

if exist "%OUTPUT_BASE_DIR%\vulkan-1.lib" (
  echo Using cached vulkan-1.lib from: %OUTPUT_BASE_DIR%\vulkan-1.lib
  goto :vulkan_done
)

REM 1) Runner Vulkan SDK (VULKAN_SDK env var, set by the LunarG installer).
if exist "%VULKAN_SDK%\Lib\vulkan-1.lib" (
  copy /Y "%VULKAN_SDK%\Lib\vulkan-1.lib" "%OUTPUT_BASE_DIR%\vulkan-1.lib" >nul
  echo Copied vulkan-1.lib from Vulkan SDK: %VULKAN_SDK%\Lib\vulkan-1.lib
  goto :vulkan_done
)

REM 2) Runner Vulkan SDK (glob, in case the env var is unset).
for %%F in ("C:\VulkanSDK\*\Lib\vulkan-1.lib") do (
  copy /Y "%%F" "%OUTPUT_BASE_DIR%\vulkan-1.lib" >nul
  echo Copied vulkan-1.lib from: %%F
  goto :vulkan_done
)

REM 3) Fall back to a cached R2 vulkan zip.
echo Vulkan SDK not found on runner; downloading vulkan-1.lib from R2...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%VULKAN_LIB_URL%' -OutFile '%VULKAN_LIB_ZIP%'" || (
  echo Error: Failed to download filament v1.74.0 vulkan zip
  exit /b 1
)
echo Extracting vulkan-1.lib from zip...
if exist "%VULKAN_LIB_EXTRACT%" rmdir /s /q "%VULKAN_LIB_EXTRACT%"
mkdir "%VULKAN_LIB_EXTRACT%"
powershell -Command "Expand-Archive -Path '%VULKAN_LIB_ZIP%' -DestinationPath '%VULKAN_LIB_EXTRACT%' -Force" || (
  echo Error: Failed to extract filament v1.74.0 zip
  exit /b 1
)
if exist "%VULKAN_LIB_EXTRACT%\vulkan-1.lib" (
  copy /Y "%VULKAN_LIB_EXTRACT%\vulkan-1.lib" "%OUTPUT_BASE_DIR%\vulkan-1.lib" >nul
) else (
  echo Error: vulkan-1.lib not found in v1.74.0 zip
  echo Contents of extracted zip:
  dir /b "%VULKAN_LIB_EXTRACT%"
  exit /b 1
)
del /q "%VULKAN_LIB_ZIP%" 2>nul
rmdir /s /q "%VULKAN_LIB_EXTRACT%" 2>nul
echo vulkan-1.lib cached at: %OUTPUT_BASE_DIR%\vulkan-1.lib

:vulkan_done
if not exist "%OUTPUT_BASE_DIR%\vulkan-1.lib" (
  echo Error: could not obtain vulkan-1.lib from the Vulkan SDK or R2
  exit /b 1
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

endlocal
