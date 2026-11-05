# ESP32 Factory

Универсальная заводская прошивка для классических ESP32 с Flash 4 МБ.

Репозиторий содержит один исходник Factory и два варианта таблицы разделов. Factory нужна для первичной USB-прошивки платы, восстановления после неудачной прошивки и установки проектной прошивки через OTA.

## Что входит

- Один общий скетч `factory/factory.ino`, не зависящий от конкретного проекта.
- **Basic**: два OTA-слота по `0x140000` (1,25 MiB), стандартная разметка Arduino ESP32.
- **Extended**: два OTA-слота по `0x1E0000` (1,875 MiB, 1920 KiB) каждый, с небольшими SPIFFS (128 KiB) и coredump (64 KiB).
- Полные Factory-образы с bootloader, partition table, OTA metadata и приложением.
- BAT-флешер для Windows.
- CI-сборка и проверка обеих таблиц.

## Factory Wi-Fi и OTA

| Параметр | Значение |
|---|---|
| Wi-Fi SSID | `ESP32` |
| Wi-Fi password | `12345678` |
| Адрес | `http://192.168.4.1` |
| OTA page | `http://192.168.4.1/update` |
| OTA username | `admin` |
| OTA password | `admin` |

Эти стандартные реквизиты оставлены намеренно. После установки проектной прошивки Factory заменяется проектом.

## Выбор разметки

| Вариант | OTA slot 0 | OTA slot 1 | Дополнительные разделы |
|---|---:|---:|---|
| Basic | 1,25 MiB | 1,25 MiB | SPIFFS и coredump, как в стандартной таблице Arduino |
| Extended | 1,875 MiB | 1,875 MiB | SPIFFS 128 KiB и coredump 64 KiB |

Оба варианта рассчитаны на Flash 4 MiB. Extended соответствует стандартной схеме `min_spiffs` в Arduino ESP32 Core 2.0.9 и оставляет небольшой раздел SPIFFS размером 128 KiB.

В обеих таблицах сохранены:
- NVS `0x9000..0xDFFF`, 20 KiB. Здесь работают Arduino Preferences и другие настройки.
- OTA metadata `0xE000..0xFFFF`, 8 KiB.
- Два OTA app-раздела.

PSRAM для этих таблиц не требуется. Размер Flash и наличие PSRAM — разные характеристики.

**Важно:** Extended подходит только проектам, которые действительно собираются с `partitions/extended.csv`. Нельзя устанавливать Extended Factory, а затем собирать проект со стандартной Basic-разметкой. Переключать разметку следует через Factory Reset, который полностью стирает Flash.

## Как использовать

1. Скачайте комплект из GitHub Actions artifact или из GitHub Release.
2. Поместите BAT-файл, `arduino-cli.exe`, Factory-образы и `boot_app0.bin` в одну папку. Установите ESP32 Arduino Core 2.0.9 через Arduino CLI, чтобы BAT мог найти esptool.
3. Запустите `ESP32-Auto-Flasher.bat`.
4. Для первой установки выберите **Factory Reset**, затем Basic или Extended.
5. Подключитесь к Wi-Fi `ESP32`, откройте `http://192.168.4.1/update` и загрузите app-only BIN нужного проекта.

После успешного Factory Reset BAT сохраняет выбранный вариант в `active_layout.txt`. Обычная прошивка INO/BIN использует этот сохранённый вариант. Файл относится к компьютеру, а не считывается с платы: если подключаете другую ESP32 с другой разметкой, сначала выполните Factory Reset с нужным вариантом.

### INO и BIN

- **INO**: BAT копирует проект во временную папку, добавляет выбранную таблицу, компилирует и загружает прошивку через Arduino CLI.
- **BIN**: ожидается app-only бинарник проекта, не полный merged image. BAT проверяет размер, записывает OTA metadata initializer и приложение в OTA slot 0 без полного стирания Flash.
- **Factory Reset**: выполняет `erase_flash` и записывает полный Factory image с адреса `0x0`.

Для OTA через ElegantOTA также нужен app-only BIN. Он должен быть собран под ту же таблицу разделов, которая установлена на плате.

## Содержимое репозитория

- `factory/factory.ino` — единственный исходник Factory.
- `partitions/basic.csv` — совместимая базовая разметка.
- `partitions/extended.csv` — схема `min_spiffs` с OTA-слотами по 1920 KiB.
- `tools/ESP32-Auto-Flasher.bat` — Windows-флешер.
- `tools/validate_partitions.py` — проверка размеров, выравнивания и пересечений.
- `.github/workflows/build-factory.yml` — сборка Factory-образов.

## Ограничения

- Цель проекта — классическая ESP32 с Flash 4 MiB (например, ESP32 DevKit V3 30 pin). Это не таблицы для ESP32-S2/S3/C3.
- Factory не содержит проектных функций и не является резервной копией Autoheater или LEGO Technic.
- Factory Reset стирает NVS, Preferences, Wi-Fi-настройки и остальные данные во Flash.
- Перед обычной записью BIN убедитесь, что он собран под выбранный вариант разметки.
- Стандартные пароли не предназначены для защищённой эксплуатации в недоверенной среде.
