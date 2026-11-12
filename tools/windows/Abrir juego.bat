@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title Last Knight 3D
rem ============================================================================
rem  Abrir juego.bat  (C:\Carpeta Juego)
rem  1. La primera vez baja el repositorio a C:\Carpeta Juego\Lk-3d.
rem  2. Cada vez lo pone al dia con lo ultimo de main (lo que suben los chats).
rem  3. Importa lo nuevo en Godot y abre el juego.
rem  Con "editor" detras (Abrir en el editor.bat) abre el editor de Godot.
rem ============================================================================
set "CARPETA=%~dp0"
set "REPO=%CARPETA%Lk-3d"
set "URL=https://github.com/digamelongames-creator/Lk-3d.git"
set "RUTA_GODOT=%CARPETA%godot_ruta.txt"

rem ---------------------------------------------------------------- Git
where git >nul 2>nul
if errorlevel 1 (
    echo No encuentro Git. Lo instalo con winget ^(acepta lo que pida Windows^)...
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
    where git >nul 2>nul
    if errorlevel 1 (
        echo.
        echo No se ha podido instalar Git. Instalalo desde https://git-scm.com/download/win y vuelve a abrir este archivo.
        pause
        exit /b 1
    )
)

rem ---------------------------------------------------------------- bajar o poner al dia
if not exist "%REPO%\.git" (
    echo Bajando el juego por primera vez ^(unos 500 MB; si sale una ventana de GitHub, entra con tu cuenta^)...
    git clone "%URL%" "%REPO%"
    if errorlevel 1 (
        echo.
        echo No se ha podido bajar el repositorio. Revisa la conexion o entra en GitHub cuando lo pida.
        pause
        exit /b 1
    )
) else (
    echo Poniendo el juego al dia con main...
    pushd "%REPO%"
    rem si algo cambio aqui ^(p. ej. el editor de Godot guardo un archivo^), se aparta sin perderse: git stash list
    git diff --quiet
    if errorlevel 1 git stash push -m "cambios locales guardados por Abrir juego.bat" >nul
    git checkout -q main
    git pull --ff-only -q
    if errorlevel 1 (
        echo Lo de main no encaja con lo de aqui: se deja igual que main ^(lo de aqui queda en git stash^).
        git stash push -u -m "cambios locales guardados por Abrir juego.bat" >nul
        git fetch -q origin
        git reset -q --hard origin/main
    )
    for /f "delims=" %%c in ('git log -1 "--format=%%h  %%s"') do echo Version: %%c
    popd
)

rem ---------------------------------------------------------------- Godot
set "GODOT="
if exist "%RUTA_GODOT%" set /p GODOT=<"%RUTA_GODOT%"
if defined GODOT if not exist "!GODOT!" set "GODOT="
if not defined GODOT (
    echo Buscando Godot 4 ^(solo la primera vez^)...
    for %%d in ("%CARPETA%" "%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%USERPROFILE%\Documents" "%LOCALAPPDATA%" "%ProgramFiles%" "C:\Godot") do (
        if not defined GODOT if exist "%%~d" (
            for /f "delims=" %%g in ('dir /b /s "%%~d\Godot_v4*_win64.exe" 2^>nul ^| findstr /v /i "console"') do (
                if not defined GODOT set "GODOT=%%g"
            )
        )
    )
    if not defined GODOT (
        echo.
        echo No encuentro Godot. Arrastra aqui el Godot_v4.7.2-stable_win64.exe y pulsa Enter:
        set /p GODOT=
        set "GODOT=!GODOT:"=!"
    )
    if not exist "!GODOT!" (
        echo No existe "!GODOT!".
        pause
        exit /b 1
    )
    >"%RUTA_GODOT%" echo !GODOT!
)

rem ---------------------------------------------------------------- importar lo nuevo y abrir
echo Importando lo nuevo en Godot...
"%GODOT%" --headless --path "%REPO%" --import >nul 2>nul
if errorlevel 1 (
    rem a veces Godot se cierra al importar; la segunda vez va bien
    "%GODOT%" --headless --path "%REPO%" --import >nul 2>nul
)
if /i "%~1"=="editor" (
    start "" "%GODOT%" --path "%REPO%" --editor
) else (
    start "" "%GODOT%" --path "%REPO%"
)
exit /b 0
