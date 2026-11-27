# Publishing Drag Tree to Google Play (RAD Studio 12 / 13)

Step-by-step guide for getting the Delphi FireMonkey app **Drag Tree**
(`com.johnhutch123.DragTree`) onto the Google Play Store.
Checked against Google's published rules on 21 October 2026.

For setting up the PC, the phone and test runs, see `Android-and-Mac-guide.md` (Chapter 1) first.
This guide starts once the app runs on your phone.

## The short version

1. Pay for a Play Console account (US$25, once) and verify your identity.
2. **Sort out the target SDK first** (step 2). Google now requires API 36 and
   the project is set to 35. This is the one thing that can stop you.
3. Make an upload keystore in RAD Studio and back it up.
4. Build a signed `.aab` (Release, Application Store) and upload it.
5. Fill in the store listing and the "App content" forms.
6. Run a closed test with **12 testers for 14 days in a row** (new personal accounts).
7. Apply for production access, then publish.

Expect about 3 to 4 weeks end to end, mostly waiting for the 14-day test and Google's reviews.

---

## 1. Create the Google Play developer account

1. Go to **play.google.com/console** and sign in with the Google account you want
   to own the app. Use one you will keep for years; moving apps between accounts is a chore.
2. Choose **Personal** account (you, as an individual). An **Organisation** account
   needs a D-U-N-S number but skips the 12-tester rule in step 7.
3. Pay the one-time **US$25** fee.
4. Complete **identity verification** (government ID, and a phone number and
   email that Google checks). Your name and country are shown on the store page.
5. Google may also ask you to verify you own an Android device by installing the
   Play Console app on your phone. Do it when asked.

## 2. Target SDK: needs fixing before upload

**The rule:** since **31 August 2026**, every new app and update for phones must target
**Android 16 (API level 36)** or higher. Google's extension form only runs to
**1 November 2026** and is meant for existing apps, so don't plan on it for a new one.

**The project today:** `targetSdkVersion=35` in Version Info. Play Console will refuse the upload.

**What RAD Studio supports:**

| RAD Studio | Android target it supports | 16 KB page size (see below) |
| --- | --- | --- |
| 12.2 | API 34 | Partly |
| 12.3 (Athens Release 3) | API 35 | Yes |
| 13.1 Florence Update 1 (March 2026) and later | **API 36** | Yes |

Check yours with **Help > About**.

**Your options, best first:**

1. **Upgrade to RAD Studio 13.1 or later.** This is the supported route. Your
   subscription may already cover it. Then:
   - Tools > Manage Platforms > Android: install/update so the SDK includes **API 36**.
   - Project > Options > Application > **Version Info**, target
     *All configurations - Android 64-bit*: set `targetSdkVersion` to **36**.
     Do the same for Android 32-bit.
   - If the IDE offers to update `AndroidManifest.template.xml`, say yes.
2. **Stay on 12.3 and set `targetSdkVersion=36` by hand** (same Version Info key).
   Play only checks the number in the manifest, so the upload may well be accepted,
   but Embarcadero does not support this combination. Test carefully on an
   Android 16 phone, especially that the top and bottom of the screen are not
   hidden: Android 16 forces apps to draw edge to edge with no way to opt out.

Either way, after the change run the full test list in `Android-and-Mac-guide.md` step 1.4 again.

### 16 KB page size

Google also requires apps with native code (all Delphi apps) to support 16 KB memory pages.
RAD Studio 12.3 and later handle this when packaging. After you upload, Play Console shows
any problem under **Test and release > App bundle explorer**. If it says the bundle is not
16 KB compatible, you are on an older RAD Studio and need to update.

## 3. Clean up the project settings (once)

Do these in **Project > Options**, with configuration **Release** and platform
**Android 64-bit**, then repeat for **Android 32-bit**.

1. **Application > Uses Permissions:** new Delphi projects tick a lot of permissions by default
   (camera, location, phone, calendar, storage...). Drag Tree needs none of them.
   **Untick them all.** Every permission you leave on must be explained to Google
   and shows on the store page, and some (location, phone) trigger extra reviews.
2. **Application > Entitlement List:** untick everything (no AdMob, maps, billing, etc.).
3. **Application > Orientation:** Portrait only (already set in code, see `Android-and-Mac-guide.md` step 1.3).
4. **Application > Icons:** replace the Delphi flame icons with the Drag Tree icons.
   Play rejects nothing for the flame, but it looks unfinished.
5. **Application > Version Info:** check `package=com.johnhutch123.DragTree` and
   `label=Drag Tree`. **Never change the package name after the first upload**; it is the
   app's permanent ID on Play.

## 4. Make the upload keystore (once, and back it up)

**What a keystore is:** a small password-protected file (`.keystore`) holding your
private **upload key**. Every `.aab` you send to Google must be signed with it, so Google
knows the upload really came from you. You make it yourself in RAD Studio; Google doesn't
give you one. Make it **once** and use the same file for every future upload.

Google uses **Play App Signing**: Google keeps a separate *app signing key* that signs what
phones install, and your upload key only proves who sent the bundle. On your first upload
Play Console asks about this; accept the default (*Let Google manage and protect your app
signing key*).

### 4a. Create the keystore with keytool (recommended)

RAD Studio's **New Keystore...** wizard has a known bug: on the alias page you can't type the
alias password, so the wizard can't finish. Make the keystore with **keytool** instead. It's
the Java tool Delphi's own wizard runs behind the scenes, and it's already installed with
RAD Studio's Android support.

1. **Find keytool.** In RAD Studio: **Tools > Options > Deployment > SDK Manager**, select your
   Android SDK, open the **Java** tab and copy the **Keytool location**. It's usually something
   like `C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot\bin\keytool.exe`.
2. **Make a folder for keys** outside the project, e.g. `C:\Users\John\Keys`
   (never inside the GitHub folder).
3. **Open Command Prompt** (Start, type `cmd`) and run this, using your own keytool path and
   all on one line:

   ```
   "C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot\bin\keytool.exe" -genkeypair -v -keystore "C:\Users\John\Keys\dragtree-upload.keystore" -alias dragtree -keyalg RSA -keysize 2048 -validity 18250
   ```

   - It asks for a **keystore password** (twice). Typing shows nothing on screen; that's normal.
   - Then your name, organisational unit, organisation (your name is fine), city, state and
     two-letter country code (e.g. `AU`, `GB`, `US`). Type `yes` to confirm.
   - If it asks for a separate key password, press **Enter** to use the same one.
     Newer Java versions always use the keystore password for the key as well.
     **So the keystore password and the alias password are the same.**
   - `-validity 18250` is 50 years (Google needs the key valid until at least 2033).
4. **Check it worked** (optional): run the same keytool path with
   `-list -v -keystore "C:\Users\John\Keys\dragtree-upload.keystore"` and enter the password.
   You should see `Alias name: dragtree`.

### 4b. Select the keystore in RAD Studio

1. Open the project, then **Project > Options > Deployment > Provisioning**.
2. At the top, set **Target** to **All configurations - Android 64-bit platform** and
   **Build Type** to **Android 64-bit - Application Store**. The keystore fields only appear
   for the *Application Store* build type (Development builds use Delphi's debug key).
3. Click **...** next to *KeyStore File* and pick `dragtree-upload.keystore`.
4. Type the **KeyStore Password**, choose the alias **dragtree**, and type the
   **Alias Password**, which is the **same password** as the keystore.
5. Change **Build Type** to **Android 32-bit - Application Store** and repeat steps 3 and 4
   with the same file.
6. Click **Save**.

You can also set the keystore once for every project under
**Tools > Options > Deployment > Provisioning** (Android, Application Store).
Do the same on a new PC: copy the `.keystore` file across and select it as above.

### 4c. Back it up

Copy the `.keystore` file **and both passwords** somewhere safe (password manager plus a
USB stick or cloud drive). If you lose the upload key, Google can reset it from
**Play Console > Test and release > App integrity > Upload key reset**, but it takes a
support request and a few days. You can't recover the passwords from the file.

## 5. Version numbers

Set in Project > Options > Application > **Version Info** (Release, Android 64-bit, and the
same values for Android 32-bit):

| Key | What it is | Rule |
| --- | --- | --- |
| `versionCode` | Whole number Google uses to order builds | Must go **up by at least 1 for every upload**, including test tracks. Play refuses a code it has seen before |
| `versionName` | What users see, e.g. `1.0.0` | Anything you like. Bump it for real releases (`1.0.1`, `1.1.0`) |

The first upload can stay at `versionCode=1`, `versionName=1.0.0`.
You can tick **Auto increment build number**, but setting `versionCode` by hand is clearer.

## 6. Build the signed App Bundle (.aab)

Play only accepts App Bundles (`.aab`) for new apps, not `.apk` files.

1. Project > Options > **Building > Delphi Compiler**, configuration **Release**, platform
   **Android 64-bit**: turn on **Generate Android App Bundle file (arm64 + arm)**.
   This puts both 32-bit and 64-bit code into one bundle.
2. In the **Projects** panel: Target Platforms > **Android 64-bit** (right-click > Activate),
   then expand it > **Configuration > Application Store**, and select **Release**.
3. **Project > Clean**, then **Project > Build**, then **Project > Deploy DragTree**.
4. The bundle is at `Android64\Release\DragTree\bin\DragTree.aab`.

If the build complains about the keystore, recheck step 4 for the *Application Store* build type.
If it says "debuggable", you built Debug or the Development build type; Play rejects those.

## 7. Create the app in Play Console

1. Play Console > **Create app**.
   - App name: **Drag Tree** (up to 30 characters; you could use
     *Drag Tree - Reaction Trainer* if the plain name is taken).
   - **Package name** (if asked): type **`com.johnhutch123.DragTree`** exactly, capital
     D and T included. This is the app's permanent ID on Google Play (Android calls it the
     *application ID*). It isn't something Google gives you: it comes from your Delphi
     project, **Project > Options > Application > Version Info > `package`**, which this
     project sets to `com.johnhutch123.$(MSBuildProjectName)`, i.e.
     `com.johnhutch123.DragTree`. Whatever you type here must match the uploaded `.aab`
     exactly, and it can never be changed after the app is created.
   - Default language: English (United Kingdom or United States).
   - App or game: **App** (or Game; *App* with category **Sports** fits a trainer best).
   - Free or paid: **Free**. You can't switch a free app to paid later.
   - Tick the declarations (policies, US export laws).
2. The **Dashboard** then shows a "Set up your app" list. Work through it (steps 8 and 9).

## 8. Store listing

**Grow users > Store presence > Main store listing.** You need:

| Item | Requirement | For Drag Tree |
| --- | --- | --- |
| App name | 30 characters max | Drag Tree |
| Short description | 80 characters max | e.g. *Practise your drag racing launch on a Pro or Sportsman tree.* |
| Full description | 4000 characters max | Adapt the "How it works" section of the README |
| App icon | 512 x 512 PNG, 32-bit, up to 1 MB | From the app icon set |
| Feature graphic | 1024 x 500 PNG or JPEG | The tree plus the app name on a dark background |
| Phone screenshots | At least 2, PNG or JPEG, 320 to 3840 px per side, 9:16 is ideal | Take them on your phone: the tree mid-countdown, a result with reaction time, the Settings screen |
| Category | | Sports |
| Contact email | Shown publicly | An address you're happy to publish |

Tip: avoid NHRA or other trademarked names and logos in the name, icon and screenshots.

## 9. App content (the policy forms)

**Policy and programmes > App content.** Answers for Drag Tree as it is today (no internet,
no ads, no accounts, settings saved only on the phone):

| Form | Answer |
| --- | --- |
| **Privacy policy** | Required for every app. Use the URL of `docs/privacy-policy.md` in the GitHub repo (public), e.g. `https://github.com/JohnHutch123/DragRaceTimingLights/blob/main/docs/privacy-policy.md` |
| **App access** | All functionality is available without special access |
| **Ads** | No, the app does not contain ads |
| **Content rating** | Fill in the IARC questionnaire: category *Utility, productivity, communication or other* (or *Game* if you chose Game). Answer No to violence, gambling, user content, etc. You'll get an "Everyone / PEGI 3" rating |
| **Target audience** | 13 and over (or 18+). Don't include under-13s; that brings in the stricter Families policy |
| **Data safety** | *Does your app collect or share any required user data types?* **No.** Encryption in transit: not applicable. You can't request deletion because nothing is collected |
| **Government apps / Financial features / Health / News** | No / none |
| **Advertising ID** | No, the app does not use the advertising ID |

If you later add anything online (leaderboards, analytics, ads), these answers must be updated first.

## 10. Testing tracks

### Internal testing (optional, quick sanity check)

**Test and release > Testing > Internal testing.** Up to 100 testers, available within minutes,
no review. Good for checking the Play-signed build installs and runs. It does **not** count
toward the 12-tester rule.

### Closed testing (required for new personal accounts)

Personal accounts created after 13 November 2023 must run a closed test with **at least 12
testers who stay opted in for 14 days in a row** before Production unlocks. A tester who
leaves and rejoins resets their 14 days, so recruit 15 to 20 to be safe.

1. **Test and release > Testing > Closed testing > Create track** (or use the default
   *Alpha* track).
2. **Testers:** add an email list (Gmail / Google accounts of friends, family, racing club
   members) or a Google Group.
3. **Countries:** pick where testers live.
4. **Create release > Upload** the `.aab`. Release name: `1.0.0 (1)`. Release notes: a line
   on what to test.
5. **Review release > Start rollout to Closed testing.** The first review typically takes a
   few days; it can take up to a week.
6. Once approved, copy the **opt-in link** from the track's *Testers* tab and send it to
   everyone. Each tester opens it, taps **Become a tester**, then installs from the Play Store.
7. Keep testers engaged: Google asks how they used the app. Ask them to try all the
   Settings combinations and to report bugs to you. Push an update or two during the
   14 days if you fix things (raise `versionCode` each time).

## 11. Apply for production

After 14 days, **Dashboard > Apply for production** becomes available. Google asks:

1. **About your closed test:** how you recruited testers, how they used the app,
   what feedback you got and how.
2. **About your app:** who it's for (drag racers and bracket racers practising
   their launch), what makes it useful, expected installs in year one (e.g. 0 to 1,000).
3. **Production readiness:** what you changed after testing, and why you think it's ready.

Write a few honest sentences for each; vague answers are the main reason for a "do more
testing" reply. The decision usually takes about **7 days**.

## 12. Release to production

1. **Test and release > Production > Countries / regions:** add the countries you want.
2. **Create new release:** "Add from library" to promote the tested bundle, or upload a new one.
3. **Review release > Start rollout to Production.** Google reviews it (hours to a few days).
   You can choose a **staged rollout** (e.g. 20% of users first) if you like.
4. The app appears on Google Play once approved. Search can take a day or two to find it;
   the direct link is `https://play.google.com/store/apps/details?id=com.johnhutch123.DragTree`.

## 13. Every update after that

For test builds during development (USB installs, Internal testing, Internal app sharing),
see `Testing-updates-guide.md`.

1. Change code, test on the phone.
2. Raise **versionCode** (and versionName) for Android 64-bit **and** 32-bit, Release.
3. Release + Application Store build, Clean, Build, Deploy (step 6).
4. Upload to a testing track or straight to Production, add release notes, roll out.
5. Every August Google raises the required target SDK by one. Each year, check the target
   API page (below) and that your RAD Studio version supports it.

## Common rejections and problems

| Problem | Fix |
| --- | --- |
| "Your app currently targets API level 35..." | Step 2 |
| "Version code 1 has already been used" | Raise `versionCode` (step 5) |
| "You uploaded a debuggable APK/AAB" | Build Release with the **Application Store** build type |
| "You uploaded an APK or bundle signed with the wrong key" | Use the same upload keystore every time. If lost, Play Console > Test and release > App integrity > Request upload key reset |
| "Not 16 KB compatible" | Update RAD Studio (step 2) |
| Rejection for permissions (e.g. location, phone) | Untick unused Uses Permissions (step 3) and upload a new build |
| Missing privacy policy / Data safety | Step 9 |
| Production button greyed out | Closed test not yet 12 testers x 14 days (step 10) |

## Sources (checked 21 October 2026)

- [Target API level requirements for Google Play apps](https://support.google.com/googleplay/android-developer/answer/11926878)
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465)
- [RAD Studio 13 Florence Update 1: Android API 36.1 support](https://blogs.embarcadero.com/announcing-the-availability-of-rad-studio-13-florence-update-1/)
- [RAD Studio 12.3: Android API 35 support](https://blogs.embarcadero.com/rad-studio-12-3-brings-android-api-level-35-support-for-delphi-developers/)
- [Delphi-PRAXiS: Android 16 KB page sizes support](https://en.delphipraxis.net/topic/14434-android-16-kb-page-sizes-support/)
