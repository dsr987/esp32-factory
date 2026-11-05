@echo off
setlocal EnableExtensions EnableDelayedExpansion
title ESP32 Auto-Flasher
set "RESULT=1"

:MENU
set "RESULT=1"
echo ====================================================
echo              ESP32 AUTO-FLASHER
echo ====================================================
echo.
echo  1. Flash project (.ino)
echo  2. Flash firmware (.bin)
echo  3. Factory Reset
echo  4. Exit
echo  5. Select/change active layout
echo  R. Restart menu
echo.
set "ACTION="
set /p ACTION="Select option: "

if "%ACTION%"=="1" goto FLASH_INO
if "%ACTION%"=="2" goto FLASH_BIN
if "%ACTION%"=="3" goto FACTORY_RESET
if "%ACTION%"=="4" exit /b 0
if /I "%ACTION%"=="5" goto CHANGE_LAYOUT
if /I "%ACTION%"=="R" goto MENU

echo.
echo [ERROR] Invalid menu option.
goto DONE

:CHECK_CLI
set "CLI=%~dp0arduino-cli.exe"
set "CLI_CONFIG_ARGS="
if not exist "%CLI%" if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\LegoTechnicESP32\arduino-cli.exe" set "CLI=%LOCALAPPDATA%\LegoTechnicESP32\arduino-cli.exe"
if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\LegoTechnicESP32\arduino-cli.yaml" set CLI_CONFIG_ARGS=--config-file "%LOCALAPPDATA%\LegoTechnicESP32\arduino-cli.yaml"

if not exist "%CLI%" (
    echo.
    echo [MISSING] Arduino CLI is not installed.
    choice /C YN /N /M "Download and install Arduino CLI now? [Y/N]: "
    if errorlevel 2 exit /b 1

    set "ESP32_CLI_HOME=%LOCALAPPDATA%\LegoTechnicESP32"
    if not exist "!ESP32_CLI_HOME!" mkdir "!ESP32_CLI_HOME!"
    echo Downloading Arduino CLI...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $zip=Join-Path $env:TEMP 'arduino-cli-windows.zip'; Invoke-WebRequest -UseBasicParsing 'https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Windows_64bit.zip' -OutFile $zip; Expand-Archive -LiteralPath $zip -DestinationPath $env:ESP32_CLI_HOME -Force; Remove-Item $zip -Force"
    if errorlevel 1 (
        echo [ERROR] Arduino CLI download or extraction failed.
        exit /b 1
    )
    set "CLI=!ESP32_CLI_HOME!\arduino-cli.exe"
    if not exist "!CLI!" (
        echo [ERROR] arduino-cli.exe was not found after extraction.
        exit /b 1
    )
    "!CLI!" config init --overwrite --dest-dir "!ESP32_CLI_HOME!" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to create Arduino CLI configuration.
        exit /b 1
    )
    set CLI_CONFIG_ARGS=--config-file "!ESP32_CLI_HOME!\arduino-cli.yaml"
)

if not exist "%CLI%" (
    echo [ERROR] Arduino CLI executable was not found.
    exit /b 1
)
exit /b 0

:CHECK_DEPENDENCIES
set "NEED_CORE=0"
set "NEED_ASYNCTCP=0"
set "NEED_WEBSERVER=0"
set "NEED_ELEGANTOTA=0"
set "CHECK_TEMP=%temp%\esp32-cli-check"

set "NEED_CORE=1"
"%CLI%" !CLI_CONFIG_ARGS! core list > "!CHECK_TEMP!-core.txt" 2>nul
for /f "tokens=1,2" %%A in ('findstr /I /B /C:"esp32:esp32 " "!CHECK_TEMP!-core.txt"') do if "%%B"=="2.0.9" set "NEED_CORE=0"

if "!CHECK_LIBS!"=="1" (
    set "NEED_ASYNCTCP=1"
    set "NEED_WEBSERVER=1"
    set "NEED_ELEGANTOTA=1"
    "%CLI%" !CLI_CONFIG_ARGS! lib list > "!CHECK_TEMP!-libs.txt" 2>nul

    for /f "tokens=1,2" %%A in ('findstr /I /B /C:"AsyncTCP " "!CHECK_TEMP!-libs.txt"') do if "%%B"=="1.1.4" set "NEED_ASYNCTCP=0"
    for /f "tokens=1,2" %%A in ('findstr /I /B /C:"ESPAsyncWebServer " "!CHECK_TEMP!-libs.txt"') do if "%%B"=="3.1.0" set "NEED_WEBSERVER=0"
    for /f "tokens=1,2" %%A in ('findstr /I /B /C:"ElegantOTA " "!CHECK_TEMP!-libs.txt"') do if "%%B"=="3.1.0" set "NEED_ELEGANTOTA=0"
)

if "!NEED_CORE!"=="0" if "!NEED_ASYNCTCP!"=="0" if "!NEED_WEBSERVER!"=="0" if "!NEED_ELEGANTOTA!"=="0" (
    echo [OK] Arduino ESP32 Core and required libraries are installed.
    goto DEPENDENCIES_DONE
)

echo.
echo [MISSING] The following build dependencies are missing or have the wrong version:
if "!NEED_CORE!"=="1" echo   - Arduino ESP32 Core 2.0.9
if "!NEED_ASYNCTCP!"=="1" echo   - AsyncTCP 1.1.4
if "!NEED_WEBSERVER!"=="1" echo   - ESPAsyncWebServer 3.1.0
if "!NEED_ELEGANTOTA!"=="1" echo   - ElegantOTA 3.1.0
choice /C YN /N /M "Install the missing dependencies now? [Y/N]: "
if errorlevel 2 (
    del "!CHECK_TEMP!-*.txt" >nul 2>&1
    exit /b 1
)

if "!NEED_CORE!"=="1" (
    "%CLI%" !CLI_CONFIG_ARGS! config dump > "!CHECK_TEMP!-config.txt" 2>nul
    findstr /I /C:"https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json" "!CHECK_TEMP!-config.txt" >nul
    if errorlevel 1 (
        "%CLI%" !CLI_CONFIG_ARGS! config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
        if errorlevel 1 goto DEPENDENCIES_FAILED
    )
    echo Installing Arduino ESP32 Core 2.0.9...
    "%CLI%" !CLI_CONFIG_ARGS! core update-index
    if errorlevel 1 goto DEPENDENCIES_FAILED
    "%CLI%" !CLI_CONFIG_ARGS! core install esp32:esp32@2.0.9
    if errorlevel 1 goto DEPENDENCIES_FAILED
)

if "!CHECK_LIBS!"=="1" (
    "%CLI%" !CLI_CONFIG_ARGS! lib update-index
    if errorlevel 1 goto DEPENDENCIES_FAILED
    if "!NEED_ASYNCTCP!"=="1" (
        echo Installing AsyncTCP 1.1.4...
        "%CLI%" !CLI_CONFIG_ARGS! lib install "AsyncTCP@1.1.4"
        if errorlevel 1 goto DEPENDENCIES_FAILED
    )
    if "!NEED_WEBSERVER!"=="1" (
        echo Installing ESPAsyncWebServer 3.1.0...
        "%CLI%" !CLI_CONFIG_ARGS! lib install "ESPAsyncWebServer@3.1.0"
        if errorlevel 1 goto DEPENDENCIES_FAILED
    )
    if "!NEED_ELEGANTOTA!"=="1" (
        echo Installing ElegantOTA 3.1.0...
        "%CLI%" !CLI_CONFIG_ARGS! lib install "ElegantOTA@3.1.0"
        if errorlevel 1 goto DEPENDENCIES_FAILED
    )
)

echo [OK] All required dependencies are installed.
goto DEPENDENCIES_DONE

:DEPENDENCIES_FAILED
echo [ERROR] Dependency installation failed. Check the messages above and try again.
del "!CHECK_TEMP!-*.txt" >nul 2>&1
exit /b 1

:DEPENDENCIES_DONE
del "!CHECK_TEMP!-*.txt" >nul 2>&1
exit /b 0

:CHECK_PORT
echo.
echo [1/3] Searching for connected ESP32 COM port...
"%CLI%" !CLI_CONFIG_ARGS! board list > "%temp%\esp32-boards.txt" 2>nul
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
    for /d %%D in ("%LOCALAPPDATA%\LegoTechnicESP32\data\packages\esp32\tools\esptool_py\*") do (
        if exist "%%~fD\esptool.exe" set "ESPTOOL=%%~fD\esptool.exe"
    )
)
if not defined ESPTOOL (
    echo [ERROR] esptool.exe not found in the Arduino ESP32 core installation.
    echo Install ESP32 Arduino Core 2.0.9 using Arduino CLI first.
    exit /b 1
)
exit /b 0

:SELECT_LAYOUT
echo.
echo [WARNING] This changes the layout selected by this PC-side script only.
echo It does NOT read or change the partition table inside the ESP32.
echo Select the layout that is ALREADY installed on the connected controller.
echo Choosing the wrong layout can make a firmware upload fail or boot incorrectly.
echo.
echo  1. Basic    (2 x 1.25 MiB OTA)
echo  2. Extended (2 x 1.875 MiB OTA)
echo  0. Cancel
echo.
set "LAYOUT_CHOICE="
set /p LAYOUT_CHOICE="Select installed layout: "
if "!LAYOUT_CHOICE!"=="1" (
    set "LAYOUT=basic"
) else if "!LAYOUT_CHOICE!"=="2" (
    set "LAYOUT=extended"
) else (
    echo [INFO] Layout selection cancelled.
    exit /b 1
)
>"%~dp0active_layout.txt" echo !LAYOUT!
echo [OK] Active layout saved as !LAYOUT! in active_layout.txt.
exit /b 0

:LOAD_LAYOUT
set "LAYOUT="
if exist "%~dp0active_layout.txt" set /p LAYOUT=<"%~dp0active_layout.txt"
if /I not "!LAYOUT!"=="basic" if /I not "!LAYOUT!"=="extended" set "LAYOUT="
if not defined LAYOUT (
    echo [INFO] No valid active_layout.txt was found.
    call :SELECT_LAYOUT
    if errorlevel 1 exit /b 1
)
if /I "!LAYOUT!"=="basic" (
    set "SLOT_SIZE=1310720"
    set "PARTITION_CSV=%~dp0partitions\basic.csv"
) else (
    set "SLOT_SIZE=1966080"
    set "PARTITION_CSV=%~dp0partitions\extended.csv"
)
exit /b 0

:CHANGE_LAYOUT
call :SELECT_LAYOUT
if errorlevel 1 goto DONE
set "RESULT=0"
goto DONE

:FLASH_INO
call :CHECK_CLI
if errorlevel 1 goto FAILED
set "CHECK_LIBS=1"
call :CHECK_DEPENDENCIES
if errorlevel 1 goto FAILED
call :LOAD_LAYOUT
if errorlevel 1 goto FAILED

echo.
set "SKETCH_DIR="
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
"%CLI%" !CLI_CONFIG_ARGS! compile --fqbn esp32:esp32:esp32 --build-property compiler.cpp.extra_flags="-DELEGANTOTA_USE_ASYNC_WEBSERVER=1" --build-path "%BUILD_DIR%" "%TEMP_SKETCH%"
if errorlevel 1 (
    echo [ERROR] Compilation failed.
    goto FAILED
)

echo.
echo [3/3] Uploading firmware to !COM_PORT!...
"%CLI%" !CLI_CONFIG_ARGS! upload --input-dir "%BUILD_DIR%" -p !COM_PORT! --fqbn esp32:esp32:esp32 "%TEMP_SKETCH%"
if errorlevel 1 (
    echo [ERROR] Upload failed. Try holding the BOOT button.
    goto FAILED
)

echo.
echo [SUCCESS] Firmware uploaded using !LAYOUT! layout.
set "RESULT=0"
goto DONE

:FLASH_BIN
call :CHECK_CLI
if errorlevel 1 goto FAILED
set "CHECK_LIBS=0"
call :CHECK_DEPENDENCIES
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
set "BIN_FILE="
set "BIN_MAGIC="
set /p BIN_FILE="Drag and drop app-only .bin file here: "
set "BIN_FILE=!BIN_FILE:"=!"
if not exist "!BIN_FILE!" (
    echo [ERROR] BIN file does not exist.
    goto FAILED
)
for %%I in ("!BIN_FILE!") do set "BIN_SIZE=%%~zI"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$b = Get-Content -LiteralPath '!BIN_FILE!' -Encoding Byte -TotalCount 1; if ($b.Length -gt 0) { '{0:X2}' -f $b[0] }"`) do set "BIN_MAGIC=%%A"
if /I not "!BIN_MAGIC!"=="E9" (
    echo [ERROR] This does not look like an app-only ESP32 firmware BIN.
    echo Do not select a merged Factory image here.
    goto FAILED
)
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
set "RESULT=0"
goto DONE

:FACTORY_RESET
call :CHECK_CLI
if errorlevel 1 goto FAILED
set "CHECK_LIBS=0"
call :CHECK_DEPENDENCIES
if errorlevel 1 goto FAILED
call :CHECK_ESPTOOL
if errorlevel 1 goto FAILED

echo.
echo Select partition layout:
echo  1. Basic    (2 x 1.25 MiB OTA)
echo  2. Extended (2 x 1.875 MiB OTA)
echo.
set "LAYOUT_CHOICE="
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
set "CONFIRM="
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
set "RESULT=0"
echo Connect to Wi-Fi ESP32 and open http://192.168.4.1/update
goto DONE

:FAILED
echo.
echo [FAILED] Operation did not complete.
:DONE
echo.
choice /C RE /N /M "Press R to return to the menu, or E to exit: "
if errorlevel 2 exit /b !RESULT!
if errorlevel 1 goto MENU
exit /b !RESULT!
