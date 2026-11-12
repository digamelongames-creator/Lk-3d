@echo off
setlocal EnableDelayedExpansion
title Coliseo Mecha (prototipo)
rem ============================================================================
rem  Abrir coliseo.bat  (C:\Carpeta Juego\Lk-3d\prototipos\coliseo-mecha)
rem  Abre el prototipo del Coliseo con mechas. Antes, "Abrir juego.bat" pone
rem  al dia la copia del repositorio con main.
rem  OJO: este archivo tiene que ir solo con letras sin acentos (cmd se lia).
rem ============================================================================
set "PROYECTO=%~dp0."
set "RUTA_GODOT=%~dp0..\..\..\godot_ruta.txt"

if not exist "%PROYECTO%\project.godot" (
    echo No encuentro project.godot en %PROYECTO%
    pause
    exit /b 1
)

set "GODOT="
if exist "%RUTA_GODOT%" set /p GODOT=<"%RUTA_GODOT%"
if defined GODOT if exist "!GODOT!\*" call :godot_en "!GODOT!"
if defined GODOT if not exist "!GODOT!" set "GODOT="
if not defined GODOT (
    echo Buscando Godot 4...
    for %%d in ("%~dp0..\..\.." "%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%USERPROFILE%\Documents" "%LOCALAPPDATA%" "%ProgramFiles%" "C:\Godot") do (
        if not defined GODOT if exist "%%~d" call :godot_en "%%~d"
    )
)
if not defined GODOT (
    echo No encuentro Godot. Abre primero "Abrir juego.bat" una vez y vuelve a probar.
    pause
    exit /b 1
)
echo Godot: !GODOT!
echo Preparando el prototipo ^(la primera vez tarda un poco^)...
"!GODOT!" --headless --path "%PROYECTO%" --import >nul 2>nul
echo Abriendo el Coliseo...
start "" "!GODOT!" --path "%PROYECTO%"
exit /b 0

:godot_en
set "GODOT="
for /f "delims=" %%g in ('dir /b /s /a-d "%~1\Godot_v4*.exe" 2^>nul ^| findstr /v /i "console"') do (
    if not defined GODOT set "GODOT=%%g"
)
exit /b 0
