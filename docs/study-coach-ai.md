# StudyDesk Study Coach · offline first, owner-only AI later

## What works without a connection

The Android build bundles five short greeting clips made with Mwijay's selected synthetic voice. **Settings → Spoken welcome** controls automatic playback and lets him preview the next clip. No microphone, cloud TTS account, or provider key is used. The public repo and resulting APK contain these personalized clips; they contain neither the original Finance PDFs nor Mwijay's study history.

**Plan → Study checklist → Study Coach** stores self-reported minutes by course and quiz totals by EAT date. It retains up to 90 recorded dates, shows recent history, and offers an explicit local reset. It records no screen activity, document contents, location, contacts, or open-ended answer history. Normal Android backup exclusions also cover these preferences. Uninstall/clear-data removes them.

**Materials → FN200** has paraphrased guides from the three attached handouts. **Practice FN200** leads to five-question rounds drawn from all three PDFs or one selected source. There are 18 authored questions, with answer explanations and PDF page numbers. This is deterministic grading of curated questions, not AI or automatic PDF ingestion. The originals are in ignored `source/` folders or can be imported into Android **My files**. Quiz questions and citations are maintained in `src/data/finance-quiz.json`; `npm run flutter:sync` copies the curated asset, never the original PDFs.

The **AI orb** and **Home → Quick capture** provide local lookup shortcuts (Leo, Kesho, Next class, Study log, FN200 and Risk and return). They do not interpret arbitrary questions or scan imported PDFs. **AI Settings** shows the built-in offline mode, response tone, and opt-in note memory. Only explicit pins are stored; users can unpin one or clear all. Do not add these pins to any request to a future provider.

## Safe connection for an optional online explanation

**Not deployed or enabled.** Choose a model provider and an owner sign-in before adding a network client. Put its API key into a secret manager or server environment on the chosen backend, not in Git, chat, a mobile asset, client-side `.env`, Vite build variable, or `--dart-define`. An APK can be inspected. The phone receives a short-lived authenticated app session, not a provider key. If a real key has ever been exposed, revoke and rotate it before use.

1. Keep an **Explain with AI** button separate from offline practice. Show the provider, exact curated excerpt to be sent and purpose. Allow cancellation before sending. Don't send a name, study journal, app settings, calendar, vault paths, raw PDFs, or unrelated content.
2. Use an HTTPS server route such as `POST /v1/study/explain`. Verify the session's issuer, audience and expiry, then enforce the configured owner identity on the server. Do not use the APK's name/device ID or a shared constant as authentication. Reject anonymous callers before contacting the model. Do not store a reusable provider token in preferences.
3. Accept only a known `sourceId`, section ID, allowlisted language (`sw` or `en`) and bounded task. Resolve text and page citations from the same curated pack on the server. No arbitrary URLs, document IDs or freeform prompts in the first deployment. Send only the previewed text. Apply owner-scoped rate limits, output/time budgets and provider spend caps. Do not log the prompt, private data or credentials.
4. Treat the model response as untrusted. Limit and validate the returned fields; enforce citations from the supplied page list. Mark explanations as AI-generated and fall back to the bundled guide if the service is off, the device is offline or the response is invalid. AI never edits the timetable, grades the official course, or starts a reminder.
5. Before enabling it for real: verify owner-only access, cancel-without-request, offline fallback, quota enforcement, correct citations, no private fields in requests/logs, and key rotation. Keep Firebase, Cloudinary and other integrations separate until explicitly configured and tested.
