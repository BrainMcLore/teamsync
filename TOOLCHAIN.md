# Проверенные версии окружения

Проверка 2026-10-28.

Обновление 2026-10-29: client 0.2.0; demoparser2 0.42.1, PyInstaller 6.22.3, rarfile 4.5, NumPy 2.2.6, pandas 2.3.3, PyArrow 25.0.1, Polars 2.0.0. Worker requirements зафиксированы отдельно в worker/. 7-Zip и License.txt поставляются рядом с worker. Inter/OFL включены в assets/fonts. Windows storage adapter 4.2.2 vendored с минимальным Win32 string-conversion patch вместо ATL; описание и оригинальная BSD-лицензия сохранены. Все клиентские версии — pubspec.lock.

- Flutter stable 3.47.8, revision 737ba8f885.
- Dart 3.13.7, Flutter engine cf636b1dfb.
- Windows 11, Visual Studio Build Tools 2022 17.14.42, Windows SDK 10.0.26100.0.
- Java 17.0.20 Eclipse Adoptium.
- Android command-line tools 16111833; Android platform 36, build-tools 36.0.0 (фактические требования Gradle и итог сборки — в CHECKS.md).
- Inno Setup 6.7.4, подпись загруженного компилятора проверена: Pyrsys B.V., Valid.
- Python 3.10.11; зависимости API зафиксированы в server/requirements.txt.
- Клиент: sqlite3 3.8.0, path_provider 2.1.6, intl 0.20.3, file_selector 1.1.0, pdf 3.13.1, printing 5.15.1, flutter_secure_storage 11.2.0, app_links 7.2.2, url_launcher 6.3.3. Полный набор и транзитивные версии — client/pubspec.lock.
- Noto Sans Regular и OFL включены в client/assets/fonts; шрифт загружен из официального notofonts/noto-fonts.

Flutter SDK и Android SDK находятся в .tools и не являются исходным кодом приложения. Переносить этот каталог в дистрибутив не нужно.
