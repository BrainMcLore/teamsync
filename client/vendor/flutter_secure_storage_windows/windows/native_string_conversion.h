// ATL-free equivalents of the two ATL conversion helpers used by the upstream
// adapter. The original CP_THREAD_ACP key encoding and Win32 crypto are retained.
#pragma once
#include <windows.h>
#include <string>

class NativeAnsiToWide {
 public:
  explicit NativeAnsiToWide(const char* input) {
    if (input == nullptr) return;
    const int size = MultiByteToWideChar(CP_THREAD_ACP, 0, input, -1, nullptr, 0);
    if (size <= 0) throw GetLastError();
    value_.resize(static_cast<size_t>(size));
    if (MultiByteToWideChar(CP_THREAD_ACP, 0, input, -1, value_.data(), size) == 0) {
      throw GetLastError();
    }
    value_.resize(static_cast<size_t>(size - 1));
  }
  operator wchar_t*() { return value_.data(); }
  operator const wchar_t*() const { return value_.c_str(); }
  wchar_t* data() { return value_.data(); }
  const wchar_t* data() const { return value_.c_str(); }
 private:
  std::wstring value_;
};

class NativeWideToAnsi {
 public:
  explicit NativeWideToAnsi(const wchar_t* input) {
    if (input == nullptr) return;
    const int size = WideCharToMultiByte(CP_THREAD_ACP, 0, input, -1, nullptr, 0, nullptr, nullptr);
    if (size <= 0) throw GetLastError();
    value_.resize(static_cast<size_t>(size));
    if (WideCharToMultiByte(CP_THREAD_ACP, 0, input, -1, value_.data(), size, nullptr, nullptr) == 0) {
      throw GetLastError();
    }
    value_.resize(static_cast<size_t>(size - 1));
  }
  operator const char*() const { return value_.c_str(); }
 private:
  std::string value_;
};
