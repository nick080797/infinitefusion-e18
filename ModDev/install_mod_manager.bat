@echo off
setlocal enabledelayedexpansion
title KIF Mod Manager Installer
color 0A

echo ============================================
echo    KIF Mod Manager - Installer
echo ============================================
echo.
echo This will install the Mod Manager into your
echo KIF Multiplayer game folder.
echo.
echo IMPORTANT: Run this script from inside your
echo game folder (where Game.exe is located).
echo.

:: Check if we're in the right folder
if not exist "Game.exe" (
    if not exist "Game.rxproj" (
        color 0C
        echo [ERROR] Game.exe not found in the current folder.
        echo.
        echo Please move this script into your KIF Multiplayer
        echo game folder and run it again.
        echo.
        echo Your game folder is where Game.exe is located.
        echo.
        pause
        exit /b 1
    )
)

echo [OK] Game folder detected.
echo.

:: Check if already installed
if exist "Data\Scripts\998_ModManager\001_ModData.rb" (
    color 0E
    echo [!] Mod Manager is already installed.
    echo.
    set /p reinstall="Reinstall/Update? (Y/N): "
    if /i not "!reinstall!"=="Y" (
        echo Cancelled.
        pause
        exit /b 0
    )
    echo.
)

:: Download
set "DOWNLOAD_URL=https://github.com/KIF-Mods/mod-manager/raw/main/KIF-ModManager.rar"
set "TEMP_FILE=%TEMP%\KIF-ModManager.rar"
set "TEMP_DIR=%TEMP%\KIF-ModManager"

echo ============================================
echo  Step 1: Downloading Mod Manager...
echo ============================================
echo.

:: Try curl first (available on Windows 10+)
where curl >NUL 2>&1
if %errorlevel%==0 (
    curl --ssl-no-revoke -L -o "%TEMP_FILE%" "%DOWNLOAD_URL%" 2>&1
    goto :download_check
)

:: Try PowerShell as fallback
echo Using PowerShell to download...
powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%TEMP_FILE%'" 2>&1

:download_check
if not exist "%TEMP_FILE%" (
    color 0C
    echo [ERROR] Download failed. Check your internet connection.
    echo.
    echo You can manually download from:
    echo   %DOWNLOAD_URL%
    echo.
    echo Extract it into your game folder.
    pause
    exit /b 1
)

echo [OK] Downloaded successfully.
echo.

:: Extract
echo ============================================
echo  Step 2: Extracting files...
echo ============================================
echo.

:: Clean up any previous temp extraction
if exist "%TEMP_DIR%" rmdir /S /Q "%TEMP_DIR%" >NUL 2>&1

:: Try to extract RAR
:: Method 1: tar (Windows 10+ supports some archives)
:: Method 2: PowerShell Expand-Archive (only works with zip)
:: Method 3: Check for WinRAR or 7zip

where unrar >NUL 2>&1
if %errorlevel%==0 (
    echo Extracting with unrar...
    unrar x -o+ "%TEMP_FILE%" "%TEMP%" >NUL 2>&1
    goto :extract_check
)

:: Check for WinRAR
if exist "C:\Program Files\WinRAR\UnRAR.exe" (
    echo Extracting with WinRAR...
    "C:\Program Files\WinRAR\UnRAR.exe" x -o+ "%TEMP_FILE%" "%TEMP%\" >NUL 2>&1
    goto :extract_check
)

if exist "C:\Program Files (x86)\WinRAR\UnRAR.exe" (
    echo Extracting with WinRAR...
    "C:\Program Files (x86)\WinRAR\UnRAR.exe" x -o+ "%TEMP_FILE%" "%TEMP%\" >NUL 2>&1
    goto :extract_check
)

:: Check for 7-Zip
if exist "C:\Program Files\7-Zip\7z.exe" (
    echo Extracting with 7-Zip...
    "C:\Program Files\7-Zip\7z.exe" x -o"%TEMP_DIR%" -y "%TEMP_FILE%" >NUL 2>&1
    goto :extract_check
)

if exist "C:\Program Files (x86)\7-Zip\7z.exe" (
    echo Extracting with 7-Zip...
    "C:\Program Files (x86)\7-Zip\7z.exe" x -o"%TEMP_DIR%" -y "%TEMP_FILE%" >NUL 2>&1
    goto :extract_check
)

:: No extractor found
color 0C
echo [ERROR] No RAR extractor found.
echo.
echo Please install one of the following:
echo   - WinRAR: https://www.win-rar.com/download.html
echo   - 7-Zip:  https://www.7-zip.org/download.html
echo.
echo Or manually extract the file:
echo   %TEMP_FILE%
echo into your game folder.
echo.
del "%TEMP_FILE%" >NUL 2>&1
pause
exit /b 1

:extract_check
:: Find the extracted folder (could be TEMP_DIR or TEMP\KIF-ModManager)
set "SOURCE="
if exist "%TEMP_DIR%\Data" set "SOURCE=%TEMP_DIR%"
if exist "%TEMP%\KIF-ModManager\Data" set "SOURCE=%TEMP%\KIF-ModManager"

if not defined SOURCE (
    :: Check one level deeper in case of double nesting
    for /d %%D in ("%TEMP_DIR%\*") do (
        if exist "%%D\Data" set "SOURCE=%%D"
    )
    for /d %%D in ("%TEMP%\KIF-ModManager\*") do (
        if exist "%%D\Data" set "SOURCE=%%D"
    )
)

if not defined SOURCE (
    color 0C
    echo [ERROR] Extraction failed or unexpected archive structure.
    echo.
    echo Please manually extract:
    echo   %TEMP_FILE%
    echo into your game folder.
    pause
    exit /b 1
)

echo [OK] Extracted successfully.
echo.

:: Install
echo ============================================
echo  Step 3: Installing files...
echo ============================================
echo.

:: Create directories
if not exist "Data\Scripts\998_ModManager" mkdir "Data\Scripts\998_ModManager"
if not exist "Mods" mkdir "Mods"
if not exist "ModDev" mkdir "ModDev"

:: Copy files
echo Copying 998_ModManager scripts...
xcopy /E /Y "!SOURCE!\Data\Scripts\998_ModManager\*" "Data\Scripts\998_ModManager\" >NUL 2>&1

echo Copying Mods bootstrap...
if exist "!SOURCE!\Mods\000_mod_manager_loader.rb" (
    copy /Y "!SOURCE!\Mods\000_mod_manager_loader.rb" "Mods\" >NUL 2>&1
)
if exist "!SOURCE!\Mods\.mod_browser_enabled" (
    copy /Y "!SOURCE!\Mods\.mod_browser_enabled" "Mods\" >NUL 2>&1
)

echo Copying ModDev tools...
if exist "!SOURCE!\ModDev\publish_mod.bat" (
    copy /Y "!SOURCE!\ModDev\publish_mod.bat" "ModDev\" >NUL 2>&1
)
if exist "!SOURCE!\ModDev\publish_mod.sh" (
    copy /Y "!SOURCE!\ModDev\publish_mod.sh" "ModDev\" >NUL 2>&1
)
if exist "!SOURCE!\ModDev\install_multiplayer.bat" (
    copy /Y "!SOURCE!\ModDev\install_multiplayer.bat" "ModDev\" >NUL 2>&1
)
if exist "!SOURCE!\ModDev\install_multiplayer.sh" (
    copy /Y "!SOURCE!\ModDev\install_multiplayer.sh" "ModDev\" >NUL 2>&1
)
if exist "!SOURCE!\ModDev\delete_mod.bat" (
    copy /Y "!SOURCE!\ModDev\delete_mod.bat" "ModDev\" >NUL 2>&1
)
if exist "!SOURCE!\ModDev\delete_mod.sh" (
    copy /Y "!SOURCE!\ModDev\delete_mod.sh" "ModDev\" >NUL 2>&1
)
if exist "!SOURCE!\ModDev\install_npt.bat" (
    copy /Y "!SOURCE!\ModDev\install_npt.bat" "ModDev\" >NUL 2>&1
)
if exist "!SOURCE!\ModDev\install_npt.sh" (
    copy /Y "!SOURCE!\ModDev\install_npt.sh" "ModDev\" >NUL 2>&1
)

:: Cleanup temp files
echo Cleaning up...
del "%TEMP_FILE%" >NUL 2>&1
rmdir /S /Q "%TEMP_DIR%" >NUL 2>&1
rmdir /S /Q "%TEMP%\KIF-ModManager" >NUL 2>&1

echo.
color 0A
echo ============================================
echo  SUCCESS! Mod Manager installed!
echo ============================================
echo.
echo What was installed:
echo   - Data\Scripts\998_ModManager\  (core scripts)
echo   - Mods\000_mod_manager_loader.rb  (bootstrap)
echo   - Mods\.mod_browser_enabled  (enables Mod Browser)
echo   - ModDev\publish_mod.bat  (mod publisher)
echo   - ModDev\publish_mod.sh  (mod publisher for Mac/Linux)
echo   - ModDev\install_multiplayer.bat  (MP installer)
echo   - ModDev\install_multiplayer.sh  (MP installer for Mac/Linux)
echo   - ModDev\delete_mod.bat  (repo mod deleter)
echo   - ModDev\delete_mod.sh  (repo mod deleter for Mac/Linux)
echo.
echo Launch the game and look for "Mod Manager"
echo on the title screen!
echo.
pause
exit /b 0