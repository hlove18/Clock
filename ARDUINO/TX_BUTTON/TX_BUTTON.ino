#include <SPI.h>
#include <RH_RF95.h>

// Radio pins
#define RFM95_CS  3
#define RFM95_RST 1
#define RFM95_INT 0
#define RFM95_EN  6

// Change to 434.0 or other frequency, must match RX's freq!
#define RF95_FREQ 433.0

// Singleton instance of the radio driver
RH_RF95 rf95(RFM95_CS, RFM95_INT);

// Button
#define buttonPin 7

// Variables will change
int buttonState;            // the current reading from the input pin
int lastButtonState = HIGH; // the previous reading from the input pin

// the following variables are unsigned longs because the time, measured in
// milliseconds, will quickly become a bigger number than can be stored in an int.
unsigned long lastDebounceTime = 0;  // the last time the output pin was toggled
unsigned long debounceDelay = 50;    // the debounce time; increase if the output flickers

void setup() {
  pinMode(buttonPin, INPUT_PULLUP);
  pinMode(RFM95_EN, OUTPUT);   
  pinMode(RFM95_RST, OUTPUT);

  while (!Serial);
  Serial.begin(9600);
  delay(100);

  // Disable the radio to save power
  disable_radio();
}

// enable radio function
void enable_radio() {
  digitalWrite(RFM95_EN, HIGH);
  delay(10);
  digitalWrite(RFM95_RST, HIGH);
  delay(10);

  // manual reset
  digitalWrite(RFM95_RST, LOW);
  delay(10);
  digitalWrite(RFM95_RST, HIGH);
  delay(10);

  while (!rf95.init()) {
    Serial.println("LoRa radio init failed");
    while (1);
  }
  Serial.println("LoRa radio init OK!");

  // Defaults after init are 434.0MHz, modulation GFSK_Rb250Fd250, +13dbM
  if (!rf95.setFrequency(RF95_FREQ)) {
    Serial.println("setFrequency failed");
    while (1);
  }
  Serial.print("Set Freq to: "); Serial.println(RF95_FREQ);

  // Defaults after init are 434.0MHz, 13dBm, Bw = 125 kHz, Cr = 4/5, Sf = 128chips/symbol, CRC on

  // The default transmitter power is 13dBm, using PA_BOOST.
  // If you are using RFM95/96/97/98 modules which uses the PA_BOOST transmitter pin, then 
  // you can set transmitter powers from 5 to 23 dBm:
  rf95.setTxPower(23, false);
}

// Disable radio function
void disable_radio() {
  digitalWrite(RFM95_EN, LOW);
  digitalWrite(RFM95_RST, LOW);

  Serial.println("LoRa radio disabled");
}

// Transmit function
void transmit() {
  // Enable radio
  enable_radio();

  Serial.println("Sending to rf95_server");
  // Send a message to rf95_server
  
  char radiopacket[] = "Hank<3";
  Serial.print("Sending "); Serial.println(radiopacket);
      
  Serial.println("Sending..."); delay(10);
  rf95.send((uint8_t *)radiopacket, strlen(radiopacket));

  Serial.println("Waiting for packet to complete..."); delay(10);
  rf95.waitPacketSent();

  // Disable the radio to save power
  disable_radio();
}

void loop() {
  // read the state of the switch into a local variable:
  int reading = digitalRead(buttonPin);

  // check to see if you just pressed the button
  // (i.e. the input went from LOW to HIGH), and you've waited long enough
  // since the last press to ignore any noise:

  // If the switch changed, due to noise or pressing:
  if (reading != lastButtonState) {
    // reset the debouncing timer
    lastDebounceTime = millis();
  }

  if ((millis() - lastDebounceTime) > debounceDelay) {
    // whatever the reading is at, it's been there for longer than the debounce
    // delay, so take it as the actual current state:

    // if the button state has changed:
    if (reading != buttonState) {
      buttonState = reading;

      // only toggle the LED if the new button state is HIGH
      if (buttonState == LOW) {
        transmit();
      }
    }
  }

  // save the reading. Next time through the loop, it'll be the lastButtonState:
  lastButtonState = reading;
}
