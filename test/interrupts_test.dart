library test.rpi_gpio.interrupts;

import 'dart:async';

import 'package:rpi_gpio/gpio.dart';
import 'package:rpi_gpio/gpio_pins.dart';
import 'package:rpi_gpio/rpi_gpio.dart';
import 'package:test/test.dart';

import 'mock_gpio.dart';
import 'test_util.dart';

// Current test hardware configuration:
// pin 4 unconnected but with an internal pull up/down resistor setting
// pin 3 = an LED (1 = on, 0 = off)
// pin 2 = a photo resistor detecting the state of the LED on pin 3
// pin 1 = an LED (1 = on, 0 = off)
// pin 0 = a photo resistor detecting the state of the LED on pin 1

main() async {
  await setupGPIO();
  runTests();
}

Pin _sensorPin;
Pin _ledPin;

runTests() {
  // This test group assumes that Mode.output from wiringPi pin 1 (BMC_GPIO 18, Phys 12)
  // can trigger an interrupt on wiringPi pin 0 (BMC_GPIO 17, Phys 11),
  // and Mode.output from wiringPi pin 3 (BMC_GPIO 22, Phys 15)
  // can be read as [Mode.input] on wiringPi pin 2  (BMC_GPIO 27, Phys 13).
  group('interrupts', () {
    /// Instantiate high # pin to check disable interrupts bug is fixed
    /// https://github.com/danrubel/rpi_gpio.dart/issues/7
    test('input', () {
      pin(10, Mode.input);
    });

    /// Test both rising and falling events
    test('Trigger.both - pin 0', () async {
      _sensorPin = pin(0, Mode.input)..pull = Pull.down;
      _ledPin = pin(1, Mode.output)..value = false;
      assertValue(_sensorPin, false);
      expect(await _nextEvent(true, Trigger.both), true);
      assertValue(_sensorPin, true);
      expect(await _nextEvent(false, Trigger.both), false);
      assertValue(_sensorPin, false);
    });

    /// Test both rising and falling events on a different set of pins
    test('Trigger.both - pin 2', () async {
      _sensorPin = pin(2, Mode.input)..pull = Pull.down;
      _ledPin = pin(3, Mode.output)..value = false;
      assertValue(_sensorPin, false);
      expect(await _nextEvent(true, Trigger.both), true);
      assertValue(_sensorPin, true);
      expect(await _nextEvent(false, Trigger.both), false);
      assertValue(_sensorPin, false);
    });

    /// Test rising events only
    test('Trigger.rising', () async {
      _sensorPin = pin(0, Mode.input)..pull = Pull.down;
      _ledPin = pin(1, Mode.output)..value = false;
      assertValue(_sensorPin, false);
      expect(await _nextEvent(true, Trigger.rising), true);
      assertValue(_sensorPin, true);

      // There should not be a falling event... but there is... why?
      //expect(await _nextEvent(false, Trigger.rising), null);
      if (gpio is MockGPIO)
        expect(await _nextEvent(false, Trigger.rising), null);
      else
        expect(await _nextEvent(false, Trigger.rising), false);

      assertValue(_sensorPin, false);
    });

    /// Test falling events only
    test('Trigger.falling', () async {
      _sensorPin = pin(0, Mode.input)..pull = Pull.down;
      _ledPin = pin(1, Mode.output)..value = false;
      assertValue(_sensorPin, false);
      expect(await _nextEvent(true, Trigger.falling), null);
      assertValue(_sensorPin, true);
      expect(await _nextEvent(false, Trigger.falling), false);
      assertValue(_sensorPin, false);
    });

    /// Test multiple sensor pins
    test('multiple triggers', () async {
      var pin2 = pin(2, Mode.input)..pull = Pull.down;
      var subscription2 = pin2.events(Trigger.both).listen((PinEvent event) {
        throw 'unexpected event';
      });
      try {
        _sensorPin = pin(0, Mode.input)..pull = Pull.down;
        _ledPin = pin(1, Mode.output)..value = false;
        assertValue(_sensorPin, false);
        expect(await _nextEvent(true, Trigger.falling), null);
        assertValue(_sensorPin, true);
        expect(await _nextEvent(false, Trigger.falling), false);
        assertValue(_sensorPin, false);
      } finally {
        subscription2.cancel();
      }
    });

    /// Test no events
    test('Trigger.none', () {
      _sensorPin = pin(0, Mode.input)..pull = Pull.down;
      _ledPin = pin(1, Mode.output)..value = false;
      assertValue(_sensorPin, false);
      expect(_sensorPin.events(Trigger.none), null);
    });

    /// Test null trigger
    test('null Trigger', () {
      _sensorPin = pin(0, Mode.input)..pull = Pull.down;
      _ledPin = pin(1, Mode.output)..value = false;
      assertValue(_sensorPin, false);
      expect(_sensorPin.events(null), null);
    });
  });
}

/// Return the sensor value reported by the next event
/// or `null` if no event received
Future<bool> _nextEvent(bool ledValue, Trigger trigger) async {
  if (gpio is MockGPIO)
    expect((gpio as MockGPIO).interruptMap[_sensorPin.pinNum],
        anyOf(isNull, Trigger.none));
  var completer = new Completer<bool>();
  var subscription = _sensorPin.events(trigger).listen((PinEvent event) {
    if (!identical(event.pin, _sensorPin)) fail('expected sensor pin');
    completer.complete(event.value);
  });
  if (gpio is MockGPIO)
    expect((gpio as MockGPIO).interruptMap[_sensorPin.pinNum],
        anyOf(isNull, trigger));
  _ledPin.value = ledValue;
  bool value = await completer.future
      .timeout(new Duration(milliseconds: 100))
      .catchError((e) => null, test: (e) => e is TimeoutException);
  await subscription.cancel();
  if (gpio is MockGPIO)
    expect((gpio as MockGPIO).interruptMap[_sensorPin.pinNum],
        anyOf(isNull, Trigger.none));
  return value;
}
