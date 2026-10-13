# Drag Race Timing Lights (Pro Tree Trainer)

A Delphi 12 FireMonkey app for iPhone and Android that simulates a drag racing
**Pro tree** so you can practise your reaction time.

## How it works

1. Press **Start**. The pre-stage bulbs light, then the stage bulbs.
2. After a random wait (0.8 to 3.0 s) all three ambers light together.
3. Exactly 0.400 s later the ambers go out and the green lights.
4. Tap the big **launch pad** at the bottom of the screen.

Your reaction time is measured from when the green is due:

| Time        | Meaning                       |
|-------------|-------------------------------|
| below 0.000 | Red light (you left too soon) |
| 0.000-0.009 | Perfect light                 |
| 0.010-0.099 | Great / good light            |
| 0.100 and up| Late                          |

As on a real Pro tree, a good light means leaving on the ambers, not waiting
to see the green.

Buttons: **Start** runs the tree, **Stop** aborts a run, **Reset** clears the
lights for the next run, **Clear** wipes the history and stats.
On Windows (handy for testing) **Enter** starts a run and **Space** launches.

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
