# Windows flasher

The BAT file expects the following files in one distribution folder:

- `ESP32-Auto-Flasher.bat`
- `arduino-cli.exe`
- `factory-basic.bin`
- `factory-extended.bin`
- `boot_app0.bin`
- `partitions/basic.csv`
- `partitions/extended.csv`

It also expects the ESP32 Arduino Core 2.0.9 to be installed through Arduino CLI. The BAT locates the core's `esptool.exe` under the standard Windows Arduino data directory (`%LOCALAPPDATA%\Arduino15`).

The BAT creates `active_layout.txt` only after a successful Factory Reset. This is a local PC-side selection, not an automatic hardware readout.
