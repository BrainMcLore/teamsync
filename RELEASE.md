# Выпуск TeamSync 0.8.0

Целевые платформы: Windows x64 и Android. Linux используется только для разработки и упаковки исходников.

## Состояние

Исправления 0.8 прошли живую проверку на Windows до переноса среды: синхронизация команды, каталог HLTV, скачивание и разбор двух карт. Windows-инсталлятор собран и установлен; Android APK собран с тестовой подписью v2. Эти готовые EXE/APK находятся на старом Windows-компьютере. Их наличие на Linux не подтверждено; здесь нельзя восстановить их SHA-256 по именам или размерам.

## Пакеты

- TeamSync-0.8.0-Windows-Setup.exe — Windows-инсталлятор.
- TeamSync-0.8.0-Android-test.apk — Android-сборка с существующим тестовым ключом; не заменять ключ случайным новым ключом CI, иначе обновление установленного APK не пройдёт.
- TeamSync-0.8.0-Source.zip — исходники, карты, документация и конфигурация CI.
- TeamSync-0.7.0-Server.zip — неизменённый совместимый сервер; живой backend не требует повторного deploy ради номера клиента.
- SHA256SUMS-0.8.0.txt и TeamSync-0.8.0-manifest.json — хеши фактически присутствующих пакетов, размеры и явный список отсутствующих файлов.

## Упаковка на машине разработки

```sh
python3 -m unittest discover -s tools -p test_release.py -v
python3 tools/package-source.py
python3 tools/package-server.py
python3 tools/release-checksums.py
```

После помещения настоящих EXE/APK в dist выполните `python3 tools/release-checksums.py --require-windows --require-android`. Отсутствие артефакта завершает проверку с ошибкой. Архивы Source/Server проходят CRC-проверку и имеют фиксированные ZIP-метки времени.

## Повторная сборка Windows

Workflow `.github/workflows/windows-release.yml`: Actions → Windows release → Run workflow. Задание также запускается по тегу v*. Оно использует Windows 2022, Python 3.10, Flutter 3.47.8, проверенный SHA-256 DEM fixture, собирает нативный загрузчик/worker и установщик, выполняет Python/Flutter-проверки, упаковывает исходники и сервер, прикладывает артефакты и SHA-256 к запуску Actions. Отсутствующий Android APK явно указывается в manifest. Это не Linux-сборка. До успешного запуска workflow новая CI-сборка не считается проверенной.

Серверный репозиторий BrainMcLore/teamsync-api используется Render. Полный проект размещается отдельно, чтобы не менять существующий deploy. В Git и release-пакеты не включать секреты Render/Neon/Discord, пользовательские базы/демки, сессии, SDK, keystore и локальный конфиг GitHub CLI.
