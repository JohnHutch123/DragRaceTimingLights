# Drag Race Timing Lights (Pro Tree Trainer)

A Delphi 12 FireMonkey app for iPhone and Android that simulates a drag racing
starting tree (Pro or Sportsman) so you can practise your reaction time.

## How it works

Tap **Settings** to choose:

- **Tree: Pro / Sportsman.** Pro lights all three ambers together with the
  green 0.400 s later. Sportsman (full tree) lights the ambers one after
  another 0.500 s apart, with the green 0.500 s after the last one.
- **Lane: Left / Right.** Your lane is marked **YOU** in blue on the tree, and
  your car is the blue one.
- **Staging: Auto / Manual.** Auto rolls your car into stage for you. In
  Manual you ease off the brake to creep forward and press it to stop.
- **Transmission: Auto / Manual.** Manual adds a **CLUTCH** pedal.
- **Throttle: Auto / Manual.** Manual adds a **THROTTLE** pedal that you must
  hold for full throttle.

The pedals are pads at the bottom of the screen, used with several fingers at
once like real pedals (clutch left, brake middle, throttle right). Without
multi-touch (a mouse on Windows) only the **BRAKE** pad is used, and the space
bar works as the brake too.

A run:

1. Press **Start**. Both cars roll up to the beams in the staging view under
   the tree. The pre-stage bulb lights when your front tyre breaks the
   pre-stage beam, and the stage bulb 7 in later at the stage beam. Roll on
   past the pre-stage window and you are deep staged. Roll right through the
   stage beam (the red zone) and you get **TOO FAR FORWARD**, which ends the
   run.
2. Hold the car: **BRAKE** (plus **CLUTCH** with a manual gearbox). With
   manual throttle, bring in the **THROTTLE** too.
3. Once both lanes are staged and you are holding the car, the tree starts
   after a random wait of 0.8 to 3.0 s.
4. Launch by letting the car go: release the brake (automatic) or release
   both brake and clutch (manual). Launching with the throttle closed bogs
   the car.

Your reaction time is measured from when the green is due to the moment you
let the car go:

| Time        | Meaning                       |
|-------------|-------------------------------|
| below 0.000 | Red light (you left too soon) |
| 0.000-0.009 | Perfect light                 |
| 0.010-0.099 | Great / good light            |
| 0.100 and up| Late                          |

When you red-light, your red bulb lights and the tree carries on for the
other lane. History marks Sportsman runs with **S**, red lights with **R** and
bogged launches with **B**. Your settings are saved between sessions.

Buttons: **Start** runs the tree, **Stop** aborts a run, **Reset** clears the
lights for the next run, **Clear** wipes the history and stats.
On Windows, **Enter** starts a run.

## Building

Open `DragTree.dproj` in RAD Studio 12. Target platforms already set up:
Android 32/64-bit, iOS Device 64-bit, iOS Simulator ARM64, Windows 32/64-bit.

- **Android**: pick *Android 64-bit*, select your phone under Target, Run.
  If the build complains about missing Java libraries, right-click
  *Libraries* under the Android target in Project Manager and choose
  *Revert System Files to Default*.
- **iOS**: needs a Mac with PAServer and Xcode, plus a provisioning profile.

If RAD Studio refuses the project file, delete `DragTree.dproj`, open
`DragTree.dpr` instead (the IDE builds a fresh project file) and add the
Android/iOS targets with right-click *Target Platforms > Add Platform*.

## Timing notes

Times come from `TStopwatch` (high resolution). The tap is timestamped in the
touch-down handler. Phone screens and touch panels add some latency
(typically 20 to 60 ms combined), which this version does not subtract.

## Files

- `DragTree.dpr` / `DragTree.dproj`: project
- `MainForm.pas` / `MainForm.fmx`: tree drawing, timing and UI

## App icons

The app icons for Android, iOS, macOS and Windows are in [Icons/](Icons/README.md), with steps for setting them in Project > Options > Application > Icons.
