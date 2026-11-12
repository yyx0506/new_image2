@echo off
rem =========================================================================
rem  new_image2 - one-click install for Codex (Windows)
rem  Copies the skill into %USERPROFILE%\.codex\skills\new_image2 and resolves
rem  Python: 1) system python3 / py -3 (developers keep their own)
rem           2) the bundled private runtime (nothing to install)
rem  No config is modified; uninstall = quick-uninstall-windows.bat
rem =========================================================================
setlocal EnableDelayedExpansion
cd /d "%~dp0"

rem 安装时可自定义技能名: -SkillName 名字 （默认 image -> $image / $image-raw / $image-psd + 8 个风格技能）
set "SKILL_NAME=image"
if not "%~1"=="" (
    if /i "%~1"=="-SkillName" ( if not "%~2"=="" set "SKILL_NAME=%~2" )
)
set "DEST=%USERPROFILE%\.codex\skills\%SKILL_NAME%"

rem ---- resolve Python: system first, bundled runtime as fallback ----
set "PYCMD="
set "PYNODELAY="
py -3 -c "import sys;raise SystemExit(0 if sys.version_info>=(3,9) else 1)" >nul 2>&1
if not errorlevel 1 ( set "PYCMD=py -3" )
if "!PYCMD!"=="" (
    python3 -c "import sys;raise SystemExit(0 if sys.version_info>=(3,9) else 1)" >nul 2>&1
    if not errorlevel 1 ( set "PYCMD=python3" )
)
if "!PYCMD!"=="" (
    python -c "import sys;raise SystemExit(0 if sys.version_info>=(3,9) else 1)" >nul 2>&1
    if not errorlevel 1 ( set "PYCMD=python" )
)
set "USERUNTIME="
if "!PYCMD!"=="" (
    if exist "%~dp0runtime\python.exe" (
        "%~dp0runtime\python.exe" -c "import sys;raise SystemExit(0 if sys.version_info>=(3,9) else 1)" >nul 2>&1
        if not errorlevel 1 (
            set "PYCMD=%~dp0runtime\python.exe"
            set "USERUNTIME=1"
            echo   [ok] No system Python - using the bundled private runtime.
            echo        ^(The runtime lives only inside the skill folder; nothing is installed system-wide^)
        )
    )
)
if "!PYCMD!"=="" (
    echo   [!!] No Python 3.9+ found and this package carries no bundled runtime.
    echo        Re-download the full Windows package ^(new_image2-windows-x64.zip^)
    echo        or install Python 3.9+ from https://python.org
    pause & exit /b 1
)
if not defined USERUNTIME (
    echo   [ok] using system Python: !PYCMD!
)

rem ---- sanity ----
if not exist SKILL.md goto broken
if not exist scripts\new_image2.py goto broken
if not exist scripts\psd_io.py goto broken
goto copyskill
:broken
echo   [!!] Run this from the unpacked skill folder (SKILL.md must be next to it).
pause & exit /b 1

:copyskill
rem ---- install: plain folder copy, idempotent ----
if exist "%DEST%" rmdir /s /q "%DEST%"
mkdir "%DEST%" >nul 2>&1
copy /y SKILL.md AGENTS.md LICENSE "%DEST%\" >nul
xcopy /e /i /y /q scripts "%DEST%\scripts" >nul
if exist "%DEST%\scripts\__pycache__" rmdir /s /q "%DEST%\scripts\__pycache__" >nul 2>&1
if errorlevel 1 (
    echo   [!!] Copy failed.
    pause & exit /b 1
)
if exist "%~dp0runtime\python.exe" (
    xcopy /e /i /y /q runtime "%DEST%\runtime" >nul
    if errorlevel 1 (
        echo   [!!] Copying the bundled runtime failed.
        pause & exit /b 1
    )
)
if exist "%~dp0runtime-x64\python.exe" (
    xcopy /e /i /y /q runtime-x64 "%DEST%\runtime-x64" >nul
)
echo   [ok] installed to %DEST%

rem ---- sibling skills ship in the same package (names follow the base) ----
set "SKILLDIRS=!SKILL_NAME!"
for %%P in ("raw-skill=!SKILL_NAME!-raw" "psd-skill=!SKILL_NAME!-psd") do (
    for /f "tokens=1,2 delims==" %%A in (%%P) do (
        if exist "%~dp0%%A\SKILL.md" (
            if exist "%USERPROFILE%\.codex\skills\%%B" rmdir /s /q "%USERPROFILE%\.codex\skills\%%B"
            mkdir "%USERPROFILE%\.codex\skills\%%B" >nul
            if defined PYCMD (
                "!PYCMD!" -c "import sys; t=open(sys.argv[1],encoding='utf-8').read(); t=t.replace('new_image2_raw',sys.argv[3]+'-raw').replace('new_image2_psd',sys.argv[3]+'-psd').replace('new_image2',sys.argv[3]); open(sys.argv[2],'w',encoding='utf-8').write(t)" "%~dp0%%A\SKILL.md" "%USERPROFILE%\.codex\skills\%%B\SKILL.md" "!SKILL_NAME!"
            ) else (
                copy /y "%~dp0%%A\SKILL.md" "%USERPROFILE%\.codex\skills\%%B\SKILL.md" >nul
            )
            set "SKILLDIRS=!SKILLDIRS! %%B"
            echo   [ok] installed sibling skill: %%B
        )
    )
)
rem ---- style skills: 每个风格一个独立技能 ----
if exist "%~dp0style-skills" (
    for /d %%D in ("%~dp0style-skills\*") do (
        if exist "%%D\SKILL.md" (
            set "SNAME=%%~nxD"
            if exist "%USERPROFILE%\.codex\skills\!SNAME!" rmdir /s /q "%USERPROFILE%\.codex\skills\!SNAME!"
            mkdir "%USERPROFILE%\.codex\skills\!SNAME!" >nul
            if defined PYCMD (
                "!PYCMD!" -c "import sys; open(sys.argv[2],'w',encoding='utf-8').write(open(sys.argv[1],encoding='utf-8').read().replace('new_image2', sys.argv[3]))" "%%D\SKILL.md" "%USERPROFILE%\.codex\skills\!SNAME!\SKILL.md" "!SKILL_NAME!"
            ) else (
                copy /y "%%D\SKILL.md" "%USERPROFILE%\.codex\skills\!SNAME!\SKILL.md" >nul
            )
            set "SKILLDIRS=!SKILLDIRS! !SNAME!"
        )
    )
    echo   [ok] installed 8 style skills ^(image-jishi / -dianying / ...^)
)
rem 主技能 SKILL.md 同步改写为选定名字
if defined PYCMD "!PYCMD!" -c "import sys; p=sys.argv[1]; b=sys.argv[2]; t=open(p,encoding='utf-8').read(); t=t.replace('new_image2_raw',b+'-raw').replace('new_image2_psd',b+'-psd').replace('new_image2',b); open(p,'w',encoding='utf-8').write(t)" "%DEST%\SKILL.md" "!SKILL_NAME!"

rem ---- frozen third-party skills (vendor\) each land as their own skill ----
if exist "%~dp0vendor" (
    for /d %%D in ("%~dp0vendor\*") do (
        if exist "%%D\SKILL.md" (
            set "VNAME=%%~nxD"
            if exist "%USERPROFILE%\.codex\skills\!VNAME!" rmdir /s /q "%USERPROFILE%\.codex\skills\!VNAME!"
            xcopy /e /i /y /q "%%D" "%USERPROFILE%\.codex\skills\!VNAME!" >nul
            set "SKILLDIRS=!SKILLDIRS! !VNAME!"
            echo   [ok] vendored skill installed: !VNAME!
        )
    )
)
set "PKGVER="
for /f "tokens=2 delims==" %%V in ('findstr /b /c:"VERSION = " scripts\new_image2.py') do set "PKGVER=%%V"
set "PKGVER=!PKGVER:^"=!"
> "%USERPROFILE%\.codex\skills\.new_image2.install" echo %DEST%
> "%DEST%\.installed-manifest" (
    echo # new_image2 distribution !PKGVER! - installed skill dirs:
    echo !SKILLDIRS!
)
if exist VENDOR-VERSIONS.txt echo   bundled third-party skills ^(frozen pins^): see VENDOR-VERSIONS.txt

echo.
echo ============================================================
echo  Done. Restart Codex, then try:
echo    "用 new_image2 生成一张 1024x1024 的橙色猫海报"
echo    "把 poster.psd 的背景层导出来，换成夕阳背景再合成 PSD"
echo.
echo  Rollback: double-click quick-uninstall-windows.bat
echo  (deletes the skill folder only; Codex config is never touched)
echo ============================================================
pause
