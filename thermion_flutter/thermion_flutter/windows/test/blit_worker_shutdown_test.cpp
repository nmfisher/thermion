// Run by run_blit_worker_shutdown_test.ps1 in a separate process for each case.
// Keep the fixture DLL loaded until process exit so its CRT detach handlers
// execute against the unmodified production plugin implementation.
#include <windows.h>

#include <cstdio>
#include <cstdlib>
#include <cwchar>

int wmain(int argc, wchar_t* argv[]) {
  // A regression must report its exit code instead of opening a crash dialog.
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
  if (argc != 3) {
    return 2;
  }
  const auto module = LoadLibraryW(argv[1]);
  if (!module) {
    std::fprintf(stderr, "LoadLibrary failed: %lu\n", GetLastError());
    return 3;
  }
  if (std::wcscmp(argv[2], L"no-worker") == 0) {
    std::puts("plugin-loaded");
    std::fflush(stdout);
    ExitProcess(0);
  }

  using StartWorker = void* (*)();
  using DestroyPlugin = void (*)(void*);
  const auto start = reinterpret_cast<StartWorker>(
      GetProcAddress(module, "ThermionTestStartBlitWorker"));
  const auto destroy = reinterpret_cast<DestroyPlugin>(
      GetProcAddress(module, "ThermionTestDestroyPlugin"));
  if (!start || !destroy) {
    std::fprintf(stderr, "Missing shutdown fixture entry points\n");
    return 4;
  }
  auto* plugin = start();
  std::puts("worker-started");
  std::fflush(stdout);

  if (std::wcscmp(argv[2], L"normal-teardown") == 0) {
    destroy(plugin);
    std::puts("plugin-destroyed");
    std::fflush(stdout);
    return 0;
  }
  if (std::wcscmp(argv[2], L"exit-process") == 0) {
    ExitProcess(0);
  }
  if (std::wcscmp(argv[2], L"crt-exit") == 0) {
    std::exit(0);
  }
  destroy(plugin);
  return 2;
}
