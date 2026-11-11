// ZETX PC ARIZA TAKİP ONARIM - başlatıcı (konsolsuz)
#include <windows.h>
#include <shlwapi.h>
#include <wchar.h>

int WINAPI wWinMain(HINSTANCE h, HINSTANCE p, LPWSTR args, int show) {
    wchar_t dir[MAX_PATH], ps1[MAX_PATH], psexe[MAX_PATH], cmd[4096];
    GetModuleFileNameW(NULL, dir, MAX_PATH);
    PathRemoveFileSpecW(dir);
    swprintf(ps1, MAX_PATH, L"%ls\\ZETX-PC-Ariza-Takip-Onarim.ps1", dir);
    if (GetFileAttributesW(ps1) == INVALID_FILE_ATTRIBUTES) {
        MessageBoxW(NULL, L"Program dosyası bulunamadı. Lütfen programı yeniden kurun.", L"ZETX PC ARIZA TAKİP ONARIM", MB_ICONERROR);
        return 1;
    }
    GetSystemDirectoryW(psexe, MAX_PATH);
    wcscat(psexe, L"\\WindowsPowerShell\\v1.0\\powershell.exe");
    swprintf(cmd, 4096, L"\"%ls\" -NoProfile -ExecutionPolicy Bypass -STA -File \"%ls\" %ls", psexe, ps1, args ? args : L"");
    STARTUPINFOW si; PROCESS_INFORMATION pi;
    // ÖNEMLİ: STARTF_USESHOWWINDOW/SW_HIDE KULLANMA — Windows bunu programın ilk penceresine (ana form) uygular ve form görünmez açılır.
    ZeroMemory(&si, sizeof(si)); si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));
    if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, dir, &si, &pi)) {
        MessageBoxW(NULL, L"Windows PowerShell başlatılamadı.", L"ZETX PC ARIZA TAKİP ONARIM", MB_ICONERROR);
        return 2;
    }
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
    return 0;
}
