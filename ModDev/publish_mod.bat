@echo off
setlocal enabledelayedexpansion
title KIF Mod Publisher
color 0A

echo ============================================
echo        KIF Mod Publisher
echo ============================================
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
:: Find mods in ModDev
:: ==========================================
echo.
set "MODDEV=%~dp0"
set "REPO_DIR=%MODDEV%_repo_cache\mods"
set "REPO_URL=https://github.com/KIF-Mods/mods.git"
set count=0

echo Available mods in ModDev:
echo.
for /d %%D in ("%MODDEV%*") do (
    if exist "%%D\mod.json" (
        set /a count+=1
        set "mod_!count!=%%~nxD"
        set "mod_path_!count!=%%D"
        echo   !count!. %%~nxD
    )
)

if %count%==0 (
    color 0E
    echo [!] No mods found in ModDev.
    echo     Use the in-game Modder Tools to create one first.
    pause
    exit /b 1
)

echo.
echo   0. Cancel
echo.
set /p choice="Select mod to publish (number): "

if "%choice%"=="0" exit /b 0
if "%choice%"=="" exit /b 0

set "selected=!mod_%choice%!"
set "selected_path=!mod_path_%choice%!"

if not defined selected (
    echo [ERROR] Invalid selection.
    pause
    exit /b 1
)

echo.
echo Selected: %selected%
echo.

:: Validate mod.json
findstr /C:"\"id\"" "%selected_path%\mod.json" >NUL 2>&1
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] mod.json is missing the "id" field.
    pause
    exit /b 1
)

findstr /C:"\"version\"" "%selected_path%\mod.json" >NUL 2>&1
if not %errorlevel%==0 (
    color 0C
    echo [ERROR] mod.json is missing the "version" field.
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
:: Check write access
:: ==========================================
echo.
echo Checking your access level...

pushd "%REPO_DIR%"
git push --dry-run origin main >NUL 2>&1
if %errorlevel%==0 (
    set "access_mode=direct"
) else (
    set "access_mode=fork"
)
popd

if "!access_mode!"=="direct" (
    color 0A
    echo [OK] You have WRITE access — your mod will be published immediately.
) else (
    color 0E
    echo [!] You do NOT have write access to the main repo.
    echo     Your mod will be prepared locally.
)

echo.

:: ==========================================
:: Copy mod files
:: ==========================================
if exist "%REPO_DIR%\%selected%\mod.json" (
    echo ============================================
    echo  Step 2: Updating existing mod...
    echo ============================================
    echo.
    echo Mod '%selected%' already exists. This will update it.
) else (
    echo ============================================
    echo  Step 2: Publishing new mod...
    echo ============================================
    echo.
    echo Mod '%selected%' is new and will be added.
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
if not exist "%REPO_DIR%\%selected%" mkdir "%REPO_DIR%\%selected%"
xcopy /E /Y "%selected_path%\*" "%REPO_DIR%\%selected%\" >NUL 2>&1
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
git add "%selected%" 2>&1

:: Check if anything is actually staged (handles CRLF/LF normalization)
set "has_changes="
for /f "delims=" %%S in ('git status --porcelain "%selected%" 2^>NUL') do set "has_changes=1"
if not defined has_changes (
    color 0E
    echo [!] No changes detected. Your mod is already up to date.
    popd
    pause
    exit /b 0
)

git commit -m "Update %selected%" 2>&1

if "!access_mode!"=="fork" goto :no_access

git push origin main 2>&1
if %errorlevel%==0 goto :push_success
git push origin master 2>&1
if %errorlevel%==0 goto :push_success

:no_access
popd
echo.
color 0E
echo ============================================
echo  ALMOST DONE - One more step needed
echo ============================================
echo.
echo Your mod is committed locally but can't be pushed
echo because you don't have write access.
echo.
echo   OPTION 1: Ask for write access
echo     Ask a KIF-Mods admin to add you to the Modders team.
echo     Then run this script again.
echo.
echo   OPTION 2: Fork and Pull Request
echo     1. Go to https://github.com/KIF-Mods/mods
echo     2. Click "Fork" (top right)
echo     3. Upload your mod folder from:
echo        %REPO_DIR%\%selected%\
echo     4. Click "Contribute" then "Open Pull Request"
echo     5. An admin will review and merge your mod.
echo.
pause
exit /b 0

:push_success
popd
echo.
color 0A
echo ============================================
echo  SUCCESS! Mod '%selected%' is now LIVE.
echo ============================================
echo.
echo Players will see it in the in-game Mod Browser.
echo.
pause
exit /b 0