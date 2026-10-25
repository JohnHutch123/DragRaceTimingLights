# Drag Tree: iPhone and Mac setup with Delphi (new Mac, macOS 27)

Written 23 Oct 2026 for: Windows PC with **RAD Studio 12 Athens** (upgrading soon to **13.2 Florence**),
a new Apple-silicon Mac on **macOS 27.1**, and a **paid Apple Developer account**.
Notes marked **13.2** say where Delphi 13.2 is different.

---

## Read first: Delphi 12 and Xcode 27

- On macOS 27 the current Xcode is **Xcode 27.1** (iOS 27.1 SDK). Xcode 27 runs only on Apple-silicon Macs and needs macOS 26.6 or later.
- **Delphi 12 was released before iOS 26/27.** Embarcadero hasn't said it supports the iOS 27 SDK, and forum users needed workarounds just to get Delphi 12 linking with iOS 26. Expect the SDK import or the link step to fail on Delphi 12.
- **Delphi 13.2** (released 17 Sep 2026) is reported by Embarcadero staff to work with macOS 27 and iOS 27.
- Apple only accepts App Store uploads built with a recent SDK (iOS 26 SDK or newer since April 2026), so plan to publish with 13.2.

**What to do:** do Parts 1 to 4 now. Certificates, profiles and Keychain belong to Apple, and they carry over unchanged to Delphi 13.2. If Part 6 (SDK import) fails on Delphi 12, stop there and finish after upgrading. Don't burn time fighting it.

Your app's bundle ID (from DragTree.dproj, iOS): **`com.johnhutch123.DragTree`**. Use exactly this everywhere below.

---

## Part 1. Xcode on the Mac

1. Install **Xcode** from the Mac App Store. Open it once, accept the licence and let it install components. When asked, tick **iOS** platform support.
2. Open **Terminal** and run:
   ```
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   xcodebuild -runFirstLaunch
   ```
3. Avoid installing a second Xcode version alongside this one.

## Part 2. Sign in and create the certificate

1. Xcode > **Settings** > **Accounts** > **+** > Apple ID. Sign in with your developer account. Your team appears (not "Personal Team").
2. Select the team > **Manage Certificates…** > **+** >
   - **Apple Development** (to run on your own iPhone)
   - **Apple Distribution** (only needed later for TestFlight / App Store)
3. Check it in **Keychain Access** (Spotlight: "Keychain Access"):
   - Keychain **login** > **My Certificates**.
   - You should see `Apple Development: John … (XXXXXXXXXX)` with a **triangle**. Click it and a **private key** shows underneath. No key = the certificate is useless on this Mac.
   - If it says "not trusted", download **Apple Worldwide Developer Relations - G3** and **G6** from apple.com/certificateauthority and double-click them.

**Moving from the old Mac?** Certificates made on the old Mac have their private key there. Either export them from the old Mac's Keychain as a `.p12` and import them here, or simply create new ones as above. New ones are easier, and you can have several.

## Part 3. Register the App ID and your iPhone

On **developer.apple.com > Account > Certificates, IDs & Profiles**:

1. **Identifiers > +** > App IDs > App. Description `Drag Tree`, Bundle ID **Explicit**: `com.johnhutch123.DragTree`. No extra capabilities needed. Register.
2. **iPhone:** plug it into the Mac and tap **Trust**. Turn on **Settings > Privacy & Security > Developer Mode** (it restarts). Then in Xcode open **Window > Devices and Simulators** and wait until the phone shows as ready. Xcode registers it with your account for you.
   (Or add it manually under **Devices > +** using its UDID.)

## Part 4. Make the provisioning profile

Pick **one** way.

**A. Automatic, via a throwaway Xcode project (easiest)**
1. Xcode > File > New > Project > iOS > App. Product Name `DragTree`, Team = your team, Organization Identifier `com.johnhutch123`. The bundle ID shown must read `com.johnhutch123.DragTree`.
2. Target > **Signing & Capabilities**: tick **Automatically manage signing**.
3. Pick your iPhone at the top and press **Run** once. A blank app opening on the phone means the profile was made.

**B. Manual, on the website (better for Delphi long term)**
1. developer.apple.com > **Profiles > +** > **iOS App Development** > App ID `com.johnhutch123.DragTree` > your Apple Development certificate > your iPhone > name it `DragTree Dev` > Generate > Download.
2. Later, for the App Store: **Profiles > +** > **App Store Connect** > same App ID > Apple Distribution certificate > `DragTree Store`.
3. Xcode > Settings > Accounts > your team > **Download Manual Profiles**.

**Where profiles live now:** since macOS 15, Xcode keeps them in
`~/Library/Developer/Xcode/UserData/Provisioning Profiles`.
Older PAServer looks in `~/Library/MobileDevice/Provisioning Profiles`. If Delphi says it can't find a profile, run this once in Terminal:
```
mkdir -p ~/Library/MobileDevice
ln -s ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles ~/Library/MobileDevice/Provisioning\ Profiles
```
(If that folder already exists, copy the files across instead:
`cp ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/* ~/Library/MobileDevice/Provisioning\ Profiles/`)

## Part 5. PAServer on the Mac

1. Copy the PAServer installer from the PC to the Mac and run it:
   - Delphi 12: `C:\Program Files (x86)\Embarcadero\Studio\23.0\PAServer\PAServer23.0.pkg`
   - **13.2:** `...\Studio\37.0\PAServer\PAServer37.0.pkg`. If you installed a patch, use the PAServer inside the patch folder under `CatalogRepository`; it's newer, and the older one has caused SDK-import bugs.
2. Open **PAServer** from Applications. A Terminal window opens. Set a password.
3. macOS will ask several times for access to the **Keychain** (choose **Always Allow**), and maybe for Developer Tools or local network. Allow them all.
4. Note the Mac's IP address: System Settings > Wi-Fi > Details.
5. Quit Xcode (Cmd+Q) before deploying from Delphi.

## Part 6. RAD Studio on the PC

1. Tools > Options > Deployment > **Connection Profile Manager** > Add. Platform **macOS ARM 64-bit**, host = the Mac's IP, port **64211**, the PAServer password. Click **Test Connection**.
2. Tools > Options > Deployment > **SDK Manager** > Add > **iOS Device 64-bit** > pick the profile > choose the iOS SDK it offers > OK. Let the import finish.
   - **Delphi 12:** this is where trouble is most likely with Xcode 27. If it fails or the build later says `ld: file too small`, wait for 13.2.
   - **13.2:** works with the iOS 27 SDK. If you see `file too small (length=0)` errors, re-import using the patch PAServer.
3. Also add **macOS ARM 64-bit** in SDK Manager if you want to run the Mac version.

## Part 7. Project settings in Delphi

1. Project > Options > Application > **Version Info**, Target **iOS Device 64-bit**: `CFBundleIdentifier` = `com.johnhutch123.DragTree` (already set).
2. Project > Options > Deployment > **Provisioning**, Target iOS Device 64-bit:
   - Build type **iOS Device 64-bit – Development**: Team = your team ID, certificate `Apple Development: …`, profile `DragTree Dev` (or the Xcode-made one).
   - Build type **Application Store**: `Apple Distribution: …` and `DragTree Store`.
   If the lists are empty, PAServer can't see your certificate or profiles: see Troubleshooting.
3. Projects panel > Target Platforms > **iOS Device 64-bit** > Activate > choose your iPhone under it.
4. Phone unlocked and plugged into the Mac. Run with **Shift+Ctrl+F9** (Run Without Debugging) first.

**Mac version:** activate **macOS ARM 64-bit** and run. It runs locally without any profile. The macOS bundle ID is currently just `DragTree`; set it to `com.johnhutch123.DragTree` before any Mac App Store work.

---

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Certificate list empty in Delphi | Keychain has no private key under the certificate (Part 2), or PAServer was denied Keychain access. Restart PAServer and choose Always Allow |
| "No provisioning profile found" | Bundle ID mismatch, or profile in the new folder only. Run the link command in Part 4, then restart PAServer |
| Profile doesn't include this device | Phone not registered when the profile was made. Re-generate the profile (or re-run the Xcode test app) and download again |
| Connection refused | PAServer not running, wrong IP, or macOS firewall. Allow PAServer in System Settings > Network > Firewall |
| SDK import fails / `ld: file too small` | Delphi 12 vs Xcode 27; wait for 13.2. On 13.2, use the patch PAServer and re-import |
| App installs but won't open | On the phone, Settings > General > VPN & Device Management > trust the developer |
| Debugger stops with "exception class" | Use Run Without Debugging, or tick "Ignore this exception type" |

## Sources

- Xcode 27 requirements: https://blakecrosley.com/blog/xcode-27-release
- RAD Studio 13.2 release and macOS/iOS 27 comment: https://blogs.embarcadero.com/rad-studio-13-2-florence-is-here/
- Delphi and Xcode 26 problems: https://en.delphipraxis.net/topic/14429-dont-upgrade-xcode-and-ios-to-release-26/
- Xcode 26.4 SDK import bug: https://en.delphipraxis.net/topic/15265-warning-importing-sdks-from-xcode-264-breaks-delphi/
- Provisioning profile folder move: https://en.delphipraxis.net/topic/12300-delphi-122-and-macos-sequoia-150-no-provisioning-profile/
- Apple SDK minimums: https://developer.apple.com/news/upcoming-requirements/
