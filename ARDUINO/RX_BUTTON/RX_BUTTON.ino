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

// Remote
#define remotePin 7

void setup() {
  pinMode(remotePin, OUTPUT);
  pinMode(RFM95_EN, OUTPUT);   
  pinMode(RFM95_RST, OUTPUT);

  // Note level shift (inverter) between this pin and the Nixie clock
  digitalWrite(remotePin, LOW);

  while (!Serial);
  Serial.begin(9600);
  delay(100);

  // Enable the radio
  enable_radio();
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

void loop()
{
  if (rf95.available())
  {
    // Should be a message for us now   
    uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
    uint8_t len = sizeof(buf);
    
    if (rf95.recv(buf, &len))
    {
      //digitalWrite(LED, HIGH);
      RH_RF95::printBuffer("Received: ", buf, len);
      Serial.print("Got: ");
      Serial.println((char*)buf);
      Serial.print("RSSI: ");
      Serial.println(rf95.lastRssi(), DEC);
      
      // Note level shift (inverter) between this pin and the Nixie clock
      digitalWrite(remotePin, HIGH);
      delay(100);
      digitalWrite(remotePin, LOW);
    }
    else
    {
      Serial.println("Receive failed");
    }
  }
}