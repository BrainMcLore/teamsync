#define NOMINMAX
#include <windows.h>
#include <shlwapi.h>
#include <wrl.h>
#include <WebView2.h>
#include <cstdio>
#include <string>
#include <filesystem>
#include <chrono>
#include <fstream>

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;
namespace fs = std::filesystem;
HWND window_handle = nullptr;
ComPtr<ICoreWebView2Controller> controller;
ComPtr<ICoreWebView2> view;
ComPtr<ICoreWebView2DownloadOperation> download;
std::wstring output_path, profile_path, source_url, window_title=L"TeamSync", window_message;
bool html_mode = false, script_pending = false;
bool downloading = false, finished = false, hidden_test = false;
int result_code = 1, seconds = 0, timeout_seconds = 300;
long long limit_bytes = 2LL * 1024 * 1024 * 1024;
std::chrono::steady_clock::time_point started;

void emit_error(const char* code) {
  std::printf("{\"phase\":\"error\",\"code\":\"%s\"}\n", code);
  std::fflush(stdout);
}
void finish(int code) {
  if (finished) return;
  finished = true; result_code = code;
  PostMessageW(window_handle, WM_CLOSE, 0, 0);
}
bool allowed(const std::wstring& url) {
  if (url.rfind(L"https://", 0) != 0) return false;
  const auto end = url.find_first_of(L"/?#", 8);
  const auto host = url.substr(8, end == std::wstring::npos ? end : end - 8);
  return host == L"www.hltv.org" || host == L"hltv.org" ||
         host == L"r2-demos.hltv.org" || host == L"demos.hltv.org";
}
void read_html() {
  if (!html_mode || !view || finished || script_pending) return;
  script_pending = true;
  view->ExecuteScript(L"document.querySelector('.result-con, .match-page') && !document.querySelector('#challenge-running, #challenge-stage') ? document.documentElement.outerHTML : null",
    Callback<ICoreWebView2ExecuteScriptCompletedHandler>([](HRESULT status, LPCWSTR json) -> HRESULT {
      script_pending = false;
      if (FAILED(status) || !json || std::wstring(json) == L"null") return S_OK;
      const int size = WideCharToMultiByte(CP_UTF8, 0, json, -1, nullptr, 0, nullptr, nullptr);
      if (size <= 1 || size > 8*1024*1024) { emit_error("catalog_size"); finish(1); return S_OK; }
      std::string bytes(static_cast<size_t>(size), '\0');
      WideCharToMultiByte(CP_UTF8, 0, json, -1, bytes.data(), size, nullptr, nullptr);
      std::ofstream out(fs::path(output_path), std::ios::binary);
      out.write(bytes.data(), size-1); out.close();
      if (!out) { emit_error("catalog_failed"); finish(1); return S_OK; }
      std::puts("{\"phase\":\"html_complete\"}"); std::fflush(stdout); finish(0);
      return S_OK;
    }).Get());
}
void resize() {
  if (!controller) return;
  RECT bounds{}; GetClientRect(window_handle, &bounds); bounds.top = 48;
  controller->put_Bounds(bounds);
}
LRESULT CALLBACK procedure(HWND hwnd, UINT msg, WPARAM w, LPARAM l) {
  switch (msg) {
    case WM_SIZE: resize(); return 0;
    case WM_TIMER:
      ++seconds;
      read_html();
      if (!downloading && seconds == 3) {
        std::puts("{\"phase\":\"source_verification\"}"); std::fflush(stdout);
        if (!hidden_test) { ShowWindow(hwnd, SW_SHOW); SetForegroundWindow(hwnd); }
      }
      if (!downloading && seconds >= timeout_seconds) { emit_error("source_verification_timeout"); finish(1); }
      return 0;
    case WM_CLOSE:
      if (!finished) { if (download) download->Cancel(); emit_error("jobCancelled"); result_code = 2; }
      if (controller) controller->Close();
      DestroyWindow(hwnd); return 0;
    case WM_DESTROY: PostQuitMessage(result_code); return 0;
    default: return DefWindowProcW(hwnd, msg, w, l);
  }
}
void wire_download(ICoreWebView2DownloadStartingEventArgs* args) {
  if (html_mode) { args->put_Cancel(TRUE); emit_error("catalog_failed"); finish(1); return; }
  if (downloading || fs::exists(output_path)) { args->put_Cancel(TRUE); emit_error("download_target_exists"); finish(1); return; }
  args->get_DownloadOperation(&download);
  LPWSTR raw_uri = nullptr; download->get_Uri(&raw_uri);
  const bool valid = raw_uri && allowed(raw_uri); CoTaskMemFree(raw_uri);
  INT64 total = 0; download->get_TotalBytesToReceive(&total);
  ULARGE_INTEGER free_bytes{};
  GetDiskFreeSpaceExW(fs::path(output_path).parent_path().c_str(), &free_bytes, nullptr, nullptr);
  if (!valid || total > limit_bytes || free_bytes.QuadPart < static_cast<ULONGLONG>(total > 0 ? total : 512LL*1024*1024) + 256LL*1024*1024) {
    args->put_Cancel(TRUE); emit_error(valid ? "file_too_large" : "unsafe_download_url"); finish(1); return;
  }
  args->put_ResultFilePath(output_path.c_str()); args->put_Handled(TRUE);
  downloading = true; started = std::chrono::steady_clock::now();
  ShowWindow(window_handle, SW_HIDE);
  std::puts("{\"phase\":\"downloading\"}"); std::fflush(stdout);
  EventRegistrationToken token{};
  download->add_BytesReceivedChanged(Callback<ICoreWebView2BytesReceivedChangedEventHandler>(
    [](ICoreWebView2DownloadOperation* operation, IUnknown*) -> HRESULT {
      INT64 received = 0, total_size = 0;
      operation->get_BytesReceived(&received); operation->get_TotalBytesToReceive(&total_size);
      if (received > limit_bytes) { operation->Cancel(); emit_error("file_too_large"); finish(1); return S_OK; }
      const auto elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
      if (total_size > 0) std::printf("{\"phase\":\"downloading\",\"bytes\":%lld,\"progress\":%.6f,\"speed\":%.0f}\n", received, double(received)/double(total_size), double(received)/(elapsed > .01 ? elapsed : .01));
      else std::printf("{\"phase\":\"downloading\",\"bytes\":%lld}\n",received);
      std::fflush(stdout); return S_OK;
    }).Get(), &token);
  download->add_StateChanged(Callback<ICoreWebView2StateChangedEventHandler>(
    [](ICoreWebView2DownloadOperation* operation, IUnknown*) -> HRESULT {
      COREWEBVIEW2_DOWNLOAD_STATE state{}; operation->get_State(&state);
      if (state == COREWEBVIEW2_DOWNLOAD_STATE_COMPLETED) {
        std::puts("{\"phase\":\"network_complete\"}"); std::fflush(stdout); finish(0);
      } else if (state == COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED) {
        emit_error("native_download_interrupted"); finish(1);
      }
      return S_OK;
    }).Get(), &token);
}
int wmain(int argc, wchar_t** argv) {
  if (argc == 2 && std::wstring(argv[1]) == L"--check-runtime") {
    LPWSTR version = nullptr;
    const HRESULT status = GetAvailableCoreWebView2BrowserVersionString(nullptr, &version);
    const bool present = SUCCEEDED(status) && version;
    CoTaskMemFree(version);
    return present ? 0 : 1;
  }
  for (int i=1; i<argc; ++i) {
    const std::wstring arg = argv[i];
    if (arg == L"--html") html_mode = true;
    else if (arg == L"--hidden-test") hidden_test = true;
    else if (i+1 < argc && arg == L"--window-title") window_title = argv[++i];
    else if (i+1 < argc && arg == L"--window-message") window_message = argv[++i];
    else if (i+1 < argc && arg == L"--url") source_url = argv[++i];
    else if (i+1 < argc && arg == L"--output") output_path = argv[++i];
    else if (i+1 < argc && arg == L"--profile") profile_path = argv[++i];
    else if (i+1 < argc && arg == L"--timeout") timeout_seconds = _wtoi(argv[++i]);
    else { emit_error("invalid_download_arguments"); return 1; }
  }
  if (!allowed(source_url) || output_path.empty() || profile_path.empty() || !fs::path(output_path).is_absolute() || fs::exists(output_path) || !fs::exists(fs::path(output_path).parent_path())) {
    emit_error("invalid_download_arguments"); return 1;
  }
  if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) return 1;
  WNDCLASSW cls{}; cls.lpfnWndProc = procedure; cls.hInstance = GetModuleHandleW(nullptr);
  cls.lpszClassName = L"TeamSyncManagedDownload"; cls.hCursor = LoadCursor(nullptr,IDC_ARROW);
  cls.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW+1); RegisterClassW(&cls);
  window_handle = CreateWindowW(cls.lpszClassName, window_title.c_str(), WS_OVERLAPPEDWINDOW, CW_USEDEFAULT,CW_USEDEFAULT,1000,740,nullptr,nullptr,cls.hInstance,nullptr);
  CreateWindowW(L"STATIC", window_message.c_str(), WS_CHILD|WS_VISIBLE,12,12,950,32,window_handle,nullptr,cls.hInstance,nullptr);
  SetTimer(window_handle,1,1000,nullptr);
  HRESULT init = CreateCoreWebView2EnvironmentWithOptions(nullptr,profile_path.c_str(),nullptr,
    Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>([](HRESULT status, ICoreWebView2Environment* env) -> HRESULT {
      if (FAILED(status) || !env) { emit_error("download_runtime_missing"); finish(1); return S_OK; }
      return env->CreateCoreWebView2Controller(window_handle, Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>([](HRESULT hr, ICoreWebView2Controller* created) -> HRESULT {
        if (FAILED(hr) || !created) { emit_error("download_runtime_failed"); finish(1); return S_OK; }
        controller = created; controller->get_CoreWebView2(&view); controller->put_IsVisible(TRUE); resize();
        ComPtr<ICoreWebView2Settings> settings; view->get_Settings(&settings);
        settings->put_AreDevToolsEnabled(FALSE); settings->put_AreDefaultContextMenusEnabled(FALSE);
        ComPtr<ICoreWebView2Settings4> settings4; if (SUCCEEDED(settings.As(&settings4))) settings4->put_IsGeneralAutofillEnabled(FALSE);
        ComPtr<ICoreWebView2Settings4> password; if (SUCCEEDED(settings.As(&password))) password->put_IsPasswordAutosaveEnabled(FALSE);
        EventRegistrationToken token{};
        view->add_NavigationStarting(Callback<ICoreWebView2NavigationStartingEventHandler>([](ICoreWebView2*, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
          LPWSTR uri = nullptr; args->get_Uri(&uri); bool valid = uri && allowed(uri); CoTaskMemFree(uri);
          if (!valid) { args->put_Cancel(TRUE); emit_error("unsafe_download_url"); finish(1); } return S_OK;
        }).Get(), &token);
        view->add_NewWindowRequested(Callback<ICoreWebView2NewWindowRequestedEventHandler>([](ICoreWebView2*,ICoreWebView2NewWindowRequestedEventArgs* args)->HRESULT { args->put_Handled(TRUE); return S_OK; }).Get(),&token);
        view->add_PermissionRequested(Callback<ICoreWebView2PermissionRequestedEventHandler>([](ICoreWebView2*,ICoreWebView2PermissionRequestedEventArgs* args)->HRESULT { args->put_State(COREWEBVIEW2_PERMISSION_STATE_DENY); return S_OK; }).Get(),&token);
        ComPtr<ICoreWebView2_4> downloads;
        if (FAILED(view.As(&downloads))) { emit_error("download_runtime_old"); finish(1); return S_OK; }
        downloads->add_DownloadStarting(Callback<ICoreWebView2DownloadStartingEventHandler>([](ICoreWebView2*,ICoreWebView2DownloadStartingEventArgs* args)->HRESULT { wire_download(args); return S_OK; }).Get(),&token);
        view->Navigate(source_url.c_str()); return S_OK;
      }).Get());
    }).Get());
  if (FAILED(init)) { emit_error("download_runtime_missing"); finish(1); }
  MSG msg{}; while (GetMessageW(&msg,nullptr,0,0)>0) { TranslateMessage(&msg); DispatchMessageW(&msg); }
  download.Reset(); view.Reset(); controller.Reset(); CoUninitialize();
  return result_code;
}
