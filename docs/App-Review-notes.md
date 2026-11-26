# Drag Tree: answering Apple's App Review request

Apple asked for six things in the **Notes** box of **App Review Information**.
Part A is the text for the Notes box (items 2 to 6). Part B is how to make the
screen recording (item 1). Part C is how to attach it and resubmit.

This text describes version **1.0** (the build you submitted on 17 November).
If you upload and submit the 1.1 build instead, use the extra 1.1 line at the end of Part A.

---

## Part A: text to paste into Notes

Copy everything between the two lines. It is about 3,100 characters, under Apple's 4,000 limit.

---

1. SCREEN RECORDING
A screen recording made on an iPhone running the latest iOS is attached to this submission. It starts with launching the app and shows a typical session: settings, staging, the start tree, a reaction time, a red light and the run history. The app has no accounts, no user-generated content and no paid content, so there are no login, deletion, reporting or purchase flows to show.

2. PURPOSE AND TARGET AUDIENCE
Drag Tree is a reaction-time trainer for drag racers. Every drag race starts with a "Christmas tree" of lights: amber lights, then green. The driver who reacts fastest to the green gains time, and a driver who leaves before the green gets a red light and loses. Racers normally can only practise this at the track, which costs money and gives only a few runs a day. Drag Tree simulates the start tree on the phone with realistic Pro and Sportsman tree timing, staging beams and on-screen pedal pads, and shows the reaction time to a thousandth of a second, with a history of runs and best and average times. It is for amateur, club and bracket drag racers and motorsport fans who want to sharpen their starts. It is a practice tool only and does not connect to or control any vehicle.

3. HOW TO USE THE APP
No account, login, setup or sample files are needed. Everything works offline from the first launch.
- Open the app. The light tree is at the top, the staging view of the two cars is under it, and the BRAKE pad is at the bottom.
- Tap START. Both cars roll up to the start line and the pre-stage and stage bulbs light.
- Touch and hold the BRAKE pad. After a short random wait the tree lights: ambers, then green.
- Lift your finger off BRAKE as soon as green lights. Your reaction time appears (for example 0.034). Lifting before green shows a red light.
- Each run is added to the History list with best and average times. STOP aborts a run, RESET clears the lights, CLEAR wipes the history.
- SETTINGS (tap Done to close) changes: Tree (Pro or Sportsman), Lane (Left or Right), Staging (Auto or Manual), Transmission (Auto, or Manual which adds a CLUTCH pad) and Throttle (Auto, or Manual which adds a THROTTLE pad). The default settings need only the BRAKE pad and are the easiest way to review the app. Settings are saved on the device only.

4. EXTERNAL SERVICES
None. The app makes no network connections and uses no external services, data providers, authentication, payment processors, advertising, analytics or AI services. It is built with Embarcadero Delphi (FireMonkey), a development tool that is compiled into the app and does not contact any service.

5. REGIONAL DIFFERENCES
None. The app works the same in every region and country, with the same features and content. It does not use location and has no region-specific content.

6. REGULATED INDUSTRY OR THIRD-PARTY MATERIAL
Not applicable. The app is not in a regulated industry (no gambling, health, financial or similar services) and contains no protected third-party material. All graphics are drawn by the app's own code, the icon was made by the developer, and there are no third-party logos, trademarks, music or videos.

---

**Only if you submit the 1.1 build:** add this line at the end of section 3:

`- Version 1.1 adds to SETTINGS: Tree speed (standard or faster/slower amber timing), Start delay (Normal or Quick) and Handicap (dial-in) bracket racing, where you type an expected run time for each lane and the slower car gets its green first.`

---

## Part B: making the screen recording on your iPhone

**Before you start**

1. Update the iPhone: **Settings > General > Software Update**, install anything offered. Apple wants the latest iOS.
2. Put the same build you are submitting on the phone. The simplest way is **TestFlight**: in App Store Connect open the app > **TestFlight**, add yourself as an internal tester, install the TestFlight app on the iPhone and install Drag Tree from it. (Running the app on the phone from Delphi also works, as long as it is the same version.)
3. Turn on **Do Not Disturb** (swipe down from the top-right corner, tap **Focus**) so no messages pop up in the video.
4. Check the Screen Recording button is in Control Centre: swipe down from the top-right corner. If you can't see a round button with a dot in a circle, tap **+** at the top left > **Add a Control** > search **Screen Recording** and tap it.

**Record (about 1 to 2 minutes)**

1. Go to the **Home Screen**, where the Drag Tree icon is.
2. Swipe down from the top-right corner, tap the **Screen Recording** button, and wait for the 3-second countdown. Swipe back up to close Control Centre.
3. Tap the **Drag Tree** icon to launch the app (Apple wants the video to start with this).
4. Tap **Settings**. Tap through the options slowly so each one is visible, then set them back to the defaults (or leave Transmission and Throttle on Auto). Tap **Done**.
5. Tap **Start**, hold **BRAKE**, wait for the tree, lift off on green. Pause a second on the reaction time.
6. Tap **Reset**, then do two or three more runs. Make one of them a red light on purpose (lift off early) so the reviewer sees it.
7. Show the **History** list with the times.
8. Optional: turn on Manual transmission in Settings and do one run with the CLUTCH pad, to show the extra pedals.
9. Stop recording: tap the red pill or red clock at the top-left of the screen, then **Stop**.

The video is saved in the **Photos** app. Play it back to check it.

---

## Part C: attaching the video and resubmitting

**Get the video onto your Mac**
- **AirDrop**: in Photos open the video, tap **Share > AirDrop** and choose your Mac. It lands in Downloads.
- Or use iCloud Photos, which syncs it to the Photos app on the Mac.

**Attach it in App Store Connect** (on the Mac, in Safari or Chrome at appstoreconnect.apple.com)
1. **Apps > Drag Tree**, then click the version under **iOS App** on the left (it will say *Rejected*).
2. Scroll down to **App Review Information**.
3. Paste the Part A text into **Notes** (replace what is there).
4. Under **Attachment**, drag the video file in (or click to choose it).
5. Click **Save** at the top right.

If the upload is refused (file too big), upload the video to iCloud Drive or Google Drive, make a share link that anyone can view, and replace the first sentence of section 1 with: `A screen recording made on an iPhone running the latest iOS is at this link: <your link>`.

**Resubmit**
1. Still on the version page, click **Add for Review** (or **Resubmit to App Review**) at the top right, then **Submit**.
2. Optional but helpful: open **App Review** on the left, open the rejection message and reply: *"I have added the requested information to the App Review Notes and attached a screen recording. Thank you."*

Review usually takes one to three days.
