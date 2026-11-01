# TeamSync Windows build adapter

Upstream: flutter_secure_storage_windows 4.2.2, distributed under its original BSD license (LICENSE).

The Windows adapter uses five ATL string conversions. This copy replaces CA2W/CW2A with native MultiByteToWideChar/WideCharToMultiByte wrappers using the same CP_THREAD_ACP encoding. It removes the optional ATL build-tools dependency. No credential key format, encryption, DPAPI, authentication or storage location logic is changed. TeamSync's session key names are ASCII SHA-256 identifiers.

Files changed: windows/flutter_secure_storage_windows_plugin.cpp (include and conversion type names), plus windows/native_string_conversion.h. The Dart interface is unchanged.
