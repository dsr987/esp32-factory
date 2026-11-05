@echo off
setlocal EnableExtensions EnableDelayedExpansion
title ESP32 Auto-Flasher

echo ====================================================
echo              ESP32 AUTO-FLASHER
echo ====================================================
echo.
echo  1. Flash project (.ino)
echo  2. Flash firmware (.bin)
echo  3. Factory Reset
echo  4. Exit
echo.
set /p ACTION="Select option: "

if "%ACTION%"=="1" goto FLASH_INO
if "%ACTION%"=="2" goto FLASH_BIN
if "%ACTION%"=="3" goto FACTORY_RESET
if "%ACTION%"=="4" exit /b 0

echo.
echo [ERROR] Invalid menu option.
pause
exit /b 1

:CHECK_CLI
set "CLI=%~dp0arduino-cli.exe"
if not exist "%CLI%" (
    echo [ERROR] arduino-cli.exe not found next to this BAT file.
    echo Place arduino-cli.exe in the same folder.
    exit /b 1
)
exit /b 0

:CHECK_PORT
echo.
echo [1/3] Searching for connected ESP32 COM port...
"%CLI%" board list > "%temp%\esp32-boards.txt" 2>nul
set "COM_PORT="
for /f "tokens=1" %%A in ('type "%temp%\esp32-boards.txt" ^| findstr /I "COM"') do (
    if not defined COM_PORT set "COM_PORT=%%A"
)
del "%temp%\esp32-boards.txt" >nul 2>&1

if not defined COM_PORT (
    echo [WARNING] Port was not detected automatically.
    set /p COM_PORT="Enter COM port manually (e.g. COM3): "
) else (
    echo [OK] Found port: !COM_PORT!
)
if not defined COM_PORT exit /b 1
exit /b 0

:CHECK_ESPTOOL
set "ESPTOOL="
if defined LOCALAPPDATA (
    for /d %%D in ("%LOCALAPPDATA%\Arduino15\packages\esp32\tools\esptool_py\*") do (
        if exist "%%~fD\esptool.exe" set "ESPTOOL=%%~fD\esptool.exe"
    )
)
if not defined ESPTOOL (
    echo [ERROR] esptool.exe not found in the Arduino ESP32 core installation.
    echo Install ESP32 Arduino Core 2.0.9 using Arduino CLI first.
    exit /b 1
)
exit /b 0

:LOAD_LAYOUT
set "LAYOUT="
if exist "%~dp0active_layout.txt" set /p LAYOUT=<"%~dp0active_layout.txt"
if /I not "!LAYOUT!"=="basic" if /I not "!LAYOUT!"=="extended" set "LAYOUT="
if not defined LAYOUT (
    echo [ERROR] Active layout is unknown.
    echo Run Factory Reset first and select Basic or Extended.
    exit /b 1
)
if /I "!LAYOUT!"=="basic" (
    set "SLOT_SIZE=1310720"
    set "PARTITION_CSV=%~dp0partitions\basic.csv"
) else (
    set "SLOT_SIZE=1966080"
    set "PARTITION_CSV=%~dp0partitions\extended.csv"
)
exit /b 0

:FLASH_INO
call :CHECK_CLI
if errorlevel 1 goto FAILED
call :LOAD_LAYOUT
if errorlevel 1 goto FAILED

echo.
set /p SKETCH_DIR="Drag and drop sketch folder here: "
set "SKETCH_DIR=!SKETCH_DIR:"=!"
if not defined SKETCH_DIR goto FAILED
if not exist "!SKETCH_DIR!\." (
    echo [ERROR] Sketch folder does not exist.
    goto FAILED
)

call :CHECK_PORT
if errorlevel 1 goto FAILED

for %%I in ("!SKETCH_DIR!") do set "SKETCH_NAME=%%~nxI"
set "TEMP_SKETCH=%temp%\esp32-factory-sketch\!SKETCH_NAME!"
set "BUILD_DIR=%temp%\esp32-factory-build"
if exist "%TEMP_SKETCH%" rmdir /s /q "%TEMP_SKETCH%"
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
mkdir "%TEMP_SKETCH%" >nul 2>&1
xcopy "!SKETCH_DIR!\*" "%TEMP_SKETCH%\" /E /I /H /Y >nul
if errorlevel 2 (
    echo [ERROR] Failed to copy sketch to temporary folder.
    goto FAILED
)
copy /Y "!PARTITION_CSV!" "%TEMP_SKETCH%\partitions.csv" >nul
if errorlevel 1 (
    echo [ERROR] Partition CSV is missing.
    goto FAILED
)

echo.
echo [2/3] Compiling with !LAYOUT! layout...
"%CLI%" compile --fqbn esp32:esp32:esp32 --build-path "%BUILD_DIR%" "%TEMP_SKETCH%"
if errorlevel 1 (
    echo [ERROR] Compilation failed.
    goto FAILED
)

echo.
echo [3/3] Uploading firmware to !COM_PORT!...
"%CLI%" upload -p !COM_PORT! --fqbn esp32:esp32:esp32 "%TEMP_SKETCH%"
if errorlevel 1 (
    echo [ERROR] Upload failed. Try holding the BOOT button.
    goto FAILED
)

echo.
echo [SUCCESS] Firmware uploaded using !LAYOUT! layout.
goto DONE

:FLASH_BIN
call :CHECK_CLI
if errorlevel 1 goto FAILED
call :LOAD_LAYOUT
if errorlevel 1 goto FAILED
call :CHECK_ESPTOOL
if errorlevel 1 goto FAILED
if not exist "%~dp0boot_app0.bin" (
    echo [ERROR] boot_app0.bin is missing next to this BAT file.
    goto FAILED
)

echo.
set /p BIN_FILE="Drag and drop app-only .bin file here: "
set "BIN_FILE=!BIN_FILE:"=!"
if not exist "!BIN_FILE!" (
    echo [ERROR] BIN file does not exist.
    goto FAILED
)
for %%I in ("!BIN_FILE!") do set "BIN_SIZE=%%~zI"
if !BIN_SIZE! GTR !SLOT_SIZE! (
    echo [ERROR] BIN is !BIN_SIZE! bytes, larger than !LAYOUT! OTA slot !SLOT_SIZE! bytes.
    goto FAILED
)

call :CHECK_PORT
if errorlevel 1 goto FAILED

echo.
echo [WARNING] This writes the app to OTA slot 0 and resets OTA selection.
echo The BIN must have been compiled for the currently installed !LAYOUT! layout.
"%ESPTOOL%" --chip esp32 --port !COM_PORT! --baud 460800 --after hard_reset write_flash --flash_mode dio --flash_freq 40m --flash_size detect 0xE000 "%~dp0boot_app0.bin" 0x10000 "!BIN_FILE!"
if errorlevel 1 (
    echo [ERROR] BIN upload failed.
    goto FAILED
)
echo.
echo [SUCCESS] BIN uploaded.
goto DONE

:FACTORY_RESET
call :CHECK_CLI
if errorlevel 1 goto FAILED
call :CHECK_ESPTOOL
if errorlevel 1 goto FAILED

echo.
echo Select partition layout:
echo  1. Basic    (2 x 1.25 MiB OTA)
echo  2. Extended (2 x 1.875 MiB OTA)
echo.
set /p LAYOUT_CHOICE="Select layout: "
if "!LAYOUT_CHOICE!"=="1" (
    set "LAYOUT=basic"
    set "FACTORY_IMAGE=%~dp0factory-basic.bin"
) else if "!LAYOUT_CHOICE!"=="2" (
    set "LAYOUT=extended"
    set "FACTORY_IMAGE=%~dp0factory-extended.bin"
) else (
    echo [ERROR] Invalid layout option.
    goto FAILED
)

if not exist "!FACTORY_IMAGE!" (
    echo [ERROR] Factory image not found: !FACTORY_IMAGE!
    goto FAILED
)

call :CHECK_PORT
if errorlevel 1 goto FAILED

echo.
echo [WARNING] FACTORY RESET WILL ERASE ALL FLASH DATA.
echo Preferences, NVS settings and existing firmware will be deleted.
echo The selected layout will be installed: !LAYOUT!
set /p CONFIRM="Type ERASE to continue: "
if not "!CONFIRM!"=="ERASE" (
    echo Cancelled.
    goto DONE
)

echo.
echo [2/3] Erasing flash...
"%ESPTOOL%" --chip esp32 --port !COM_PORT! --baud 460800 erase_flash
if errorlevel 1 (
    echo [ERROR] Flash erase failed.
    goto FAILED
)

echo.
echo [3/3] Writing full Factory image...
"%ESPTOOL%" --chip esp32 --port !COM_PORT! --baud 460800 --after hard_reset write_flash --flash_mode dio --flash_freq 40m --flash_size 4MB 0x0 "!FACTORY_IMAGE!"
if errorlevel 1 (
    echo [ERROR] Factory image upload failed.
    goto FAILED
)

>"%~dp0active_layout.txt" echo !LAYOUT!
echo.
echo [SUCCESS] Factory installed. Active layout saved as !LAYOUT!.
echo Connect to Wi-Fi ESP32 and open http://192.168.4.1/update
goto DONE

:FAILED
echo.
echo [FAILED] Operation did not complete.
:DONE
echo.
pause
exit /b 0
