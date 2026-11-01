# Интеграции

Проверка документации: 2026-10-28. Проверка страницы не равна работающей интеграции.

## Обновление 0.2 — 2026-10-29

- Карты: https://github.com/MurkyYT/cs2-map-icons, revision `d84e5b19af6e17f25ce295545a01456c46acee5f`. Включены 9 радаров, 3 нижних уровня и 9 настоящих обложек; авторские права на игровые графику/overview — Valve Corporation. manifest и attribution входят в приложение. Проверены наличие, контрольные суммы и преобразование координат Mirage, этажи Nuke; старые версии геометрии требуют дополнительной приёмки.
- Парсер: https://github.com/LaihoE/demoparser, demoparser2 0.42.1, MIT. Windows wheels и frozen runtime проверены на реальной открытой DEM-фикстуре, в том числе после ZIP/RAR-импорта. Credentials не нужны. Отдельный процесс, без доступа к игре.
- HLTV: https://www.hltv.org/terms, пункт 2.2; автоматическое scraping запрещено условиями. Provider 0.2 принимает скачанные пользователем файлы, прямые публичные ссылки и необязательную страницу матча. Защита сайта не обходится, cookies из браузера не копируются. Автоматический каталог не подключён. Фактическое скачивание защищённого HLTV URL и коммерческое разрешение на данные не заявляются проверенными. Парсер работает с бинарной записью, независимо от сайта-источника.
- RAR: https://www.7-zip.org/download.html, системный extractor 7-Zip поставляется отдельно от Python-модуля, с оригинальной License.txt. Проверены ZIP deflate и стандартный stored RAR4 с реальным DEM; защитные проверки путей/ссылок и лимитов проходят тесты. Зашифрованные архивы не поддерживаются.
- Windows secure storage: локальный BSD-licensed adapter 4.2.2 заменяет ATL-конвертеры на Win32 с прежним CP_THREAD_ACP. Шифрование/формат upstream не изменены. Отдельный native smoke test проверил запись/чтение Unicode-значения через Credential Manager, преобразование ключа, перечисление и удаление только QA-записи.

| Интеграция | Документация | Возможность / credentials / ограничения / fallback / статус |
|---|---|---|
| Flutter Windows | https://docs.flutter.dev/platform-integration/windows/setup | Нативная сборка, C++ workload Visual Studio. Credentials не нужны. Лицензии зависимостей сохраняются. Сборка проверяется отдельно. |
| Flutter Android | https://docs.flutter.dev/platform-integration/android/setup | Android SDK/JDK, release keystore для подписи. Нативный проект; сборка требует tooling. |
| Flutter iOS | https://docs.flutter.dev/platform-integration/ios/setup | macOS/Xcode, Apple account для дистрибуции. На Windows сборка невозможна, передаётся проект и процесс. |
| Локализация | https://docs.flutter.dev/ui/internationalization | ARB, ICU, offline ru/en, без credentials. |
| SQLite | https://pub.dev/packages/sqlite3 | FFI native SQLite, локальные данные. Версия и лицензия в lock/пакете. |
| Каталоги ОС | https://pub.dev/packages/path_provider | Native Application Support directory; без credentials. |
| Steam OpenID | https://steamcommunity.com/dev | Backend server verification, signed fields/return_to/nonce, state, одноразовый код и native PKCE реализованы. Это не OAuth2. Живой вход не проверен, Steam Web API key для самого OpenID не нужен. Fallback: локальная область без серверных прав. |
| Discord OAuth2 | https://docs.discord.com/developers/topics/oauth2 | Backend secret и redirect URI, minimal identify scope, state и native PKCE реализованы. Нужны DISCORD_CLIENT_ID/SECRET на сервере. Секрет в клиент не включается. Живой вход не проверен. Fallback: локальная область или отдельно Steam. |
| Native secure storage и callback | https://pub.dev/packages/flutter_secure_storage / https://pub.dev/packages/app_links / https://pub.dev/packages/url_launcher | Windows loopback, mobile teamsync scheme, системный браузер, секреты в хранилище ОС. Проекты и библиотеки собираются; OAuth на физических устройствах ещё не проверен. |
| PDF и системное меню | https://pub.dev/packages/pdf / https://pub.dev/packages/printing | Native PDF с bundled Noto Sans/OFL, ru/en, radar overlay. В Windows сохраняется через системный выбор файла, на mobile — share. Генерация и чтение кириллицы проверены, mobile share требует устройства. |
| YouTube | https://developers.google.com/youtube/terms/api-services-terms-of-service | Ссылки/разрешённое встраивание; никакого обещания offline downloads. Не реализовано. |
| CS2Tricks/FACEIT | Документация и условия ещё не проверены | Не реализовано. Никакого скрейпинга без проверки разрешений; ручной импорт собственных данных. |
| CS2 / TeamSpeak | Документация и лицензии ещё не проверены | Не реализовано. Требуются реальные хосты, разрешения и ограниченный агент; бинарники не включены. |

## PUG и practice, 0.3

Официальные источники: https://github.com/shobhit-pathak/MatchZy/releases/tag/0.9.2 (MIT), https://github.com/roflmuffin/CounterStrikeSharp/releases/tag/v1.0.378 (GPL3 + plugin exception), https://github.com/alliedmodders/metamod-source/releases/tag/2.0.0.1483. Приложение не распространяет эти бинарники в своём установщике: по кнопке загружает оригинальные архивы с официальных release URLs. Список, версии и SHA — worker/plugin_installer.py. Используется отдельный сервер, не модификация игрового клиента. Контрольные суммы защищают закреплённую сборку, а не подтверждают совместимость с будущими патчами CS2.

Инструкции upstream: https://shobhit-pathak.github.io/MatchZy/installation/ , https://shobhit-pathak.github.io/MatchZy/commands/ , https://shobhit-pathak.github.io/MatchZy/match_setup/ , https://docs.cssharp.dev/docs/guides/getting-started.html . Для TS3: https://www.teamspeak.com/en/downloads?product=server . Лицензию TS3 приложение не принимает за пользователя. Запуск существующей установки и проверка Query-порта не являются полным TS ServerQuery-управлением каналами.

## 0.4: актуальный путь HLTV и загрузки серверов

Позднее указание пользователя заменило первоначальное ограничение ТЗ по прямому каталогу. worker/hltv_catalog.py получает public /results?offset=… и только выбранную /matches/… через browser-compatible curl_cffi TLS/HTTP2; data-demo-link /download/demo/<id> разбирается, redirects проверяются по публичному DNS с libcurl RESOLVE и TLS hostname verification. При 429 действует cooldown. Никакие аккаунты, личные браузерные cookies, прокси или solver не используются. Нативный frozen worker проверен живым запросом и вернул 100 результатов. Страница выбранного матча/карты/игроки/Demo-link тоже получены; сам R2 CDN в проверке отвечает 403, поэтому прямой архив не заявляется гарантированным. Программа переводит такую загрузку в браузер и автоматически принимает завершённый файл.

worker/server_installer.py: SteamCMD bootstrap с официального steamcdn-a.akamaihd.net, затем anonymous app_update 730 validate; native Windows bootstrap проверен после самостоятельного обновления (exit 7 обработан, затем штатный +quit exit 0), подпись Valve Corp. действительна. Полная CS2 загрузка в QA не выполнялась. TS3 3.13.8 с files.teamspeak-services.com закреплён SHA-256; фактическая распаковка и подпись TeamSpeak Systems GmbH проверены. Лицензия показывается в приложении и принимается человеком, без фонового авто-согласия. SHA/URL находятся в SOURCES установщика. Эти серверные бинарники скачиваются по действию пользователя, не включаются в дистрибутив TeamSync.
