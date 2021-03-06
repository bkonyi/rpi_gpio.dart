library test.gpio.blink;

import 'dart:async';

import 'package:rpi_gpio/gpio.dart';
import 'package:rpi_gpio/gpio_pins.dart';
import 'package:rpi_gpio/wiringpi_gpio.dart';

/// Simple example to blink an LED.
/// connected to Pin 1 (BMC_GPIO 18, Physical Pin 12).
main() async {

  // Initialize the GPIO used
  // See read_with_mocks.dart for testing on non-RaspberryPi platforms
  Pin.gpio = new WiringPiGPIO();

  var ledPin = pin(1, Mode.output);
  for (int count = 0; count < 5; ++count) {
    ledPin.value = true;
    await _delay(1000);
    ledPin.value = false;
    await _delay(1000);
  }
}

Future _delay(int milliseconds) async {
  await new Future.delayed(new Duration(milliseconds: milliseconds));
}
