@echo off
rem DotA Kart - copies the addon from the Dota 2 install into this repository for the GitHub backup.
rem Skips model_work, .blend files, local .zip archives and editor caches.
rem Files that are not part of the backup are only removed from Git tracking (git rm --cached), never deleted from disk.
setlocal
set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
set "DOTA=C:\Steam\steamapps\common\dota 2 beta"
set "LOG=%REPO%\backup_sync.log"
echo DotA Kart backup sync %DATE% %TIME% > "%LOG%"

set "XD=model_work __pycache__ .codex .claude"
set "XF=*.blend *.blend1 content.zip game.zip *.pyc tools_thumbnail_cache.sqlite3* tools_asset_info.bin CLAUDE.md AGENTS.md"

echo Copiando content...
robocopy "%DOTA%\content\dota_addons\dota_kart" "%REPO%\content" /E /XD %XD% /XF %XF% "maps and panorama.zip" /R:1 /W:1 /NP /NFL /NDL /LOG+:"%LOG%"
if %ERRORLEVEL% GEQ 8 goto :fail
echo Copiando game...
robocopy "%DOTA%\game\dota_addons\dota_kart" "%REPO%\game" /E /XD %XD% /XF %XF% /R:1 /W:1 /NP /NFL /NDL /LOG+:"%LOG%"
if %ERRORLEVEL% GEQ 8 goto :fail

rem Git bundled with GitHub Desktop (git may not be on PATH).
set "GIT=git"
where git >nul 2>nul
if errorlevel 1 (
  for /d %%D in ("%LOCALAPPDATA%\GitHubDesktop\app-*") do if exist "%%D\resources\app\git\cmd\git.exe" set "GIT=%%D\resources\app\git\cmd\git.exe"
)
echo Git: %GIT% >> "%LOG%"
pushd "%REPO%"
"%GIT%" rm -r --cached --ignore-unmatch --quiet content/model_work game/model_work CLAUDE.md AGENTS.md >> "%LOG%" 2>&1
"%GIT%" rm -r --cached --ignore-unmatch --quiet -- "*.blend" "*.blend1" >> "%LOG%" 2>&1
"%GIT%" status --short > "%REPO%\backup_sync_status.txt" 2>&1
popd
echo [dotakart] SYNC_DONE >> "%LOG%"
echo PRONTO. Agora faca o commit e o push no GitHub Desktop.
exit /b 0

:fail
echo [dotakart] SYNC_FAILED >> "%LOG%"
echo ERRO no robocopy. Veja backup_sync.log
pause
exit /b 1
