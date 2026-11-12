@echo off
chcp 65001 >nul
title Coliseo Mecha (prototipo)
rem Abre el prototipo del Coliseo con mechas.
rem Antes, «Abrir juego.bat» pone al dia C:\Carpeta Juego\Lk-3d con main (este archivo va dentro).
set "GODOT="
set "RUTA_GODOT=%~dp0..\..\..\godot_ruta.txt"
if exist "%RUTA_GODOT%" set /p GODOT=<"%RUTA_GODOT%"
if not defined GODOT (
    echo No encuentro godot_ruta.txt. Abre primero "Abrir juego.bat" una vez.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0." --import >nul 2>nul
start "" "%GODOT%" --path "%~dp0."
