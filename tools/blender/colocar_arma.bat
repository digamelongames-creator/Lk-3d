@echo off
setlocal EnableDelayedExpansion
rem Colocar armas en las manos de un personaje de SPRITE_FACTORY (panel «Agarre» de Blender).
rem Va en la raiz de SPRITE_FACTORY, con colocar_arma.py, agarre.py y monstruos_glb.py en tools\agarre\.
chcp 65001 >nul
cd /d "%~dp0"

set "BLENDER="
if exist "%~dp0blender.txt" set /p BLENDER=<"%~dp0blender.txt"
if not defined BLENDER (
  for /d %%D in ("%ProgramFiles%\Blender Foundation\Blender*") do (
    if exist "%%D\blender.exe" set "BLENDER=%%D\blender.exe"
  )
)
if not defined BLENDER (
  for /d %%D in ("%ProgramFiles(x86)%\Steam\steamapps\common\Blender") do (
    if exist "%%D\blender.exe" set "BLENDER=%%D\blender.exe"
  )
)
if not defined BLENDER (
  echo No encuentro Blender. Escribe la ruta de blender.exe en blender.txt, junto a este archivo.
  pause
  exit /b 1
)

echo Personajes:
set n=0
for %%F in ("config\characters\*.json") do (
  set /a n+=1
  set "P!n!=%%~nF"
  echo   !n!. %%~nF
)
echo.
set /p ELIGE=Numero o nombre del personaje:
set "ID=!P%ELIGE%!"
if not defined ID set "ID=%ELIGE%"
if not exist "config\characters\%ID%.json" (
  echo No existe config\characters\%ID%.json
  pause
  exit /b 1
)

echo Abriendo Blender con %ID%...
"%BLENDER%" --python "%~dp0tools\agarre\colocar_arma.py" -- "%~dp0." "%ID%"
