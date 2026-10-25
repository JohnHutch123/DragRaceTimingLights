# Drag Tree on Android: testing and deployment (Delphi 12)

Android is much simpler than iPhone: no Mac, no PAServer, no provisioning profile.
Everything runs from RAD Studio on your Windows PC.

## What I checked in the project

| Item | Value in DragTree.dproj | OK? |
| --- | --- | --- |
| Platforms | Android 32-bit and Android 64-bit enabled | Yes |
| Package name | `com.johnhutch123.DragTree` | Yes. Never change it after publishing |
| App label (home screen) | `Drag Tree` (was "Pro Tree", fixed in PR #7) | Yes |
| Min / target SDK | minSdkVersion 23 (Android 6), targetSdkVersion 35 (Android 15) | Fine for testing. See the Play Store note below |
| Version | versionCode 1, versionName 1.0.0 | Raise versionCode by 1 for every Play upload |
| Orientation | Not locked (iPhone is locked to portrait) | Set it, step 3 below |
| Code | Multi-touch pedals on, settings saved in the app's private folder, desktop-only code compiled out | Yes |
| Back button | Closed the app even with Settings open | Fixed in PR #7: Back now closes Settings |

## 1. One-time setup on the PC

1. Tools > Manage Platforms (or GetIt): make sure **Android** support is installed.
   It installs the Android SDK, NDK and a Java JDK for you.
2. Tools > Options > Deployment > **SDK Manager**: you should see an Android SDK entry
   (32-bit and 64-bit). If any path has a red warning, click it and point it at the folder
   the installer used (usually under `C:\Users\Public\Documents\Embarcadero\Studio\23.0\CatalogRepository\`).

## 2. Get the phone ready

1. On the phone: Settings > About phone > tap **Build number** 7 times. Developer options are now on.
2. Settings > System > Developer options > turn on **USB debugging**.
3. Plug the phone into the PC. On the phone tap **Allow** for "Allow USB debugging?"
   (tick "Always allow from this computer").
4. If Windows doesn't see it, install your phone maker's USB driver
   (Samsung: "Samsung USB Driver for Mobile Phones"; Pixel: "Google USB Driver").

## 3. Project settings (once)

1. Projects panel > Target Platforms > right-click **Android 64-bit** > Activate.
   Expand it, then expand **Target**: your phone should appear. Pick it.
   (Press Refresh if it isn't listed.)
2. Project > Options > Application > **Orientation**: tick **Custom orientation**,
   tick only **Portrait**. Target: All configurations - Android 64-bit, and repeat for Android 32-bit.
3. Project > Options > Application > **Icons**: optional, replace the Delphi flame icons with your own.

## 4. Test on the phone

1. Build configuration **Debug**, press **F9** (Run). First build is slow.
   The app installs and opens on the phone.
2. Things to test:
   - Fresh start shows the **Sportsman** tree.
   - Hold clutch, brake and throttle with **three fingers at once** (multi-touch is the risky part).
   - Release to launch; reaction time and verdict show.
   - Settings: change options, press the phone's **Back** button, it should close Settings, not the app.
   - Close the app fully and reopen: your settings are remembered.
   - Top and bottom of the screen are not hidden under the status bar or the gesture bar
     (Android 15 and newer phones draw apps edge to edge; tell me if anything is covered).
3. To share with a friend without the Play Store: build in **Release**, then
   Project > Deploy. Send them the `.apk` from `Android64\Release\DragTree\bin\`.
   They must allow "Install unknown apps" for the app they open it with.

## 5. Publish to Google Play

1. **Google Play Console** account: one-time US$25 fee, play.google.com/console.
   New personal accounts must run a **closed test with at least 12 testers for 14 days**
   before they can publish to everyone.
2. **Signing key (keystore)**: Project > Options > Deployment > Provisioning,
   Target **Android 64-bit**, Build type **Application Store**. Click **New Keystore**,
   fill it in, and **back up the .keystore file and passwords**. Losing them means you
   can't update the app (Play App Signing can reset an upload key, but it is a hassle).
3. Project > Options > Building > Delphi Compiler, **Release** config, Android 64-bit:
   make sure **Generate Android App Bundle file (arm64 + arm)** is on. Play wants an `.aab`.
4. Configuration **Release**, Platform Android 64-bit, Build type **Application Store**
   (Project Manager > Android 64-bit > Configuration). Then Project > **Deploy DragTree**.
   The `.aab` lands in `Android64\Release\DragTree\bin\`.
5. In Play Console: create the app, fill in the store listing, content rating, privacy
   policy (a one-line page saying the app collects no data is enough), data safety form
   (no data collected), then upload the `.aab` to the closed test track.
6. Every new upload: raise **versionCode** in Project > Options > Application > Version Info.

### Target SDK note

Google Play now requires target SDK **36** (since 31 August 2026) and the project is set to 35,
so Play Console will refuse the upload until that changes. RAD Studio 13.1 or later is the
supported way to target 36. Full details, and the rest of the publishing steps, are in
`PlayStore-guide.md`.

## Common problems

| Problem | Fix |
| --- | --- |
| Phone not in Target list | USB debugging off, "Allow" not tapped, or missing USB driver. Try another cable (some are charge-only) |
| "INSTALL_FAILED_UPDATE_INCOMPATIBLE" | An older build was signed differently. Uninstall the app from the phone and run again |
| Build fails, no Java / JDK not found | Install Temurin JDK 17 (x64 .msi) from adoptium.net, then SDK Manager > Android > Java tab: set the JDK folder |
| SDK Manager red warnings | Re-run Tools > Manage Platforms > Android, or fix the paths |
| App flashes then closes; log shows `Resources$NotFoundException` | Icons/splash not packaged. Project > Deployment, Android 64-bit, Revert to default, tick the LauncherIcon and Splash rows, Clean, reinstall |
| App opens sideways | Orientation not set, step 3.2 |
| Pedals don't all register | Some cheap phones report only 2 touches. Set Transmission and Throttle to Auto in Settings so only the brake pad is needed |
