// ioPrims.cpp - Microblocks IO primitives and hardware dependent functions
// John Maloney, April 2017

#include "Arduino.h"
#include <SPI.h>
#include "Wire.h"
#include <stdio.h>

#include "mem.h"
#include "interp.h"

static void initPins(void); // forward reference
static void sendNeoPixelByte(int val); // forward reference

// Timing Functions

#ifdef NRF51

static char *clock_base = (char *) 0x40008000;

void initClock_NRF51() {
	*((int *) (clock_base + 0x010)) = 1; // shutdown & clear
	*((int *) (clock_base + 0x504)) = 0; // timer mode
	*((int *) (clock_base + 0x508)) = 3; // 32-bit
	*((int *) (clock_base + 0x510)) = 4; // prescale - divides 16MHz by 2^N
	*((int *) (clock_base + 0x0)) = 1; // start
}

uint32 microsecs() {
	*((int *) (clock_base + 0x40)) = 1; // capture into cc1
	return *((uint32 *) (clock_base + 0x540)); // return contents of cc1
}

uint32 millisecs() {
	// Approximate milliseconds as (usecs / 1024) using a bitshift, since divide is very slow.
	// This avoids the need for a second hardware timer for milliseconds, but the millisecond
	// clock is effectively only 22 bits, and (like the microseconds clock) it wraps around
	// every 72 minutes.

	return microsecs() >> 10;
}

void hardwareInit() {
	initClock_NRF51();
	initPins();
}

#else

uint32 microsecs() { return (uint32) micros(); }
uint32 millisecs() { return (uint32) millis(); }

void hardwareInit() {
	initPins();
}

#endif

// Communciation/System Functions

void putSerial(char *s) { Serial.print(s); } // callable from C; used to simulate printf for debugging

int readBytes(uint8 *buf, int count) {
	int bytesRead = Serial.available();
	for (int i = 0; i < bytesRead; i++) {
		buf[i] = Serial.read();
	}
	return bytesRead;
}

int canReadByte() { return Serial.available(); }
int sendByte(char aByte) { return Serial.write(aByte); }

// System Reset

void systemReset() {
	initPins();
	#if defined(ARDUINO_SAM_DUE) || defined(ARDUINO_NRF52_PRIMO) || defined(ARDUINO_BBC_MICROBIT) || defined(ARDUINO_CALLIOPE) || defined(ARDUINO_SAMD_MKRZERO)
		NVIC_SystemReset();
	#endif
}

// LED Matrix Pins on BBC micro:bit and Calliope

#if defined(ARDUINO_BBC_MICROBIT)

#define ROW1 3
#define ROW2 4
#define ROW3 6
#define ROW4 7
#define ROW5 9
#define ROW6 10
#define ROW7 23
#define ROW8 24
#define ROW9 25

#define COL1 26
#define COL2 27
#define COL3 28

#elif defined(ARDUINO_CALLIOPE)

#define ROW1 4
#define ROW2 5
#define ROW3 12
#define ROW4 11
#define ROW5 10
#define ROW6 6
#define ROW7 7
#define ROW8 8
#define ROW9 9

#define COL1 13
#define COL2 14
#define COL3 15

#endif

// General Purpose I/O Pins

#if defined(ARDUINO_SAM_DUE)

	#define BOARD_TYPE "Due"
	#define DIGITAL_PINS 54
	#define ANALOG_PINS 12
	#define TOTAL_PINS (DIGITAL_PINS + ANALOG_PINS)
	static const int analogPin[] = {A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11};

#elif defined(ARDUINO_NRF52_PRIMO)

	#define BOARD_TYPE "Primo"
	#define DIGITAL_PINS 14
	#define ANALOG_PINS 6
	#define DEDICATED_PINS 2 // USER1_BUTTON (20) and BUZZER (21)
	#define TOTAL_PINS (DIGITAL_PINS + ANALOG_PINS + DEDICATED_PINS)
	static const int analogPin[] = {A0, A1, A2, A3, A4, A5};

#elif defined(ARDUINO_BBC_MICROBIT)

	#define BOARD_TYPE "micro:bit"
	#define DIGITAL_PINS 33
	#define ANALOG_PINS 6
	#define TOTAL_PINS DIGITAL_PINS
	static const int analogPin[] = {A0, A1, A2, A3, A4, A5};

	// See variant.cpp in variants/BBCMicrobit folder for a detailed pin map.
	// Pins 0-20 are for micro:bit pads and edge connector
	//   (but pin numbers 17-18 correspond to 3.3 volt pads, not actual I/O pins)
	// Pins 21-22: RX, TX (for USB Serial?)
	// Pins 23-28: COL4, COL5, COL6, ROW1, ROW2, ROW3
	// Button A: pin 5
	// Button B: pin 11
	// Analog pins: The micro:bit does not have dedicated analog input pins;
	// the analog pins are aliases for digital pins 0-4 and 10.

#elif defined(ARDUINO_CALLIOPE)

	#define BOARD_TYPE "Calliope"
	#define DIGITAL_PINS 26
	#define ANALOG_PINS 6
	#define TOTAL_PINS DIGITAL_PINS
	static const int analogPin[] = {A0, A1, A2, A3, A4, A5};

	// See variant.cpp in variants/Calliope folder for a detailed pin map.
	// Pins 0-19 are for the large pads and 26 pin connector
	// Button A: pin 20
	// Microphone: pin 21
	// Button B: pin 22
	// Motor/Speaker: pins 23-25
	// Analog pins: The Calliope does not have dedicated analog input pins;
	// the analog pins are aliases for digital pins 6, 1, 2, 21 (microphone), 4, 5.

#elif defined(ARDUINO_SAMD_MKRZERO)

	#define BOARD_TYPE "MKRZero"
	#define DIGITAL_PINS 8
	#define ANALOG_PINS 7
	#define TOTAL_PINS (DIGITAL_PINS + ANALOG_PINS)
	static const int analogPin[] = {A0, A1, A2, A3, A4, A5, A6};

	#define PIN_LED 32

#elif defined(ARDUINO_SAMD_CIRCUITPLAYGROUND_EXPRESS)

	#define BOARD_TYPE "CircuitPlayground"
	#define DIGITAL_PINS 39
	#define ANALOG_PINS 11
	#define TOTAL_PINS 39
	static const int analogPin[] = {A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10};

#elif defined(ARDUINO_ESP8266_NODEMCU)

	#define BOARD_TYPE "ESP8266"
	#define DIGITAL_PINS 11
	#define ANALOG_PINS 1
	#define TOTAL_PINS (DIGITAL_PINS + ANALOG_PINS)
	static const int analogPin[] = {A0};
	#define PIN_LED BUILTIN_LED

#else // unknown board

	#define BOARD_TYPE "Generic"
	#define DIGITAL_PINS 0
	#define ANALOG_PINS 0
	#define TOTAL_PINS (DIGITAL_PINS + ANALOG_PINS)
	static const int analogPin[] = {};
	#define PIN_LED 0

#endif

// Board Type

const char * boardType() { return BOARD_TYPE; }

// Pin Modes

// The current pin input/output mode is recorded in the currentMode[] array to
// avoid calling pinMode() unless mode has actually changed. (This speeds up pin I/O.)

#define MODE_NOT_SET (-1)
static char currentMode[TOTAL_PINS];

#define SET_MODE(pin, newMode) { \
	if ((newMode) != currentMode[pin]) { \
		pinMode((pin), newMode); \
		currentMode[pin] = newMode; \
	} \
}

static void initPins(void) {
	// Initialize currentMode to MODE_NOT_SET (neigher INPUT nor OUTPUT)
	// to force the pin's mode to be set on first use.

	analogWriteResolution(10); // 0-1023; low-order bits ignored on boards with lower resolution

	for (int i; i < TOTAL_PINS; i++) currentMode[i] = MODE_NOT_SET;
	#ifdef ARDUINO_NRF52_PRIMO
		pinMode(USER1_BUTTON, INPUT);
		pinMode(BUZZER, OUTPUT);
	#endif

	for (int i = 0; i < 30; i++) sendNeoPixelByte(0); // turn off NeoPixels (up to 10 of them)
}

// Pin IO Primitives

OBJ primAnalogPins(OBJ *args) { return int2obj(ANALOG_PINS); }

OBJ primDigitalPins(OBJ *args) { return int2obj(DIGITAL_PINS); }

OBJ primAnalogRead(OBJ *args) {
	int pinNum = obj2int(args[0]);
	if ((pinNum < 0) || (pinNum >= ANALOG_PINS)) return int2obj(0);
	int pin = analogPin[pinNum];
	SET_MODE(pin, INPUT);
	return int2obj(analogRead(pin));
}

OBJ primAnalogWrite(OBJ *args) {
	int pinNum = obj2int(args[0]);
	int value = obj2int(args[1]);
	if (value < 0) value = 0;
	if (value > 1023) value = 1023;
	if ((pinNum < 0) || (pinNum >= ANALOG_PINS)) return nilObj;
	int pin = analogPin[pinNum];
	SET_MODE(pin, OUTPUT);
	analogWrite(pin, value); // sets the PWM duty cycle on a digital pin
	return nilObj;
}

OBJ primDigitalRead(OBJ *args) {
	int pinNum = obj2int(args[0]);
	if ((pinNum < 0) || (pinNum >= TOTAL_PINS)) return nilObj;
	#ifdef ARDUINO_NRF52_PRIMO
		if (20 == pinNum) return (HIGH == digitalRead(USER1_BUTTON)) ? trueObj : falseObj;
		if (21 == pinNum) return falseObj;
	#endif
	SET_MODE(pinNum, INPUT);
	return (HIGH == digitalRead(pinNum)) ? trueObj : falseObj;
}

OBJ primDigitalWrite(OBJ *args) {
	int pinNum = obj2int(args[0]);
	int value = (args[1] == trueObj) ? HIGH : LOW;
	if ((pinNum < 0) || (pinNum >= TOTAL_PINS)) return nilObj;
	#ifdef ARDUINO_NRF52_PRIMO
		if (20 == pinNum) return nilObj;
		if (21 == pinNum) { digitalWrite(BUZZER, value); return nilObj; }
	#endif
	SET_MODE(pinNum, OUTPUT);
	digitalWrite(pinNum, value);
	return nilObj;
}

OBJ primSetLED(OBJ *args) {
	 #if defined(ARDUINO_BBC_MICROBIT) || defined(ARDUINO_CALLIOPE)
		// Special case: Use a row-column compinaton to turn on one LED in the LED matrix.

		SET_MODE(ROW2, OUTPUT);
		SET_MODE(COL1, OUTPUT);
		if (trueObj == args[0]) {
			digitalWrite(ROW2, LOW);
			digitalWrite(COL1, HIGH);
		} else {
			digitalWrite(ROW2, HIGH);
			digitalWrite(COL1, LOW);
		}
	#else
		SET_MODE(PIN_LED, OUTPUT);
		digitalWrite(PIN_LED, (trueObj == args[0]) ? HIGH : LOW);
	#endif
	return nilObj;
}

static int wireStarted = false;

static void startWire() {
	Wire.begin();
	wireStarted = true;
}

OBJ primI2cGet(OBJ *args) {
	if (!isInt(args[0]) || !isInt(args[1])) return fail(needsIntegerError);
	int deviceID = obj2int(args[0]);
	int registerID = obj2int(args[1]);
	if ((deviceID < 0) || (deviceID > 128)) return fail(i2cDeviceIDOutOfRange);
	if ((registerID < 0) || (registerID > 255)) return fail(i2cRegisterIDOutOfRange);

	if (!wireStarted) startWire();
	Wire.beginTransmission(deviceID);
	Wire.write(registerID);
	int error = Wire.endTransmission(false);
	if (error) return int2obj(0 - error);  // error; bad device ID?

	Wire.requestFrom(deviceID, 1);
	while (!Wire.available());
	return int2obj(Wire.read());
}

OBJ primI2cSet(OBJ *args) {
	if (!isInt(args[0]) || !isInt(args[1]) || !isInt(args[2])) return fail(needsIntegerError);
	int deviceID = obj2int(args[0]);
	int registerID = obj2int(args[1]);
	int value = obj2int(args[2]);
	if ((deviceID < 0) || (deviceID > 128)) return fail(i2cDeviceIDOutOfRange);
	if ((registerID < 0) || (registerID > 255)) return fail(i2cRegisterIDOutOfRange);
	if ((value < 0) || (value > 255)) return fail(i2cValueOutOfRange);

	if (!wireStarted) startWire();
	Wire.beginTransmission(deviceID);
	Wire.write(registerID);
	Wire.write(value);
	Wire.endTransmission();

	return nilObj;
}

static void initSPI() {
	SET_MODE(13, OUTPUT);
	SET_MODE(14, OUTPUT);
	SET_MODE(15, INPUT);
	SPI.begin();
	SPI.setClockDivider(SPI_CLOCK_DIV16);
}

OBJ primSPISend(OBJ *args) {
	if (!isInt(args[0])) return fail(needsIntegerError);
	unsigned data = obj2int(args[0]);
	if (data > 255) return fail(i2cValueOutOfRange);
	initSPI();
	SPI.transfer(data); // send data byte to the slave
	return nilObj;
}

OBJ primSPIRecv(OBJ *args) {
	initSPI();
	int result = SPI.transfer(0); // send a zero byte while receiving a data byte from slave
	return int2obj(result);
}

// BBC micro:bit and Calliope Primitives (noops on other boards)

static int microBitDisplayBits = 0;

#if defined(ARDUINO_BBC_MICROBIT) || defined(ARDUINO_CALLIOPE)

static void turnDisplayOn() {
	SET_MODE(COL1, OUTPUT);
	SET_MODE(COL2, OUTPUT);
	SET_MODE(COL3, OUTPUT);
	SET_MODE(ROW1, OUTPUT);
	SET_MODE(ROW2, OUTPUT);
	SET_MODE(ROW3, OUTPUT);
	SET_MODE(ROW4, OUTPUT);
	SET_MODE(ROW5, OUTPUT);
	SET_MODE(ROW6, OUTPUT);
	SET_MODE(ROW7, OUTPUT);
	SET_MODE(ROW8, OUTPUT);
	SET_MODE(ROW9, OUTPUT);
}

static void turnDisplayOff() {
	SET_MODE(COL1, INPUT);
	SET_MODE(COL2, INPUT);
	SET_MODE(COL3, INPUT);
	SET_MODE(ROW1, INPUT);
	SET_MODE(ROW2, INPUT);
	SET_MODE(ROW3, INPUT);
	SET_MODE(ROW4, INPUT);
	SET_MODE(ROW5, INPUT);
	SET_MODE(ROW6, INPUT);
	SET_MODE(ROW7, INPUT);
	SET_MODE(ROW8, INPUT);
	SET_MODE(ROW9, INPUT);
}

static int displaySnapshot = 0;
static int displayCycle = 0;

#define DISPLAY_BIT(n) (((displaySnapshot >> (n - 1)) & 1) ? LOW : HIGH)

void updateMicrobitDisplay() {
	// Update the display by cycling three the three columns, turning on the rows
	// for each column. To minimize display artifacts, the display bits are snapshot
	// at the start of each cycle and the snapshot is not changed during the cycle.

	if (!microBitDisplayBits && !displaySnapshot) return; // display is off

	if (0 == displayCycle) { // starting a new cycle
		if (!displaySnapshot && microBitDisplayBits) turnDisplayOn(); // display just became on
		if (displaySnapshot && !microBitDisplayBits) { // display just became off
			displaySnapshot = 0;
			turnDisplayOff();
			return;
		}
		// take a snapshot of the display bits for the next cycle
		displaySnapshot = microBitDisplayBits;
	}

	// turn off all columns
	digitalWrite(COL1, LOW);
	digitalWrite(COL2, LOW);
	digitalWrite(COL3, LOW);

	switch (displayCycle) {
	case 0:
		digitalWrite(ROW1, DISPLAY_BIT(1));
		digitalWrite(ROW2, DISPLAY_BIT(3));
		digitalWrite(ROW6, DISPLAY_BIT(5));
		digitalWrite(ROW3, DISPLAY_BIT(12));
		digitalWrite(ROW4, DISPLAY_BIT(16));
		digitalWrite(ROW5, DISPLAY_BIT(17));
		digitalWrite(ROW9, DISPLAY_BIT(18));
		digitalWrite(ROW8, DISPLAY_BIT(19));
		digitalWrite(ROW7, DISPLAY_BIT(20));
		digitalWrite(COL1, HIGH);
		break;
	case 1:
		digitalWrite(ROW7, DISPLAY_BIT(2));
		digitalWrite(ROW8, DISPLAY_BIT(4));
		digitalWrite(ROW2, DISPLAY_BIT(11));
		digitalWrite(ROW6, DISPLAY_BIT(13));
		digitalWrite(ROW1, DISPLAY_BIT(15));
		digitalWrite(ROW5, DISPLAY_BIT(22));
		digitalWrite(ROW9, DISPLAY_BIT(24));
		digitalWrite(ROW3, HIGH); // unused
		digitalWrite(ROW4, HIGH); // unused
		digitalWrite(COL2, HIGH);
		break;
	case 2:
		digitalWrite(ROW7, DISPLAY_BIT(6));
		digitalWrite(ROW8, DISPLAY_BIT(7));
		digitalWrite(ROW9, DISPLAY_BIT(8));
		digitalWrite(ROW5, DISPLAY_BIT(9));
		digitalWrite(ROW4, DISPLAY_BIT(10));
		digitalWrite(ROW3, DISPLAY_BIT(14));
		digitalWrite(ROW6, DISPLAY_BIT(21));
		digitalWrite(ROW1, DISPLAY_BIT(23));
		digitalWrite(ROW2, DISPLAY_BIT(25));
		digitalWrite(COL3, HIGH);
		break;
	}
	displayCycle = (displayCycle + 1) % 3;
}

#if defined(ARDUINO_BBC_MICROBIT)
  #define ACCEL_ID 29
  #define MAG_ID 14
#endif

static int accelerometerOn = false;
static int magnetometerOn = false;

static int microbitAccel(int registerID) {
	if (!accelerometerOn) {
		// turn on the accelerometer
		if (!wireStarted) startWire();
		Wire.beginTransmission(ACCEL_ID);
		Wire.write(0x2A);
		Wire.write(1);
		Wire.endTransmission();
		accelerometerOn = true;
	}

	Wire.beginTransmission(ACCEL_ID);
	Wire.write(registerID);
	int error = Wire.endTransmission(false);
	if (error) return 0;  // error; return 0

	Wire.requestFrom(ACCEL_ID, 1);
	while (!Wire.available());
	int val = Wire.read();
	return (val < 128) ? val : -(256 - val); // value is a signed byte
}

static int microbitTemp(int registerID) {
	// Get the temp from magnetometer chip (faster response than CPU temp sensor)

	if (!magnetometerOn) {
		// configure and turn on magnetometer
		if (!wireStarted) startWire();
		Wire.beginTransmission(MAG_ID);
		Wire.write(0x10);
		Wire.write(0x29);  // 20 Hz with 16x oversample (see spec sheet)
		Wire.endTransmission();
		magnetometerOn = true;
	}

	// read a byte from register 1 to force an update
	Wire.beginTransmission(MAG_ID);
	Wire.write(1); // register 1
	int error = Wire.endTransmission(false);
	if (error) return 0;
	Wire.requestFrom(MAG_ID, 1);
	while (!Wire.available());
	Wire.read();

	// read temp from register 15
	Wire.beginTransmission(MAG_ID);
	Wire.write(15); // register 15
	error = Wire.endTransmission(false);
	if (error) return 0;
	Wire.requestFrom(MAG_ID, 1);
	while (!Wire.available());
	int degrees = Wire.read();
	degrees = (degrees < 128) ? degrees : -(256 - degrees); // temp is a signed byte

	int adjustment = 5; // based on John's micro:bit, Jan 2018
	return degrees + adjustment;
}

static int microbitMag(int registerID) {

	if (!magnetometerOn) {
		// configure and turn on magnetometer
		if (!wireStarted) startWire();
		Wire.beginTransmission(MAG_ID);
		Wire.write(0x10);
		Wire.write(0x29);  // 20 Hz with 16x oversample (see spec sheet)
		Wire.endTransmission();
		magnetometerOn = true;
	}

	Wire.beginTransmission(MAG_ID);
	Wire.write(1); // read from register 1
	int error = Wire.endTransmission(false);
	if (error) { Serial.print("Error: "); Serial.println(error); }

	// always read x, y, and z at 16-bit resolution
	// even when reading temp, this is needed to force an update
	Wire.requestFrom(MAG_ID, 6);
	while (Wire.available() < 6);
	int x = Wire.read() << 8;
	x |= Wire.read();
	if (x > 32767) x += -65536;
	int y = Wire.read() << 8;
	y |= Wire.read();
	if (y > 32767) y += -65536;
	int z = Wire.read() << 8;
	z |= Wire.read();
	if (z > 32767) z += -65536;

	if (1 == registerID) return x;
	if (3 == registerID) return y;
	if (5 == registerID) return z;
	if (15 == registerID) { // read temperature
		Wire.beginTransmission(MAG_ID);
		Wire.write(15);
		int error = Wire.endTransmission(false);
		if (error) return 0;  // error; return 0

		Wire.requestFrom(MAG_ID, 1);
		while (!Wire.available());
		int val = Wire.read();
		return (val < 128) ? val : -(256 - val); // temp is a signed byte
	}
	return 0;
}

static OBJ microbitButton(int buttonID) {
	int pinNum = (1 == buttonID) ? PIN_BUTTON_A : PIN_BUTTON_B;
	SET_MODE(pinNum, INPUT);
	return (HIGH == digitalRead(pinNum)) ? falseObj : trueObj;
}

#else // stubs for non-micro:bit boards

void updateMicrobitDisplay() { }
static int microbitAccel(int reg) { return 0; }
static int microbitTemp(int registerID) { return 0; }
static OBJ microbitButton(int buttonID) { return falseObj; }

#endif // micro:bit primitve support

// NeoPixel Support

#define DELAY_CYCLES(n) { \
  __asm__ __volatile__ ( \
    ".rept " #n " \n\t" \
    "nop \n\t" \
    ".endr \n\t" \
  ); \
}

inline uint32_t saveIRQState(void) {
    uint32_t pmask = __get_PRIMASK() & 1;
    __set_PRIMASK(1);
    return pmask;
}

inline void restoreIRQState(uint32_t pmask) {
     __set_PRIMASK(pmask);
}

#if defined(ARDUINO_CALLIOPE)

#define pinBit 0x40004 // pin 18 (Calliope)
volatile int *pinSetDir = (int *) 0x50000518;
volatile int *pinSet = (int *) 0x50000508;
volatile int *pinClr = (int *) 0x5000050C;

static void sendNeoPixelByte(int val) { // Calliope (16 MHz)
  *pinSetDir = pinBit;
  for (int i = 0; i < 8; i++) {
     if (val & 0x80) {  // one bit: goal > 600 nqnosecs
      *pinSet = pinBit;
      DELAY_CYCLES(8);
	  *pinClr = pinBit;
    } else { // zero bit: goal < 350 nqnosecs
      uint32_t oldIRQ = saveIRQState();
      *pinSet = pinBit;
      *pinClr = pinBit;
      restoreIRQState(oldIRQ);
    }
    val <<= 1;
  }
}

#elif defined(ARDUINO_SAMD_CIRCUITPLAYGROUND_EXPRESS)

#define pinBit 0x800000 // pin PB23 (CircuitPlayground)
volatile int *pinSetDir = (int *) 0x41004488;
volatile int *pinSet = (int *) 0x41004498;
volatile int *pinClr = (int *) 0x41004494;

static void sendNeoPixelByte(int val) { // Circuit Playground (48 MHz)
  *pinSetDir = pinBit;
  for (int i = 0; i < 8; i++) {
     if (val & 0x80) {  // one bit: goal > 600 nqnosecs
      *pinSet = pinBit;
      DELAY_CYCLES(15);
	  *pinClr = pinBit;
    } else { // zero bit: goal < 350 nqnosecs
      uint32_t oldIRQ = saveIRQState();
      *pinSet = pinBit;
      *pinClr = pinBit;
      restoreIRQState(oldIRQ);
    }
	DELAY_CYCLES(5);
    val <<= 1;
  }
}

#else // stub for boards without NeoPixels

static void sendNeoPixelByte(int val) { }

#endif // NeoPixel Support

OBJ primNeoPixelSend(OBJ *args) {
	int r = evalInt(args[0]);
	int g = evalInt(args[1]);
	int b = evalInt(args[2]);
	if (r < 0) r = 0; if (r > 255) r = 255;
	if (g < 0) g = 0; if (g > 255) g = 255;
	if (b < 0) b = 0; if (b > 255) b = 255;
	sendNeoPixelByte(g);
	sendNeoPixelByte(r);
	sendNeoPixelByte(b);
	return nilObj;
}

// Microbit Primitives (noops on other boards)

OBJ primMBDisplay(OBJ *args) {
	OBJ arg = args[0];
	if (isInt(arg)) microBitDisplayBits = evalInt(arg);
	return nilObj;
}

OBJ primMBDisplayOff(OBJ *args) {
	microBitDisplayBits = 0;
	return nilObj;
}

OBJ primMBPlot(OBJ *args) {
	int x = evalInt(args[0]);
	int y = evalInt(args[1]);
	if ((1 <= x) && (x <= 5) && (1 <= y) && (y <= 5)) {
		int shift = (5 * (y - 1)) + (x - 1);
		microBitDisplayBits |= (1 << shift);
	}
	return nilObj;
}

OBJ primMBUnplot(OBJ *args) {
	int x = evalInt(args[0]);
	int y = evalInt(args[1]);
	if ((1 <= x) && (x <= 5) && (1 <= y) && (y <= 5)) {
		int shift = (5 * (y - 1)) + (x - 1);
		microBitDisplayBits &= ~(1 << shift);
	}
	return nilObj;
}

OBJ primMBTiltX(OBJ *args) { return int2obj(microbitAccel(1)); }
OBJ primMBTiltY(OBJ *args) { return int2obj(microbitAccel(3)); }
OBJ primMBTiltZ(OBJ *args) { return int2obj(-microbitAccel(5)); } // invert sign of Z
OBJ primMBTemp(OBJ *args) { return int2obj(microbitTemp(15)); }
OBJ primMBButtonA(OBJ *args) { return microbitButton(1); }
OBJ primMBButtonB(OBJ *args) { return microbitButton(2); }
