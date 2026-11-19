# StudyDesk Android · Cloudinary document backup plan

**Current build:** **Materials → My files → Add file** imports a private local copy from Android's picker. It opens in an installed viewer and can be shared explicitly. It works without an account and does not upload anything to Cloudinary, Firebase, or another service. This guide prepares the separate, opt-in Cloudinary phase; it is not a deployed backend or an upload claim.

## Local contract already in the app

`DocumentLibrary` lists/imports by a durable `PersonalDocument.id`. The Android vault owns the bytes; Flutter receives only the ID, sanitized display name, MIME type and actual size. Word (`.doc`, `.docx`), PowerPoint (`.ppt`, `.pptx`) and PDF are allowed. Local limits are 20 MiB each, 50 files or 200 MiB total. Upload must additionally respect the Cloudinary plan's current raw-file and account limits. Removing a local copy, canceling a pick, or viewing a file must never create a backup.

## Set up Cloudinary when ready

1. Use a Cloudinary product environment for StudyDesk testing with **dummy files**. The cloud name is an identifier. Keep the **API secret** and any Cloudinary account credentials on an authorized server, never in Dart, APK build flags, Git, public logs or chat. Do not enable an unsigned upload preset for private documents.
2. Add an HTTPS backend route authenticated to your owner account. The identity provider is replaceable: Firebase, if you choose it later, would supply a verified user identity; it is not needed to use My files offline. Reject anonymous callers. Rate limit by owner, enforce a storage/size budget, and validate that each requested upload belongs to that owner.
3. Store original documents as Cloudinary **raw** assets (including PDFs written as-is, no PDF transformations), with delivery **`authenticated`**, not the default public `upload` type. Build a random, owner-scoped `public_id` ending in the validated extension. Never use the student's name or original filename in the public ID. Verify uncredentialed access is denied, even if someone learns the asset identifier. Check the account's PDF delivery rules before use. See [Cloudinary's asset and delivery types](https://cloudinary.com/documentation/upload_parameters) and [Upload API reference](https://cloudinary.com/documentation/image_upload_api_reference).

## Integration boundary (proposed, not wired)

Use a separate `Back up to Cloudinary` action on a selected local ID, after explicit confirmation of what leaves the phone. Keep **On this phone**, **Uploading**, and **Backed up** distinct. Cancel/deny/offline must leave the local copy usable. No implicit retries or queue on install, boot, or file selection.

| Call | Proposed behavior |
| --- | --- |
| `POST /v1/documents/{id}/upload-session` | Owner-authenticated. Accept the local ID, allowlisted MIME/extension and byte count. Reserve a quota slot and assign a single upload intent and server-generated remote ID. Return only the upload URL, required signed fields and the app session expiry. Sign on the server using [Cloudinary's signature rules](https://cloudinary.com/documentation/authentication_signatures). For direct upload use a signed preset, a fixed Cloudinary raw endpoint and fixed signed delivery type; never let the app select a different host/preset or pass a user URL for Cloudinary to fetch. |
| Multipart upload | Stream the chosen local file from app-private storage, not a base64 string in the Dart/native bridge and not a public file URI. If a backend proxies the bytes instead, set a compatible request-size limit and reject oversized or invalid data before forwarding it. |
| `POST /v1/documents/{id}/complete` | Verify the returned asset server-side against the upload intent (`asset_id`, owner, `public_id`, resource/delivery type, actual size/format). Client metadata and a successful POST alone are not proof. Mark backed up only after verification. Handle replays and clean up over-limit or abandoned assets server-side; a short app session alone does not revoke a Cloudinary signature. |
| Open/download a backup | Authorize each request. Issue short-lived access where supported, or stream via the authorized server. No public links, no long-lived signed URLs stored in the app or exported as notes. Offline opening uses the original local copy. |
| Remove backup | An explicit separate action with ownership check; never piggyback on `Remove` for the local copy. Keep a remote reference after phone-side copy removal only once the owner has agreed to that lifecycle. |

Before turning it on, test cancellation, offline retry only on tap, invalid ownership, invalid/oversized bytes, quotas, duplicate intent handling, account PDF restrictions and private retrieval. A small GitHub debug APK must not embed files from the vault or a configured Cloudinary uploader. No cloud service is deployed by the Android APK workflow.
