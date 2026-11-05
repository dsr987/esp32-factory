# Windows flasher

The BAT file expects the following files in one distribution folder:

- `ESP32-Auto-Flasher.bat`
- `arduino-cli.exe` (optional: if it is missing, the BAT offers to download and install it into `%LOCALAPPDATA%\\LegoTechnicESP32`)
- `factory-basic.bin`
- `factory-extended.bin`
- `boot_app0.bin`
- `partitions/basic.csv`
- `partitions/extended.csv`

The BAT checks for Arduino ESP32 Core 2.0.9 before each operation. For **Flash project (.ino)** it also checks `AsyncTCP 1.1.4`, `ESPAsyncWebServer 3.1.0`, and `ElegantOTA 3.1.0`. If any dependency is missing or has another version, the script offers to install the required version through Arduino CLI. The ESP32 core's `esptool.exe` is located under the standard Windows Arduino data directory (`%LOCALAPPDATA%\\Arduino15`).

## Active partition layout

The BAT stores the selected layout in `active_layout.txt` next to the script.

- After a successful Factory Reset, the script saves the layout that it installed.
- If the file is missing or invalid, the script asks you to select Basic or Extended before flashing.
- Use menu option **5. Select/change active layout** to change the selection manually.
- This is only a PC-side setting. The script does not read the partition table from the ESP32. Select the layout that is already installed on that controller. A wrong selection can cause firmware upload or boot failures.

Basic uses two 1.25 MiB OTA slots. Extended uses two 1.875 MiB OTA slots.

## Flashing several controllers

After an operation, press **R** to return to the main menu without closing the BAT window. Connect the next controller and repeat the required operation. Press **E** to exit.

The **R** option in the main menu also returns to the menu. Restarting the menu does not erase Flash or change the installed layout.

## Dependency checks

- If `arduino-cli.exe` is not found next to the BAT or in the portable install folder, the script offers to download the official Windows x64 build and create a local CLI configuration.
- Before flashing, it checks for Arduino ESP32 Core **2.0.9**. If missing, it offers to add Espressif's board index and install the core.
- Before compiling an `.ino` sketch, it checks the three pinned libraries listed above and offers to install any missing or mismatched versions.
- If installation is declined or fails, the current operation stops without starting a flash or erase.

The library check covers the Factory toolchain dependencies. A user-supplied project sketch may require additional libraries; those are not inferred automatically and must be installed separately.
