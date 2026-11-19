# StudyDesk for Mwijay · Flutter personal app

A separate, personal app for UAUT BIT Year 2. The yellow planner artwork, dark **Up Next** card, purple Study plan, and green Materials follow the PWA. **Settings** is the fourth bottom tab. The timetable, guides and three generated study files are bundled, so they need no connection, web preview, or sign-in. Day/Week, checklist rollover, class reminders and Campus events use Dar es Salaam time (EAT / UTC+3), not the phone’s configured time zone. Android has opt-in local notifications, an optional Calendar handoff, and a private **Materials → My files** library for your documents. This phase does not change the iOS or web editions.

## Build and run

Install [Flutter](https://docs.flutter.dev/get-started/install) 3.32.8 or a compatible newer stable SDK. The Android and iOS projects and launcher icons are included; don't regenerate over them. Use `flutter doctor` to check the required toolchain:

- **Android:** JDK 17, the Android SDK (including platform 35 for Flutter 3.32.8), and phone with USB debugging or an emulator.
- **iPhone:** macOS, Xcode, CocoaPods, and a simulator or signed device. For a physical phone, open `ios/Runner.xcworkspace` in Xcode and select your team under Runner → Signing & Capabilities. Do not share signing credentials or commit them. The bundle/Android package ID is `tz.altraware.studydesk`.

From the repository root:

```sh
npm run flutter:check   # verifies that the bundled timetable and study files match the PWA
cd mobile
flutter doctor
flutter pub get        # first setup needs internet; running the installed app does not
flutter analyze
flutter test
flutter devices
flutter run            # add -d <device-id> if there is more than one device
```

To build an Android test APK, run `flutter build apk --debug` in `mobile/`. It writes `build/app/outputs/flutter-apk/app-debug.apk`. Install on a connected test phone with `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. A debug APK is for testing, not a signed release; installing over an existing test build requires the same signing key. Uninstalling or clearing app data erases local document copies, events, checklist, preferences and pending notifications. Files outside the app and separate Calendar copies are not removed.

The native reminder, calendar and document tests can be run after the debug build creates the Gradle wrapper: `cd android && ./gradlew :app:testDebugUnitTest` (Windows: `gradlew.bat :app:testDebugUnitTest`).

## Android 17 and APK from GitHub

The target phone is **Android 17 (API 37)**. This build still uses the pinned Flutter 3.32.8 / Android SDK 35 toolchain; compiling against new APIs and opting into a higher target SDK are separate from testing on the newer OS. The handset has not been tested yet. The APK workflow verifies the APK signature, ARM64 engine presence, ZIP alignment and 16 KiB LOAD-segment alignment of the 64-bit libraries. See Android's [API 37 setup](https://developer.android.com/about/versions/17/setup-sdk) and [page-size checks](https://developer.android.com/guide/practices/page-sizes).

1. Open the PR and wait for **StudyDesk Android checks & APK** to pass before merging. It checks the web build and asset mirrors, runs Flutter analysis/tests, builds the app, runs the Android JVM tests, and checks the APK. No APK is attached on PRs, and no test signing key is read there.
2. After merge, open **Actions → StudyDesk Android checks & APK → Run workflow**, select **main**, and wait for success. Under that run's **Artifacts**, download `studydesk-android-debug` and unzip `StudyDesk-debug.apk` and its SHA-256 checksum. The artifact expires in seven days. Download from your own repository's Actions run. This repo is public: an Actions artifact is **not private distribution**. The APK only bundles curated assets, not the personal files you add on your phone.
3. Install the debug test APK on Android 17 (for example, `adb install -r StudyDesk-debug.apk` on an authorized device), then follow the four checklists below with dummy files. This is a **debug APK**, not a production/store release. If Android disallows the installer, use a trusted workstation with authorized USB debugging; don't uninstall just to bypass a failed update.

### Keep updates compatible before storing real documents

A GitHub-hosted runner's default debug key can change on each run. Android will reject an in-place update signed with a different key. If this is only a first smoke install, use dummy data. Before depending on updates, keep `tz.altraware.studydesk`, use the **same signing key**, and increase the build number (`+4` in this version) for future versions. Back up your originals outside StudyDesk; reinstalling is not an update.

For stable personal **test** builds, choose one debug keystore (the same one that signed any build you need to update). If starting fresh, you can generate a test-only key locally, outside the repo:

```sh
keytool -genkeypair -keystore "$HOME/studydesk-test.jks" -storetype JKS \
  -alias androiddebugkey -storepass android -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=StudyDesk Test'
base64 < "$HOME/studydesk-test.jks" | tr -d '\n' | gh secret set STUDYDESK_TEST_DEBUG_KEYSTORE_B64 --repo mwijaydavie/study
```

`android` is the conventional **debug** key password, not a release password. Set the secret from your own machine or GitHub repository settings and keep the private keystore backed up securely. Never commit it, send it in chat, or reuse a release key here. Only the manual main build uses the secret if configured. No CI key is configured by the source change. Compare the APK signing certificate fingerprints in the Actions log before installing an update.

**Verification status:** The Kotlin Android bridges were compiled with API 35 and Flutter/AndroidX signatures, and the pure Kotlin payload/storage rules were checked on the JVM. The workspace does not have a complete Flutter/Android SDK or a connected phone. Flutter analysis/tests, the hosted workflow and its APK alignment checks on a real build, and device checks on Android 17 are still open. The PWA build and web tests pass separately.

## Phase 1 phone check

1. Launch in airplane mode. Select Thursday and confirm **08:00 IS237 practical (Computer Lab)** and **11:00 FN200 lecture (BH301)**. Flip Day/Week, open a detail sheet, and confirm **Up Next** uses EAT even if you temporarily change the phone's time zone. The timetable is a revised draft, not a live university feed.
2. In Settings, turn off **24-hour time** and turn on **Open Week view by default**. Return to Timetable, then force-close and reopen; both choices should remain.
3. Tick a study block, reopen offline, then clear the current week using the Settings confirmation. A different EAT study week starts empty.
4. Search Materials, read a guide, and share the bundled timetable PDF to Files or an installed reader. Dismissing the share sheet should not claim the file was saved.
5. Try increased text size and Android back/dismiss behavior. Check there is **no notification permission prompt on launch**.

## Phase 2 Android reminder check

1. Open **Settings → Class reminders** (or **Timetable → class details → Set class reminder**). No reminders are created automatically. Add a class, confirm a date with UAUT within the next 14 campus days, and choose 5 / 15 / 30 / 60 minutes before. On **Android 13+**, the first explicit save or test may ask for notification permission. On earlier Android versions there is no runtime dialog; check system notification settings if delivery is blocked.
2. On a fresh Android 13+ test install, try **Don’t allow** first. Verify nothing is scheduled, the timetable still opens offline, and **Open Android settings** lets you enable notifications without repeated permission prompts. Then use **Send test now** in airplane mode. Check the notification shade (a banner or sound can be suppressed by system settings).
3. Tap **Schedule lock-screen test**, let the app go to the background, and lock the phone while still offline. Target is one minute away, **not an exact delivery promise**. Check when it actually arrives and record device model, Android version, battery mode and Do Not Disturb state. If you don’t receive it, check the channel/lock-screen settings; a foreground test alone does not verify scheduling while locked.
4. Set one real class reminder after confirming its date. **Pending reminders** shows its EAT target. Edit the lead time; there should still be one entry for that date. Tap a delivered class notification and confirm it opens that dated class. Use **Remove** or **Turn off class & test reminders** and make sure cancelled reminders do not appear later. This does not change Campus events. With a different phone timezone, the app still labels the time in EAT (e.g. an 08:00 EAT class targeted 15 minutes early is 07:45 EAT / 04:45 UTC).
5. For the reboot check, set a confirmed reminder comfortably in the future, reboot and unlock **before its target**, then see if it arrives without opening StudyDesk. Repeat with a new future reminder and reopen the app after an Android **Force stop** to verify re-arming. Don't count an expired notification or a test pushed while the app is open as proof of reboot delivery.

### What Android can and can’t guarantee

- The notification scheduler is on-device and needs no account, network, calendar permission, exact-alarm access or full-screen alerts. The system uses an **inexact** notification target; Android can delay it because of batching, Doze or device battery controls. Class notices are dropped after the class starts. The delayed test expires one hour after its target. The pending list is StudyDesk’s saved requests, not a promise of OS delivery.
- On a normal reboot the boot receiver tries to restore future requests after first unlock for the same app build. Restricted battery mode, force stop or manufacturer settings can prevent this. Reopen StudyDesk to reconcile and re-arm still-future targets. Do Not Disturb and lock-screen privacy still apply. Android 5–6 may not report notification blocking reliably in-app; system settings are authoritative.
- After an app update, open StudyDesk again: no old build’s requests can post before StudyDesk reviews the timetable and event book. Unchanged future requests can be re-armed; a removed, moved or revised class needs a new date confirmation. Nothing repeats indefinitely. A manual change to the device’s actual clock (not just timezone) can affect when Android dispatches.

## Phase 3 Android campus events check

Go to **Settings → Campus events**. Add your own seminar, workshop, lab, exam, deadline or other date. A personal checkmark is not university verification. Dates are manual, not a feed. Event records (up to 100) and private notes are stored on the phone; there is no StudyDesk account or cloud sync. Android backup is disabled for this build, but device-to-device transfer behavior can depend on the manufacturer.

1. In airplane mode, add a timed test event and a one- or two-day all-day test event. Enter the venue, source, HTTPS link and notes. Make sure a timed end at/before the start or an earlier all-day end cannot be saved. Confirm both **Upcoming & ongoing** and **Past** (also add a dummy dated yesterday). Reopen the app; verify fields persist, then edit and delete one dummy entry without a connection.
2. Leave the StudyDesk notification **Off** at first. Adding an event or sending it to Calendar must not by itself enable a StudyDesk alert. Then opt in for a timed event. If Android denies or blocks notifications, the event and preference should remain, but no alert is shown as pending. Enable notifications in Android settings, return, and look for a pending EAT target. Only future targets within 365 days can be queued, up to 32 event requests independently of classes. Reopening StudyDesk or **Refresh Android status** retries eligible saved preferences without a permission prompt. All-day StudyDesk alerts target **09:00 EAT on the first day** and expire at EAT midnight; timed alerts expire at the event start.
3. Edit a future alert to a different time, verify only the replacement target, and watch that the old target does not post. For another dummy event, turn its notification off or delete the event and check cancellation. Leave one eligible event in the background with the phone locked in airplane mode; record target and actual arrival, then tap it to open that event. For a short test, schedule an event about 30 minutes from now with a 15-minute lead (inexact delivery can still be late or skipped). Check that class reminders are unaffected. Use the separate Phase 2 checks for reboot and battery behavior.
4. Change the device zone to a non-EAT zone, e.g. America/Los_Angeles. From event details, use **Add to device calendar** for one timed and one all-day event (or **Share .ics** and import in a Calendar app that accepts the file). For example, on a dummy date in late November (PST), **08:00 EAT = 05:00 UTC = 21:00 the previous day in Los Angeles**. Check that the timed event represents the same instant, and the all-day example retains its selected date(s) regardless of zone. An optional last day in StudyDesk is inclusive; the export end is the next date (exclusive). Calendar apps differ; inspect the draft before saving and try `.ics` if the editor interprets dates differently.
5. Cancel a handoff in StudyDesk and cancel/discard one in Calendar; test no editor or declined Calendar permission if practical. StudyDesk does not claim a Calendar save. A handoff includes only title, date/time and venue, not your notes, source or StudyDesk notification. If you want a Calendar alert, confirm it in the Calendar app where supported. The app may sync the copy to your Calendar account; repeated imports can produce copies. StudyDesk requests no **Read/Write Calendar** permission. Editing or deleting the StudyDesk event does not update an external copy.

**Device check is open.** A pending entry reflects the scheduler’s last check, not guaranteed delivery. Battery restrictions, Do Not Disturb, lock-screen settings and force stop apply to event alerts too. A same-build reboot can re-arm already queued future requests after first unlock; reopen StudyDesk after an update, force stop or a missed boot restoration. No exact alarms or Clock integration are included.

## My files · Android 17 phone check

1. Download a dummy PDF, Word document and PowerPoint file to the device. In airplane mode open **Materials → My files → Add file**. Pick a file in the Android picker and verify the app saves a local copy. Cancel a second pick and check that nothing was created. No all-files, media-library or permanent picker access is requested.
2. Reopen StudyDesk offline and verify each file is still listed. **Open** uses an installed viewer, with only a temporary read grant. Check the fallback when a file type has no viewer. Try a mismatched document and one larger than **20 MiB**; neither should leave a copy. The local limit is 50 files or 200 MiB total, whichever comes first.
3. Cancel **Share copy** and confirm that nothing was sent. Choose **Remove** and verify only the StudyDesk copy disappears, not the original. Repeat with a same-signing-key, higher-build-number APK; confirm the remaining documents, settings and events survive the update.
4. Do the phase 1–3 checks on the same Android 17 phone. Record picker/viewer availability, permission behavior, background alert arrival, Cancel in Calendar, and import with a non-EAT phone time zone. Neither compilation nor alignment checks prove any of that device behavior.

**Cloudinary is not connected.** Local app-private files are excluded from Android backup and standard device transfer rules, but desktop copies you keep and copies shared to other apps are separate. See the [Cloudinary handoff plan](../docs/cloudinary-documents.md) for owner authentication, signed upload and private retrieval. No Firebase, AI or remote uploader is activated by this build.

## Maintain the bundled edition

`src/data/`, `public/art/`, and `public/downloads/` are the shared content sources. After updating them, run `npm run flutter:sync` from the repo root, commit the curated copies under `mobile/assets/` alongside the source changes, and rebuild. Keep the current draft status and page reference explicit. Do not copy original course PDFs, the private profile or personalized covers into the app. No StudyDesk account or cloud sync is configured; device storage and OS backup rules are separate from the app.

The Android/iOS runners are adapted from the [Flutter 3.32.8 templates](https://github.com/flutter/flutter/tree/3.32.8/packages/flutter_tools/templates) under the included [template license](FLUTTER-TEMPLATE-LICENSE.txt). Android’s wrapper scripts, jar and `local.properties` are supplied locally by Flutter tooling. Launcher icons are resized from `public/icons/icon-512.png`. Plus Jakarta Sans is bundled under its [SIL Open Font License](assets/fonts/OFL.txt).

## What to do next

Run the PR checks and test the GitHub APK on Android 17 before relying on notifications, imported documents or in-place updates. The [phase prompts](../docs/mwijay-flutter-next-prompts.md) keep stronger alarms, a private TZS tracker and study AI separate. None of those is activated by this Android update.
