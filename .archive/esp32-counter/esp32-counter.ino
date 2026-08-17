#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

constexpr uint8_t SCREEN_WIDTH = 128;
constexpr uint8_t SCREEN_HEIGHT = 64;
constexpr uint8_t OLED_ADDRESS = 0x3C;
constexpr uint8_t BUTTON_PIN = 18;
constexpr unsigned long DEBOUNCE_MS = 35;

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

uint32_t counter = 0;
bool stableButtonState = HIGH;
bool lastButtonReading = HIGH;
unsigned long lastButtonChangeAt = 0;

void drawCounter()
{
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println("COUNTER");

    display.setTextSize(4);
    display.setCursor(0, 22);
    display.println(counter);
    display.display();
}

void setup()
{
    Serial.begin(115200);
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    Wire.begin(21, 22);

    if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
        Serial.println("SSD1306 not found");
        while (true) {
            delay(1000);
        }
    }

    drawCounter();
}

void loop()
{
    const bool reading = digitalRead(BUTTON_PIN);

    if (reading != lastButtonReading) {
        lastButtonChangeAt = millis();
        lastButtonReading = reading;
    }

    if (millis() - lastButtonChangeAt >= DEBOUNCE_MS && reading != stableButtonState) {
        stableButtonState = reading;

        if (stableButtonState == LOW) {
            ++counter;
            drawCounter();
            Serial.println(counter);
        }
    }
}
