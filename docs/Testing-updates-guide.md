# Getting new changes onto your phones while developing and testing

Written 27 Nov 2026 for Delphi 13 (RAD Studio 13.2) on the PC at `D:\DragRaceTimingLights`,
an Android phone, an iPhone, and the Mac running PAServer.

This guide covers the everyday loop: a change lands on GitHub (from me or from you), and you
want the new build on your phones. The one-time setup (SDKs, USB debugging, certificates,
PAServer) is in `Android-and-Mac-guide.md`. Store uploads are covered in full in
`PlayStore-guide.md` and `AppStore-guide.md`; this guide only has the short version for test builds.

| I want to... | Go to |
| --- | --- |
| Get the latest code onto the PC first (always) | Step 1 |
| Try a change quickly on the PC | Step 2 |
| Put a change on my Android phone over USB | Step 3 |
| Put a change on my iPhone through the Mac | Step 4 |
| Send a test build through Google Play (Internal testing) | Step 5 |
| Send a test build through TestFlight | Step 6 |
| Know which version numbers to raise | Step 7 |

The current numbers in `DragTree.dproj` are **Android versionCode 4, versionName 2.0.0** and
**iOS CFBundleShortVersionString 2.0.0, CFBundleVersion 2.0.0**.

---

## 1. Pull the latest code first (every time)

Changes from me arrive as pull requests that get merged into `main` on GitHub. Your PC copy
doesn't change until you pull. Do this before you open the project or edit anything.

1. **Close the project in RAD Studio** (File > Close All), or close RAD Studio. If the IDE has
   the project open while git changes the files, it can save its old copy of `DragTree.dproj`
   or `MainForm.fmx` over the new one when you close it.
2. Open a command prompt in the project folder and check for your own unsaved work:
   ```
   cd /d D:\DragRaceTimingLights
   git status
   ```
3. If `git status` lists files you changed in the IDE (often `DragTree.dproj` after changing
   Project Options), commit them first so the pull can merge them:
   ```
   git add -A
   git commit -m "My IDE changes"
   ```
   If you don't need those changes, throw them away instead with `git checkout -- .`
4. Pull:
   ```
   git checkout main
   git pull
   ```
   (GitHub Desktop does the same: Current branch **main**, then **Fetch origin**, then **Pull origin**.)
5. Open `DragTree.dproj` in RAD Studio.

### If the pull reports a conflict

A conflict means you and the new code both changed the same lines. **Do not pick "keep mine"
(or "use my version") on `MainForm.pas`, `MainForm.fmx` or `DragTree.dproj`.** That is how the
1.1 to 2.0 features were wiped from main on 27 Nov 2026 (fixed by PR #26). Your copy of those
files is usually older than the one on GitHub.

Safest way out:

- To take GitHub's version of a file and drop your edits to it:
  ```
  git checkout --theirs MainForm.pas
  git add MainForm.pas
  ```
  (Repeat for each conflicted file, then `git commit`.)
- Or back out completely and ask me: `git merge --abort`, then tell me which files conflicted.
  I can merge them for you on a branch.
- If you changed something small in Project Options (a keystore path, a version number), take
  GitHub's `DragTree.dproj` and redo that one setting in the IDE afterwards. It's quicker than
  hand-merging the XML.

After any pull: **Project > Clean** for the platform you're about to build, so nothing stale is reused.

---

## 2. Quick check on the PC (optional, fastest)

For layout and logic changes you can see most of it without a phone:

1. Projects panel > Target Platforms > **Windows 64-bit** > Activate.
2. Debug, press **F9**. It runs in seconds.

Multi-touch pedals, the Android navigation-bar padding and the iPhone notch can only be checked
on the phones, so still do step 3 or 4 before calling a change good.

---

## 3. Android phone over USB (the everyday loop)

1. Phone plugged in, unlocked, USB debugging on (set up in `Android-and-Mac-guide.md` 1.2).
2. Projects panel > Target Platforms > **Android 64-bit** > Activate, pick your phone under
   **Target** (press Refresh if it's missing).
3. Build configuration **Debug**, press **F9** (or **Shift+Ctrl+F9** for Run Without Debugging,
   which starts faster).
4. Delphi installs the new build **over** the one already on the phone and opens it. Your saved
   settings (DragTree.ini) are kept, because it's an update of the same app.

You **don't** need to raise versionCode for USB installs. Raise it only for store uploads (step 7).

### When the install fails

| Message or symptom | Why | Fix |
| --- | --- | --- |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | The app on the phone came from Google Play (signed by Google) or from a different keystore, and Android won't replace it with a Debug build | Uninstall Drag Tree from the phone, then F9 again. Settings are lost |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | The phone has a build with a higher versionCode (often a Play test build) | Uninstall it first, or raise versionCode above it |
| Old version still shows | Delphi skipped the deploy or the phone kept the old process | Project > Clean, build again. Swipe the app away on the phone before reopening |
| Phone not listed | USB cable, driver or the "Allow USB debugging" prompt | See `Android-and-Mac-guide.md` 1.6 |

To uninstall from the PC instead of the phone (the `adb` tool is in the Android SDK's
`platform-tools` folder that Delphi uses):
```
adb uninstall com.johnhutch123.DragTree
```

### Without a cable (optional)

On Android 11 and later you can deploy over Wi-Fi: phone **Developer options > Wireless
debugging** > on > **Pair device with pairing code**, then on the PC:
```
adb pair <ip>:<pairing port>
adb connect <ip>:<debug port>
```
The phone then shows up in Delphi's Target list like a USB device. The PC and phone must be on
the same Wi-Fi.

### Giving a test build to someone else without the Play Store

Build **Release**, then **Project > Deploy DragTree**, and send them
`Android64\Release\DragTree\bin\DragTree.apk`. They need "Install unknown apps" allowed for
whatever they open it with. If they already have the Play version, they must uninstall it first
(different signature).

---

## 4. iPhone through the Mac (the everyday loop)

1. On the Mac: start **PAServer** (Applications), and quit Xcode.
2. iPhone plugged into the **Mac** (not the PC), unlocked, Developer Mode on.
3. In RAD Studio: Projects panel > Target Platforms > **iOS Device 64-bit** > Activate, pick
   the iPhone under it. Build configuration **Debug**, and under
   **iOS Device 64-bit > Configuration** the build type **Development**.
4. **Shift+Ctrl+F9** (Run Without Debugging). The first build after a pull is slow; the Mac
   may ask for your login password to let codesign use the key: **Always Allow**.
5. The new build replaces the one on the phone and opens. Settings are kept.

You **don't** need to raise CFBundleVersion for these installs. Raise it only for TestFlight /
App Store uploads (step 7).

Notes:

- **The App Store or TestFlight copy gets replaced.** A Development build has the same bundle
  ID, so it installs over the store copy. That's fine for testing. To go back, reinstall from
  TestFlight or the App Store.
- **Development builds stop opening after the profile expires** (a year, or 7 days for a free
  account). Re-generate `DragTree Dev` as in `Android-and-Mac-guide.md` 2.4.
- **New iPhone?** It must be registered and added to the `DragTree Dev` profile first (2.3 and 2.4).

### When the install fails

| Message or symptom | Fix |
| --- | --- |
| Can't connect to the Mac | PAServer not running, Mac IP changed (check Wi-Fi > Details and update the Connection Profile), or firewall |
| "Profile doesn't include this device" | Re-generate the Dev profile with this iPhone ticked, download it, restart PAServer |
| Build fails after the Mac updated Xcode or iOS | Re-import the iOS SDK in Tools > Options > Deployment > SDK Manager |
| PAServer version mismatch after a Delphi patch | Reinstall PAServer on the Mac from the patch's `.pkg` |
| App installs but won't open | iPhone Settings > General > VPN & Device Management > trust the developer, and check Developer Mode is on |
| iPhone not listed in Delphi | Unlock it, tap **Trust** on the phone, and open Xcode once to let it finish "preparing" the device, then quit Xcode |

More in `Android-and-Mac-guide.md` 2.10.

---

## 5. Android test build through Google Play

Use this when you want the real Play-signed build on your phone (or friends' phones), or for
the closed test.

### Internal testing track (minutes, no review)

1. Raise **versionCode** by 1 (step 7). For example 4 to 5. versionName can stay `2.0.0` for test builds.
2. Build configuration **Release**, Android 64-bit, build type **Application Store**
   (with *Generate Android App Bundle* on, as in `PlayStore-guide.md` step 6).
3. **Project > Clean**, **Build**, then **Project > Deploy DragTree**.
   The file is `Android64\Release\DragTree\bin\DragTree.aab`.
4. Play Console > Drag Tree > **Test and release > Testing > Internal testing > Create new release**
   > upload the `.aab` > release notes (one line on what changed) > **Save > Review > Start rollout**.
5. On the phone open the Play Store page for Drag Tree (or the tester opt-in link from the
   track's **Testers** tab) and tap **Update**. It can take a few minutes to appear. If it
   doesn't, clear the Play Store's cache or wait a bit.

The same `.aab` can be promoted to Closed testing or Production later from **Releases > Promote**.

### Internal app sharing (fastest, no version bump)

Play Console > **Test and release > Internal app sharing** (turn it on once in its settings,
and add yourself as an uploader). Upload the `.aab` or a Release `.apk`, and Play gives you a
link. Open it on the phone to install. It doesn't use up a versionCode, so it's good for
"does this build work" checks. The phone's Play Store must allow it once: Play Store > profile
picture > Settings > About > tap **Play Store version** seven times, then Settings > General >
**Developer options** > turn on **Internal app sharing**.

### Switching between USB and Play builds

A USB Debug build and a Play build are signed differently, so going from one to the other means
uninstalling first (settings are lost). A simple habit: use USB builds while changing code, and
only install from Play when you want to check a finished build.

---

## 6. iPhone test build through TestFlight

Use this to check the App Store-signed build, or to get a build onto an iPhone that isn't
plugged into the Mac.

1. Raise **CFBundleVersion** (the build number) above the last upload (step 7).
2. Build configuration **Release**, iOS Device 64-bit, build type **Application Store**
   (certificate `Apple Distribution`, profile `DragTree Store`).
3. **Project > Clean**, then **Project > Deploy DragTree**. The `.ipa` lands in
   `iOSDevice64\Release\DragTree.ipa` on the PC and in PAServer's `scratch-dir` on the Mac.
4. On the Mac open **Transporter**, drag in the `.ipa`, **Deliver**.
5. Wait 5 to 30 minutes for App Store Connect > Drag Tree > **TestFlight** to show the build as
   ready (Apple emails if it finds a problem).
6. Your Internal Testing group gets it automatically if *Automatic distribution* is on;
   otherwise open the group and add the build.
7. On the iPhone open **TestFlight** and tap **Update** (or Install).

Internal testers need no review. External testers need a short Beta App Review for the first
build of each new version. TestFlight builds expire after 90 days.

Full details: `AppStore-guide.md` steps 5 and 6.

---

## 7. Version numbers: what to raise and when

| Where it goes | Android | iPhone |
| --- | --- | --- |
| USB / PAServer install (steps 3, 4) | Nothing to change | Nothing to change |
| Play Internal app sharing | Nothing to change | n/a |
| Play testing track or Production (step 5) | **versionCode +1** every upload | n/a |
| TestFlight or App Store (step 6) | n/a | **CFBundleVersion** higher than any earlier upload of this version |
| A real public release | Also raise versionName (2.0.0 to 2.0.1 or 2.1.0) | Also raise CFBundleShortVersionString (2.0.0 to 2.0.1 or 2.1.0) |

Where to change them: **Project > Options > Application > Version Info**.

- **Android:** set `versionCode` (and `versionName` if needed) for **Android 64-bit and
  Android 32-bit**, **Release** (the bundle contains both). Doing it under
  *All configurations* changes Debug and Release together, which keeps them matching.
- **iPhone:** select **iOS Device 64-bit**, **Release**. Keep `CFBundleShortVersionString`
  at the version you're testing (for example `2.0.0`) and give each TestFlight upload a higher
  `CFBundleVersion`: `2.0.0`, then `2.0.1`, `2.0.2`... (up to three numbers separated by dots).
  Or tick **Auto increment build number** and let Delphi do it. Once a version has been
  released on the App Store, the next upload needs a higher `CFBundleShortVersionString`.

Commit the `.dproj` after changing version numbers (`git add DragTree.dproj`,
`git commit -m "versionCode 5"`, `git push`) so the next pull doesn't fight over it, and so I
work from the right numbers.

---

## Quick checklist

**Every change:**
1. Close the project, `git status`, commit or discard your edits, `git pull`.
2. Conflicts on MainForm or the dproj: take GitHub's version, never "keep mine".
3. Open the project, Clean.
4. Android: Debug, F9 with the phone on USB.
5. iPhone: PAServer on, phone on the Mac, Debug + Development, Shift+Ctrl+F9.

**Store test build:**
1. Raise versionCode (Android) / CFBundleVersion (iPhone), commit and push the dproj.
2. Release + Application Store, Clean, Build, Deploy.
3. Android: upload the `.aab` to Internal testing. iPhone: Transporter, then TestFlight.
