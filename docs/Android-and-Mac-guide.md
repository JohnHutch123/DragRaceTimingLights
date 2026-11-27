# Drag Tree on Android and Mac: setup, testing and deployment (Delphi 13)

Updated 18 Nov 2026 for: Windows PC with **RAD Studio 13 Florence (13.2)**, an Android phone,
and an Apple-silicon Mac on **macOS 27.1** with a **paid Apple Developer account**.

This guide replaces the old `Android-guide.md` and `iPhone-and-Mac-setup.md`.

- **Chapter 1, Android:** everything runs from RAD Studio on the PC. No Mac needed.
- **Chapter 2, Mac (iPhone and macOS):** the Mac builds, signs and installs the iPhone app
  through PAServer, and can also run the Mac desktop version.

Publishing to the stores is covered separately in `PlayStore-guide.md` (Google Play) and
`AppStore-guide.md` (Apple). Start those once the app runs on your phone.

For the everyday loop of pulling new changes and putting them on the phones (USB, PAServer,
Play Internal testing, TestFlight, which version numbers to raise), see `Testing-updates-guide.md`.

---

## Where the project is now

| Item | Value in DragTree.dproj | Notes |
| --- | --- | --- |
| Delphi project version | ProjectVersion 20.5 (Delphi 13) | Opening it in Delphi 12 is no longer supported |
| App ID, all platforms | `com.johnhutch123.DragTree` | Android package and iOS bundle ID. **Never change it** after publishing |
| App name on the phone | `Drag Tree` | |
| Android SDK levels | minSdkVersion 24 (Android 7), **targetSdkVersion 36** (Android 16) | 36 is what Google Play requires since 31 Aug 2026 |
| Version | Android versionCode 1 / 1.0.0. iOS Release CFBundleVersion 1.0.2 | Raise versionCode / CFBundleVersion by 1 for every store upload |
| Orientation | Portrait only, set in code (`DragTree.dpr`) and in the iOS Info.plist keys | Nothing to tick in Project Options |
| Icons | Android launcher icons and splash images (PR #18, #20). iOS icons on Release iOS Device 64-bit | Files in `Icons\`, see `Icons\README.md` |
| Android system bars | Form is padded clear of the status bar and navigation bar (PR #21) | Needed because targetSdk 36 forces edge to edge |
| Buttons | Drawn in code (coloured rectangles), not stock FMX buttons (PR #9) | They no longer live in MainForm.fmx |

---

# Chapter 1. Android

## 1.1 One-time setup on the PC

1. **Tools > Manage Platforms**: make sure **Android** is installed for Delphi 13.
   It installs the Android SDK (including API 36), NDK and a Java JDK.
2. **Tools > Options > Deployment > SDK Manager**: there should be an Android 64-bit SDK entry
   (and a 32-bit one if you build 32-bit). If any path shows a red warning, click it and point
   it at the folder the installer used, usually
   `C:\Users\Public\Documents\Embarcadero\Studio\37.0\CatalogRepository\`.
3. **Java:** if the build says no JDK was found, install **Temurin JDK 17 (x64 .msi)** from
   adoptium.net, then in SDK Manager > Android > **Java** tab set the JDK folder.

## 1.2 Get the phone ready

1. On the phone: **Settings > About phone** > tap **Build number** 7 times. Developer options are now on.
2. **Settings > System > Developer options** > turn on **USB debugging**.
3. Plug the phone into the PC and tap **Allow** for "Allow USB debugging?"
   (tick "Always allow from this computer").
4. If Windows doesn't see it, install your phone maker's USB driver
   (Samsung: "Samsung USB Driver for Mobile Phones"; Pixel: "Google USB Driver").

## 1.3 Project settings to check (once)

Most of this is already in the project. Check it after pulling from GitHub or after the IDE
upgrades the project.

1. **Projects panel > Target Platforms** > right-click **Android 64-bit** > Activate.
   Expand **Target**: your phone should appear. Pick it (press Refresh if it isn't listed).
2. **Libraries (do this after any Delphi upgrade):** in the Projects panel expand
   **Android 64-bit > Libraries**, right-click it > **Revert System Files to Default**.
   Do the same under Android 32-bit if you use it. This swaps the old Delphi 12 jar list
   (for example `play-services-basement-18.4.0`) for the jars Delphi 13 ships.
   PR #20 already removed the old list from the project file.
3. **Project > Options > Application > Icons**, target *All configurations - Android 64-bit*:
   - The six launcher icons point at `Icons\Android\LauncherIcon_*.png`.
   - The four splash images point at `Icons\Android\Splash\SplashImage_*.png`, and
     **Include splash image** is ticked. **Keep them set**: Delphi 13 always deploys
     `splash_image_def.xml`, which needs `drawable/splash_image`, so the build fails without them.
4. **Project > Options > Application > Version Info**, Android 64-bit: check
   `minSdkVersion=24`, `targetSdkVersion=36`, `package=com.johnhutch123.DragTree`, `label=Drag Tree`.
5. **Project > Options > Application > Uses Permissions**: Drag Tree needs none. Untick them all.

## 1.4 Test on the phone

After the first run, use `Testing-updates-guide.md` (steps 1 and 3) each time new code arrives.

1. Build configuration **Debug**, press **F9** (Run). The first build is slow.
   The app installs and opens on the phone, with the Drag Tree icon and a dark splash.
2. Things to test:
   - Fresh start shows the **Sportsman** tree.
   - The bottom buttons sit **above** the navigation bar (3-button or gesture bar), and the
     top isn't under the status bar. The app stays portrait when you turn the phone.
   - Hold clutch, brake and throttle with **three fingers at once** (multi-touch is the risky part).
   - Release to launch: reaction time and verdict show.
   - Settings: change options, press the phone's **Back** button. It should close Settings, not the app.
   - Close the app fully and reopen: your settings are remembered.
3. To share with a friend without the Play Store: build in **Release**, then **Project > Deploy**,
   and send them the `.apk` from `Android64\Release\DragTree\bin\`.
   They must allow "Install unknown apps" for the app they open it with.

## 1.5 Publishing

Full details are in `PlayStore-guide.md`. These are the steps that tripped us up.

### 1.5.1 Package name

Play Console's **Create app** asks for a **Package name**. Type **`com.johnhutch123.DragTree`**
exactly (capital D and T). It comes from Project > Options > Application > Version Info >
`package` (`com.johnhutch123.$(MSBuildProjectName)`), must match the uploaded `.aab`, and can
never be changed after the app is created.

### 1.5.2 Upload keystore (make it with keytool)

The keystore is a password-protected file holding your upload key; every `.aab` is signed
with it. RAD Studio's **New Keystore...** wizard has a bug where the alias password can't be
typed, so make the keystore on the command line instead:

1. Find keytool: **Tools > Options > Deployment > SDK Manager**, your Android SDK,
   **Java** tab, **Keytool location**.
2. Make a folder outside the project, e.g. `D:\AndroidKeyStore`.
3. In Command Prompt, on one line (use your own keytool path):

   ```
   "C:\path\to\keytool.exe" -genkeypair -v -keystore "D:\AndroidKeyStore\DragTreeKeyStore.keystore" -alias dragtree -keyalg RSA -keysize 2048 -validity 18250
   ```

   Type a password (nothing shows while typing), your name, city and two-letter country code,
   then `yes`. If asked for a key password, press Enter. **The keystore password and alias
   password are the same.** `-validity 18250` is 50 years.
4. In RAD Studio: **Project > Options > Deployment > Provisioning**, Build Type
   **Android 64-bit - Application Store**. Click **...** next to *KeyStore File*, pick the file,
   type the password, choose alias `dragtree`, type the same password again. Repeat for
   **Android 32-bit - Application Store**, then **Save**.
5. Back the keystore file and password up somewhere other than this PC.

### 1.5.3 Build the .aab: Build, then Deploy

1. Project > Options > Building > Delphi Compiler, Android 64-bit: **Generate Android App
   Bundle file (arm64 + arm)** is on.
2. Projects panel: **Android 64-bit** active, configuration **Release** (its build type is
   Application Store).
3. **Project > Build**. This only compiles `libDragTree.so` into `Android64\Release\`;
   **no `.aab` is made yet**, even though it says Success.
4. **Project > Deploy DragTree**. This packages and signs the bundle.
5. The file is `Android64\Release\DragTree\bin\DragTree.aab`. Upload that to Play Console.

Remember to raise `versionCode` in Version Info before every new upload. After that: a closed
test with 12 testers for 14 days, then production (see `PlayStore-guide.md`).

## 1.6 Android problems and fixes

| Problem | Fix |
| --- | --- |
| Phone not in the Target list | USB debugging off, "Allow" not tapped, or missing USB driver. Try another cable (some are charge-only) |
| `E7688` ... `NoSuchFileException` on a jar during deploy | Old Delphi 12 library list. Projects panel > Android 64-bit > Libraries > right-click > **Revert System Files to Default**, then Clean and build |
| Build stops with `drawable/splash_image` missing | Splash images not set. Re-set them in Options > Icons and tick **Include splash image** (step 1.3.3) |
| App flashes then closes; log shows `Resources$NotFoundException` | Icons or splash not packaged. **Project > Deployment**, Android 64-bit, **Revert to default**, check the LauncherIcon and Splash rows are ticked, Clean, reinstall |
| Bottom buttons hidden under the navigation bar | You are running a build without PR #21. Pull main and rebuild. If it still happens, tell me the phone model and Android version |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | An older build was signed differently. Uninstall the app from the phone and run again |
| Build fails, no Java / JDK not found | Install Temurin JDK 17 and set it in SDK Manager (step 1.1.3) |
| Build says Success but there's no `.aab` | Build only compiles. Run **Project > Deploy DragTree** (step 1.5.3) |
| New Keystore wizard won't accept the alias password | Known RAD Studio bug. Make the keystore with keytool and select it (step 1.5.2) |
| Play says the package name doesn't match | The `.aab` and Create app must both use `com.johnhutch123.DragTree` (step 1.5.1) |
| Play says the version code is already used | Raise `versionCode` in Version Info, then Build and Deploy again |
| SDK Manager red warnings | Re-run Tools > Manage Platforms > Android, or fix the paths |
| Buttons look grey or disabled | Old MainForm from before PR #9. Pull main: buttons are now made in code |
| Pedals don't all register | Some cheap phones report only 2 touches. Set Transmission and Throttle to Auto in Settings so only the brake pad is needed |

---

# Chapter 2. Mac (iPhone and macOS)

The Windows PC does the compiling; the Mac runs **PAServer**, which calls Xcode to sign the app and
install it on the iPhone. Parts 2.1 to 2.4 are Apple accounts and Keychain work and only need doing once.

**Versions:** macOS 27 comes with **Xcode 27.1** (iOS 27.1 SDK). Xcode 27 runs only on Apple-silicon Macs.
Delphi 13.2 works with it; Delphi 12 does not reliably import the iOS 26/27 SDK, and Apple only accepts
App Store uploads built with the iOS 26 SDK or newer, so use Delphi 13.2 for everything Apple.

## 2.1 Xcode on the Mac

1. Install **Xcode** from the Mac App Store. Open it once, accept the licence and let it install
   components. When asked, tick **iOS** platform support.
2. In **Terminal**:
   ```
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   xcodebuild -runFirstLaunch
   ```
3. Keep one Xcode version only.

## 2.2 Sign in and create the certificates

1. Xcode > **Settings** > **Accounts** > **+** > Apple ID. Sign in with your developer account.
   Your team appears (not "Personal Team").
2. Select the team > **Manage Certificates…** > **+**:
   - **Apple Development** (to run on your own iPhone)
   - **Apple Distribution** (TestFlight and App Store)
3. Check in **Keychain Access**: keychain **login** > **My Certificates**. Each certificate should have a
   **triangle**, and a **private key** underneath when you open it. No key means the certificate is useless on this Mac.
   If it says "not trusted", download **Apple Worldwide Developer Relations - G3** and **G6** from
   apple.com/certificateauthority and double-click them.

## 2.3 App ID and your iPhone

On **developer.apple.com > Account > Certificates, IDs & Profiles**:

1. **Identifiers > +** > App IDs > App. Description `Drag Tree`, Bundle ID **Explicit**:
   `com.johnhutch123.DragTree`. No extra capabilities. (Already done if you have submitted to the App Store.)
2. **iPhone:** plug it into the Mac and tap **Trust**. Turn on
   **Settings > Privacy & Security > Developer Mode** (it restarts). In Xcode open
   **Window > Devices and Simulators** and wait until the phone shows as ready; Xcode registers it for you.

## 2.4 Provisioning profiles

On the website (the simplest for Delphi):

1. **Profiles > +** > **iOS App Development** > App ID `com.johnhutch123.DragTree` > your Apple Development
   certificate > your iPhone > name `DragTree Dev` > Generate > Download.
2. **Profiles > +** > **App Store Connect** > same App ID > Apple Distribution certificate > `DragTree Store`.
3. Xcode > Settings > Accounts > your team > **Download Manual Profiles**.

**Profile folder:** current Xcode keeps profiles in
`~/Library/Developer/Xcode/UserData/Provisioning Profiles`, but PAServer may look in
`~/Library/MobileDevice/Provisioning Profiles`. If Delphi says it can't find a profile, run once:
```
mkdir -p ~/Library/MobileDevice
ln -s ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles ~/Library/MobileDevice/Provisioning\ Profiles
```
If that folder already exists, copy the files across instead:
`cp ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/* ~/Library/MobileDevice/Provisioning\ Profiles/`

A new or re-registered iPhone means re-generating the Dev profile and downloading it again.

## 2.5 PAServer on the Mac

1. Copy the PAServer installer from the PC to the Mac and run it:
   `C:\Program Files (x86)\Embarcadero\Studio\37.0\PAServer\PAServer37.0.pkg`.
   If you installed a 13.x patch, use the PAServer inside the patch folder under `CatalogRepository`
   instead; it is newer, and older ones have caused SDK-import bugs.
   **Reinstall PAServer whenever you update Delphi**, so the PC and Mac versions match.
2. Open **PAServer** from Applications. A Terminal window opens. Set a password.
3. Allow the **Keychain** prompts (**Always Allow**), Developer Tools and local network access.
4. Note the Mac's IP address: System Settings > Wi-Fi > Details.
5. Quit Xcode (Cmd+Q) before deploying from Delphi.

## 2.6 RAD Studio on the PC

1. **Tools > Options > Deployment > Connection Profile Manager** > Add. Platform **macOS ARM 64-bit**,
   host = the Mac's IP, port **64211**, the PAServer password. **Test Connection**.
2. **Tools > Options > Deployment > SDK Manager** > Add > **iOS Device 64-bit** > pick the profile >
   choose the iOS 27 SDK > OK. Let the import finish.
   If you later see `ld: file too small (length=0)`, re-import the SDK with the patch PAServer running.
   **Re-import the SDK after every Xcode update.**
3. Add **macOS ARM 64-bit** in SDK Manager too, for the Mac version.

## 2.7 Run on the iPhone

After the first run, use `Testing-updates-guide.md` (steps 1 and 4) each time new code arrives.

1. **Project > Options > Deployment > Provisioning**, target iOS Device 64-bit:
   - Build type **iOS Device 64-bit - Development**: your team, `Apple Development: …`, profile `DragTree Dev`.
   - Build type **Application Store**: `Apple Distribution: …`, profile `DragTree Store`.
   Empty lists mean PAServer can't see your certificate or profiles; see the table below.
2. **Project > Options > Application > Version Info**, iOS Device 64-bit: `CFBundleIdentifier`
   is `com.johnhutch123.DragTree`, and in **Release** `UIDeviceFamily` is **iPhone** (iPhone only, no iPad
   screenshots needed). The Debug settings still say iPhoneAndiPad, which is harmless for testing.
3. **Icons:** the iOS icons, including the 1024 App Store icon, are set for **Release** iOS Device 64-bit.
   A Debug build shows the Delphi flame; set *All configurations - iOS Device 64-bit* in Options > Icons if that bothers you.
4. **Projects panel > Target Platforms > iOS Device 64-bit** > Activate > choose your iPhone under it.
5. Phone unlocked and plugged into the Mac. Run with **Shift+Ctrl+F9** (Run Without Debugging) first.
6. Run the same checks as Android step 1.4 (Sportsman default, three-finger pedals, Settings, settings remembered),
   plus: nothing hidden under the notch/Dynamic Island or the home bar.

## 2.8 Run the Mac desktop version

1. Activate **macOS ARM 64-bit** in Target Platforms and press F9. It runs on the Mac through PAServer;
   no provisioning profile is needed for local runs.
2. The window opens 390 points wide and centred, phone-shaped, with Sportsman as the default tree.
3. Before any Mac App Store work: set the macOS `CFBundleIdentifier` (currently just `DragTree`) to
   `com.johnhutch123.DragTree`, and set the icon in Options > Icons to `Icons\macOS\DragTree.icns`
   (it still points at Delphi's default).

## 2.9 Publishing

See `AppStore-guide.md`: Application Store build, upload the `.ipa` with **Transporter**, TestFlight,
then submit for review. Drag Tree was submitted for review on 17 Nov 2026.
Raise **CFBundleVersion** for every new upload.

## 2.10 Mac and iPhone problems and fixes

| Problem | Fix |
| --- | --- |
| Certificate list empty in Delphi | No private key under the certificate (2.2), or PAServer was denied Keychain access. Restart PAServer and choose Always Allow |
| "No provisioning profile found" | Bundle ID mismatch, or the profile is only in the new folder. Run the link command in 2.4, then restart PAServer |
| Profile doesn't include this device | Phone wasn't registered when the profile was made. Re-generate the Dev profile and download again |
| Connection refused | PAServer not running, wrong IP, or the macOS firewall. Allow PAServer in System Settings > Network > Firewall |
| PAServer version mismatch | Delphi was updated but the Mac wasn't. Reinstall PAServer from the matching `PAServer37.0.pkg` (2.5) |
| SDK import fails / `ld: file too small` | Use the patch PAServer and re-import the SDK in SDK Manager |
| Build breaks after an Xcode update | Re-import the iOS SDK (2.6.2) |
| App installs but won't open | On the phone: Settings > General > VPN & Device Management > trust the developer |
| Debugger stops with "exception class" | Use Run Without Debugging, or tick "Ignore this exception type" |

---

## Sources

- RAD Studio 13 Florence Update 1, Android API 36: https://blogs.embarcadero.com/announcing-the-availability-of-rad-studio-13-florence-update-1/
- RAD Studio 13.2 and macOS/iOS 27: https://blogs.embarcadero.com/rad-studio-13-2-florence-is-here/
- Xcode 27 requirements: https://blakecrosley.com/blog/xcode-27-release
- Xcode SDK import bug with older PAServer: https://en.delphipraxis.net/topic/15265-warning-importing-sdks-from-xcode-264-breaks-delphi/
- Provisioning profile folder move: https://en.delphipraxis.net/topic/12300-delphi-122-and-macos-sequoia-150-no-provisioning-profile/
- Apple SDK minimums: https://developer.apple.com/news/upcoming-requirements/
