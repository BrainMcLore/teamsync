#include <windows.h>
#include <shellapi.h>
#include "reminders.h"
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Data.Xml.Dom.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.UI.Notifications.h>
#include <chrono>
#include <map>
#include <regex>
#include <set>
#include <string>
#include <stdexcept>
#include <vector>

namespace {
using namespace winrt::Windows::UI::Notifications;
using flutter::EncodableValue;
using flutter::EncodableMap;
using flutter::EncodableList;
constexpr wchar_t kApp[] = L"TeamSync.Desktop";
constexpr wchar_t kGroup[] = L"ts-reminders";
int64_t Now() { return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count(); }
const EncodableValue& Get(const EncodableMap& m, const char* key) {
  auto found = m.find(EncodableValue(key));
  if (found == m.end()) throw std::runtime_error("Missing argument");
  return found->second;
}
int64_t Number(const EncodableValue& v) {
  if (auto n = std::get_if<int64_t>(&v)) return *n;
  if (auto n = std::get_if<int32_t>(&v)) return *n;
  throw std::runtime_error("Invalid time");
}
auto Notifier() { return ToastNotificationManager::CreateToastNotifier(kApp); }
auto Xml(const std::string& title, const std::string& body) {
  winrt::Windows::Data::Xml::Dom::XmlDocument doc;
  doc.LoadXml(L"<toast activationType='protocol' launch='teamsync-reminder://open'><visual><binding template='ToastGeneric'><text/><text/></binding></visual></toast>");
  auto nodes = doc.GetElementsByTagName(L"text");
  nodes.Item(0).AppendChild(doc.CreateTextNode(winrt::to_hstring(title)));
  nodes.Item(1).AppendChild(doc.CreateTextNode(winrt::to_hstring(body)));
  return doc;
}
struct Item { std::string id, title, body; int64_t at, start; };
int Replace(const EncodableMap& args) {
  const auto& input = std::get<EncodableList>(Get(args, "items"));
  if (input.size() > 64) throw std::runtime_error("Too many reminders");
  std::map<std::string, Item> desired;
  const auto now = Now();
  for (const auto& value : input) {
    const auto& m = std::get<EncodableMap>(value);
    Item item{std::get<std::string>(Get(m,"id")),std::get<std::string>(Get(m,"title")),
      std::get<std::string>(Get(m,"body")),Number(Get(m,"at")),Number(Get(m,"start"))};
    if (!std::regex_match(item.id,std::regex("[a-f0-9]{16}")) || item.title.size()>320 || item.body.size()>1600 ||
        item.at<0 || item.start<item.at || item.start>now+31LL*86400000 || item.start-item.at>120*60000)
      throw std::runtime_error("Invalid reminder");
    if (desired.count(item.id)) throw std::runtime_error("Duplicate reminder");
    if (item.start+300000>now) desired.emplace(item.id,std::move(item));
  }
  auto notifier = Notifier();
  std::vector<ScheduledToastNotification> previous;
  for (const auto& item : notifier.GetScheduledToastNotifications()) if (item.Group()==kGroup) previous.push_back(item);
  std::set<std::string> retained;
  for (const auto& old : previous) {
    auto id = winrt::to_string(old.Tag());
    auto found = desired.find(id);
    if (found!=desired.end() && (found->second.at<=now || old.Content().GetXml()==Xml(found->second.title,found->second.body).GetXml())) {
      retained.insert(id);
    } else notifier.RemoveFromSchedule(old);
  }
  for (const auto& entry : desired) {
    const auto& item = entry.second;
    if (retained.count(item.id) || item.at<=now) continue;
    auto date = winrt::clock::from_sys(std::chrono::system_clock::time_point(std::chrono::milliseconds(item.at)));
    ScheduledToastNotification toast(Xml(item.title,item.body), date);
    toast.Tag(winrt::to_hstring(item.id)); toast.Id(winrt::to_hstring(item.id)); toast.Group(kGroup);
    notifier.AddToSchedule(toast);
    retained.insert(item.id);
  }
  return static_cast<int>(retained.size());
}
void Clear() {
  auto notifier = Notifier();
  std::vector<ScheduledToastNotification> items;
  for (const auto& item : notifier.GetScheduledToastNotifications()) if (item.Group()==kGroup) items.push_back(item);
  for (const auto& item : items) notifier.RemoveFromSchedule(item);
  // Older unpackaged Windows APIs may not allow removing already shown history.
  try { ToastNotificationManager::History().RemoveGroup(kGroup, kApp); } catch (const winrt::hresult_error&) { }
}
}
bool ClearScheduledReminders() {
  try { Clear(); return true; } catch (...) { return false; }
}
ReminderChannel::ReminderChannel(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(messenger,"app.teamsync/reminders",&flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([](const auto& call, auto result) {
    try {
      if (call.method_name()=="status") {
        auto notifier = Notifier(); int count=0;
        for (const auto& item : notifier.GetScheduledToastNotifications()) if (item.Group()==kGroup) ++count;
        result->Success(EncodableValue(EncodableMap{{EncodableValue("supported"),EncodableValue(true)},
          {EncodableValue("enabled"),EncodableValue(notifier.Setting()==NotificationSetting::Enabled)},
          {EncodableValue("count"),EncodableValue(count)}}));
      } else if (call.method_name()=="requestPermission") {
        result->Success(EncodableValue(Notifier().Setting()==NotificationSetting::Enabled));
      } else if (call.method_name()=="replace") {
        result->Success(EncodableValue(Replace(std::get<EncodableMap>(*call.arguments()))));
      } else if (call.method_name()=="clear") { Clear(); result->Success(); }
      else if (call.method_name()=="settings") {
        ShellExecuteW(nullptr,L"open",L"ms-settings:notifications",nullptr,nullptr,SW_SHOWNORMAL); result->Success();
      } else if (call.method_name()=="test") {
        const auto& args = std::get<EncodableMap>(*call.arguments());
        ToastNotification toast(Xml(std::get<std::string>(Get(args,"title")),std::get<std::string>(Get(args,"body"))));
        toast.Group(kGroup); toast.Tag(L"test"); Notifier().Show(toast); result->Success(EncodableValue(true));
      } else result->NotImplemented();
    } catch (const winrt::hresult_error&) { result->Error("reminderUnavailable","Windows notifications are unavailable"); }
      catch (const std::exception&) { result->Error("reminderUnavailable","Invalid notification request"); }
  });
}
