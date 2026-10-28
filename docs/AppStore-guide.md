# Publishing Drag Tree to the Apple App Store (Delphi / RAD Studio)

Step-by-step guide for getting the Delphi FireMonkey app **Drag Tree**
(`com.johnhutch123.DragTree`) onto the iPhone App Store.
Checked against Apple's published rules on 26 October 2026.

For setting up Xcode, PAServer, certificates and running on your own iPhone, see
`iPhone-and-Mac-setup.md` first. This guide starts once the app runs on your iPhone.

## The short version

1. Paid Apple Developer Program membership (US$99 a year). You have this already.
2. **Plan to publish with Delphi 13.2** (step 1). Apple only accepts uploads built with the
   iOS 26 SDK or newer, and Delphi 12 does not officially support it.
3. Make an **Apple Distribution** certificate and an **App Store Connect** provisioning profile.
4. Tidy the project: iPhone only, icons, version numbers.
5. Build the **Application Store** `.ipa` and upload it with **Transporter** on the Mac.
6. Test it yourself through **TestFlight**.
7. Fill in the App Store Connect page: screenshots, description, privacy, age rating.
8. Submit for review. Apple usually answers within 1 to 3 days.

Unlike Google Play there is **no 12-tester, 14-day rule**. You can go from first upload to
"Ready for Sale" in under a week.

---

## 1. Delphi version: the one possible blocker

**Apple's rules:**

| From | Uploads must be built with |
| --- | --- |
| 28 April 2026 (now) | Xcode 26 or later, **iOS 26 SDK** or later |
| April 2027 | **iOS 27 SDK** or later (announced September 2026) |

Apple also requires the app to support iOS 13 or later (since 9 September 2026). Delphi's
own minimum is higher than that, so this is not a problem.

**What that means for you:**

- Your Mac has Xcode 27 (iOS 27 SDK), which satisfies both rules.
- **Delphi 12** was released before iOS 26. Embarcadero has not said it supports the iOS 26
  or 27 SDK, and the SDK import or linking may fail (see the setup guide, Part 6). Even if
  you get a build, an upload built on an older SDK is refused with an *"SDK version issue"*
  (ITMS-90725) error.
- **Delphi 13.2** is reported to work with Xcode 27 and the iOS 27 SDK.

**What to do:** do steps 2 to 4 and 7 now on Delphi 12. They are Apple website work and
project settings, and they carry over to 13.2 unchanged. Do the build and upload (step 5)
on **Delphi 13.2**. If you do try Delphi 12 first and the SDK import or upload fails, stop
there; it's the SDK, not something you did.

## 2. Distribution certificate and App Store profile (once)

You made the **Apple Development** certificate and `DragTree Dev` profile for running on your
phone. Publishing needs a second pair. The App ID `com.johnhutch123.DragTree` is already
registered (setup guide, Part 3).

1. **Certificate:** on the Mac, Xcode > Settings > Accounts > your team > **Manage
   Certificates** > **+** > **Apple Distribution**.
   Check in Keychain Access > login > My Certificates that `Apple Distribution: John …` has a
   **private key** under it (click the triangle).
2. **Profile:** developer.apple.com > Account > Certificates, IDs & Profiles > **Profiles > +**
   - Distribution: **App Store Connect**
   - App ID: `com.johnhutch123.DragTree`
   - Certificate: the Apple Distribution one
   - Name: `DragTree Store` > Generate.
3. Xcode > Settings > Accounts > your team > **Download Manual Profiles**.
   If Delphi doesn't list it later, use the link/copy command from the setup guide, Part 4.
4. **Back up the certificate:** in Keychain Access right-click the Apple Distribution
   certificate > **Export** > `.p12` with a password. Keep it with your Android keystore
   backup. (Unlike Android, losing it isn't fatal; you can make a new one. But it saves time.)

## 3. App Store Connect record (once)

1. Go to **appstoreconnect.apple.com** > **Apps** > **+** > **New App**.
   - Platforms: **iOS**
   - Name: **Drag Tree** (30 characters max, must be unique on the store. If taken, try
     *Drag Tree - Reaction Trainer*)
   - Primary language: English (U.K.) or English (U.S.)
   - Bundle ID: pick **com.johnhutch123.DragTree** from the list
   - SKU: anything private to you, e.g. `DRAGTREE001`
   - User access: Full access
2. **EU trader status** (required to sell in the EU): App Store Connect > **Business** >
   your account > *Digital Services Act*. As a hobbyist giving away a free app you can declare
   yourself **not a trader**. If you declare yourself a trader, your address and phone number
   are shown publicly on the EU store page. If you skip this, the app won't appear in EU countries.
3. **Agreements:** a free app only needs the *Free Apps Agreement*, which is accepted when you
   join. Banking and tax forms are only needed for paid apps or in-app purchases.

## 4. Clean up the project settings (once)

In **Project > Options**, configuration **Release**, platform **iOS Device 64-bit**.

1. **Application > Version Info:**
   - `CFBundleIdentifier` = `com.johnhutch123.DragTree` (already set). **Never change it**
     after the first upload.
   - `CFBundleDisplayName` = `Drag Tree` (already set).
   - **Device family: change `iPhoneAndiPad` to `iPhone`.** Recommended for a first release:
     - With iPad support Apple requires **13-inch iPad screenshots** as well, and the reviewer
       tests on an iPad.
     - The app is portrait only. On iPad that triggers upload error *ITMS-90474 "iPad
       Multitasking support requires these orientations"*.
     - An iPhone-only app still installs on iPads (in an iPhone-sized window), so nobody is
       locked out. You can add proper iPad support in a later update.
   - `ITSAppUsesNonExemptEncryption` = `false` is already set. That answers Apple's export
     compliance question for you (the app uses no encryption), so leave it.
   - Leave `UIBackgroundModes` empty.
2. **Application > Icons:** replace the Delphi flame icons with the Drag Tree set, as listed in
   `Icons/README.md` (iOS section). The **1024 x 1024 App Store** icon is the important one:
   App Store Connect takes the store icon from the build, and an upload without it is rejected
   (*"Missing required icon file"*). It must have no transparency, which ours doesn't.
3. **Application > Launch screen:** Delphi uses the storyboard in `LaunchScreen.TemplateiOS`.
   Set the background colour to dark (black or `#101418`) so the launch matches the tree
   screen. A launch screen is required; an empty dark one is fine.
4. **Application > Orientation:** Portrait only (already set).
5. **Application > Entitlement List:** untick everything. Drag Tree needs no iCloud, push,
   Game Center etc.
6. **Version Info, usage descriptions:** the iOS keys contain no `NS...UsageDescription`
   entries (camera, location...), which is right, because the app uses none. Don't add any:
   Apple asks you to justify each one.

### Version numbers

| Key | What it is | Rule |
| --- | --- | --- |
| `CFBundleShortVersionString` | Version users see, e.g. `1.0.0` | Bump it for each App Store release (`1.0.1`, `1.1.0`) |
| `CFBundleVersion` | Build number | Must go **up for every upload** within the same version. Apple refuses a build number it has seen |

The Release config already has *Auto increment build number* ticked, which raises
`CFBundleVersion` on each build. That's fine. If you'd rather control it, untick it and set
`1`, `2`, `3`... by hand. Start at `CFBundleShortVersionString=1.0.0`.

### Privacy manifest (only if Apple emails you about it)

After uploading, Apple may email a warning *ITMS-91053: Missing API declaration*. Delphi's
runtime uses some "required reason" APIs (file dates, boot time for the stopwatch, free disk
space). The repo includes a ready-made `PrivacyInfo.xcprivacy` declaring them, with
**no data collected and no tracking**. If you get the email:

1. Project > **Deployment** (Deployment Manager), platform **iOS Device 64-bit**, config Release.
2. **Add Files** > `PrivacyInfo.xcprivacy`. Set **Remote Path** to `.\` so it lands in the root
   of the app bundle.
3. Raise the build number and upload again.

So far these emails have been warnings rather than rejections for the app's own code.

## 5. Build and upload

### Build the .ipa

1. PAServer running on the Mac, Xcode closed.
2. Project > Options > **Deployment > Provisioning**, target iOS Device 64-bit, build type
   **iOS Device 64-bit - Application Store**:
   - Team: your team ID
   - Certificate: `Apple Distribution: John …`
   - Provisioning profile: `DragTree Store`
3. Projects panel: **Build Configurations > Release** (double-click), then **Target Platforms >
   iOS Device 64-bit** (double-click), then **iOS Device 64-bit > Configuration > Application
   Store** (double-click).
4. **Project > Clean**, then **Project > Deploy DragTree**. The first time, the Mac asks to let
   PAServer use your private key: click **Always Allow**.
5. The file is copied back to the PC as `iOSDevice64\Release\DragTree.ipa` in the project folder.
   A copy also sits on the Mac in PAServer's `scratch-dir` folder (in your home folder, under
   `PAServer`).

Note: don't make an `.ipa` by zipping the `.app` yourself. That doesn't work; only the
Application Store build does it properly.

### Upload with Transporter

1. On the Mac install **Transporter** from the Mac App Store (free, made by Apple).
2. Sign in with your developer Apple ID.
3. Get the `.ipa` onto the Mac (scratch-dir copy, or AirDrop / USB / shared folder from the PC)
   and drag it into Transporter.
4. Click **Deliver**. Transporter checks the file first; most mistakes (icons, bundle ID, build
   number, SDK) show here.
5. After about 5 to 30 minutes the build appears in App Store Connect > your app >
   **TestFlight**, first as *Processing*. Apple emails you if it finds a problem.

## 6. TestFlight

TestFlight is Apple's beta app. Use it to check the store-signed build before the public sees it.

1. App Store Connect > your app > **TestFlight**.
2. Export compliance: because `ITSAppUsesNonExemptEncryption=false` is set, it won't ask.
3. **Internal Testing > +** > create a group (e.g. "Me"), add yourself (and anyone on your
   developer team). Internal testing needs **no review** and is ready in minutes.
4. On the iPhone install **TestFlight** from the App Store, open the invite email, install
   Drag Tree.
5. Run through everything: Pro and Sportsman trees, staging, the pedals with multi-touch, the
   Settings screen, history, reopening the app.
6. Optional **External Testing** (friends, racing club, up to 10,000 people by email or a
   public link). The first external build gets a short Beta App Review, usually under a day.

TestFlight builds expire after 90 days. Not required before release, but strongly recommended.

## 7. The App Store page

App Store Connect > your app > **Distribution** tab.

### Version page (iOS App 1.0)

| Item | Requirement | For Drag Tree |
| --- | --- | --- |
| **Screenshots** | PNG or JPEG, no transparency, up to 10. At least one for the size App Store Connect marks as required (currently the iPhone with Dynamic Island: **1179 x 2556** or **1206 x 2622** portrait). Smaller iPhones are scaled from it | 3 to 5 shots: staged and waiting, mid-countdown, a result with reaction time, red light, Settings |
| Promotional text | 170 characters, can change any time without review | e.g. *Sharpen your launch: Pro and Sportsman trees with real pedal controls.* |
| Description | 4000 characters | Adapt the "How it works" section of the README |
| Keywords | 100 characters, comma separated, no spaces needed | `drag,racing,tree,reaction,timer,launch,bracket,christmas tree,practice,sportsman` |
| Support URL | Required, public web page | `https://github.com/JohnHutch123/DragRaceTimingLights` (or its Issues page) |
| Marketing URL | Optional | Leave empty |
| Version / Copyright | | `1.0.0` / `2026 John Hutchings` |
| **Build** | Pick the build uploaded in step 5 | |

**Taking screenshots:**
- Easiest: on an iPhone 15, 16 or 17 (not Plus/Max), press side button + volume up. They
  come out at exactly the required size. AirDrop them to the Mac.
- Or run in the **iOS Simulator** (Delphi target *iOS Simulator ARM 64-bit*, simulator set to
  iPhone 17) and press **Cmd+S**.
- Avoid NHRA and other trademarked names or logos in the name, icon, keywords and screenshots.
  Apple rejects apps for using other brands (guideline 5.2).

### App Information (left menu, General)

| Item | For Drag Tree |
| --- | --- |
| Subtitle (30 characters) | *Drag racing reaction trainer* |
| Category | Primary **Sports**, secondary **Utilities** (optional) |
| Content rights | No, it doesn't contain third-party content |
| **Age rating** | Fill in the questionnaire: answer *None / No* to everything (violence, gambling, web access, user content, contests...). Result: **4+** |

### App Privacy (left menu, Trust & Safety)

1. **Privacy Policy URL** (required):
   `https://github.com/JohnHutch123/DragRaceTimingLights/blob/main/docs/privacy-policy.md`
   (the same one used for Google Play).
2. **Data collection** > Get Started > *Do you or your third-party partners collect data from
   this app?* **No, we do not collect data from this app.** > Publish.
   The store then shows **"Data Not Collected"**. True because settings stay in `DragTree.ini`
   on the phone and the app has no internet access.

If you ever add anything online (leaderboards, analytics, ads), update this before that version
ships.

### Pricing and Availability

- Price: **Free** (USD 0.00). Unlike Google Play, you can change between free and paid later.
- Availability: all countries, or pick some. EU countries need the trader status from step 3.

## 8. Submit for review

1. Back on the **iOS App 1.0** version page, fill in **App Review Information**:
   - Sign-in required: **No**.
   - Contact: your name, phone, email (only Apple sees these).
   - **Notes** (this helps a lot, because reviewers don't know drag racing): e.g.
     *"Practice tool for drag racing starts. Press START, then hold the BRAKE pad at the
     bottom of the screen. When both cars are staged the lights count down; release BRAKE
     when the green shows. Your reaction time is shown at the top. The Settings button
     switches Pro/Sportsman tree, lane, staging and pedal options. Works offline, no account."*
2. **Version Release:** *Manually release this version* (you press the button once approved)
   or *Automatically release*.
3. Click **Add for Review**, then **Submit to App Review**.
4. Status goes *Waiting for Review* > *In Review* > **Pending Developer Release** or **Ready for
   Distribution**. Most apps are reviewed within 24 to 48 hours.
5. Once live, search can take a few hours to find it. The direct link is in App Store Connect
   under App Information > *View on App Store*.

## 9. Every update after that

1. Change code, test on your phone.
2. Bump `CFBundleShortVersionString` (e.g. `1.0.1`) and make sure `CFBundleVersion` went up.
3. Application Store build, Deploy, Transporter (step 5).
4. App Store Connect > **+** next to iOS App > new version number > *What's New in This Version*
   > pick the build > Submit for review.
5. Each spring Apple raises the minimum SDK (iOS 27 SDK from April 2027). Before then, make
   sure your Delphi version and Xcode are current.
6. Certificates last a year, profiles a year. When they expire, existing App Store installs
   keep working; you just need new ones to upload. Renew as in step 2.

## Common rejections and problems

| Problem | Fix |
| --- | --- |
| ITMS-90725 "SDK version issue" | Built with too old an SDK. Build with Delphi 13.2 and the Xcode 27 SDK (step 1) |
| "Missing required icon file" / no 1024 icon | Assign the iOS icons, especially App Store 1024 (step 4) |
| ITMS-90474 iPad multitasking orientations | Set device family to iPhone only (step 4) |
| "The bundle version must be higher than the previously uploaded version" | Raise `CFBundleVersion` |
| "No suitable application records were found" | Bundle ID in Version Info doesn't match the App Store Connect record (step 3) |
| Certificate / profile lists empty in Provisioning | Private key missing or profile not downloaded. Step 2 and setup guide Troubleshooting |
| "Invalid Code Signing Entitlements" | Untick everything in Entitlement List, rebuild |
| ITMS-91053 email | Add `PrivacyInfo.xcprivacy` (step 4) |
| Guideline 4.2 "Minimum functionality" | Rare for a working trainer, but make sure the review notes explain how to use it (step 8) |
| Guideline 2.1 crash on iPad | The reviewer ran the iPhone app on an iPad. Test it in an iPad simulator before submitting |
| Guideline 5.2 intellectual property | Remove NHRA or other brand names / logos |

## Sources (checked 26 October 2026)

- [Apple: SDK minimum requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Apple: App Store submissions open for iOS 27, iOS 27 SDK required from April 2027](https://www.mactech.com/2026/09/10/app-store-submissions-now-open-for-the-latest-os-releases/amp/)
- [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Embarcadero: Deploying your iOS application for submission to the App Store](https://docwiki.embarcadero.com/RADStudio/en/Deploying_Your_iOS_Application_for_Submission_to_the_App_Store)
- [Delphi-PRAXiS: iOS app to TestFlight and Transporter](https://en.delphipraxis.net/topic/12081-ios-application-to-test-flight-and-transporter)
- [Delphi-PRAXiS: ITMS-91053 missing API declaration](https://www.delphipraxis.net/214874-ios-ab-1-mai-itms-91053-missing-api-declaration.html)
