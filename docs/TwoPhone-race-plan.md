# Two-phone head-to-head racing: plan

_Status: plan only, no code yet. Written 17 November 2026 against `main` at the
App Store submission build (PR #15). Updated 18 November 2026 with John's
answers: the host picks the tree mode, and a race is won on reaction time plus
elapsed time, from a car each player sets up (section 6)._

## The short answer

**Yes, it is possible, and it fits the app well.** Two phones can race side by
side: one phone hosts (and picks its lane), the other joins and takes the other
lane. Both phones show the same tree, the greens come on together, both cars
run down the track, and the first car to the finish line wins, exactly like a
real heads-up race: **reaction time + elapsed time**. Each player sets up their
car (power, weight, gearing, tyres) or picks one from a list, and the host
picks the tree and the race length (1/8 mile, 1000 ft or 1/4 mile).

The key idea that makes it work: **each phone times its own driver locally**,
exactly as the app does today. Bluetooth is only used to agree *when* the tree
starts and to swap results afterwards. Bluetooth delay never ends up inside a
reaction time, so the numbers stay as accurate as the solo mode.

It must be **Bluetooth Low Energy (BLE)**, not classic Bluetooth, because
iPhones only let ordinary apps use BLE. Delphi 12 has BLE built in
(`System.Bluetooth`), on iOS, Android and macOS, so no extra libraries are
needed.

The elapsed time comes from a small physics model of the car that runs on each
phone, driven by that player's own throttle. Like the reaction time, it is
worked out locally and only the result is sent across.

Rough size: the car model is about the size of the pedal-controls work
(PR #5), and the Bluetooth racing about the same again, split into seven
phases below. The car model is useful on its own in solo mode, so it comes
first. The one real risk is getting an iPhone and an Android phone to talk
through Delphi's BLE "host" support, so that is tested on its own before any
Bluetooth work goes into the app.

## 1. Bluetooth choice

| | Classic Bluetooth (`TBluetooth`, RFCOMM sockets) | Bluetooth LE (`TBluetoothLE`, GATT) |
|---|---|---|
| Android | Yes | Yes |
| iPhone | **No** (Apple only allows it for MFi accessories) | Yes |
| Mac | Yes | Yes |
| iPhone vs Android race | Impossible | Works |

So: **BLE everywhere.** One app, one code path, any mix of iPhone and Android.

How BLE roles map onto the race:

- **Host phone = BLE peripheral (GATT server).** It advertises a "Drag Tree
  race" service with our own 128-bit UUID and holds the "truth": tree mode,
  lanes, when the tree starts.
- **Joining phone = BLE central (client).** It scans for that UUID, lists the
  hosts it finds ("John's iPhone - Left lane"), connects, and subscribes.

One service, two characteristics:

| Characteristic | Direction | Properties |
|---|---|---|
| `HostToJoiner` | host -> joiner | Notify |
| `JoinerToHost` | joiner -> host | Write without response |

Every message fits in **20 bytes** (the BLE minimum packet), so we never
depend on MTU negotiation, which behaves differently on iOS and Android.

Delphi pieces (names from `System.Bluetooth`; check exact signatures against
the RAD Studio 12 source when coding, BLE APIs moved a little between
versions):

- Host: `TBluetoothLEManager.Current.GetGattServer`, then `CreateService`,
  `CreateCharacteristic`, `AddService`, advertise the service UUID, handle
  `OnCharacteristicWrite` and `OnClientSubscribed`, send with
  `UpdateCharacteristicValue`.
- Joiner: `StartDiscovery` filtered on our service UUID, `OnDiscoverLEDevice`,
  `Connect`, `DiscoverServices`, `SetCharacteristicNotification`,
  `WriteCharacteristic`, and `OnCharacteristicRead` for incoming notifications.
- BLE events can arrive on a background thread (Android especially). Rule:
  **read `NowMs` first, inside the event**, then hand the message to the main
  thread with `TThread.Queue`. `TStopwatch` is safe to read from any thread.

Windows: Delphi's Windows BLE does not reliably support being a GATT server,
so a Windows PC should not be a host. Phones (and probably the Mac) can host.
Racing is a phone feature anyway.

## 2. Where it slots into the current code

Today `MainForm.pas` already runs two lanes: your car in `FCars[FUserLane]`
and a computer "opponent" in `FCars[OppLane]`, which rolls in on its own
(`RollAtMs`) and leaves on a random delay after green (`LaunchAtMs`). That is
the hook. In a race, the opponent car is simply driven by messages from the
other phone instead of by the random numbers.

New units (kept out of the form so `MainForm.pas` does not grow past 2,000
lines):

- `RaceProtocol.pas`: message records and pack/unpack to 20-byte buffers. No
  Bluetooth in it, so it can be tested anywhere.
- `RaceLink.pas`: an abstract `TRaceLink` class (`Send`, `OnMessage`,
  `OnConnected`, `OnDisconnected`) plus `TBleHostLink` and `TBleJoinLink`. A
  `TLoopbackLink` (talks to itself with a fake delay) lets the whole race flow
  be tested on one Windows PC before any phones are involved. A Wi-Fi link
  could be added later behind the same class (see section 10).
- `RaceClock.pas`: the clock sync maths from section 4.

Form changes:

- A new **Mode** setting on the Settings screen: `Solo` (default, exactly
  today's app), `Host race`, `Join race`. Uses the same `TTapButton` style.
- A small **race lobby panel** (same idea as `FSettingsPanel`): host sees
  "Waiting for a racer..." then "Racing Sam's Pixel"; joiner sees a list of
  hosts found, tap one to join.
- `TRunResult` gains elapsed time, trap speed, `OppReactionMs`, `OppElapsedMs`, `OppFoul`, `Won`, and the history box
  shows "W 0.042 v 0.118" style rows for races.

## 3. Host / join flow

1. **Host** picks Mode = Host race and a lane (the existing Lane setting),
   then taps Start in the lobby. The phone advertises.
2. **Joiner** picks Mode = Join race. It scans, shows hosts with their lane,
   and the user taps one. The joiner takes the other lane automatically.
3. On connect they exchange `HELLO` (protocol version, short name). Different
   versions are refused with a clear message ("Update Drag Tree on both
   phones").
4. Host sends `SETUP`: tree mode (Pro / Sportsman), race length, lanes. These
   are the host's choice, and the joiner's screen shows them read-only. Each
   driver keeps their own car, pedal, gearbox, throttle and staging settings,
   because those only affect their own car. Both phones send `CAR` (name,
   power, weight) so each screen can show "Your V8 sedan v Sam's hot hatch".
5. Clock sync runs (section 4), about 1 second, invisible to the user.
6. Both phones show the tree with both cars. **Start** on either phone means
   "I'm ready"; each driver stages their own car as today.
7. Each phone sends `STAGE` updates (pre-staged / staged / deep, a few times
   a second, plus the car position so the other car moves on screen).
8. When the host sees **both lanes staged and both drivers holding the car
   ready** (`CarReady`, the same check as today), it picks the random delay
   (today's `AutoStartMinMs + Random(AutoStartRandMs)`) and sends
   `TREE start=<host clock ms>`. The start is always at least 600 ms in the
   future so the message has arrived well before the first amber.
9. Each phone converts that to its own clock, sets `FCountdownMs`, and runs
   the tree locally. `GreenDueMs`, `AmberLit`, `GreenLit` need no changes.
10. Each driver launches; `Launch` computes `ReactionMs` locally exactly as now,
    and sends `LAUNCH rt=<ms> flags=<foul, before tree, bogged>`.
11. Each phone runs its own car down the track (section 6) and sends
    `PROGRESS` (distance, speed) about 10 times a second, so the other car
    moves on screen, then `FINISH` (elapsed time, 60 ft time, trap speed).
12. When a phone has both results, it shows the winner and the time slip.
    Host sends a final `RESULT` so both screens agree even in odd cases
    (section 5).
13. Reset / Start goes round again without reconnecting.

## 4. Clock sync (so both greens come on together)

The two phones have unrelated stopwatches, so they need a shared idea of
"now". The standard trick (the same as internet time / NTP):

```
joiner:  sends PING(t1)              t1 = joiner clock when sent
host:    replies PONG(t1, t2)        t2 = host clock when received
joiner:  receives at t3              t3 = joiner clock when received

round trip   = t3 - t1
offset       = t2 - (t1 + t3) / 2     (host clock minus joiner clock)
```

- Send about 20 pings, 40 ms apart. BLE round trips are typically 30-100 ms
  depending on the connection interval the phones agree.
- **Keep only the 5 fastest round trips** and take the median offset. Slow
  round trips are the ones where one direction got stuck, so they are the
  inaccurate ones.
- Expected accuracy: within about **5-10 ms**. Repeat a short sync (5 pings)
  before every run, so clock drift (tiny, a few parts per million) never adds
  up.
- Ask for a fast connection: Android has `requestConnectionPriority(HIGH)`
  (7.5-15 ms interval); Delphi doesn't wrap it, but it can be reached via the
  Android JNI bridge if timing tests show it's needed. iOS picks its own
  (usually 15-30 ms), which is still fine.

Why 5-10 ms is good enough:

- **Reaction times are not affected at all.** Each phone measures its driver
  against its own green. A 10 ms sync error only means one green bulb lights
  10 ms before the other, which nobody can see.
- The screens themselves only refresh every 8-16 ms, and today's tree timer
  ticks at a similar rate, so the sync error is the same size as the display
  error that solo mode already has.
- Winner is decided on reaction time, which is exact on each phone, so the
  sync error never changes who wins.

A hidden debug line (long-press the reaction time, say) shows "offset 1234 ms,
best round trip 38 ms" for testing. Best test: put both phones side by side,
film them with an iPhone in 240 fps slow-motion, and count frames between the
two greens.

## 5. Red lights, fouls and who wins

Same rules as a real Christmas tree, using what `Launch` already records:

| Your result | Their result | Winner |
|---|---|---|
| Clean | Clean | **First to the finish line**: lower reaction time + elapsed time. A dead heat (same ms) is shown as a tie. |
| Clean | Red light | You win, even if you were slow. |
| Red light | Red light | **First to foul loses**: the more negative reaction time left earlier (the greens were simultaneous, so this is fair). |
| Left before the tree started (`BeforeTree`) | anything | Red light, counted as the earliest foul. |
| Stalled, too far forward, or never left | Clean or red light | The other driver wins. |
| Stalled / too far | Stalled / too far | No result, re-run. |

- Because the greens come on together, "reaction time + elapsed time" is the
  same as real finish-line order, so a quick light can beat a faster car (a
  "holeshot win"). The time slip shows the winning margin, for example
  "won by 0.031 s".
- A driver who red-lights still runs down the track and gets a time slip, but
  can't win (unless the other driver fouled first).
- Your red bulb lights straight away on your own phone (as now). The other
  lane's red bulb lights when the `LAUNCH` message arrives, a few hundred ms
  later at most.
- "Never left": if a driver hasn't launched 5 s after green, their phone sends
  `LAUNCH` with a "no launch" flag.
- The opponent's car on your screen launches when their message arrives; the
  animation is started a little "late but caught up" so it looks right.
- Optional later: **bracket racing**, where each driver enters a "dial-in"
  (their predicted elapsed time), the slower car gets a head start on the
  tree, and running quicker than your dial-in ("breaking out") loses. The
  car model makes this possible, but it changes the tree timing per lane, so
  it's a separate step after heads-up racing works.
- Optional later: a pre-race "staging duel" rule (both must stage within N
  seconds of the first one) and "deep staging allowed" on/off, chosen by host.

## 6. Cars and elapsed time

### What each player sets up

A new **Car** screen (another panel like Settings, same `TTapButton` style),
reached from a "Car" button. The car is saved in `DragTree.ini` with the other
settings, and is used in solo runs too.

| Setting | Example | Notes |
|---|---|---|
| Car | "V8 sedan" | Pick from the list below, then change anything; "Save as..." keeps your own cars |
| Power | 300 kW at 6,000 rpm | Peak power and the rpm it arrives at; kW or hp |
| Weight | 1,800 kg | With driver; kg or lb |
| Drive | RWD | RWD, FWD or AWD (decides how much weight is on the driving wheels) |
| Tyres | Street | Street, drag radial or slick (grip) |
| Gearbox | 6-speed | Number of gears; ratios filled in from the preset |
| Final drive | 3.70 | Short (quicker off the line) or tall (higher top speed) |
| Rev limit / shift point | 7,000 / 6,800 rpm | Ties in with the rev bar the throttle pad already shows |
| Launch | 4,000 rpm (manual) or 2,500 rpm stall (auto) | Manual uses the revs you are holding on the throttle pad when you drop the clutch |

Units: kW / kg / km/h by default, with an hp / lb / mph switch, because time
slips at many tracks still show mph.

Race length is chosen by the host (or by you in solo): **1/8 mile** (660 ft,
201 m), **1000 ft** (305 m), or **1/4 mile** (1320 ft, 402 m).

### The preset list

Generic names, not brands or model names. Apple's guideline 5.2 (other
people's trademarks) and Google's equivalent make real car names a review
risk, and generic presets avoid it. Players can rename their own saved cars
whatever they like, because that's their own text on their own phone.

| Preset | Power | Weight | Drive | Rough 1/4 mile |
|---|---|---|---|---|
| Daily hatchback | 90 kW | 1,150 kg | FWD | 16.5 s |
| Hot hatch | 180 kW | 1,350 kg | FWD | 14.0 s |
| Turbo AWD sedan | 220 kW | 1,500 kg | AWD | 13.3 s |
| V8 sedan | 300 kW | 1,800 kg | RWD | 12.9 s |
| Modern muscle car | 340 kW | 1,750 kg | RWD | 12.3 s |
| Supercharged V8 | 485 kW | 1,900 kg | RWD | 11.4 s |
| Superbike | 150 kW | 200 kg + rider | RWD | 10.0 s (traction and wheelie limited) |
| Street/strip turbo | 600 kW | 1,500 kg | RWD, radials | 9.6 s |
| Pro-mod style | 2,000 kW | 1,200 kg | RWD, slicks | 6.0 s |

The rough times come from the well-known Hale formula
(ET = 5.825 x (lb / hp)^(1/3), trap mph = 234 x (hp / lb)^(1/3)), which is
what the model should land near for a clean full-throttle run. That gives us a
simple check while tuning: if the V8 sedan runs 10 s, something is wrong.

### How the elapsed time is worked out

A small "point mass" model, in a new unit `CarSim.pas` (no UI code, so it can
be tested on Windows with a console program). Each time step it does:

1. **Engine:** torque at the current rpm from a simple curve built from peak
   power and its rpm (rises to peak torque, then falls so power peaks where
   you said). Throttle off means no torque and some engine braking.
2. **Gearing:** wheel force = torque x gear ratio x final drive x 0.9 (losses)
   / tyre radius.
3. **Grip limit:** the force can't be more than the tyres can hold: grip
   (street 1.0, radial 1.4, slick 2.0) x weight on the driving wheels. Under
   acceleration weight moves to the rear, so RWD gains grip and FWD loses it.
   Too much force means wheelspin: the excess turns into tyre smoke, not
   speed.
4. **Launch:** manual: the clutch slips from your launch rpm until the wheels
   catch up, so too few revs bogs and too many spins the tyres. Auto: the
   torque converter holds the stall rpm until it locks up.
5. **Shifts:** at the shift point the car changes up, with a short gap with
   no drive (0.25 s auto, 0.15 s manual).
6. **Drag:** air drag (from a frontal area x drag figure, preset per car) and
   rolling resistance.
7. **Speed and distance:** add up acceleration over 1 ms steps. Record the
   60 ft, 330 ft, 1/8 mile, 1000 ft and 1/4 mile times and the trap speed.

The model runs inside the existing `tmrTree` tick (several 1 ms steps per
tick) from the moment of launch, so **lifting off the throttle pad mid-run
really costs time**, and the car on screen moves at the model's speed.
Because each car is worked out from its own phone's throttle, nothing about
it depends on Bluetooth timing.

Today the throttle pad is on or off (`ThrottleOpen`). That stays: on is full
throttle. A "pedal travel" slider could come later.

Manual shifting during the run (tap the clutch and lift the throttle to
change up) would make it more of a game, but it's harder to do with thumbs
on a phone. The plan starts with **automatic shifts at the shift point** for
both gearbox settings, and keeps manual shifting as an option to try later.

### What the screen shows

- **During the run:** a simple top-down strip below the tree with both lanes,
  the cars moving towards a finish line, scaled to the race length. The
  current staging view stays as it is for the start.
- **At the finish:** the win light comes on in the winner's lane, and a
  **time slip** appears for both lanes: reaction time, 60 ft, 330 ft,
  1/8 mile time and speed, and (on longer races) 1000 ft or 1/4 mile time and
  speed, plus the winning margin. History keeps the slips.
- **Solo mode** gets this too: the computer opponent gets a car (by default
  the same preset as yours), so solo practice becomes a real race.


## 7. Disconnects and interruptions

- Both phones send a tiny `HB` (heartbeat) every 500 ms, even when idle.
  No message for **3 s** = connection lost.
- Lost **before the tree starts**: stop the run, show "Lost connection to
  Sam's Pixel", and the joiner automatically scans and reconnects for 30 s.
  Host keeps advertising.
- Lost **after the tree started**: carry on locally. Your own reaction time
  is still valid and goes into history as a solo run, marked "opponent lost".
- Lost **after you launched but before their result arrived**: same, plus
  "result unknown".
- App sent to the background, phone call, screen locks: iOS suspends BLE for
  apps without background modes, so treat it as a disconnect. We won't add
  background modes (it complicates App Store review for no benefit). We
  should keep the screen awake while in a race lobby.
- Bluetooth switched off, or permission refused: the Mode button explains it
  and offers to open Settings; Solo mode always works without Bluetooth.

## 8. Permissions

### Android (Project Options > Application > Uses Permissions, Android 64-bit)

| Permission | Needed for |
|---|---|
| `BLUETOOTH_SCAN` | Joiner finding hosts (Android 12+) |
| `BLUETOOTH_CONNECT` | Both phones connecting (Android 12+) |
| `BLUETOOTH_ADVERTISE` | Host advertising (Android 12+) |
| `BLUETOOTH`, `BLUETOOTH_ADMIN` | Android 11 and older only |
| `ACCESS_FINE_LOCATION` | Android 11 and older only; BLE scanning required it then |

- The new ones are **runtime permissions** ("Nearby devices" in Android's
  wording): request them with `PermissionsService.RequestPermissions` when the
  user picks Host or Join, not at app start.
- Mark `BLUETOOTH_SCAN` with `android:usesPermissionFlags="neverForLocation"`
  and limit the old ones with `android:maxSdkVersion="30"`. Delphi's
  permission checkboxes can't add those attributes, so that bit goes into
  `AndroidManifest.template.xml` by hand (it's already in the repo, so the
  edit is tracked).
- Declare `<uses-feature android:name="android.hardware.bluetooth_le"
  android:required="false"/>` so phones without BLE can still install the app
  for solo practice.

### iOS (Project Options > Version Info, iOS Device 64-bit)

- Add `NSBluetoothAlwaysUsageDescription`, for example: _"Drag Tree uses
  Bluetooth to race against a friend's phone nearby. It is only used when you
  choose Host or Join race."_ The iOS key list was cleaned of Delphi's
  placeholder texts for the App Store; this is the one to add back, with real
  wording (Apple rejects the default "The reason for accessing..." text).
- iOS shows its Bluetooth prompt the first time the app touches the
  Bluetooth manager, so create `TBluetoothLEManager` **only** when the user
  picks Host or Join, never in `FormCreate`. Otherwise every solo user gets a
  Bluetooth prompt on first launch, which reviewers dislike.
- No entitlements or background modes are needed.

### macOS (if the Mac build gets racing)

- Same usage string in the OSX64/OSXARM64 Version Info keys (they currently
  hold the Delphi placeholder, which should be replaced either way), plus the
  `com.apple.security.device.bluetooth` entitlement for a sandboxed Mac App
  Store build.

## 9. App Store and Play Store implications

- **It's an update, not a new app.** Same bundle ID `com.johnhutch123.DragTree`;
  bump the version (1.1.0) and build number.
- **Privacy policy** (`docs/privacy-policy.md`) needs a line: "Race mode uses
  Bluetooth to talk directly to another phone nearby. Only race data (lane,
  tree timing, reaction and elapsed times, car settings, a device name) is exchanged, it never leaves
  the two phones, and nothing is sent to us." The "does not ask for access"
  list needs "Bluetooth (only when you start a race)".
- **Apple App Privacy label**: stays "Data Not Collected", because nothing
  reaches the developer. Same for Google Play **Data safety**.
- **App Review**: the reviewer usually has one device. Solo mode must stay the
  default and work fully without Bluetooth, and the Review Notes should say
  "Race mode needs two devices running Drag Tree; a video is attached" with a
  short screen recording of two phones racing. This avoids a "feature doesn't
  work" (guideline 2.1) rejection.
- **Google Play**: the Nearby devices permissions are fine for this use; no
  special declaration form is needed (unlike location or SMS).
- The existing blockers still apply: iOS uploads need Delphi 13.2 (iOS 26 SDK),
  and Play needs target API 36 (see `docs/PlayStore-guide.md`). The race work
  is plain Delphi and should carry over to 13.2 unchanged.
- Version 1.0 is in review now. Nothing here should hold that up; racing
  goes in a later 1.1 update.

## 10. Wi-Fi instead of Bluetooth?

Considered, and **not meaningfully easier**, so BLE stays the plan:

- Delphi's **App Tethering** (`TTetheringManager`) or plain TCP sockets are
  simpler to code than BLE GATT, and Wi-Fi latency is lower.
- But both phones must be on the **same Wi-Fi network**. At a track or in a
  car park there often isn't one (one phone's hotspot works, but that's a
  fiddly extra step and some carriers block hotspot clients from seeing each
  other).
- On iPhone, automatic discovery uses broadcast/multicast, which needs a
  "Local Network" permission prompt **and** a special multicast entitlement
  that Apple has to approve by request. Without it you'd type the other
  phone's IP address.
- Because `TRaceLink` is abstract, a Wi-Fi link can be added later as a
  fallback if BLE proves unreliable on some phones. Nothing in the race logic
  would change.

## 11. Build order

Each phase ends with something John can build and try locally in RAD Studio
12. Phase 1 is useful straight away in solo mode, and phase 2 is the go /
no-go test for Bluetooth. They don't depend on each other, so the BLE spike
can be tried at any time.

1. **Cars and elapsed time, solo.** `CarSim.pas` with the presets, checked
   against the rough times in section 6 using a small Windows console test.
   Car screen, race length setting, the track strip, time slips, win light,
   and the computer opponent driving a car. Version 1.1 could ship with just
   this.
2. **BLE spike (the risk).** A throwaway test form, outside the main app:
   one phone advertises, the other finds it, connects, and they echo
   messages and show round-trip times. Test all four combinations: iPhone
   host + Android join, Android host + iPhone join, and same-OS pairs. If
   Delphi 12's GATT server misbehaves on one platform, we know before
   touching the app (and can check whether 13.2 fixes it).
3. **Protocol, clock, loopback.** `RaceProtocol.pas`, `RaceClock.pas`,
   `TLoopbackLink`. Refactor the opponent car so it is driven through
   `TRaceLink` messages. With loopback plus a fake 40 ms delay, the full race
   flow can be tested on one Windows PC. Solo mode must behave exactly as
   before.
4. **Lobby and settings.** Mode setting, host/join panel, permission
   requests, lazy Bluetooth start, HELLO / SETUP / CAR, lane assignment, the
   joiner seeing the host's tree mode and race length.
5. **Synchronised tree.** Clock sync before each run, `STAGE` updates,
   host-scheduled `TREE` start, opponent car animated from messages, debug
   offset line. Slow-motion video test of the two greens.
6. **Race results, fouls, disconnects.** `LAUNCH` / `PROGRESS` / `FINISH` /
   `RESULT`, the winner and both time slips on both phones, the foul table
   from section 5, history rows, heartbeats, auto-reconnect, background
   handling, keep screen awake.
7. **Store prep.** Usage strings, Android manifest edits, privacy policy,
   screenshots of a race, review video and notes, version bump.

## 12. Message list (for reference)

All messages are one type byte plus up to 19 bytes of data. Times are
milliseconds as 32-bit integers (enough for 24 days of uptime); reaction times
are signed 32-bit in 0.1 ms units (a "before the tree" foul can be several seconds early).

| Type | From | Data |
|---|---|---|
| `HELLO` | both | protocol version, 16-char name |
| `SETUP` | host | tree mode, race length, host lane, rule flags |
| `CAR` | both | 12-char car name, power (kW), weight (kg) |
| `PING` / `PONG` | joiner / host | t1 / t1, t2 |
| `READY` | both | ready flag (pressed Start) |
| `STAGE` | both | staging state, car position (0.1 in) |
| `TREE` | host | countdown start, host clock |
| `LAUNCH` | both | reaction time, flags (foul, before tree, bogged, no launch, stalled) |
| `PROGRESS` | both | distance (0.1 ft), speed (0.1 km/h), 10 times a second |
| `FINISH` | both | elapsed time, 60 ft time, trap speed (a second `SPLITS` message carries 330 ft and 1/8 mile) |
| `RESULT` | host | winner, winning margin |
| `ABORT` | both | reason (reset, stalled, too far, settings) |
| `HB` | both | none |

## Decided

- The **host picks** the tree mode (Pro / Sportsman) and the race length for
  both phones. (John, 18 Nov 2026)
- A race is won on **reaction time + elapsed time** (first to the finish
  line), from a car each player sets up or picks from a list. (John,
  18 Nov 2026)

## Open questions for John

- Start with **automatic shifts** at the shift point (planned), or do you
  want to shift by hand during the run?
- **kW / kg / km/h** as the default units (planned, with an hp / lb / mph
  switch), or imperial first?
- Are the **presets** in section 6 the right kinds of cars, and which would
  you add?
- Do **phase 1 (cars, solo)** first and ship it as 1.1 before the Bluetooth
  work (recommended), or build it all together?
