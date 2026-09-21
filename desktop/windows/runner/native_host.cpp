#include <windows.h>
#include <objbase.h>
#include <fcntl.h>
#include <io.h>
#include <cstdio>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

bool Reply(const std::string& message) {
  auto size = static_cast<uint32_t>(message.size());
  return fwrite(&size, 4, 1, stdout) == 1 && fwrite(message.data(), 1, size, stdout) == size && fflush(stdout) == 0;
}
int main() {
  _setmode(_fileno(stdin), _O_BINARY); _setmode(_fileno(stdout), _O_BINARY);
  wchar_t value[32768]{}; DWORD bytes = sizeof(value);
  if (RegGetValueW(HKEY_CURRENT_USER, L"Software\\VDM2", L"Inbox", RRF_RT_REG_SZ, nullptr, value, &bytes) != ERROR_SUCCESS) {
    Reply("{\"ok\":false,\"error\":\"Open VDM and register the browser extension in Settings first.\"}"); return 1;
  }
  const std::filesystem::path inbox(value);
  uint32_t size = 0;
  while (fread(&size, 4, 1, stdin) == 1) {
    if (size == 0 || size > 1024 * 1024) return 1;
    std::string input(size, '\0'); if (fread(input.data(), 1, size, stdin) != size) return 1;
    // The native host only transports opaque JSON. Dart validates the protocol.
    // UUID filenames prevent input-controlled paths and concurrent response mixups.
    GUID guid; if (FAILED(CoCreateGuid(&guid))) return 1;
    wchar_t id[40]; StringFromGUID2(guid, id, 40);
    const std::wstring stem(id);
    const auto request = inbox / (stem + L".request");
    const auto partial = inbox / (stem + L".tmp");
    const auto response = inbox / (stem + L".response");
    std::error_code ec;
    const auto heartbeat = inbox / L"heartbeat";
    const auto modified = std::filesystem::last_write_time(heartbeat, ec);
    if (ec || std::filesystem::file_time_type::clock::now() - modified > std::chrono::seconds(4)) {
      wchar_t exe[MAX_PATH]; GetModuleFileNameW(nullptr, exe, MAX_PATH);
      const auto app = std::filesystem::path(exe).parent_path() / L"vdm.exe";
      std::wstring command = L"\"" + app.wstring() + L"\"";
      STARTUPINFOW startup{}; startup.cb = sizeof(startup); PROCESS_INFORMATION process{};
      if (CreateProcessW(app.c_str(), command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, app.parent_path().c_str(), &startup, &process)) {
        CloseHandle(process.hThread); CloseHandle(process.hProcess);
      }
    }
    { std::ofstream file(partial, std::ios::binary); file.write(input.data(), static_cast<std::streamsize>(input.size())); if (!file) { Reply("{\"ok\":false,\"error\":\"Cannot send to VDM\"}"); continue; } }
    if (!MoveFileW(partial.c_str(), request.c_str())) return 1;
    bool answered = false;
    for (int i = 0; i < 250; ++i) {
      Sleep(100);
      if (!std::filesystem::exists(response, ec)) continue;
      std::ifstream file(response, std::ios::binary);
      const std::string message((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
      file.close(); if (message.empty()) continue;
      Reply(message); std::filesystem::remove(response, ec); answered = true; break;
    }
    if (!answered) { Reply("{\"ok\":false,\"error\":\"VDM did not respond\"}"); std::filesystem::remove(request, ec); }
  }
  return 0;
}
