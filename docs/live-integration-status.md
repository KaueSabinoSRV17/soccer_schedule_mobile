# Live integration status

## Implemented source; deployment pending

The owner-only integration now spans the Flutter app, collector and separate IaC
repository. No cloud apply, production Calendar mutation, or remote push test has
been performed during this implementation. The default app build remains a demo.

Validated locally: 29 Flutter tests, analyzer and Android arm64 debug build;
9 Firestore emulator access-rule tests; 36 backend tests including transactional
selection claims, retries, notification targeting and Calendar migration. Terraform
validation passed for the data, collector and mobile worker modules. The IaC
`make test-mobile` command reproduces the emulator checks.

## Repository ownership

| Repository | Responsibilities |
| --- | --- |
| `infra/soccer_scheduler` | Firebase Android registration/public API key, certificate fingerprints, Auth configuration, owner policy, Firestore rules, worker archive/build/IAM, Eventarc and collector rollout |
| `backend/functions/soccer_schedule` | Frozen daily review, authoritative choice validation, daily FCM publishing and Calendar synchronization |
| This Flutter repository | Google sign-in, review reads, immutable submissions, FCM registration/routing and server-confirmed synchronization status |

The IaC repository also contains Google provider setup and public Android
configuration export helpers. OAuth client secrets and Calendar refresh tokens
never enter Flutter or Terraform state through those helpers.

## Activation prerequisites

1. Supply the sole owner's Google email as `SOCCER_OWNER_EMAIL`.
2. Complete Google OAuth consent and create matching web/Android OAuth clients for
   `dev.kaue.soccer_schedule` and the registered signing certificate. Configure the
   Firebase Google provider using the IaC helper with web OAuth JSON on stdin.
3. Review and apply the IaC rollout in its README, publish the updated collector,
   and select its full commit-SHA image. The live flag defaults to false.
4. Export Android configuration from applied IaC outputs; run Flutter with
   `--dart-define-from-file=.config/firebase-android.json` and sign in on the S23.
5. Execute the collector once and verify push delivery, review routing, owner-only
   access, accepted selection and Calendar results before resuming the scheduler.

Read-only inventory on 2026-10-22 found Firebase and the Native Firestore database
in `grand-bridge-354215`, `southamerica-east1`, but no Android registration or
Firebase Auth/Google-provider configuration. The deployed collector still uses
its previous Calendar workflow until the rollout is applied.
