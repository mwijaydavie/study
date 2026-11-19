# Mwijay’s StudyDesk · Flutter build prompts

**Personal app first:** UAUT BIT Year 2, Dar es Salaam time, offline by default. Keep the existing PWA working. No multi-student onboarding, Google/Firebase setup, campus feed, admissions work or public rollout in these phases. The [UAUT Connect pilot](uaut-connect-roadmap.md) is parked until Mwijay wants to revisit it.

**How to use this list:** Say **“next”** or **“go on”**. Work on the first unfinished phase, not the whole list. First read this file and the current `mobile/` project. Close each turn with what changed, what was tested on a real phone versus only in mocks, and what is still blocked. Do not mark a phone check done without that test.

- [x] **1 · Flutter foundation source:** keep the yellow timetable, dark Up Next, Day/Week, study plan and course folders from the PWA. Add Settings to the bottom bar and bundle offline assets. Include Android/iOS projects and the StudyDesk launcher icon.
- [x] **1 · Build and automated checks:** PR #2 merged; the [GitHub debug APK build](../mobile/README.md#android-17-and-apk-from-github) passed for `0.4.0+4`.
- [ ] **1 · Device check (next):** install on Mwijay’s Android 17 phone and report the [airplane-mode smoke test](../mobile/README.md#phase-1-phone-check). No real-device result yet.
- [x] **2 · Android class notification source:** opt-in, confirmed single dates, lead times, pending, edit/cancel, tests and notification taps.
- [ ] **2 · Android device check:** [permissions, airplane mode/lock screen, cancellation and reboot](../mobile/README.md#phase-2-android-reminder-check) on Mwijay’s phone.
- [x] **3 · Android campus events source:** manual offline book, regular event notifications and optional Calendar editor / `.ics` export.
- [ ] **3 · Android device check:** [offline edits/cancellation, calendar import in two time zones, and background alert](../mobile/README.md#phase-3-android-campus-events-check).
- [x] **Personal documents prep:** Android **Materials → My files**, private offline PDF/Word/PowerPoint import, open/share/remove. [Cloudinary upload handoff](cloudinary-documents.md) is planned; no live service.
- [ ] **Android 17 My files and update check:** use [dummy documents](../mobile/README.md#my-files--android-17-phone-check). Set up a persistent test signing key and verify a same-key update before relying on in-app storage.
- [ ] **4 · Optional stronger alarms**
- [ ] **5 · Private TZS budget**
- [x] **6 · Offline Coach source:** personal spoken welcomes, manual EAT study log and cited FN200 practice. [Build notes and phone check](../mobile/README.md#spoken-welcome-and-study-coach-0606).
- [ ] **6 · Study Coach phone check and opt-in online AI:** [owner-only setup](study-coach-ai.md). Online model is not configured.
- [ ] **7 · Personal release and update check**

## 2 · Local class notifications

**Current Android implementation:** one notification per confirmed date within 14 EAT days, plus immediate and delayed test actions. Kotlin build-stub/JVM and static source checks do not replace an Android install. Record the phone’s Android version and run both phone checks before depending on this feature.

> Continue my personal Flutter app. Ask whether I use Android or iPhone, and its OS version, if unknown. Finish or document the Phase 1 build/device gate first. Add **Class reminders** in Settings and a reminder option in class details. Default to Off; let me pick sessions and a lead time (5, 15, 30 or 60 minutes), test one notification, and see what is pending. Tapping a delivered notification should open the related class details where possible.
>
> Use normal, on-device scheduled notifications; no server, calendar access, background polling, full-screen UI, or exact-alarm permission in this phase. Ask for notification permission only when I opt in. Differentiate Off, denied, restricted, and active; give a path to system settings without looping prompts. Keep the timetable usable even when the plugin fails or permission is revoked. Explain that notification settings, Do Not Disturb/Focus, power restrictions and force stop can affect delivery.
>
> Separate the scheduler and permission adapter from the UI. Compute each occurrence in `Africa/Dar_es_Salaam` and convert to a real instant; do not pass Phase 1’s shifted UTC wall time straight to the OS. The bundled timetable is a revised draft with no teaching term end date. Require a confirmed date or explicitly confirmed teaching window before scheduling; never repeat it forever. Show dated times and the source. Use stable IDs by occurrence, a bounded horizon within platform pending limits, and reconcile on resume, settings edit, and timetable revision. Cancel old IDs when a session is unselected, rescheduled or outside the confirmed window. Document what gets re-armed after reboot and what needs the app reopened.
>
> **Done when:** tests cover EAT midnight, a phone in another zone, denied permission, edits/cancellation, duplicate prevention and notification taps. On my phone, opt in to a short test alert, lock/background the app in airplane mode, and verify the alert; test disabling it and reopening the app. Report any reboot case that could not be checked. Stop before calendar or alarm integration.

## 3 · Campus events and calendar reminders

**Current Android implementation:** **Settings → Campus events**, local save, optional ordinary Android notifications, and an explicit editor or file handoff. No official feed, Calendar access, two-way sync, or exact alarms. Confirm the result in the Calendar app. Keep the device checks open until the behavior is tested on the phone.

> Add a personal **Campus events** area for seminars, workshops, labs, exams and deadlines. Start with manual entry—no scraping or invented UAUT dates. Save title, start, optional end, all-day option, venue, source/link, notes, and reminder preference offline. Separate upcoming/past, label manual/unconfirmed dates, and validate start/end. Use the Phase 2 scheduler for the app’s own reminder, with edits and deletes reconciling pending alerts.
>
> Provide **Add to device calendar** with a user-confirmed OS handoff or `.ics` export, a stable UID, correct timed EAT conversion, and date-only values for all-day events. Show separately whether the StudyDesk reminder is configured. Marking a calendar date alone does not enable a StudyDesk alert. Let me confirm a calendar alert in my Calendar app where supported. Do not request access to my full calendar by default, imply two-way sync, or claim an event was added if the handoff gives no confirmation. Warn that edits/deletes in StudyDesk do not change an exported calendar event automatically.
>
> **Done when:** add, edit and delete work offline; replacing a reminder leaves no stale notification; timed and all-day examples import correctly on my phone, including with a different device zone. Test a canceled/denied handoff and one app alert while backgrounded in airplane mode. No official campus feed or scraping yet.

## 4 · Optional stronger alarms

> Add stronger alerts only for events I explicitly select (for example an exam or an early lecture). Start by checking current platform policies, my actual OS version and the needed permissions. Clearly separate a regular notification, a precise delivery time, and a ringing clock alarm; they are not interchangeable.
>
> On Android, prefer a confirmed handoff to the phone’s Clock where it fits, or document and justify an app-managed exact alarm only if the device and policy allow it. Don’t request alarm access at launch or full-screen/Do Not Disturb privileges by default. If precision access is denied or revoked, label and use the Phase 2 fallback when available; never show “alarm set” as a guarantee. On iOS, check the version’s supported APIs and available entitlements first. If a true alarm is unavailable, keep the local notification and offer instructions for setting a Clock alarm manually. Do not claim Focus or silent mode is bypassed. Make it easy to cancel a pending app-managed alarm; for an external Clock handoff explain how to edit or cancel it there without creating duplicates.
>
> **Done when:** test an opt-in alert on my phone with screen locked and airplane mode on, then cancel it and verify it does not ring. Check permission denial/revocation and the fallback. Document reboot, Focus/Do Not Disturb, force-stop and battery behavior separately from what was tested. If the OS doesn’t support the intended alarm, deliver the honest fallback and stop.

## 5 · Private TZS budget

> Add a small **Budget** area inside my workspace or Settings without changing the timetable tab. Keep it separate from my FN200 course. Start with a monthly TZS target and manually entered expenses for transport, meals, data, books and Other. Validate whole shilling amounts and real dates. Support edit/delete and show monthly spend, remaining amount and category totals using EAT month boundaries. Use a private local store with a versioned schema and document what OS backup will or won’t do. No bank/M-Pesa connection, SMS access, analytics, AI calls or cloud sync. If I request CSV export, preview exactly what leaves the app and confirm before sharing.
>
> **Done when:** I can add/edit/delete entries offline and data survives a restart; totals reconcile in EAT, including across two months and with large amounts; bad values remain unsaved. Test storage and any approved export with dummy data only. Keep private spending out of logs, the repo and AI requests.

## 6 · Offline study helper and opt-in AI

> Start with deterministic **Leo**, **Kesho**, and **Next class** shortcuts from the same schedule used by Timetable, with EAT, source/status labels and explicit no-class and stale-draft states. These must work without a model, account or internet. Then, only if I approve online AI, offer **Explain in Kiswahili/English** and short recall quizzes from selected approved guide text. Before sending anything, show what text will leave the phone, where it goes, and allow me to decline. Keep keys on a backend with authentication, quotas and budget limits; do not put API secrets in Git or the app. Do not send my ID, budget, private PDFs, calendar or unrelated notes. Label generated text, cite real source titles/pages or say the guide doesn’t cover it. Never let AI invent schedule details, campus notices or assignment deadlines, or modify those records.
>
> **Done when:** offline Leo/Kesho match Timetable in EAT; declining consent sends no request; request tests exclude personal data; the tool handles loss of connectivity and quota failures without blocking guides. A study answer links to a real source or clearly says it lacks one. No public AI launch.

## 7 · Personal release and update check

> Prepare one installable build for my phone. Keep the app name, icon and package ID stable. Agree on signing locally and don’t ask me to put keys in chat or the repo. Check notifications/calendars/alarms actually supported on this phone, high text scaling and back/dismiss behavior. Document updating a bundled timetable, preserving local data across an in-place app upgrade, what uninstall/clear-data does and which OS restrictions I need to recheck on a new phone. No store release or public distribution without my approval.
>
> **Done when:** install on my exact OS, reopen offline after force-closing, verify one class notification and one campus event end-to-end, and install an update over the same app ID/signing identity without losing settings or private data. Check corrections remove stale reminders and confirm the app never treats a draft as an official schedule.
