# Drag Tree shoe pedal sensors
# Seeed XIAO RP2040 + CircuitPython + adafruit_hid library
# Brake = B (A0), Throttle = T (A1), Clutch = C (A2)
# The board's user LED shows each pedal: red = brake, green = throttle,
# blue = clutch (two pedals at once mix, e.g. brake + throttle = yellow).
import time
import board
import analogio
import digitalio
import usb_hid
from adafruit_hid.keyboard import Keyboard
from adafruit_hid.keycode import Keycode

# ---- Settings you can tune ----
PRESS_LEVEL = 20000    # reading (0-65535) above this = pedal down
RELEASE_LEVEL = 14000  # reading below this = pedal up (the gap stops flicker)
SAMPLES = 4            # readings averaged per check, smooths noise
DEBUG = False          # True = print readings for calibration (keys still work)
SHOW_LED = True        # light the user LED while a pedal is down

PEDALS = [
    # (pin,     key,          name,       LED colour)
    (board.A0, Keycode.B, "Brake",    board.LED_RED),
    (board.A1, Keycode.T, "Throttle", board.LED_GREEN),
    (board.A2, Keycode.C, "Clutch",   board.LED_BLUE),
]


class Pedal:
    def __init__(self, pin, key, name, led_pin):
        self.adc = analogio.AnalogIn(pin)
        self.key = key
        self.name = name
        self.down = False
        self.level = 0
        # The XIAO's user LED is active low: False = on, True = off
        self.led = digitalio.DigitalInOut(led_pin)
        self.led.switch_to_output(value=True)

    def show(self):
        if SHOW_LED:
            self.led.value = not self.down

    def read(self):
        total = 0
        for _ in range(SAMPLES):
            total += self.adc.value
        self.level = total // SAMPLES
        return self.level


def send(action, key):
    # Ignore errors while the phone is still setting up USB
    try:
        action(key)
    except OSError:
        pass


pedals = [Pedal(pin, key, name, led) for pin, key, name, led in PEDALS]

# Wait until the phone (or PC) accepts us as a keyboard
keyboard = None
while keyboard is None:
    try:
        keyboard = Keyboard(usb_hid.devices)
    except OSError:
        time.sleep(0.5)

try:
    keyboard.release_all()
except OSError:
    pass

last_print = 0.0

while True:
    for p in pedals:
        level = p.read()
        if not p.down and level > PRESS_LEVEL:
            p.down = True
            send(keyboard.press, p.key)
            p.show()
        elif p.down and level < RELEASE_LEVEL:
            p.down = False
            send(keyboard.release, p.key)
            p.show()

    if DEBUG:
        now = time.monotonic()
        if now - last_print > 0.2:
            last_print = now
            # Brake, Throttle, Clutch. Mu/Thonny Plotter draws these as lines
            print(tuple(p.level for p in pedals))

    time.sleep(0.001)
