@echo off
setlocal enabledelayedexpansion
title Aleks Full Implementation Installer
color 0A

echo ============================================
echo   Aleks Full Implementation - Installer
echo ============================================
echo.

:: Args: version, mode, game_root
::   mode: "full" = code + assets, "code" = code only
set "TARGET_VERSION=%~1"
set "INSTALL_MODE=%~2"
set "GAME_ROOT=%~3"

if "%GAME_ROOT%"=="" set "GAME_ROOT=%~dp0.."
:: Remove trailing backslash
if "%GAME_ROOT:~-1%"=="\" set "GAME_ROOT=%GAME_ROOT:~0,-1%"
if "%TARGET_VERSION%"=="" set "TARGET_VERSION=unknown"
if "%INSTALL_MODE%"=="" set "INSTALL_MODE=full"

echo  Version:  %TARGET_VERSION%
echo  Mode:     %INSTALL_MODE%
echo  Game Dir: %GAME_ROOT%
echo.

:: ── GitHub Release URLs ─────────────────────────────────────────────
set "REPO=sKarreku/Aleks-Full-Implementation"
set "BASE_URL=https://github.com/%REPO%/releases/latest/download"

:: ── Find 7z.exe ─────────────────────────────────────────────────────
set "SEVENZ="
if exist "%GAME_ROOT%\REQUIRED_BY_INSTALLER_UPDATER\7z.exe" (
    set "SEVENZ=%GAME_ROOT%\REQUIRED_BY_INSTALLER_UPDATER\7z.exe"
    goto :found_7z
)
if exist "C:\Program Files\7-Zip\7z.exe" (
    set "SEVENZ=C:\Program Files\7-Zip\7z.exe"
    goto :found_7z
)
if exist "C:\Program Files (x86)\7-Zip\7z.exe" (
    set "SEVENZ=C:\Program Files (x86)\7-Zip\7z.exe"
    goto :found_7z
)
where 7z >NUL 2>&1
if %errorlevel%==0 (
    set "SEVENZ=7z"
    goto :found_7z
)
color 0C
echo [ERROR] 7-Zip not found.
echo Please install 7-Zip from: https://www.7-zip.org/download.html
pause
exit /b 1

:found_7z
echo  7z:       %SEVENZ%
echo.

:: ── Step 1: Download manifest ───────────────────────────────────────
echo ============================================
echo  Step 1: Fetching manifest...
echo ============================================
echo.

set "TEMP_DIR=%TEMP%\aleks_npt_%TARGET_VERSION%_%RANDOM%"
mkdir "%TEMP_DIR%" >NUL 2>&1

:: ── Construct filenames from version (no manifest needed) ───────────
set "CODE_FILE=v%TARGET_VERSION%_code.7z"

:: Asset part count: download manifest to get parts count, fallback to scanning
set "ASSET_PARTS=0"
set "MANIFEST=%TEMP_DIR%\manifest.json"
call :download_file "%BASE_URL%/manifest.json" "%MANIFEST%"
if exist "%MANIFEST%" (
    for /f "delims=" %%A in ('powershell -NoProfile -Command "try { (Get-Content '%MANIFEST%' | ConvertFrom-Json).assets.parts } catch { 0 }"') do set "ASSET_PARTS=%%A"
)
:: Fallback: count parts by probing (up to 9)
if "%ASSET_PARTS%"=="0" (
    set "ASSET_PARTS=0"
    for /l %%N in (1,1,9) do (
        set "PROBE_FILE=v%TARGET_VERSION%_assets.7z.00%%N"
        curl --ssl-no-revoke -L --fail --head -o NUL -s "%BASE_URL%/!PROBE_FILE!" && set /a "ASSET_PARTS=%%N"
    )
)

echo  Code file:    %CODE_FILE%
echo  Asset parts:  %ASSET_PARTS%
echo.

:: ── Step 2: Download archives ───────────────────────────────────────
echo ============================================
echo  Step 2: Downloading v%TARGET_VERSION% (%INSTALL_MODE%)...
echo ============================================
echo.

:: Always download code
echo Downloading %CODE_FILE%...
call :download_file "%BASE_URL%/%CODE_FILE%" "%TEMP_DIR%\%CODE_FILE%"
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Failed to download code archive.
    goto :cleanup_fail
)
echo [OK] Code archive downloaded.
echo.

:: Download asset parts if full mode
if /i not "%INSTALL_MODE%"=="full" goto :skip_asset_download

echo Downloading %ASSET_PARTS% asset parts...
echo This may take a while (~10 GB total).
echo.

set "PART_NUM=0"
set "PART_TOTAL=%ASSET_PARTS%"
:download_loop
set /a "PART_NUM+=1"
if %PART_NUM% gtr %PART_TOTAL% goto :download_done
set "PART_FILE=v%TARGET_VERSION%_assets.7z.00%PART_NUM%"
echo   [%PART_NUM%/%PART_TOTAL%] Downloading %PART_FILE%...
call :download_file "%BASE_URL%/%PART_FILE%" "%TEMP_DIR%\%PART_FILE%"
if not exist "%TEMP_DIR%\%PART_FILE%" (
    color 0C
    echo [ERROR] Failed to download %PART_FILE%
    goto :cleanup_fail
)
echo   [OK] %PART_FILE% downloaded.
goto :download_loop
:download_done
echo.
echo [OK] All asset parts downloaded.
echo.

:skip_asset_download

:: ── Step 3: Extract ─────────────────────────────────────────────────
echo ============================================
echo  Step 3: Extracting files...
echo ============================================
echo.

set "EXTRACT_TEMP=%TEMP_DIR%\extract"
mkdir "%EXTRACT_TEMP%" >NUL 2>&1

:: Extract code archive
echo Extracting code...
"%SEVENZ%" x -y -o"%EXTRACT_TEMP%" "%TEMP_DIR%\%CODE_FILE%"
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Code extraction failed.
    goto :cleanup_fail
)
echo [OK] Code extracted.
echo.

:: Extract assets (7z auto-finds .002, .003 etc. from .001)
if /i not "%INSTALL_MODE%"=="full" goto :skip_asset_extract

set "FIRST_PART=v%TARGET_VERSION%_assets.7z.001"
echo Extracting assets from %FIRST_PART% (%ASSET_PARTS% volumes)...
echo This may take several minutes...
"%SEVENZ%" x -y -o"%EXTRACT_TEMP%" "%TEMP_DIR%\!FIRST_PART!"
if !errorlevel! neq 0 (
    color 0C
    echo [ERROR] Asset extraction failed.
    goto :cleanup_fail
)
echo [OK] Assets extracted.
echo.

:skip_asset_extract

:: ── Step 4: Merge into game directory ───────────────────────────────
echo ============================================
echo  Step 4: Installing to game directory...
echo ============================================
echo.

:: Check if there's a top-level wrapper folder
set "MERGE_SRC=%EXTRACT_TEMP%"
set "HAS_INNER=0"
for /d %%D in ("%EXTRACT_TEMP%\*") do (
    :: If there's a Data or Graphics folder directly, no wrapper
    if exist "%EXTRACT_TEMP%\Data" goto :no_wrapper
    if exist "%EXTRACT_TEMP%\Graphics" goto :no_wrapper
    if exist "%EXTRACT_TEMP%\Audio" goto :no_wrapper
    set "MERGE_SRC=%%D"
    set "HAS_INNER=1"
    goto :no_wrapper
)
:no_wrapper

echo Merging from: %MERGE_SRC%
echo Into:         %GAME_ROOT%
echo.

robocopy "%MERGE_SRC%" "%GAME_ROOT%" /E /NFL /NDL /NJH /NJS /NC /NS

if %errorlevel% GEQ 8 (
    color 0C
    echo [ERROR] Failed to copy files to game directory.
    goto :cleanup_fail
)

echo.
echo [OK] Files installed successfully.
echo.

:: ── Step 5: Cleanup ─────────────────────────────────────────────────
echo Cleaning up temporary files...
rmdir /s /q "%TEMP_DIR%" >NUL 2>&1

echo.
color 0A
echo ============================================
if /i "%INSTALL_MODE%"=="full" (
    echo  SUCCESS! AFI v%TARGET_VERSION% fully installed!
) else (
    echo  SUCCESS! AFI v%TARGET_VERSION% code updated!
)
echo ============================================
echo.
echo Restart the game to apply changes.
echo.
pause
exit /b 0

:: ── Cleanup on failure ──────────────────────────────────────────────
:cleanup_fail
echo.
echo Cleaning up...
rmdir /s /q "%TEMP_DIR%" >NUL 2>&1
echo.
pause
exit /b 1

:: ── Download helper ─────────────────────────────────────────────────
:: Usage: call :download_file "URL" "OUTPUT_PATH"
:download_file
set "DL_URL=%~1"
set "DL_OUT=%~2"

:: Try curl first
where curl >NUL 2>&1
if %errorlevel%==0 (
    curl --ssl-no-revoke -L --progress-bar --fail -o "%DL_OUT%" "%DL_URL%"
    if %errorlevel%==0 exit /b 0
)

:: PowerShell fallback
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'Continue'; Invoke-WebRequest -Uri '%DL_URL%' -OutFile '%DL_OUT%'" 2>&1
if exist "%DL_OUT%" exit /b 0

exit /b 1