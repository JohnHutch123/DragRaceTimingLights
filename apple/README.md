# Drag Tree for iPhone and Mac (SwiftUI)

A native Swift version of the Delphi app in the folder above: the same Pro and
Sportsman trees, staging, pedals, reaction timing, history and settings. One
Xcode project builds both the Mac app and the iPhone/iPad app.

It is written for **Xcode 14.2** (the newest Xcode that runs on macOS
Monterey) and runs on **macOS 12** or later and **iOS 15** or later.

## Run it on the Mac

1. Download the repository (green **Code** button on GitHub, then
   **Download ZIP**, or `git clone`).
2. Double-click `apple/DragTree.xcodeproj` to open it in Xcode.
3. In the toolbar, set the run destination to **My Mac**.
4. Press **Run** (Cmd+R).

No Apple developer account is needed for the Mac: the project signs the app
to run locally.

On the Mac there is no multi-touch, so only the brake is used. Hold the
**BRAKE** pad with the mouse or hold the **space bar**, and press **Return**
to start a run.

## Run it on an iPhone

1. Plug the iPhone into the Mac with a cable and unlock it. Tap **Trust** if
   asked.
2. In Xcode, click the blue **DragTree** project at the top of the file list,
   select the **DragTree** target, open **Signing & Capabilities** and pick
   your Apple ID under **Team** (add it with **Add an Account...** if it is
   not there; a free Apple ID works). If Xcode says the bundle identifier is
   taken, change `com.johnhutch123.DragTree` to something of your own.
3. Set the run destination to your iPhone and press **Run**.
4. The first time, the iPhone refuses to open an app from an unknown
   developer. On the iPhone go to **Settings > General > VPN & Device
   Management**, tap your Apple ID and tap **Trust**, then run again.
   On iOS 16 you may also need to turn on **Settings > Privacy & Security >
   Developer Mode** and restart the phone.

Xcode 14.2 can install on iPhones running up to iOS 16.2. A phone on a newer
iOS needs a newer Xcode, which needs a newer macOS.

You can also try it without a phone: pick an **iPhone simulator** as the run
destination. Multi-touch in the simulator is limited (hold Option for a
two-finger pinch), so a real phone is the way to test the pedals.

## Files

- `DragTree/TreeModel.swift`: the run, staging, timing, pedals and stats
  (a port of `MainForm.pas`)
- `DragTree/TreeCanvas.swift`: drawing of the tree and the staging view
- `DragTree/PedalPads.swift`: the pedal pads, multi-touch on iPhone, mouse
  and space bar on the Mac
- `DragTree/ContentView.swift`: the main screen
- `DragTree/SettingsView.swift`: the Settings screen
- `DragTree/DragTreeApp.swift`: app entry point

## Timing

Pedal changes carry the timestamp of the touch or key event itself
(`UITouch.timestamp`, `NSEvent.timestamp`), on the same clock as the tree, so
the reaction time is not delayed by when the app gets round to handling the
event. Screen and touch panel latency (typically 20 to 60 ms) is not
subtracted.
