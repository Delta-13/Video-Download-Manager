#include "native_bridge.h"
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <wincrypt.h>
#include <aclapi.h>
#include <sddl.h>
#include <map>
#include <memory>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
std::unique_ptr<flutter::MethodChannel<Value>> channel;
std::map<DWORD, HANDLE> jobs;
std::wstring inbox;
std::wstring Wide(const std::string& s) {
  const int count = MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
  std::wstring out(count, 0);
  MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), count);
  return out;
}
std::string Utf8(const std::wstring& s) {
  const int count = WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0, nullptr, nullptr);
  std::string out(count, 0);
  WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), count, nullptr, nullptr);
  return out;
}
std::string JsonString(const std::string& s) {
  std::string out = "\"";
  for (char c : s) { if (c == '\\' || c == '"') out += '\\'; out += c; }
  return out + "\"";
}
DWORD Pid(const Value* value) {
  const auto& map = std::get<Map>(*value);
  const auto& number = map.at(Value("pid"));
  if (const auto* n = std::get_if<int32_t>(&number)) return static_cast<DWORD>(*n);
  return static_cast<DWORD>(std::get<int64_t>(number));
}
bool SetRegistry(const std::wstring& key, const std::wstring& name, const std::wstring& value) {
  HKEY handle;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, key.c_str(), 0, nullptr, 0, KEY_SET_VALUE, nullptr, &handle, nullptr) != ERROR_SUCCESS) return false;
  const auto status = RegSetValueExW(handle, name.c_str(), 0, REG_SZ, reinterpret_cast<const BYTE*>(value.c_str()), static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(handle); return status == ERROR_SUCCESS;
}
bool Restrict(const std::wstring& path) {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
  DWORD size = 0; GetTokenInformation(token, TokenUser, nullptr, 0, &size);
  std::vector<BYTE> buffer(size);
  const BOOL ok = GetTokenInformation(token, TokenUser, buffer.data(), size, &size);
  CloseHandle(token); if (!ok) return false;
  LPWSTR sid = nullptr;
  if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &sid)) return false;
  std::wstring sddl = L"D:P(A;OICI;FA;;;" + std::wstring(sid) + L")(A;OICI;FA;;;SY)";
  LocalFree(sid);
  PSECURITY_DESCRIPTOR sd = nullptr;
  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(), SDDL_REVISION_1, &sd, nullptr)) return false;
  const BOOL applied = SetFileSecurityW(path.c_str(), DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION, sd);
  LocalFree(sd); return applied != FALSE;
}
}

void RegisterNativeBridge(flutter::BinaryMessenger* messenger) {
  channel = std::make_unique<flutter::MethodChannel<Value>>(messenger, "io.vdm/native", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const flutter::MethodCall<Value>& call, std::unique_ptr<flutter::MethodResult<Value>> result) {
    const auto& name = call.method_name();
    const auto* args = call.arguments();
    if (name == "attachProcess") {
      DWORD pid = Pid(args);
      HANDLE job = CreateJobObjectW(nullptr, nullptr);
      JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
      limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
      HANDLE process = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE, FALSE, pid);
      const bool ok = job && process && SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits)) && AssignProcessToJobObject(job, process);
      if (process) CloseHandle(process);
      if (!ok) { if (job) CloseHandle(job); result->Error("process", "Cannot supervise engine process"); return; }
      jobs[pid] = job; result->Success();
    } else if (name == "terminateProcess" || name == "releaseProcess") {
      const auto it = jobs.find(Pid(args));
      if (it != jobs.end()) { if (name == "terminateProcess") TerminateJobObject(it->second, 1); CloseHandle(it->second); jobs.erase(it); }
      result->Success();
    } else if (name == "protect" || name == "unprotect") {
      const auto& bytes = std::get<std::vector<uint8_t>>(*args);
      DATA_BLOB in{static_cast<DWORD>(bytes.size()), const_cast<BYTE*>(bytes.data())}, out{};
      const BOOL ok = name == "protect" ? CryptProtectData(&in, L"VDM2 cookies", nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &out)
        : CryptUnprotectData(&in, nullptr, nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &out);
      if (!ok) { result->Error("credentials", "Windows could not access the protected cookies"); return; }
      std::vector<uint8_t> data(out.pbData, out.pbData + out.cbData);
      SecureZeroMemory(out.pbData, out.cbData); LocalFree(out.pbData); result->Success(Value(data));
    } else if (name == "restrictFile") {
      if (!Restrict(Wide(std::get<std::string>(*args)))) { result->Error("permissions", "Cannot restrict credential file permissions"); return; }
      result->Success();
    } else if (name == "moveExclusive") {
      const auto& map = std::get<Map>(*args);
      const auto from = Wide(std::get<std::string>(map.at(Value("from"))));
      const auto to = Wide(std::get<std::string>(map.at(Value("to"))));
      if (MoveFileExW(from.c_str(), to.c_str(), MOVEFILE_WRITE_THROUGH)) { result->Success(Value(true)); return; }
      const auto error = GetLastError();
      if (error == ERROR_ALREADY_EXISTS || error == ERROR_FILE_EXISTS) { result->Success(Value(false)); }
      else { result->Error("publish", "Cannot publish completed file", Value(static_cast<int64_t>(error))); }
    } else if (name == "startInbox") {
      inbox = Wide(std::get<std::string>(*args));
      if (!SetRegistry(L"Software\\VDM2", L"Inbox", inbox)) { result->Error("registry", "Cannot configure native messaging"); return; }
      result->Success();
    } else if (name == "registerBrowser") {
      const auto id = std::get<std::string>(*args);
      if (id.size() != 32 || id.find_first_not_of("abcdefghijklmnop") != std::string::npos || inbox.empty()) { result->Error("extension", "Invalid extension id"); return; }
      wchar_t exe[MAX_PATH]; GetModuleFileNameW(nullptr, exe, MAX_PATH);
      const auto host = std::filesystem::path(exe).parent_path() / L"vdm_native_host.exe";
      const auto manifest = std::filesystem::path(inbox).parent_path() / L"native-host.json";
      std::ofstream out(manifest, std::ios::binary);
      out << "{\"name\":\"io.vdm.bridge\",\"description\":\"VDM 2 browser bridge\",\"path\":" << JsonString(Utf8(host.wstring()))
          << ",\"type\":\"stdio\",\"allowed_origins\":[\"chrome-extension://" << id << "/\"]}";
      out.close();
      if (!out || !SetRegistry(L"Software\\Google\\Chrome\\NativeMessagingHosts\\io.vdm.bridge", L"", manifest.wstring()) ||
          !SetRegistry(L"Software\\Microsoft\\Edge\\NativeMessagingHosts\\io.vdm.bridge", L"", manifest.wstring())) {
        result->Error("registry", "Cannot register browser host"); return;
      }
      result->Success();
    } else { result->NotImplemented(); }
  });
}
void CloseNativeBridge() {
  channel.reset(); for (const auto& entry : jobs) CloseHandle(entry.second); jobs.clear();
}
