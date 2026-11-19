# UAUT Connect × StudyDesk — timetable pilot plan

**Decision:** finish Mwijay’s personal StudyDesk first. Then test a small, timetable-only pilot under UAUT Connect, with optional sign-in. Keep admissions, official academic records and the university’s own planned system separate. No cloud project, DNS change, or public launch is part of this plan yet.

## 1. Finish the personal version

- Keep the [personal Flutter build](../mobile/README.md) separate from this pilot. Its [phase checklist](mwijay-flutter-next-prompts.md) starts with offline and real-device checks before adding native class reminders.
- For the web edition, on your phone, open the production PWA directly in the browser, add it to your home screen, then **open it from the home-screen icon while online**. Wait for **Offline ready**. Open in airplane mode and confirm the Day/Week timetable, next session, one guide, timetable PDF and saved checklist still work. Check the day rolls over at midnight in **Dar es Salaam (EAT / UTC+3)** even if the device time zone differs.
- Confirm the BIT Year 2 schedule against the university’s latest version. The current app uses page 2 of the revised draft; it must not silently become the official source. Test an app update once: the older cached release opens immediately; **Update now** switches to the already-cached new release.
- Keep Mwijay’s university ID, personalized covers and original course packs local. For daily use on a phone, use a stable HTTPS deployment; an Arena preview is for testing.

## 2. Public pilot: a timetable, not a new student information system

**Proposed URL:** `timetable.uautconnect.com`. Confirm renewal, DNS control and hosting with the domain owner before making changes. If the existing domain is controlled by the team, a subdomain normally does not require a separate domain purchase.

**Guest flow:** Open → select **Programme** → **Year** → semester if more than one is published → **Leo / This week**. Show rooms, class type, local time, the source and when it was updated. Remember the chosen cohort on that device and make switching easy. An unpublished year gets a clear “Timetable not published yet,” never someone else’s classes.

**Optional account flow:** Offer **Continue with Google** only when the student wants preferences and study progress synced. Sign-in needs a connection; already-saved classes do not. Use Firebase Authentication `uid` to locate the private profile. Mwijay’s Google account can load his own profile; everyone else gets the same cohort picker and a fresh private workspace. Don’t hard-code an email, collect a student ID, or grant editing rights just because an account has a particular domain. On a shared device, sign-out must remove the local private workspace without deleting saved public schedules.

**Approval boundary:** The team says UAUT Connect itself is already approved. Confirm separately who can authorize republishing timetable data and who owns corrections for the pilot. Ask for one approved cohort export and a contact, not approval for a second admissions or grades portal. Publish only approved data; visibly label preview/draft data and keep it in a private preview. If the university launches its own timetable, use its approved feed or link to it and retire any duplicate entry workflow. If permission isn’t granted, keep StudyDesk personal and continue approved campus updates on Connect.

**How to pitch it:** “Tunaomba majaribio ya wiki mbili kwa cohort moja: ratiba iliyoidhinishwa ionekane kwa simu hata bila intaneti. Hatutashughulikia admissions, results, au student records. Ofisi ya ratiba itaidhinisha mabadiliko; mfumo wenu ukiwa tayari, tutatumia chanzo au link mtakayotupa.”

**Pilot exit criteria:** Start with one approved cohort (BIT Year 2 is a good candidate) and 8–15 volunteers through a class rep. Over two teaching weeks, check that first-time guests can find today’s room without an account, repeat users return, saved classes survive airplane mode, and a venue correction published by the owner reaches guests after reconnecting. Do not expand cohorts until someone owns the update process and any wrong-time/wrong-room issues are resolved.

## 3. Firebase design — separate the official data from personal data

| Data | Proposed home | Access |
| --- | --- | --- |
| Public, approved cohort timetable | `publishedSchedules/{cohortTermId}` | Guest-readable. One compact, complete snapshot per cohort/term. Only a trusted publishing backend writes. |
| Staging and previous revisions | Private editor/version collections | Named timetable editors or approvers, using server-assigned roles and an audit trail. Never read as a guest timetable. |
| Personal cohort preference and study progress | `profiles/{uid}` and a task-progress subcollection | The signed-in owner only. Ownership is checked in Firestore Rules, not just UI. Keep owner and publisher roles separate. |

A snapshot should include cohort/programme/year, term, `Africa/Dar_es_Salaam`, effective dates, version, approved source/page, published time, weekly sessions and dated exceptions (e.g. a room change or a holiday). Dates matter: a new term must not silently inherit the last one. Preserve previous revisions so bad changes can be rolled back as a new published version.

**Publishing:** Upload next source privately → create a structured draft → preview a diff of day/time/room/type → check missing rooms, wrong cohorts and overlaps → approve → publish the complete version atomically. Timetable content updates should not need a PWA or Flutter release. Add one “Report incorrect time or venue” route with the session and version prefilled; no student number required.

**Offline contract:** Keep the PWA shell cached, and persist a complete last-known-good **public snapshot** per selected cohort/term in IndexedDB. Restore it immediately, then check for a newer approved version online. Validate the complete snapshot before replacing it. Show `Version / last synced`, and when disconnected show “Saved copy — recent changes may not appear.” If a cohort has never been opened, tell the student they need a connection for that cohort. An expired term can be viewed as history, not announced as today’s classes. Keep guest preferences and private signed-in data separate. Firestore web persistence is **off by default** and its cache can remain between sessions; don’t silently enable private caches on shared devices. [1](https://firebase.google.com/docs/firestore/manage-data/enable-offline)

**Before going live:** Test Google sign-in on the actual subdomain (including mobile Safari/standalone) with [Firebase’s web sign-in setup](https://firebase.google.com/docs/auth/web/google-signin). Review open and closed Firestore Rules in the emulator: a guest reads only approved snapshots, a student cannot read another profile or publish, only the approved backend publishes, and signed-out caches don’t expose another user’s data. Use separate test and production projects, limit reads (one current cohort document is enough for the pilot), and set budget/usage alerts before expanding.

## 4. Don’t leave the existing site quiet until March 2027

The current [UAUT Connect homepage](https://www.uautconnect.com/) leads with admissions and action links for applicants. It already has Campus Highlights and Campus News further down. Keep the main application journey intact. Add **Students → Timetable** and a secondary homepage link **Already at UAUT? Check your classes** once the pilot is approved. It creates a reason to return between intakes without turning the home page into a second portal.

- Start a realistic editorial cadence now: one approved campus update, short student guide, or event recap every two weeks if someone owns it. Confirm the next intake dates before announcing them; keep the official application path clear.
- Invite the first cohort through one class-rep message and a QR link. Show the last revision, publisher/point of contact and a correction link; respond to issues before asking more cohorts to join. No mass sign-up campaign or obligatory accounts for a timetable.
- Add **“Built & maintained by Altraware Technologies”** in the footer and a short About/Maintenance section with permission. A visible working correction process, real campus updates, and an honest changelog build more trust than calling an unapproved pilot “official.”

## 5. AI and Flutter: add when they solve a need

1. **First:** a fast **“Leo/kesho nina class gani?”** shortcut powered by the saved structured schedule and EAT. It works offline and doesn’t need a model. Never have AI guess a room or time.
2. **After the pilot:** opt-in **“Explain this topic in simple Kiswahili/English”** and short recall quizzes from approved notes, with source titles/pages. AI needs a connection; keep normal classes, quick answers and existing guides available offline. Keep keys on the server, set quotas, and don’t send IDs or private PDFs without permission. AI can draft practice tasks or summarize an approved change; it cannot publish or edit the timetable.
3. **Personal Flutter first; public native app later:** Mwijay’s [personal Flutter sequence](mwijay-flutter-next-prompts.md) can test native phone features without changing the pilot or the PWA. For a future public app, only add a native distribution if pilot use shows a real need. Use the **same** auth roles and versioned schedule contract, keep the web path usable, and test iOS separately rather than making installation mandatory.

## Pick this up after the personal app

- [ ] Mwijay confirms the offline check on his own phone.
- [ ] Get the latest BIT Year 2 source and a named pilot publisher/correction contact.
- [ ] Confirm permission to reuse that source, the proposed subdomain, and the Altraware credit.
- [ ] First public change: a guest **programme + year** screen with one approved cohort and no login wall. Add Google sign-in only after that works.

**Resume phrase:** “Nimemaliza StudyDesk yangu; tuanze UAUT Connect timetable pilot.” Start from the checklist above, not from Flutter, AI, or a homepage redesign.
