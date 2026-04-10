@echo off
setlocal enabledelayedexpansion

set "GODOT=C:\Program Files\Godot\Godot.exe"
set "PROJECT_DIR=%~dp0"
set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
set "BUILD_DIR=%PROJECT_DIR%\build"

set "PLATFORMS="
set "COUNT=0"

if "%~1"=="" goto :prompt

:parse_args
if "%~1"=="" goto :after_parse
if /i "%~1"=="--platform" (
    shift
    if /i "%~1"=="windows" (
        set /a COUNT+=1
        set "PLATFORMS=!PLATFORMS! windows"
    ) else if /i "%~1"=="macos" (
        set /a COUNT+=1
        set "PLATFORMS=!PLATFORMS! macos"
    ) else if /i "%~1"=="linux" (
        set /a COUNT+=1
        set "PLATFORMS=!PLATFORMS! linux"
    ) else (
        echo Unknown platform: %~1
        exit /b 1
    )
    shift
    goto :parse_args
) else (
    echo Unknown option: %~1
    exit /b 1
)

:prompt
set /p "choice=Platform? [w]indows / [l]inux / [m]acos / [enter] all: "
if /i "%choice%"=="w" (
    set "PLATFORMS=windows"
) else if /i "%choice%"=="l" (
    set "PLATFORMS=linux"
) else if /i "%choice%"=="m" (
    set "PLATFORMS=macos"
) else (
    set "PLATFORMS=windows linux macos"
)

:after_parse
echo === Cleaning build directory ===
for %%P in (%PLATFORMS%) do (
    if exist "%BUILD_DIR%\%%P" rd /s /q "%BUILD_DIR%\%%P"
    mkdir "%BUILD_DIR%\%%P"
)

echo === Importing project ===
"%GODOT%" --headless --path "%PROJECT_DIR%" --import 2>&1 || echo Import warnings (continuing)

for %%P in (%PLATFORMS%) do (
    if "%%P"=="windows" set "PRESET=Windows"
    if "%%P"=="linux" set "PRESET=Linux"
    if "%%P"=="macos" set "PRESET=macOS"
    echo === Exporting !PRESET! ===
    "%GODOT%" --headless --path "%PROJECT_DIR%" --export-release "!PRESET!" || (
        echo Export failed for !PRESET!
        exit /b 1
    )
)

echo === Zipping builds ===
for %%P in (%PLATFORMS%) do (
    pushd "%BUILD_DIR%\%%P"
    tar -a -cf "%BUILD_DIR%\ElderScrollsLegends-%%P.zip" *
    popd
)

echo === Done ===
for %%F in ("%BUILD_DIR%\ElderScrollsLegends-*.zip") do echo %%~nxF  %%~zF bytes

endlocal
