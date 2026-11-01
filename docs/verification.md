# Verification

Local release preparation: **81 Flutter tests passed, 5 external/private checks skipped; 20 API tests and 4 release-packaging tests passed. Static analysis reported no issues.**

Release CI checks the native Windows installer and signed Android APK from the release source revision.

- Flutter static analysis and unit/widget tests, including English/Russian UI snapshots.
- API tests for accounts, teams, role boundaries, media and versioned synchronization.
- Parser tests using a pinned demo fixture; native Windows worker build.
- Android emulator integration against a real API fixture: accounts, team assignments, task review/history, preparation plans and media access.
- APK signing certificate compared with the public pin in `packaging/android-signing.sha256`.
- Reproducible source/server archive tests, excluded credential fixtures and final SHA-256 manifest.

External/private-fixture tests can be skipped when their inputs are unavailable; see CI logs for the exact run result. Real Steam consent, CS2 playback, PUG/TeamSpeak sessions and physical-device acceptance are not implied by a green build.

[Windows runs](https://github.com/BrainMcLore/teamsync/actions/workflows/windows-release.yml) · [Android runs](https://github.com/BrainMcLore/teamsync/actions/workflows/android.yml) · [Acceptance boundary](acceptance.md)

## Development toward 1.0 — scheduling milestone

The development branch passes 106 Flutter tests (5 external/private checks skipped), 28 API tests and clean static analysis. Coverage includes independent RSVP/attendance, manager permissions, cancellation, corrections with reasons, retained former-member records, UTC normalization, durable retries, version conflicts, account changes and foreground refresh. Windows attendance snapshots were captured in English and Russian in [UI run 41357190142](https://github.com/BrainMcLore/teamsync/actions/runs/41357190142). These checks do not imply a newly published installer/APK or physical-device acceptance.
