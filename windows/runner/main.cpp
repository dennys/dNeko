#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // 桌寵只能有一隻：重開 exe 不要再跑出第二顆寵物（兩顆會互相搶存檔，
  // 而第二顆的 controller 讀到的餓度是舊的）。named mutex 就夠，不用 IPC。
  HANDLE single_instance = ::CreateMutexW(nullptr, TRUE, L"dNeko.Pet.SingleInstance");
  if (single_instance == nullptr || ::GetLastError() == ERROR_ALREADY_EXISTS) {
    if (single_instance != nullptr) ::CloseHandle(single_instance);
    return EXIT_FAILURE;
  }

  FlutterWindow window(project);
  // 初始幾何隨意（真正的大小/位置由 Dart 依設定與存檔決定，且 runner 不會自己 Show()）；
  // 給個接近預設寵物尺寸的預設值，省掉一次 surface 重建。
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(120, 120);
  if (!window.Create(L"dNekoPet", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::ReleaseMutex(single_instance);
  ::CloseHandle(single_instance);
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
