@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
echo ===================================================
echo       ModRetro Chromatic Firmware Updater
echo ===================================================
echo.

REM 1. Locate openFPGALoader (check PATH, then script folder)
where openFPGALoader >nul 2>nul
if %errorlevel%==0 (
    set "FPGALOADER=openFPGALoader"
    goto :found
)

REM Allow a locally placed openFPGALoader.exe alongside this script
if exist "%~dp0openFPGALoader.exe" (
    set "FPGALOADER=%~dp0openFPGALoader.exe"
    goto :found
)

echo [INFO] openFPGALoader was not found on this system.
echo.
echo To flash on Windows, please install openFPGALoader:
echo   1. Download the latest Windows build from:
echo      https://github.com/trabucayre/openFPGALoader/releases
echo   2. Extract openFPGALoader.exe and place it EITHER:
echo        - In this same folder as flash_windows.bat, OR
echo        - Anywhere on your PATH.
echo   3. You MUST also replace the GWU2X driver with WinUSB using Zadig:
echo        - Download Zadig from https://zadig.akeo.ie/
echo        - Options ^> List All Devices, select "GWU2X"
echo        - Set the target driver to "WinUSB" and click Replace Driver.
echo   4. Re-run this script.
echo.
echo [ERROR] Cannot continue without openFPGALoader.
pause
exit /b 1

:found
echo IMPORTANT:
echo 1. Plug your Chromatic into your PC via USB.
echo 2. Ensure the device is powered ON.
pause
echo.
echo Flashing firmware... Please do not unplug the device.

REM 2. Run the flash command
"%FPGALOADER%" --write-flash --cable gwu2x --reset evt1_x2.fs

REM 3. Check for success
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Flashing failed!
    echo Please check your USB connection, ensure the device is ON,
    echo and verify the GWU2X driver was replaced with WinUSB via Zadig.
) else (
    echo.
    echo [SUCCESS] Firmware updated successfully!
    echo The Chromatic is now rebooting with the new logic.
)
pause
