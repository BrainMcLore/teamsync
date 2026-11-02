# 1.0 acceptance audit / Аудит готовности 1.0

Date: 2026-11-02. Targets: Windows x64 and Android. Linux is the development host. **This is an acceptance report, not a 1.0 release announcement.** Published 0.95 Beta artifacts remain unchanged.

## Release decision

The user chose to publish the current feature baseline as 1.0.0 with the known limitations below. Earlier readiness assessments are retained as audit history; the release does not mark failed, unavailable or unimplemented checks as passed. Official versioned packages and release notes are linked from the README.

## Verified locally

| Check | Result | Scope |
| --- | --- | --- |
| Flutter analysis | Passed | No analyzer issues |
| Client regression | 127 passed, 3 skipped | Includes the pinned real-recording query benchmark and desktop/mobile review rendering |
| API/worker on Linux host | 57 passed, 1 deliberately excluded | The combined ZIP/RAR test needs the Windows-bundled `7z.exe`; Windows CI runs it without this exclusion |
| Packaging | 5 passed | Reproducibility, source/server exclusion rules, APK certificate matching, installer data canaries |
| Python dependency consistency | Passed | `pip check` |
| Python advisories | Passed | `pip-audit`: 45 Linux-resolved server/worker/build dependencies, no known advisories, none skipped |
| Pub advisories | Passed | OSV: 104 hosted packages, no known advisories; SDK and local vendored code excluded |
| Git secret scan | Passed, redacted | Full tracked history; credentials are not printed or packaged |
| Pinned CS2 recording | Passed | SHA-256 verified; parsed 3,544 frames / 10 rounds / 73 kills |
| Review CPU benchmark | Passed | Real recording, 300 queries; not a GPU FPS or real CS2 playback measurement |
| Live HLTV catalog | Passed | One on-demand public request returned 100 matches; this is not archive delivery acceptance |
| Production health | Passed after retry | First HTTP client probe timed out at 30s; a subsequent curl request returned healthy. Cause of initial delay not established; cold-start/network latency needs acceptance. Both providers are configured |
| Steam/Discord OAuth start | Passed | Both return authorization URLs; no consent/profile/linking claim |
| Anonymous production access | Passed | `/api/v1/me` and `/api/v1/teams` return 401 |

Dependency advisory checks do not certify the Flutter/Dart SDK, local C++ changes, all Windows-only conditional packages or Android Gradle dependencies. No claim of a complete security audit is made.

The three locally skipped client checks are native Windows demo import, optional live HLTV archive import and private authenticated hosted synchronization. No production account token was borrowed to bypass an authenticated check. Two local fixture clients already exercise interruption, persistent outbox restart, acknowledgement loss, conflicts and account isolation; that is separate from two physical-device acceptance.

## Native candidate checks

Android [run 41480858870](https://github.com/BrainMcLore/teamsync/actions/runs/41480858870), source `12a9164`, passed the emulator integration, release build and pinned signing certificate verification. Independently downloaded APK SHA-256 and ZIP CRC checks passed (104,034,484 bytes; arm64-v8a, armeabi-v7a, x86_64). APK SHA-256: `eb465394615655c2fa951c2c123cda0a1a062bf978ac270de6eafa74a00dab48`.

Windows Credential Manager adapter [run 41483193104](https://github.com/BrainMcLore/teamsync/actions/runs/41483193104), source `c1b5e4a`, passed a native Unicode-value round trip, key conversion, enumeration and cleanup of a unique test credential. This is a focused adapter check, not a complete cryptographic audit of the plugin.

Full Windows acceptance [run 41481687166](https://github.com/BrainMcLore/teamsync/actions/runs/41481687166), source `895430e`: **overall failed because live HLTV archive import failed**. Independent checks passed: 58 worker/API tests, 124 client tests (3 skipped), installer build, published-Beta installer hash, baseline install, candidate upgrade, actual app startup and schema-1-to-7 migration, reminder protocol registration/removal, database/media canaries after uninstall, and source/server/checksum packaging. The preserved data is a seeded legacy profile, not a substitute for physical testing with a user's real team/account state.

Independent downloads verified all three Windows artifacts against the build manifest, ZIP CRCs, safe archive paths and credential/generated-folder exclusions. Installer: 133,232,178 bytes, SHA-256 `8d105334c596cdb0555a011df9798531375219f2063544d5edb2eea18c5a1274`.

Real-review Windows rendering [run 41483693332](https://github.com/BrainMcLore/teamsync/actions/runs/41483693332), source `273c312`, passed, including the pinned recording, player playback assertion and wide/mobile snapshots. Snapshots were visually inspected; current Windows review baselines were retained for regression checks.

The archive failure originally exposed only a generic DomainError after about five minutes. Diagnostic-only [run 41484636670](https://github.com/BrainMcLore/teamsync/actions/runs/41484636670) reused the hash-verified built candidate and failed with `source_verification_timeout`, `phase=error`, `bytes=0`. Source verification did not finish and archive delivery never started. The underlying reason for verification not completing on the hosted runner is not established; this is not a passed download test. This failure is not hidden by the successful public catalog probe. Each run's source revision matters: later source changes require final CI again before publication. An uploaded artifact alone does not imply all optional checks passed.

- Windows acceptance includes the full worker/API suite, bundled parser import, real-recording query benchmark, installer creation, published-Beta hash verification, baseline install, candidate upgrade/startup/database migration, uninstall with database/media preservation, and source/server/checksum packaging.
- Explicit live-HLTV acceptance imports a real remote archive with the native companion. Failure remains a failed check and does not suppress independent installer/integrity checks.
- Android acceptance includes emulator account/team workflows, local reminder scheduling/clearing, portable notebook export/import/open, release APK build and persistent signing-certificate verification.

## Still required for 1.0

| Gate | Why it remains open | Acceptance evidence needed |
| --- | --- | --- |
| Two physical devices | User confirmed currently unavailable | Coach/player on Windows+Android: disconnect, restart, concurrent edits, conflict resolution, logout/account change and membership revocation |
| Steam sign-in and linking | Starting OAuth is insufficient | Live user consent, correct profile/linking, callback after cold start and logout/revocation |
| Notification delivery | Native scheduling tests are insufficient | Actual banners, reboot, denied/re-enabled permission, Android Doze/force-stop, Windows off/late wake and cancellation after sync |
| Android physical update | Emulator/certificate checks are insufficient | Install published Beta then candidate with the same certificate; retain team data and signed-in state as intended |
| CS2 playback | CS2 and a representative Windows gaming device are unavailable | Open real `.dem` in CS2, playable analysis timeline and measured responsiveness |
| CS2/TeamSpeak bootcamp | Mocked installation/process tests are insufficient | Real download/install/start/stop, practice/PUG connection, TeamSpeak session, restart and preservation of existing server data |
| Cloud push | Not implemented | Background remote event changes with provider delivery, permissions and revocation |
| Joint live review | Not implemented | Authorized session, shared playback, reconnect, access removal and event ordering |
| Authenticated remote bootcamp agent | Not implemented | Scoped authenticated commands, errors, isolation and revocation |
| Review edit/deletion audit | Not implemented | Retained revisions/deletions and explicitly attributed history, including portable transfer |

**Русский.** Автотесты и нативные сборки подтверждают только перечисленные сценарии. Физические устройства, живой вход Steam, показ уведомлений, CS2 и реальные серверы требуют отдельной приёмки. Облачный push, совместный онлайн-разбор, защищённый удалённый агент и журнал правок/удалений заметок ещё не реализованы — их нельзя закрыть одним запуском тестов. До закрытия обязательных пунктов сборка не объявляется финальной 1.0.


## Defect found and fixed during acceptance

Backup restoration created an unlinked local team that the account-only workspace did not display. The application now copies into the selected online team, after manager confirmation. It retains existing materials, refuses viewer/logout/account-switch cases, creates no archive members/accounts, resets copied tasks to unassigned Todo, and keeps local tactic snapshots without claiming server-authenticated review history. A logout during media writes rolls back the import and removes newly written files. Local regressions pass, including import followed by synchronization to a second fixture account with no imported identities/approvals. Refreshed native candidate verification follows below. This functional change means the earlier APK/installer hashes above identify pre-fix acceptance builds, not a final 1.0 package.


## Latest candidates with the restore fix

Both candidates use runtime source `6809ad5` and remain development builds, versioned 0.95 Beta. The later `f297674` change adds a fixture regression and updates documentation, without changing application runtime code.

| Native check | Result | Evidence |
| --- | --- | --- |
| Windows core acceptance | Passed | [Run 41486629187](https://github.com/BrainMcLore/teamsync/actions/runs/41486629187): 127 client tests passed, 2 private/external skips; 58 worker/API tests passed; installer build, baseline upgrade, actual startup/migration and uninstall canaries passed again |
| Android acceptance | Passed | [Run 41486635945](https://github.com/BrainMcLore/teamsync/actions/runs/41486635945): 124 client tests passed, 5 platform/private skips; 4 emulator integration tests passed; signed APK and certificate pin verified |
| Independent final artifact integrity | Passed | Both binaries' SHA-256 values verified after downloading; APK/source/server ZIP CRCs passed; source/server archives exclude generated folders and credential/database files |
| Live HLTV archive | Failed, still open | `source_verification_timeout`, 0 bytes. The green core workflow does not rerun or override the failed explicit external acceptance |

Current candidate binary hashes:

- Windows installer: 133,255,208 bytes; SHA-256 `79af50124a8b98a1a15f6cec917f33b4f3e4fd4a305a21ab503e829f15471925`.
- Android APK: 104,034,484 bytes; SHA-256 `bd2c258bb1cdf60c213f000fc4682db1a901a27cc4eed9938be888930f037b00`.

The Windows workflow manifest lists the APK as missing because binaries are produced by separate workflows; the independently verified Android artifact above supplies the other target. These pre-release hashes are retained as audit evidence; official 1.0.0 artifacts have their own release manifest. Physical devices were confirmed unavailable by the user, and the missing functionality/physical gates above remain open.
