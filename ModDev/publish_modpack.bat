@echo off
setlocal enabledelayedexpansion
title KIF Modpack Publisher
color 0A

echo ============================================
echo        KIF Modpack Publisher
echo ============================================
echo.
echo NOTE: Publishing modpacks requires write access
echo to the KIF-Mods repository. You must be on the
echo verified team with write permissions.
echo.

:: ==========================================
:: Step 0: Check/Install Git
:: ==========================================
where git >NUL 2>&1
if %errorlevel%==0 goto :git_ok

color 0E
echo [!] Git is not installed.
echo.
set /p installgit="Install Git automatically? (Y/N): "
if /i not "!installgit!"=="Y" (
    echo Install Git from: https://git-scm.com/downloads
    pause
    exit /b 1
)

where winget >NUL 2>&1
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] winget is not available.
    echo Please install Git manually from: https://git-scm.com/downloads
    pause
    exit /b 1
)

echo Installing Git via winget...
winget install Git.Git --accept-source-agreements --accept-package-agreements
echo.
echo Git installed! Please close and reopen this script.
pause
exit /b 0

:git_ok
echo [OK] Git is installed.
echo.

:: ==========================================
:: Step 1: GitHub Authentication
:: ==========================================
echo Checking GitHub authentication...
echo.

where gh >NUL 2>&1
if not %errorlevel%==0 goto :no_gh

:: gh CLI is available — check if logged in
gh auth status >NUL 2>&1
if %errorlevel%==0 goto :auth_done

echo [!] Not logged into GitHub.
echo.
echo Your browser will open to log into GitHub.
echo.
pause
gh auth login --hostname github.com --git-protocol https --web
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] GitHub login failed. Please try again.
    pause
    exit /b 1
)
echo.
echo Setting up Git credentials...
gh auth setup-git
echo.
color 0A
echo [OK] GitHub authentication complete!
goto :auth_done

:no_gh
echo GitHub CLI (gh) not found. Checking for existing credentials...
echo.

set "credhelper="
for /f "tokens=*" %%A in ('git config --global credential.helper 2^>NUL') do set "credhelper=%%A"
if defined credhelper (
    echo [OK] Git credential helper configured: !credhelper!
    goto :auth_done
)

color 0E
echo [!] No GitHub authentication found.
echo.
echo You have two options:
echo.
echo   1. Install GitHub CLI (RECOMMENDED - easiest)
echo      Then rerun this script.
echo.
echo   2. Use a Personal Access Token
echo      a. Go to: https://github.com/settings/tokens
echo      b. Click "Generate new token (classic)"
echo      c. Check the "repo" scope, generate it
echo      d. When Git asks for your password, paste the token
echo.
set /p authchoice="Install GitHub CLI now? (Y/N): "
if /i not "!authchoice!"=="Y" (
    echo.
    echo Continuing without auth setup.
    echo Git will prompt for credentials when pushing.
    echo Use your GitHub username and a Personal Access Token as password.
    echo.
    pause
    goto :auth_done
)

where winget >NUL 2>&1
if not %errorlevel%==0 (
    echo [ERROR] winget not available. Install gh manually from: https://cli.github.com
    pause
    exit /b 1
)

echo Installing GitHub CLI...
winget install GitHub.cli --accept-source-agreements --accept-package-agreements

where gh >NUL 2>&1
if not %errorlevel%==0 (
    echo.
    echo GitHub CLI installed! Please close and reopen this script to use it.
    pause
    exit /b 0
)

echo.
echo Running authentication...
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
echo.

:auth_done
color 0A

:: Git identity (needed for commits)
set "gituser="
set "gitemail="
for /f "tokens=*" %%A in ('git config --global user.name 2^>NUL') do set "gituser=%%A"
for /f "tokens=*" %%A in ('git config --global user.email 2^>NUL') do set "gitemail=%%A"

if not defined gituser (
    echo.
    set /p gituser="Enter your name for commits (e.g. John): "
    git config --global user.name "!gituser!"
)
if not defined gitemail (
    set /p gitemail="Enter your email for commits (e.g. john@example.com): "
    git config --global user.email "!gitemail!"
)

:: ==========================================
:: Find modpacks in ModDev
:: ==========================================
echo.
set "MODDEV=%~dp0"
set "REPO_DIR=%MODDEV%_repo_cache\mods"
set "REPO_URL=https://github.com/KIF-Mods/mods.git"
set count=0

echo Available modpacks in ModDev:
echo.
for /d %%D in ("%MODDEV%*") do (
    if exist "%%D\modpack.json" (
        set /a count+=1
        set "pack_!count!=%%~nxD"
        set "pack_path_!count!=%%D"
        echo   !count!. %%~nxD
    )
)

if %count%==0 (
    color 0E
    echo [!] No modpacks found in ModDev.
    echo     Use the in-game Modder Tools to create one first.
    pause
    exit /b 1
)

echo.
echo   0. Cancel
echo.
set /p choice="Select modpack to publish (number): "

if "%choice%"=="0" exit /b 0
if "%choice%"=="" exit /b 0

set "selected=!pack_%choice%!"
set "selected_path=!pack_path_%choice%!"

if not defined selected (
    echo [ERROR] Invalid selection.
    pause
    exit /b 1
)

echo.
echo Selected: %selected%
echo.

:: Validate modpack.json
findstr /C:"\"id\"" "%selected_path%\modpack.json" >NUL 2>&1
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] modpack.json is missing the "id" field.
    pause
    exit /b 1
)

findstr /C:"\"mods\"" "%selected_path%\modpack.json" >NUL 2>&1
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] modpack.json is missing the "mods" field.
    pause
    exit /b 1
)

:: ==========================================
:: Clone or update repo
:: ==========================================
echo ============================================
echo  Step 1: Syncing with GitHub...
echo ============================================
echo.

if exist "%REPO_DIR%\.git" goto :repo_pull

echo Cloning repository (first time setup)...
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
    echo Publishing modpacks requires write access to the
    echo KIF-Mods repository. You must be on the verified
    echo team with write permissions.
    echo.
    echo Contact a KIF-Mods admin to get added to the team.
    pause
    exit /b 1
)
popd

color 0A
echo [OK] You have WRITE access.
echo.

:: ==========================================
:: Copy modpack files
:: ==========================================
if not exist "%REPO_DIR%\modpacks" mkdir "%REPO_DIR%\modpacks"

if exist "%REPO_DIR%\modpacks\%selected%\modpack.json" (
    echo ============================================
    echo  Step 2: Updating existing modpack...
    echo ============================================
    echo.
    echo Modpack '%selected%' already exists. This will update it.
) else (
    echo ============================================
    echo  Step 2: Publishing new modpack...
    echo ============================================
    echo.
    echo Modpack '%selected%' is new and will be added.
)

echo.
set /p confirm="Continue? (Y/N): "
if /i not "%confirm%"=="Y" (
    echo Cancelled.
    pause
    exit /b 0
)

echo.
echo Copying files...
if not exist "%REPO_DIR%\modpacks\%selected%" mkdir "%REPO_DIR%\modpacks\%selected%"
xcopy /E /Y "%selected_path%\*" "%REPO_DIR%\modpacks\%selected%\" >NUL 2>&1
echo Done.

:: ==========================================
:: Commit and push
:: ==========================================
echo.
echo ============================================
echo  Step 3: Pushing to GitHub...
echo ============================================
echo.

pushd "%REPO_DIR%"
git add "modpacks\%selected%" 2>&1

:: Check if anything is actually staged
set "has_changes="
for /f "delims=" %%S in ('git status --porcelain "modpacks\%selected%" 2^>NUL') do set "has_changes=1"
if not defined has_changes (
    color 0E
    echo [!] No changes detected. Your modpack is already up to date.
    popd
    pause
    exit /b 0
)

git commit -m "Update modpack %selected%" 2>&1

git push origin main 2>&1
if %errorlevel%==0 goto :push_success
git push origin master 2>&1
if %errorlevel%==0 goto :push_success

popd
color 0C
echo [ERROR] Push failed.
pause
exit /b 1

:push_success
popd
echo.
color 0A
echo ============================================
echo  SUCCESS! Modpack '%selected%' is now LIVE.
echo ============================================
echo.
echo Players will see it in the in-game Mod Browser
echo under the Modpacks tab.
echo.
pause
exit /b 0