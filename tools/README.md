# Windows flasher

The BAT file expects the following files in one distribution folder:

- `ESP32-Auto-Flasher.bat`
- `arduino-cli.exe` (or an existing portable copy at `%LOCALAPPDATA%\\LegoTechnicESP32\\arduino-cli.exe`)
- `factory-basic.bin`
- `factory-extended.bin`
- `boot_app0.bin`
- `partitions/basic.csv`
- `partitions/extended.csv`

It also expects the ESP32 Arduino Core 2.0.9 to be installed through Arduino CLI. The BAT locates the core's `esptool.exe` under the standard Windows Arduino data directory (`%LOCALAPPDATA%\\Arduino15`).

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
