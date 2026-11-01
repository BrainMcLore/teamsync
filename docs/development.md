# Development

TeamSync targets Windows x64 and Android. Linux is supported as a development environment only.

## Toolchain

- Flutter 3.47.8 (revision 737ba8f885), Dart 3.13.7.
- JDK 17 and Android SDK for Android; Gradle configuration is in `client/android`.
- Visual Studio C++ build tools, Windows SDK and Inno Setup for Windows.
- Python 3.10/3.12; dependencies are pinned in `server/requirements.txt` and the worker requirements.

## Checks

```sh
cd client
flutter pub get
flutter analyze
flutter test
cd ..
python3 -m pip install -r server/requirements.txt
python3 -m pytest server/tests -q
python3 -m unittest discover -s tools -p test_release.py -v
```

Run native build commands on the target build host. CI workflows are the authoritative reproducible native build recipes: [Windows](../.github/workflows/windows-release.yml), [Android](../.github/workflows/android.yml), [UI snapshots](../.github/workflows/ui-goldens.yml).

Windows packaging scripts live in `tools` and `packaging`. The internal Windows build flavor is `v08`; it does not determine the displayed application version. The public version comes from `client/pubspec.yaml` and installer metadata.

## Repository layout

Client UI and persistence are in `client/lib`; API and tests are in `server`; the demo parser is in `worker`; native download integration is in `native`. User-facing screenshots are in `docs/images`; comparison baselines are in `client/test/goldens`.

Do not commit SDKs, builds, credentials, signing keys, user databases or demos. Use `.env.example` as a configuration template. See [deployment](deployment.md) and [release packaging](../RELEASE.md).
