# StudyDesk · UAUT BIT Year 2

A personal, phone-friendly study desk for Mwijay Davie. It uses **Semester 1, academic year 2026/27** and **East Africa Time (Africa/Dar_es_Salaam, UTC+3)** regardless of the phone's time zone.

- **Timetable:** day/week views, the current or next scheduled activity, class rooms, lecturers and a print-friendly PDF. This is transcribed from **page 2** of the UAUT *CoEIT/BIT Weekly Class Timetable — Updated Revised Draft*. It contains 11 classes and Wednesday Chapel; empty slots were not treated as classes. Confirm changes with UAUT.
- **Study plan:** six suggested study blocks around class time, with a concrete output for each. The checklist starts over each Monday in EAT and stores progress only in the current browser, not in a cloud account.
- **Materials:** searchable course folders, short explanations, an editable Word planner, and an eight-slide editable OOAD PowerPoint. The networking PDFs are grouped by topic with **course code unconfirmed**. See the [materials index](study-materials/README.md).

## Run and install

```sh
npm ci               # Node.js 22.12+ (or a newer supported release)
npm run dev          # live development; no service worker
npm test             # timetable, EAT rollover, study blocks and offline-worker checks
npm run build        # static output + versioned offline cache in dist/
npm run preview      # serve the production build locally
```

Serve `dist/` from the **root** of a stable HTTPS URL for everyday phone use. Use the `build` command (not Vite's standalone build command) so the service worker is generated. The same static site works without an API, accounts or environment variables. If deploying to a shared host, review the name and the timetable; it is not an authenticated app. The Arena preview link can expire.

Open the HTTPS site **directly in the phone browser**, not inside an embedded preview. On **Android/Chrome**, use the app’s **Install app** button or Chrome’s menu → **Install app / Add to Home screen**. On **iPhone/Safari**, use **Share → Add to Home Screen**. Open from the icon **while online** and wait for **Offline ready** (also shown in the install dialog). Then try airplane mode. The saved timetable, guides, study kit and on-device checklist work without a connection. New changes need an online check; if the browser clears the app’s storage, set it up online again. For local HTTP, use the production preview on localhost to test the service worker.

The installed app opens from its cached release first, even on a poor connection. When another release has downloaded, choose **Update now** to switch to it. Existing study checklist entries stay on the device. Serve `/sw.js` with `Cache-Control: no-cache` on any permanent host so clients can check for new releases.

## Update the semester or study kit

- `src/data/semester.json` is the source for official times, names and venues. Update it only from the applicable BIT Year 2 revision and update the source fields and tests together.
- `src/data/plan.json` and `src/data/guides.json` contain suggested self-study and guides, separate from the official class hours.
- `public/downloads/` contains the three original, generated study aids. After timetable or study-plan changes, regenerate and rebuild:

  ```sh
  python -m pip install PyMuPDF python-docx python-pptx
  python scripts/generate-study-kit.py
  npm run build
  ```

- To recreate the locally organized original PDFs and private ZIP, run `python scripts/import-materials.py '/path/to/uploads'`. This copies the five named PDFs from the upload directory into their module subfolders. Original handouts and the private ZIP are not tracked or bundled in the website.

## Mwijay’s personal Flutter app

The [personal Flutter app](mobile/README.md) in `mobile/` bundles the timetable, study plan and materials independently of the web preview. Run `npm run flutter:sync` when updating shared content, then rebuild the native app. On Android, **Settings → Class reminders** saves an inexact notification for a confirmed class date. **Settings → Campus events** adds manually entered offline events, optional StudyDesk notifications, and an optional Calendar editor or `.ics` handoff without reading your calendars. **Materials → My files** imports your own PDF, Word and PowerPoint copies offline; [Cloudinary backup is planned, not connected](docs/cloudinary-documents.md). The [GitHub debug APK steps and Android 17 phone checks](mobile/README.md#android-17-and-apk-from-github) remain open. The [step-by-step prompts](docs/mwijay-flutter-next-prompts.md) leave stronger alarms, offline budgeting and AI separate. The PWA remains the web edition.

## Future UAUT Connect pilot

Start with the [timetable pilot roadmap](docs/uaut-connect-roadmap.md) once the personal app works offline on Mwijay’s phone. It covers the programme/year picker, proposed subdomain, optional Google sign-in, and approval and publishing workflow. No Firebase project, public deployment, admissions site or DNS settings were changed here.

## UAUT student submission covers

For coursework, reports, and formal presentations, use a clean cover with the supplied UAUT logo, the student's formal name and student ID, and the assignment details. Follow any lecturer-provided template or cover instructions first. Keep the logo and student ID off the public app and out of tracked Git files.

Reusable Word and PowerPoint covers live in `study-materials/private/covers/`. Fill in the title, course, lecturer or supervisor, and submission date before turning in the document. To regenerate them, keep the supplied `logo.png` and a `profile.json` containing `student_name` and `student_id` strings inside `study-materials/private/`, then run `python scripts/generate-uaut-covers.py` with `python-docx` and `python-pptx` installed. This private directory is intentionally ignored by Git and isn't part of the PWA or the materials ZIP.
