#include <windows.h>

#include <algorithm>
#include <cwctype>
#include <filesystem>
#include <string>
#include <vector>

namespace fs = std::filesystem;

namespace {

std::wstring ReadArgument(const std::vector<std::wstring>& arguments,
                          const std::wstring& name) {
  for (size_t index = 0; index + 1 < arguments.size(); ++index) {
    if (arguments[index] == name) return arguments[index + 1];
  }
  return L"";
}

std::wstring QuotePowerShell(const std::wstring& value) {
  std::wstring escaped;
  escaped.reserve(value.size() + 8);
  for (const wchar_t character : value) {
    escaped += character == L'\'' ? L"''" : std::wstring(1, character);
  }
  return L"'" + escaped + L"'";
}

std::wstring Lower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(), towlower);
  return value;
}

bool IsInside(const fs::path& child, const fs::path& parent) {
  const std::wstring child_value = Lower(child.lexically_normal().wstring());
  std::wstring parent_value = Lower(parent.lexically_normal().wstring());
  if (!parent_value.empty() && parent_value.back() != L'\\') {
    parent_value += L'\\';
  }
  return child_value.starts_with(parent_value);
}

int Fail(const std::wstring& message) {
  MessageBoxW(nullptr, message.c_str(), L"MBNDL updater", MB_OK | MB_ICONERROR);
  return 1;
}

}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  int argument_count = 0;
  LPWSTR* raw_arguments = CommandLineToArgvW(GetCommandLineW(), &argument_count);
  if (raw_arguments == nullptr) return Fail(L"Could not read updater arguments.");

  std::vector<std::wstring> arguments(raw_arguments, raw_arguments + argument_count);
  LocalFree(raw_arguments);

  const fs::path package = ReadArgument(arguments, L"--package");
  const fs::path target = ReadArgument(arguments, L"--target");
  const fs::path restart = ReadArgument(arguments, L"--restart");
  const std::wstring process_id_value = ReadArgument(arguments, L"--pid");
  if (package.empty() || target.empty() || restart.empty() ||
      process_id_value.empty()) {
    return Fail(L"The updater received incomplete arguments.");
  }

  std::error_code error;
  const fs::path absolute_package = fs::absolute(package, error).lexically_normal();
  if (error || !fs::is_regular_file(absolute_package, error) ||
      Lower(absolute_package.extension().wstring()) != L".zip") {
    return Fail(L"The downloaded update package is missing or invalid.");
  }
  const fs::path absolute_target = fs::absolute(target, error).lexically_normal();
  if (error || absolute_target == absolute_target.root_path() ||
      absolute_target.wstring().size() < 4) {
    return Fail(L"The MBNDL installation folder is invalid.");
  }
  const fs::path absolute_restart = fs::absolute(restart, error).lexically_normal();
  if (error || !IsInside(absolute_restart, absolute_target)) {
    return Fail(L"The restart executable is outside the MBNDL folder.");
  }

  const DWORD process_id = wcstoul(process_id_value.c_str(), nullptr, 10);
  if (process_id > 0) {
    HANDLE process = OpenProcess(SYNCHRONIZE, FALSE, process_id);
    if (process != nullptr) {
      WaitForSingleObject(process, 120000);
      CloseHandle(process);
    }
  }

  wchar_t temporary_directory[MAX_PATH] = {};
  if (GetTempPathW(MAX_PATH, temporary_directory) == 0) {
    return Fail(L"Windows did not provide a temporary folder.");
  }
  const fs::path staging = fs::path(temporary_directory) /
                           (L"MBNDL-install-" + std::to_wstring(GetCurrentProcessId()));

  const std::wstring command =
      L"$ErrorActionPreference='Stop'; "
      L"$stage=" + QuotePowerShell(staging.wstring()) + L"; "
      L"if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }; "
      L"New-Item -ItemType Directory -Path $stage -Force | Out-Null; "
      L"Expand-Archive -LiteralPath " + QuotePowerShell(absolute_package.wstring()) +
      L" -DestinationPath $stage -Force; "
      L"Copy-Item -Path (Join-Path $stage '*') -Destination " +
      QuotePowerShell(absolute_target.wstring()) + L" -Recurse -Force; "
      L"Start-Process -FilePath " + QuotePowerShell(absolute_restart.wstring()) + L"; "
      L"Remove-Item -LiteralPath $stage -Recurse -Force";

  std::wstring command_line =
      L"powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"" +
      command + L"\"";
  STARTUPINFOW startup = {};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION process_info = {};
  if (!CreateProcessW(nullptr, command_line.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, nullptr, &startup,
                      &process_info)) {
    return Fail(L"Windows could not start the update installer.");
  }

  WaitForSingleObject(process_info.hProcess, INFINITE);
  DWORD exit_code = 1;
  GetExitCodeProcess(process_info.hProcess, &exit_code);
  CloseHandle(process_info.hThread);
  CloseHandle(process_info.hProcess);
  if (exit_code != 0) {
    return Fail(L"The update could not be installed. Reopen MBNDL and try again.");
  }
  return 0;
}
