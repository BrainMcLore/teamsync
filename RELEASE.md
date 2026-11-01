# TeamSync 0.95 Beta

Targets: Windows x64 and Android. Release tag: `v0.95.0-beta`.

## Packages

- `TeamSync-0.95.0-beta-Windows-Setup.exe` — Windows installer.
- `TeamSync-0.95.0-beta-Android.apk` — Android APK signed with the persistent release key.
- `TeamSync-0.95.0-beta-Source.zip` — source, map assets, documentation and CI configuration.
- `TeamSync-0.95.0-beta-Server.zip` — self-hosted API deployment package.
- `SHA256SUMS-0.95.0-beta.txt` and `TeamSync-0.95.0-beta-manifest.json` — checksums, sizes and package completeness.

## Reproduce a release

Windows and Android workflows build native packages from the release commit. The Android workflow checks the signing certificate against `packaging/android-signing.sha256`; private signing material is supplied through CI secrets.

```sh
python3 -m unittest discover -s tools -p test_release.py -v
python3 tools/package-source.py
python3 tools/package-server.py
python3 tools/release-checksums.py --require-windows --require-android
```

Place the actual native builds in `dist` before the final command. Missing binaries fail verification. Source/server ZIPs use fixed timestamps and undergo CRC checks. Never replace a missing build by renaming an older binary.

Beta limitations and the verification boundary are documented in [README](README.md), [verification](docs/verification.md) and [acceptance](docs/acceptance.md).
