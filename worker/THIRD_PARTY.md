# Demo processing companion

- demoparser2 0.42.1 — https://github.com/LaihoE/demoparser — MIT.
- pandas, NumPy, PyArrow and Polars — their package licenses and notices apply; see the included runtime package metadata and upstream distributions.
- Python runtime — Python Software Foundation license.
- PyInstaller bootloader — GPL with the bootloader distribution exception; https://pyinstaller.org/en/stable/license.html.
- 7-Zip — https://www.7-zip.org/license.txt; LGPL/BSD and unRAR restriction. The original 7-Zip License.txt is included next to 7z.exe. This application uses RAR extraction only.

The worker runs independently of CS2 and does not inject code, read game memory or automate game input. Game demo files are supplied by the user or fetched from a user-selected public file URL.

HLTV reader: curl_cffi 0.17.0 (MIT), cffi, pycparser and certifi; runtime notices are collected from installed packages. Source: https://github.com/lexiforest/curl_cffi . Browser-compatible HTTPS is used for public pages; personal browser cookies and accounts are not accessed. CS2 and TeamSpeak server binaries are downloaded from their official hosts after a user action; they are not redistributed in TeamSync.
