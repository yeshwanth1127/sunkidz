@echo off
REM Fix for "The process cannot access the file because it is being used by another process"
REM Run this when flutter build apk fails with R8/classes.dex lock error

echo Stopping Gradle daemons...
cd /d "%~dp0"
if exist android\gradlew.bat (call android\gradlew.bat --stop 2>nul) else (echo Gradle wrapper not found, skipping...)

echo.
echo Cleaning Flutter build...
call flutter clean

echo.
echo Removing build folder (clears locked files)...
if exist build rmdir /s /q build

echo.
echo Waiting 3 seconds for file handles to release...
timeout /t 3 /nobreak >nul

echo.
echo Building APK...
call flutter build apk --release

echo.
echo Done.
pause
