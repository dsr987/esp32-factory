/*
 * ESP32 Universal Factory
 * Version: 1.0.0
 *
 * Универсальная временная прошивка для первичной настройки и восстановления
 * классических ESP32 с Flash 4 MiB.
 *
 * Не содержит кода конкретного проекта. После установки проектной прошивки
 * Factory заменяется проектом через OTA.
 */

#define ELEGANTOTA_USE_ASYNC_WEBSERVER 1

#include <Arduino.h>
#include <WiFi.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <ElegantOTA.h>

namespace {
constexpr char AP_SSID[] = "ESP32";
constexpr char AP_PASSWORD[] = "12345678";
constexpr char OTA_USERNAME[] = "admin";
constexpr char OTA_PASSWORD[] = "admin";

constexpr char ROOT_PAGE[] PROGMEM = R"HTML(
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>ESP32 Factory</title>
  <style>
    body{font:16px system-ui,sans-serif;max-width:640px;margin:12vh auto;padding:24px;line-height:1.5}
    main{border:1px solid #ccc;border-radius:12px;padding:24px}
    a{display:inline-block;padding:12px 18px;background:#1769aa;color:white;border-radius:8px;text-decoration:none}
    code{background:#eee;padding:2px 5px;border-radius:4px}
  </style>
</head>
<body>
<main>
  <h1>ESP32 Factory</h1>
  <p>Universal recovery firmware is running.</p>
  <p>Open the OTA page to install your project firmware.</p>
  <p><a href="/update">Open ElegantOTA</a></p>
  <p>Default OTA login: <code>admin</code> / <code>admin</code></p>
</main>
</body>
</html>
)HTML";

AsyncWebServer server(80);
}

void setup() {
  Serial.begin(115200);
  delay(150);

  WiFi.mode(WIFI_AP);
  WiFi.setSleep(false);

  if (!WiFi.softAP(AP_SSID, AP_PASSWORD)) {
    Serial.println("[FACTORY] ERROR: failed to start access point");
  } else {
    Serial.println();
    Serial.println("[FACTORY] Access point started");
    Serial.print("[FACTORY] SSID: ");
    Serial.println(AP_SSID);
    Serial.print("[FACTORY] IP: ");
    Serial.println(WiFi.softAPIP());
  }

  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send_P(200, "text/html; charset=utf-8", ROOT_PAGE);
  });

  server.onNotFound([](AsyncWebServerRequest *request) {
    request->send(404, "text/plain; charset=utf-8", "Not found. Open / or /update.");
  });

  ElegantOTA.begin(&server, OTA_USERNAME, OTA_PASSWORD);
  server.begin();

  Serial.println("[FACTORY] ElegantOTA: http://192.168.4.1/update");
}

void loop() {
  ElegantOTA.loop();
  delay(2);
}
