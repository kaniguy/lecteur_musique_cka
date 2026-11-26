@echo off
chcp 65001 >nul
title Musique CKA - Démarrer
setlocal

rem Outils installés pour Godé
set "JAVA_HOME=C:\Program Files\Java\jdk-17"
set "ANDROID_HOME=C:\Android"
set "PATH=C:\flutter\bin;C:\Android\platform-tools;C:\Android\cmdline-tools\latest\bin;%PATH%"

if not exist "C:\flutter\bin\flutter.bat" (
  echo Flutter est introuvable dans C:\flutter.
  pause
  exit /b 1
)

cd /d "%~dp0"

echo Recherche du téléphone...
adb start-server >nul 2>&1
set "APPAREIL="
for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
  if "%%b"=="device" if not defined APPAREIL set "APPAREIL=%%a"
)

if not defined APPAREIL (
  echo.
  echo Aucun téléphone autorisé n'est branché.
  echo  - Branche le téléphone avec un câble qui transfère les données
  echo  - Active le Débogage USB dans les Options pour les développeurs
  echo  - Accepte le message "Autoriser le débogage USB ?" sur le téléphone
  echo.
  pause
  exit /b 1
)

echo Téléphone trouvé : %APPAREIL%
echo.
echo  1. Installer et ouvrir Musique CKA (version finale, rapide)
echo  2. Mode développement (rechargement à chaud : r = recharger, q = quitter)
echo.
choice /c 12 /n /m "Ton choix (1 ou 2) : "

if errorlevel 2 (
  call flutter run -d %APPAREIL%
) else (
  call flutter run -d %APPAREIL% --release
)

pause
