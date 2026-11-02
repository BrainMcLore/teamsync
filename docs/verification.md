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

## Development toward 1.0 — reminders and workload

Reminder revision `54c2583` passed the full [Windows installer workflow](https://github.com/BrainMcLore/teamsync/actions/runs/41465857300) and [Android verification workflow](https://github.com/BrainMcLore/teamsync/actions/runs/41465864147). Android integration exercises native schedule replacement and clearing, including idempotent replacement; this does not verify actual banner delivery, reboot or Doze. Local checks passed 113 Flutter tests (5 external/private skips), 28 API tests, clean static analysis and a redacted Git history secret scan.

The following workload snapshot adds three tests (116 Flutter passes total): unfinished deadlines versus submitted/approved work, unknown/unassigned statuses, empty teams, and Russian/English dialogs at 320px. The report uses actual current assignments, with an explicit cache warning; it does not claim historical player performance. Native UI snapshots are refreshed for the new Training action, with Windows capture verified in [run 41468353174](https://github.com/BrainMcLore/teamsync/actions/runs/41468353174). Production API health remains healthy with schedule capability enabled. Published 0.95 Beta assets remain unchanged.

## Development toward 1.0 — portable review notebooks

Revision `62fc923` adds timeline-note/scouting round trips to portable reviews. Local checks: 119 Flutter tests passed, 5 external/private checks skipped; static analysis clean. Tests cover legacy analysis-only compatibility, original tick/round/text/creation-time preservation, independent imported IDs, unknown scouting/path rejection, invalid note boundaries and database-triggered rollback with file cleanup. Review encoding runs through an isolate. A redacted history scan found no secrets.

The Android integration suite now performs an offline review export/import/open round trip on device storage. Native verification runs: [Android 41478417578](https://github.com/BrainMcLore/teamsync/actions/runs/41478417578), [Windows 41478423066](https://github.com/BrainMcLore/teamsync/actions/runs/41478423066). Consult run conclusions; dispatch alone is not acceptance. Physical cross-device sharing and annotation edit/deletion history remain outstanding.
