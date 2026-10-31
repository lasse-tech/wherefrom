@echo off
setlocal EnableDelayedExpansion
rem Windows counterpart to the Makefile. Same targets, same behaviour; it just
rem cannot rely on a shell, so each one is a label instead of a rule.

set "ADDON=Wherefrom"
set "TOC=%ADDON%_Mainline.toc"
set "DIST_DIR=dist"
set "INSTALL_DIRS=Core UI Locales Media"
set "INSTALL_FILES=%TOC% CHANGELOG.md LICENSE"

for /f "tokens=2 delims=: " %%v in ('findstr /b "## Version:" "%TOC%"') do set "VERSION=%%v"

set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=help"
set "ARG2=%~2"

for %%t in (help version check check-toc check-locales lint test install debug ^
            uninstall dist deploy release clean distclean purge) do (
    if /i "%TARGET%"=="%%t" goto :run
)
echo Unknown target "%TARGET%".
goto :help

:run
call :%TARGET%
exit /b %ERRORLEVEL%

rem ---------------------------------------------------------------------------

rem help: list the targets
:help
echo %ADDON% %VERSION%
for /f "tokens=1,*" %%a in ('findstr /b /r /c:"rem [abcdefghijklmnopqrstuvwxyz][abcdefghijklmnopqrstuvwxyz0123456789-]*: " "%~f0"') do echo   %%b
echo.
echo Variables (set NAME=value): WOW_RETAIL_ADDON_FOLDER, WOW_DIR, WOW_UI_SIM
exit /b 0

rem version: print the addon version
:version
echo %VERSION%
exit /b 0

rem Finding the client ---------------------------------------------------------

:find_addons
set "ADDONS="
if defined WOW_RETAIL_ADDON_FOLDER (
    set "ADDONS=%WOW_RETAIL_ADDON_FOLDER%"
    exit /b 0
)
if defined WOW_DIR (
    if exist "%WOW_DIR%\_retail_" set "ADDONS=%WOW_DIR%\_retail_\Interface\AddOns"
    exit /b 0
)
for %%d in ("%PROGRAMFILES(X86)%\World of Warcraft" ^
            "%PROGRAMFILES%\World of Warcraft" ^
            "C:\Games\World of Warcraft" ^
            "D:\World of Warcraft") do (
    if exist "%%~d\_retail_" (
        set "ADDONS=%%~d\_retail_\Interface\AddOns"
        exit /b 0
    )
)
exit /b 0

:no_addons
echo AddOns folder not found. Set WOW_RETAIL_ADDON_FOLDER=path\to\Interface\AddOns,
echo or WOW_DIR=path\to\World of Warcraft
exit /b 1

rem Linting --------------------------------------------------------------------
rem luacheck is the real lint. Without it only the syntax is checked, which is
rem not enough to call the lint passed - so that case fails too.

rem check: luacheck over Core, UI, Locales and tests, any warning fails
:check
where luacheck >nul 2>&1
if %ERRORLEVEL%==0 (
    luacheck Core UI Locales tests
    exit /b %ERRORLEVEL%
)
where luac >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo no Lua available ^(install lua and luacheck^)
    exit /b 1
)
for /r %%f in (Core\*.lua UI\*.lua Locales\*.lua tests\*.lua) do (
    luac -p "%%f" || exit /b 1
)
echo luac: all files parse
echo   warning: luacheck is not installed - this only checked syntax.
echo   install it with: luarocks install luacheck
exit /b 1

rem check-toc: every file the TOC lists exists
:check-toc
set "MISSING=0"
for /f "usebackq delims=" %%l in ("%TOC%") do (
    set "LINE=%%l"
    echo !LINE! | findstr /r "\.lua$ \.xml$" >nul && (
        if not exist "!LINE!" (
            echo   MISSING !LINE! ^(listed in the TOC^)
            set "MISSING=1"
        )
    )
)
if "!MISSING!"=="1" exit /b 1
echo toc: every listed file exists
exit /b 0

rem check-locales: every L[...] the code asks for exists in both locales
:check-locales
python tools\check-locales.py
exit /b %ERRORLEVEL%

rem lint: luacheck, TOC, locales (BLOCKER; ruff and Makefile comments: make lint)
:lint
call :check || exit /b 1
call :check-toc || exit /b 1
call :check-locales || exit /b 1
exit /b 0

rem Testing ---------------------------------------------------------------------

rem test: run tests\ headless in wow-ui-sim
:test
if not defined WOW_UI_SIM set "WOW_UI_SIM=%USERPROFILE%\git\wow-ui-sim"
set "SIM_BIN=%WOW_UI_SIM%\target\release\wow-sim.exe"
if not exist "%SIM_BIN%" (
    echo wow-sim not found at %SIM_BIN%
    echo build it: cd %WOW_UI_SIM% ^&^& cargo build --release --no-default-features --features casc,client-retail --bin wow-sim
    exit /b 1
)
set "SIM_DIR=%DIST_DIR%\sim"
if exist "%SIM_DIR%" rmdir /s /q "%SIM_DIR%"
set "OUT=%SIM_DIR%\Interface\AddOns\%ADDON%"
mkdir "%OUT%" 2>nul
for %%d in (%INSTALL_DIRS% tests) do xcopy /e /i /q /y "%%d" "%OUT%\%%d" >nul
copy /y "%TOC%" "%OUT%\" >nul
xcopy /e /i /q /y "%WOW_UI_SIM%\Interface\AddOns\TestFramework" "%SIM_DIR%\Interface\AddOns\TestFramework" >nul
copy /y "%SIM_BIN%" "%SIM_DIR%\wow-sim.exe" >nul
pushd "%SIM_DIR%"
set "WOW_SIM_WOW_PATH="
wow-sim.exe --no-saved-vars run-tests %ADDON%
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%

rem Installing -------------------------------------------------------------------

rem install: copy the addon into the client
:install
call :find_addons
if not defined ADDONS goto :no_addons
set "DEST=%ADDONS%\%ADDON%"
echo installing %ADDON% %VERSION% -^> %DEST%
mkdir "%DEST%" 2>nul
if not exist "%DEST%" (
    echo cannot create %DEST% - check the folder permissions
    exit /b 1
)
for %%d in (%INSTALL_DIRS%) do (
    if exist "%DEST%\%%d" rmdir /s /q "%DEST%\%%d"
    xcopy /e /i /q /y "%%d" "%DEST%\%%d" >nul || exit /b 1
)
for %%f in (%INSTALL_FILES%) do copy /y "%%f" "%DEST%\" >nul || exit /b 1
for %%x in (tests tools scripts .claude .git dist README.md CLAUDE.md .gitignore ^
            .pkgmeta .luacheckrc Makefile Makefile.bat) do (
    if exist "%DEST%\%%x" (
        echo   removing stray %%x ^(not part of the addon^)
        if exist "%DEST%\%%x\" ( rmdir /s /q "%DEST%\%%x" ) else ( del /q "%DEST%\%%x" )
    )
)
echo done - /reload in game
exit /b 0

rem debug: install with tests\ and print the in-game debug switches
:debug
call :install || exit /b 1
call :find_addons
xcopy /e /i /q /y tests "%ADDONS%\%ADDON%\tests" >nul || exit /b 1
echo   tests\ included
echo.
echo In game:
echo   /console scriptErrors 1     show Lua errors instead of swallowing them
echo   /wf status                  what is recorded and indexed
echo   /wf index                   rebuild the drop index now
echo   set 'Announce every recorded item in chat' to watch captures live
exit /b 0

rem uninstall: remove the addon, SavedVariables stay
:uninstall
call :find_addons
if not defined ADDONS goto :no_addons
set "DEST=%ADDONS%\%ADDON%"
if not exist "%DEST%" (
    echo not installed: %DEST%
    exit /b 0
)
rmdir /s /q "%DEST%"
echo removed %DEST%
echo SavedVariables kept - use "Makefile.bat purge CONFIRM=yes" to delete those too
exit /b 0

rem Releasing ----------------------------------------------------------------------

rem dist: build dist\Wherefrom-<version>.zip
:dist
if exist "%DIST_DIR%\%ADDON%" rmdir /s /q "%DIST_DIR%\%ADDON%"
if exist "%DIST_DIR%\%ADDON%-%VERSION%.zip" del /q "%DIST_DIR%\%ADDON%-%VERSION%.zip"
mkdir "%DIST_DIR%\%ADDON%" 2>nul
for %%d in (%INSTALL_DIRS%) do xcopy /e /i /q /y "%%d" "%DIST_DIR%\%ADDON%\%%d" >nul
for %%f in (%INSTALL_FILES%) do copy /y "%%f" "%DIST_DIR%\%ADDON%\" >nul
if exist "%DIST_DIR%\%ADDON%\Media\README.md" del /q "%DIST_DIR%\%ADDON%\Media\README.md"
if exist "%DIST_DIR%\%ADDON%\Media\Icon.svg" del /q "%DIST_DIR%\%ADDON%\Media\Icon.svg"
rem tar ships with Windows 10 and up and writes forward slashes, which is what
rem the addon sites expect; Compress-Archive does not.
tar -a -c -f "%DIST_DIR%\%ADDON%-%VERSION%.zip" -C "%DIST_DIR%" "%ADDON%"
rmdir /s /q "%DIST_DIR%\%ADDON%"
echo built %DIST_DIR%\%ADDON%-%VERSION%.zip
exit /b 0

rem deploy: none - installation: README.md, section Installation
:deploy
echo No deploy: see README.md, section Installation
exit /b 0

rem release: print the commands that tag v<version> and push it to Forgejo (exported to GitHub)
:release
echo git tag v%VERSION% ^&^& git push origin main v%VERSION%
exit /b 0

rem Housekeeping ---------------------------------------------------------------------

rem clean: remove dist\
:clean
if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"
echo cleaned
exit /b 0

rem distclean: same as clean, the addon embeds no libraries
:distclean
call :clean
echo nothing else to clean - this addon embeds no libraries
exit /b 0

rem purge: uninstall and delete the SavedVariables (needs CONFIRM=yes)
:purge
if /i not "%ARG2%"=="CONFIRM=yes" (
    echo refusing to delete SavedVariables without CONFIRM=yes
    echo    Makefile.bat purge CONFIRM=yes
    exit /b 1
)
call :uninstall || exit /b 1
call :find_addons
if not defined ADDONS goto :no_addons
for %%p in ("%ADDONS%\..\..") do set "FLAVOR_DIR=%%~fp"
set "FOUND=0"
for /d %%a in ("%FLAVOR_DIR%\WTF\Account\*") do (
    if exist "%%a\SavedVariables\%ADDON%.lua" (
        echo   deleting %%a\SavedVariables\%ADDON%.lua
        del /q "%%a\SavedVariables\%ADDON%.lua*"
        set "FOUND=1"
    )
)
if "!FOUND!"=="0" echo   no SavedVariables found
exit /b 0
