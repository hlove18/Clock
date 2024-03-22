#include <SPI.h>
#include <RH_RF95.h>

// Radio pins
#define RFM95_CS  6 //3
#define RFM95_RST 5 //1
#define RFM95_INT 4 //0
// #define RFM95_EN  6
// LED pins
#define RED_LED_OFF 0
#define GREEN_LED_OFF 1
// Input pins
#define POWER_VOLTAGE 2
#define CHARGING 3
#define NOT_BUTTON 7

// Change to 434.0 or other frequency, must match RX's freq!
#define RF95_FREQ 433.0

// Singleton instance of the radio driver
RH_RF95 rf95(RFM95_CS, RFM95_INT);

// Variables for storing battery status.
float supply_voltage = 0;
bool is_plugged_in = false;
bool did_transmit = false;


void setup() {
  // Set up radio pins.
  // pinMode(RFM95_EN, OUTPUT);   
  pinMode(RFM95_RST, OUTPUT);

  // Set up I/O.
  pinMode(RED_LED_OFF, OUTPUT);
  pinMode(GREEN_LED_OFF, OUTPUT);
  pinMode(POWER_VOLTAGE, INPUT);
  pinMode(CHARGING, INPUT);
  pinMode(NOT_BUTTON, INPUT);

  // Turn off LEDs.
  digitalWrite(RED_LED_OFF, HIGH);
  digitalWrite(GREEN_LED_OFF, HIGH);

  // Change the analogRead resolution to 12 bits
  analogReadResolution(12);

  //while (!Serial);
  //Serial.begin(9600);
  //delay(100);
}

// enable radio function
void enable_radio() {
  // digitalWrite(RFM95_EN, HIGH);
  // delay(5);
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
  // digitalWrite(RFM95_EN, LOW);
  digitalWrite(RFM95_RST, LOW);
}

// Transmit function
void transmit() {
  //Serial.println("Transmitting!");

  // Enable radio
  enable_radio();

  // Send a message to rf95_server
  char radio_packet[] = "Hank<3";
  // delay(10);
  rf95.send((uint8_t *)radio_packet, strlen(radio_packet));
  // delay(10);
  rf95.waitPacketSent();

  // Disable the radio to save power
  disable_radio();
}

// Check battery and display if low voltage.
void check_battery_status() {
  // Times 2 for voltage divider.
  // updated analogRead resolution to 12bits (as supported by qt py)
  supply_voltage = 2 * (analogRead(POWER_VOLTAGE) * 3.3) / 4095;

  // Serial.println(supply_voltage);

  // Check if plugged in.
  if (supply_voltage > 4.5) {  // Plugged in.
    // Check if charging.
    if (digitalRead(CHARGING) == true) {  // Charging.
      // Indicate charging with yellow light.
      digitalWrite(RED_LED_OFF, LOW);
      digitalWrite(GREEN_LED_OFF, LOW);
    }
    else { // Fully charged.
      // Indicate full charge with green light.
      digitalWrite(RED_LED_OFF, HIGH);
      digitalWrite(GREEN_LED_OFF, LOW);
    }
  }
  else {  // Battery power.
    // Check if the battery voltage is low.  Discharge cut-off voltage is 3.0V.
    if (supply_voltage < 3.425) { // Low battery; defined by LDO (AP2112-3.3) dropout voltage
      // Indicate low battery with red light.
      digitalWrite(RED_LED_OFF, LOW);
      digitalWrite(GREEN_LED_OFF, HIGH);
    }
    else {  // Battery has charge.
      // Indicate battery has charge with green light.
      digitalWrite(RED_LED_OFF, HIGH);
      digitalWrite(GREEN_LED_OFF, LOW);
    }
  }
}

void loop() {
  // Check and display battery voltage if low.
  check_battery_status();

  // Transmit once for every button press.
  if (digitalRead(NOT_BUTTON) == false) {   // Button is pressed.
    if (did_transmit == false) {
      transmit();
      did_transmit = true;
    }
  }
  else {
    did_transmit = false;
  }

  delay(100);
}
