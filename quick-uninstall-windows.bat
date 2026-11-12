@echo off
rem =========================================================================
rem  new_image2 - one-click rollback (Windows)
rem  Deletes %USERPROFILE%\.codex\skills\new_image2. Nothing else is
rem  touched: the skill only ever READS the Codex config, so there is
rem  nothing to undo.
rem =========================================================================
setlocal
set "DEST=%USERPROFILE%\.codex\skills\new_image2"
if exist "%USERPROFILE%\.codex\skills\.new_image2.install" (
    set /p DEST=<"%USERPROFILE%\.codex\skills\.new_image2.install"
)

if exist "%DEST%" (
    if exist "%DEST%\.installed-manifest" (
        rem remove every skill this package installed ^(incl. frozen vendors^)
        for /f "usebackq eol=# delims=" %%L in ("%DEST%\.installed-manifest") do (
            for %%N in (%%L) do (
                if exist "%USERPROFILE%\.codex\skills\%%N" (
                    rmdir /s /q "%USERPROFILE%\.codex\skills\%%N"
                    echo   [ok] removed skill: %%N
                )
            )
        )
    ) else (
        rmdir /s /q "%DEST%"
        echo   [ok] removed %DEST%
    )
    del /q "%USERPROFILE%\.codex\skills\.new_image2.install" >nul 2>&1
) else (
    echo   %DEST% was not installed ^(nothing to do^).
)

echo.
echo ============================================================
echo  Rollback complete. Restart Codex and the skill is gone.
echo  Your Codex config.toml was never modified by this skill.
echo ============================================================
pause
