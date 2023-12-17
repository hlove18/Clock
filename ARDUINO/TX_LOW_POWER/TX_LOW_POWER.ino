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

void setup() {
  pinMode(RFM95_EN, OUTPUT);   
  pinMode(RFM95_RST, OUTPUT);

  // transmit
  transmit();
}

// enable radio function
void enable_radio() {
  digitalWrite(RFM95_EN, HIGH);
  delay(5);
  digitalWrite(RFM95_RST, HIGH);
  delay(5);

  // manual reset
  digitalWrite(RFM95_RST, LOW);
  delay(5);
  digitalWrite(RFM95_RST, HIGH);
  delay(5);

  while (!rf95.init()) {
    while (1);
  }

  // Defaults after init are 434.0MHz, modulation GFSK_Rb250Fd250, +13dbM
  if (!rf95.setFrequency(RF95_FREQ)) {
    while (1);
  }

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
}

// Transmit function
void transmit() {
  // Enable radio
  enable_radio();

  // Send a message to rf95_server
  char radiopacket[] = "Hank<3";
  // delay(10);
  rf95.send((uint8_t *)radiopacket, strlen(radiopacket));
  // delay(10);
  rf95.waitPacketSent();

  // Disable the radio to save power
  disable_radio();
}

void loop() {
  // transmit();
  // delay(100);
}
