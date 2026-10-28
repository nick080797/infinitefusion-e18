@echo off
setlocal enabledelayedexpansion
title KIF Multiplayer Installer
color 0A

echo ============================================
echo    KIF Multiplayer Installer
echo ============================================
echo.

:: Read version to install (passed as argument or fetch latest)
set "TARGET_VERSION=%~1"
set "ARCHIVE_URL=%~2"
set "GAME_ROOT=%~3"

if "%GAME_ROOT%"=="" set "GAME_ROOT=%~dp0"
:: Remove trailing backslash from GAME_ROOT
if "%GAME_ROOT:~-1%"=="\" set "GAME_ROOT=%GAME_ROOT:~0,-1%"

:: If no version provided, fetch latest
if "%TARGET_VERSION%"=="" (
    echo Fetching latest version...
    for /f "delims=" %%V in ('curl --ssl-no-revoke -s -L "https://raw.githubusercontent.com/sKarreku/KIF-Multiplayer/main/version.txt" 2^>NUL') do set "TARGET_VERSION=%%V"
    if "!TARGET_VERSION!"=="" (
        color 0C
        echo [ERROR] Could not fetch latest version.
        pause
        exit /b 1
    )
    set "ARCHIVE_URL=https://media.githubusercontent.com/media/sKarreku/KIF-Multiplayer/main/updates/!TARGET_VERSION!/v!TARGET_VERSION!.7z"
)

echo.
echo Version:  %TARGET_VERSION%
echo Archive:  %ARCHIVE_URL%
echo Game Dir: %GAME_ROOT%
echo.

:: Step 1: Download
echo ============================================
echo  Step 1: Downloading v%TARGET_VERSION%...
echo ============================================
echo.
echo This may take a few minutes depending on your
echo internet connection (~100 MB).
echo.

set "TEMP_FILE=%TEMP%\KIF_Multiplayer_v%TARGET_VERSION%.7z"

:: Delete old temp file if exists
if exist "%TEMP_FILE%" del "%TEMP_FILE%" >NUL 2>&1

:: Try curl first
where curl >NUL 2>&1
if %errorlevel%==0 (
    curl --ssl-no-revoke -L --progress-bar -o "%TEMP_FILE%" "%ARCHIVE_URL%"
    goto :download_check
)

:: PowerShell fallback
echo Using PowerShell to download...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'Continue'; Invoke-WebRequest -Uri '%ARCHIVE_URL%' -OutFile '%TEMP_FILE%'" 2>&1

:download_check
if not exist "%TEMP_FILE%" (
    color 0C
    echo.
    echo [ERROR] Download failed. Check your internet connection.
    echo.
    pause
    exit /b 1
)

:: Check file size (should be > 1MB at least)
for %%A in ("%TEMP_FILE%") do set "FILESIZE=%%~zA"
if %FILESIZE% LSS 1000000 (
    color 0C
    echo.
    echo [ERROR] Downloaded file is too small (%FILESIZE% bytes^).
    echo The download may have failed or the version may not exist.
    echo.
    del "%TEMP_FILE%" >NUL 2>&1
    pause
    exit /b 1
)

echo.
echo [OK] Downloaded successfully.
echo.

:: Step 2: Extract
echo ============================================
echo  Step 2: Extracting files...
echo ============================================
echo.

:: Find 7z.exe
set "SEVENZ="

:: Check bundled copy first
if exist "%GAME_ROOT%\REQUIRED_BY_INSTALLER_UPDATER\7z.exe" (
    set "SEVENZ=%GAME_ROOT%\REQUIRED_BY_INSTALLER_UPDATER\7z.exe"
    echo Using bundled 7z.exe
    goto :do_extract
)

:: Check common locations
if exist "C:\Program Files\7-Zip\7z.exe" (
    set "SEVENZ=C:\Program Files\7-Zip\7z.exe"
    echo Using 7-Zip from Program Files
    goto :do_extract
)
if exist "C:\Program Files (x86)\7-Zip\7z.exe" (
    set "SEVENZ=C:\Program Files (x86)\7-Zip\7z.exe"
    echo Using 7-Zip from Program Files (x86^)
    goto :do_extract
)

:: Check PATH
where 7z >NUL 2>&1
if %errorlevel%==0 (
    set "SEVENZ=7z"
    echo Using 7z from PATH
    goto :do_extract
)

:: No 7z found
color 0C
echo [ERROR] 7-Zip not found.
echo.
echo Please install 7-Zip from: https://www.7-zip.org/download.html
echo Or place 7z.exe in: %GAME_ROOT%\REQUIRED_BY_INSTALLER_UPDATER\
echo.
del "%TEMP_FILE%" >NUL 2>&1
pause
exit /b 1

:do_extract
echo Extracting to game directory...
echo This may take a moment...
echo.

"%SEVENZ%" x -y -o"%GAME_ROOT%" "%TEMP_FILE%"

if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [ERROR] Extraction failed.
    echo.
    del "%TEMP_FILE%" >NUL 2>&1
    pause
    exit /b 1
)

echo.
echo [OK] Extracted successfully.
echo.

:: Step 3: Cleanup
echo Cleaning up...
del "%TEMP_FILE%" >NUL 2>&1

echo.
color 0A
echo ============================================
echo  SUCCESS! KIF Multiplayer v%TARGET_VERSION% installed!
echo ============================================
echo.
echo Restart the game to apply changes.
echo.
pause
exit /b 0
