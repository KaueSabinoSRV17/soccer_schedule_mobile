# Owner-only daily review integration

## Production flow

1. The collector runs `--publish-daily-review` for the São Paulo date. It freezes
   the first review for that date, groups 135-minute match intervals, removes only
   tagged app-owned future conflicting Calendar events and syncs isolated games.
2. It marks the review ready and advances `state/current` before sending one daily
   FCM notification. Calendar continues to provide kickoff reminders.
3. The Google-authenticated owner opens the review and chooses compatible matches
   or explicitly skips each conflict group. Connected groups can contain multiple
   compatible choices: A/C can both be selected when only B overlaps them.
4. The app creates an immutable pending submission. A private Firestore-triggered
   worker validates ownership, revision, membership, overlap and kickoff eligibility,
   then updates stable Calendar event IDs. The UI reports `synced` only after the
   worker acknowledges success; transient failures retry the same accepted choices.

The first valid submission is final for that daily review. Rejected submissions
can be corrected; queued, processing, failed and synced selections remain locked.
Unanswered conflicts stay out of Calendar. Completed and unrelated Calendar events
are preserved. Reviews are immutable daily snapshots; reruns do not refresh fixtures.

## Firestore contract

- `config/access`: IaC-owned lowercase owner email; no client access.
- `state/current`: latest ready `reviewId`, readable only by the owner.
- `dailyReviews/{YYYY-MM-DD}`: schema version 1, revision, timezone, UTC timestamps,
  fixtures, automatic IDs, connected groups, fingerprint and server lifecycle fields.
- `dailyReviews/{id}/submissions/{autoId}`: `reviewRevision`, `selectedIds`,
  `skippedGroupIds`, `ownerEmail`, `status=pending`, server `createdAt`. Server adds
  status/error metadata and claims one `acceptedSubmissionId` transactionally.
- `devices/{randomInstallationId}`: FCM `fid`, Android platform, enabled flag, owner
  email and server update timestamp. FIDs are refreshed on registration and deleted
  at sign-out; invalid installations are removed by the publisher.

Rules require verified Google sign-in with the configured email. Arbitrary accounts
cannot access reviews, requests or devices, regardless of client-side checks.
Browser access to collector credentials or privileged Google APIs is never needed.

## Notifications and retries

Messages contain `type=daily_review` and `reviewId`; the app fetches authoritative
Firestore content after a tap. Foreground, background and cold-start routing are
implemented. Android notifications use the `daily_review` channel and new FCM
installation-ID APIs. Delivery uses per-day collapse keys/tags and a server lease.
FCM acceptance cannot guarantee the phone displayed a notification; a crash between
sending and recording acknowledgement can cause a retry, with the same daily tag.
No-device runs leave notification delivery retryable after the phone is registered.

## Configuration

See the separate IaC README for provisioning, Google OAuth setup, rollout and
`make test-mobile`. Its export helper writes ignored native SDK configuration plus
`.config/firebase-android.json`. Run:

```bash
source scripts/env.sh
flutter run -d DEVICE_ID --dart-define-from-file=.config/firebase-android.json
```

Live mode requires Android and all owner/Firebase/OAuth values. It fails closed
when incomplete. Omit the define file for the explicitly labeled local demo.
