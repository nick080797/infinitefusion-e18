@echo off
setlocal enabledelayedexpansion
title KIF Modpack Deleter
color 0A

echo ============================================
echo        KIF Modpack Deleter
echo ============================================
echo.
echo NOTE: Deleting modpacks from the repo requires
echo write access. You must be on the verified team.
echo.

:: ==========================================
:: Step 0: Check Git
:: ==========================================
where git >NUL 2>&1
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] Git is not installed.
    echo Run publish_mod.bat first to set up Git and authentication.
    pause
    exit /b 1
)

echo [OK] Git is installed.
echo.

:: ==========================================
:: Step 1: GitHub Authentication check
:: ==========================================
echo Checking GitHub authentication...
echo.

where gh >NUL 2>&1
if not %errorlevel%==0 goto :check_cred

:: gh CLI is available — check if logged in
gh auth status >NUL 2>&1
if %errorlevel%==0 (
    echo [OK] Authenticated via GitHub CLI.
    goto :auth_done
)

:check_cred
set "credhelper="
for /f "tokens=*" %%A in ('git config --global credential.helper 2^>NUL') do set "credhelper=%%A"
if defined credhelper (
    echo [OK] Git credential helper configured: !credhelper!
    goto :auth_done
)

color 0E
echo [!] No GitHub authentication found.
echo Run publish_mod.bat first to set up authentication.
echo Git will prompt for credentials when pushing.
echo.

:auth_done
color 0A
echo.

:: ==========================================
:: Sync repo
:: ==========================================
set "MODDEV=%~dp0"
set "REPO_DIR=%MODDEV%_repo_cache\mods"
set "REPO_URL=https://github.com/KIF-Mods/mods.git"

echo ============================================
echo  Step 1: Syncing with GitHub...
echo ============================================
echo.

if exist "%REPO_DIR%\.git" goto :repo_pull

echo Cloning repository...
if not exist "%MODDEV%_repo_cache" mkdir "%MODDEV%_repo_cache"
git clone "%REPO_URL%" "%REPO_DIR%" 2>&1
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] Could not clone the repository.
    pause
    exit /b 1
)
goto :repo_ready

:repo_pull
echo Updating local repo cache...
pushd "%REPO_DIR%"
git pull origin main 2>&1
if not %errorlevel%==0 git pull origin master 2>&1
popd

:repo_ready

:: ==========================================
:: List modpacks in the repo
:: ==========================================
echo.
echo ============================================
echo  Step 2: Select modpack to delete
echo ============================================
echo.

set count=0
echo Modpacks in the repository:
echo.
for /d %%D in ("%REPO_DIR%\modpacks\*") do (
    if exist "%%D\modpack.json" (
        set "dirname=%%~nxD"
        set /a count+=1
        set "pack_!count!=!dirname!"
        echo   !count!. !dirname!
    )
)

if %count%==0 (
    color 0E
    echo [!] No modpacks found in the repository.
    pause
    exit /b 1
)

echo.
echo   0. Cancel
echo.
set /p choice="Select modpack to DELETE from the repo (number): "

if "%choice%"=="0" exit /b 0
if "%choice%"=="" exit /b 0

set "selected=!pack_%choice%!"

if not defined selected (
    echo [ERROR] Invalid selection.
    pause
    exit /b 1
)

:: ==========================================
:: Ownership check (requires gh auth)
:: ==========================================
echo.
echo Verifying ownership...

where gh >NUL 2>&1
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] GitHub CLI (gh) is required to delete modpacks.
    echo Run publish_mod.bat first to set up authentication.
    pause
    exit /b 1
)

gh auth status >NUL 2>&1
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] Not logged into GitHub.
    echo Run publish_mod.bat first to authenticate.
    pause
    exit /b 1
)

set "gh_user="
for /f "tokens=*" %%A in ('gh api user -q ".login" 2^>NUL') do set "gh_user=%%A"

if not defined gh_user (
    color 0C
    echo [ERROR] Could not get your GitHub username.
    pause
    exit /b 1
)

set "pack_author="
if exist "%REPO_DIR%\modpacks\!selected!\modpack.json" (
    for /f "tokens=2 delims=:" %%A in ('findstr /C:"\"author\"" "%REPO_DIR%\modpacks\!selected!\modpack.json"') do (
        set "pack_author=%%~A"
    )
)
if defined pack_author (
    set "pack_author=!pack_author: =!"
    set "pack_author=!pack_author:"=!"
    set "pack_author=!pack_author:,=!"
)

if defined pack_author (
    if /i not "!pack_author!"=="!gh_user!" (
        color 0C
        echo [ERROR] You are not the author of this modpack.
        echo.
        echo   Modpack author: !pack_author!
        echo   Logged in as:   !gh_user!
        echo.
        echo Only the modpack author can delete their own modpack.
        pause
        exit /b 1
    )
    color 0A
    echo [OK] Verified: you are the author (!gh_user!^).
) else (
    color 0E
    echo [!] Could not read author from modpack.json. Proceeding...
)

echo.
color 0E
echo WARNING: This will permanently delete modpack '%selected%'
echo from the KIF-Mods repository. Players will no longer
echo be able to find or install this modpack.
echo.
set /p confirm_name="Type the modpack name to confirm: "

if not "!confirm_name!"=="!selected!" (
    echo.
    echo Names don't match. Cancelled.
    pause
    exit /b 0
)

:: ==========================================
:: Check write access (REQUIRED for modpacks)
:: ==========================================
echo.
echo Checking your access level...

pushd "%REPO_DIR%"
git push --dry-run origin main >NUL 2>&1
if not %errorlevel%==0 (
    popd
    color 0C
    echo [ERROR] You do NOT have write access to the repo.
    echo.
    echo Deleting modpacks requires write access to the
    echo KIF-Mods repository. You must be on the verified
    echo team with write permissions.
    echo.
    echo Contact a KIF-Mods admin if you need access.
    pause
    exit /b 1
)
popd

color 0A
echo [OK] Write access confirmed.
echo.

:: ==========================================
:: Delete and push
:: ==========================================
echo ============================================
echo  Step 3: Deleting from GitHub...
echo ============================================
echo.

pushd "%REPO_DIR%"
rmdir /s /q "modpacks\%selected%" 2>NUL
git add -A "modpacks\%selected%" 2>&1
git commit -m "Delete modpack %selected%" 2>&1

git push origin main 2>&1
if %errorlevel%==0 goto :delete_success
git push origin master 2>&1
if %errorlevel%==0 goto :delete_success

popd
color 0C
echo [ERROR] Push failed.
pause
exit /b 1

:delete_success
popd
echo.
color 0A
echo ============================================
echo  DONE! Modpack '%selected%' has been deleted.
echo ============================================
echo.
echo The modpack has been removed from the repository.
echo Players will no longer see it in the Mod Browser.
echo.
pause
exit /b 0