# Foot pedal sensors (Seeed XIAO RP2040)

New in version 1.2. Pressure sensors in the driver's shoes (or on the car's
pedals) are wired to a Seeed XIAO RP2040 running CircuitPython. The board shows
up on the phone as a USB keyboard and holds a key down while a foot presses.
In the app, choose **Settings > Pedal input: Foot sensors**.

| Sensor | Pin | Key | Use |
| --- | --- | --- | --- |
| Brake (left shoe, automatic) | A0 | B | Hold to stage, release to launch |
| Throttle (right shoe) | A1 | T | Hold for throttle |
| Clutch (left shoe, manual) | A2 | C | Hold in, release to launch |

Map the sensors by foot, not by pedal: left foot on the brake (automatic) or
clutch (manual), right foot on the throttle. You can fit all three, or only the
ones your transmission setting needs. A sensor that isn't plugged in reads as
released, so it never sends a key.

## Wiring

Each sensor is a voltage divider. The force sensor (FSR 402 or 406) goes from
3V3 to the analog pin, and a 10 kΩ resistor goes from that pin to GND. Pressing
lowers the sensor's resistance, so the pin voltage rises from about 0 V towards
3.3 V. The resistor keeps an unplugged socket at 0 V.

```
3V3 ──[ FSR sensor ]──┬── A0 (brake) / A1 (throttle) / A2 (clutch)
                      │
                    [10 kΩ]
                      │
                     GND
```

| Part | Connects to |
| --- | --- |
| Jack plug: tip | Sensor leg 1 → socket tip → A0, A1 or A2 |
| Jack plug: ring | Sensor leg 2 → socket ring → 3V3 |
| Jack plug: sleeve | Not used |
| 10 kΩ resistor (×3, inside the box) | From each A pin to GND |

- Use **stereo (TRS)** jack plugs and sockets (3.5 mm or 6.35 mm). With a mono
  plug the outer sleeve would carry 3V3 and could short the supply on metal in
  the car.
- Use panel-mount sockets with a nut so the box takes the pull, not the solder
  joints. Heat-shrink where the wires meet each sensor.
- A0, A1 and A2 are the pins labelled D0, D1 and D2. Check your board's pinout
  card for 3V3 and GND.
- Never connect a sensor to the 5V pin. The RP2040's analog pins take 3.3 V at
  most.
- Don't plug or unplug a sensor during a run: the contacts brush past each
  other and can cause a brief fake press.

The phone powers the board over the same USB-C cable (about 20-30 mA). Use a
USB-C to USB-C **data** cable.

## Loading the code onto the board

1. **Download CircuitPython.** From
   [circuitpython.org/board/seeeduino_xiao_rp2040](https://circuitpython.org/board/seeeduino_xiao_rp2040/)
   download the latest stable **.UF2** file.
2. **Boot mode.** Hold the tiny **B** (BOOT) button, plug the board into the PC,
   then let go. A drive called **RPI-RP2** appears. If it's already plugged in,
   hold B, tap R (reset), then let go of B.
3. **Install CircuitPython.** Drag the .UF2 onto RPI-RP2. The board restarts as
   a drive called **CIRCUITPY**. Steps 1 to 3 are only needed once.
4. **Keyboard library.** From
   [circuitpython.org/libraries](https://circuitpython.org/libraries) download
   the Library Bundle matching your CircuitPython version. Copy the
   **adafruit_hid** folder into **CIRCUITPY\lib**.
5. **The code.** Copy [firmware/xiao-rp2040/code.py](../firmware/xiao-rp2040/code.py)
   to the root of CIRCUITPY. It runs as soon as it's saved, and on every power-up.
6. **Editor (optional).** [Thonny](https://thonny.org) or [Mu](https://codewith.mu)
   edit code.py on the board and show its output. In Thonny choose Tools >
   Options > Interpreter > CircuitPython (generic).

Always eject CIRCUITPY before unplugging it from the PC.

## How the code works

- It checks all three sensors about 1,000 times a second and sends a key only
  when a pedal changes state.
- **Two levels:** a press needs a reading above `PRESS_LEVEL` (20000 of 65535)
  and a release needs one below `RELEASE_LEVEL` (14000). The gap stops flicker.
- **Averaging:** 4 readings per check smooth electrical noise.
- **Safe start-up:** it waits until the phone accepts it as a keyboard, then
  releases all keys.
- **Changing keys:** edit the `PEDALS` list.

## Calibration

1. Set `DEBUG = True` in code.py and save. Thonny's Shell or Plotter shows
   three numbers (Brake, Throttle, Clutch) five times a second.
2. Note three readings per foot: foot off, foot resting on the pedal, and a
   firm press.
3. Set `PRESS_LEVEL` about halfway between resting and firm, and
   `RELEASE_LEVEL` a bit above resting.
4. Test on the PC in Notepad: one B, T or C per press.
5. Test on the phone: plug it in, open a notes app, press the sensors.
6. Set `DEBUG = False` when done.

If light presses barely register, try a 22 kΩ or 47 kΩ resistor instead of 10 kΩ.

## What the app does

- **Settings > Pedal input** switches between **On-screen pads** and **Foot
  sensors**. It's saved with the other settings.
- B (or Space), T and C are read in the form's `OnKeyDown` / `OnKeyUp`, checking
  both `Key` and `KeyChar` because platforms fill in different ones. A held
  key's repeats are ignored.
- With foot sensors, manual transmission and manual throttle work even without
  multi-touch, touches on the pads are ignored, and the pads light up to show
  what your feet are doing.
- The summary line under the tree says "foot sensors connected" once the
  first B, T or C arrives.
- Key events are time-stamped on the same clock as the tree, so reaction
  times compare directly with the on-screen pads.
- The keys also work with on-screen pads selected, for example a desktop
  keyboard.

Test on Android first. FireMonkey's hardware-keyboard support on iPhone is the
main unknown.
