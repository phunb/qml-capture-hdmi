#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <string>

namespace {

std::wstring parentDir(const std::wstring &path)
{
    const size_t pos = path.find_last_of(L"\\/");
    if (pos == std::wstring::npos)
        return path;
    return path.substr(0, pos);
}

std::wstring join(const std::wstring &a, const std::wstring &b)
{
    if (a.empty())
        return b;
    if (a.back() == L'\\' || a.back() == L'/')
        return a + b;
    return a + L'\\' + b;
}

bool samePath(const std::wstring &a, const std::wstring &b)
{
    wchar_t fa[MAX_PATH];
    wchar_t fb[MAX_PATH];
    if (!GetFullPathNameW(a.c_str(), MAX_PATH, fa, nullptr))
        return false;
    if (!GetFullPathNameW(b.c_str(), MAX_PATH, fb, nullptr))
        return false;
    return _wcsicmp(fa, fb) == 0;
}

bool copyTree(const std::wstring &src, const std::wstring &dst)
{
    if (!CreateDirectoryW(dst.c_str(), nullptr) && GetLastError() != ERROR_ALREADY_EXISTS)
        return false;

    WIN32_FIND_DATAW fd{};
    const std::wstring spec = join(src, L"*");
    const HANDLE find = FindFirstFileW(spec.c_str(), &fd);
    if (find == INVALID_HANDLE_VALUE)
        return false;

    bool ok = true;
    do {
        const std::wstring name = fd.cFileName;
        if (name == L"." || name == L"..")
            continue;
        const std::wstring from = join(src, name);
        const std::wstring to = join(dst, name);
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            if (!copyTree(from, to))
                ok = false;
        } else if (!CopyFileW(from.c_str(), to.c_str(), FALSE)) {
            ok = false;
        }
    } while (FindNextFileW(find, &fd));
    FindClose(find);
    return ok;
}

bool createShortcut(const std::wstring &lnk, const std::wstring &target, const std::wstring &workDir)
{
    IShellLinkW *link = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_IShellLinkW, reinterpret_cast<void **>(&link));
    if (FAILED(hr) || !link)
        return false;
    link->SetPath(target.c_str());
    link->SetWorkingDirectory(workDir.c_str());
    IPersistFile *persist = nullptr;
    hr = link->QueryInterface(IID_IPersistFile, reinterpret_cast<void **>(&persist));
    bool saved = false;
    if (SUCCEEDED(hr) && persist) {
        saved = SUCCEEDED(persist->Save(lnk.c_str(), TRUE));
        persist->Release();
    }
    link->Release();
    return saved;
}

void addAutostart(const std::wstring &exe)
{
    HKEY key = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER,
                        L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
                        0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
        return;
    }
    const std::wstring value = L"\"" + exe + L"\"";
    RegSetValueExW(key, L"HdmiKiosk", 0, REG_SZ,
                   reinterpret_cast<const BYTE *>(value.c_str()),
                   static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(key);
}

std::wstring specialFolder(int csidl)
{
    wchar_t path[MAX_PATH]{};
    if (FAILED(SHGetFolderPathW(nullptr, csidl, nullptr, SHGFP_TYPE_CURRENT, path)))
        return {};
    return path;
}

} // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    wchar_t modulePath[MAX_PATH]{};
    if (!GetModuleFileNameW(nullptr, modulePath, MAX_PATH)) {
        MessageBoxW(nullptr, L"Không đọc được đường dẫn bộ cài.", L"HDMI Kiosk", MB_ICONERROR);
        return 1;
    }

    const std::wstring srcDir = parentDir(modulePath);
    const std::wstring srcExe = join(srcDir, L"hdmi-kiosk.exe");
    if (GetFileAttributesW(srcExe.c_str()) == INVALID_FILE_ATTRIBUTES) {
        MessageBoxW(nullptr,
                    L"Không thấy hdmi-kiosk.exe trong cùng folder với bộ cài.\n"
                    L"Hãy copy cả folder (exe + DLL), không copy một mình file setup.",
                    L"HDMI Kiosk", MB_ICONERROR);
        return 1;
    }

    const int answer = MessageBoxW(
        nullptr,
        L"Cài HDMI Kiosk vào máy này?\n\n"
        L"App sẽ được copy vào thư mục người dùng, tạo shortcut Desktop\n"
        L"và tự chạy khi đăng nhập Windows.\n\n"
        L"Máy không cần mạng và không cần cài Qt.",
        L"HDMI Kiosk",
        MB_ICONQUESTION | MB_OKCANCEL);
    if (answer != IDOK)
        return 0;

    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    const std::wstring localApp = specialFolder(CSIDL_LOCAL_APPDATA);
    if (localApp.empty()) {
        MessageBoxW(nullptr, L"Không lấy được AppData.", L"HDMI Kiosk", MB_ICONERROR);
        CoUninitialize();
        return 1;
    }

    const std::wstring destDir = join(localApp, L"HdmiKiosk");
    if (!samePath(srcDir, destDir)) {
        if (!copyTree(srcDir, destDir)) {
            MessageBoxW(nullptr, L"Không copy được file vào máy.", L"HDMI Kiosk", MB_ICONERROR);
            CoUninitialize();
            return 1;
        }
    }

    const std::wstring destExe = join(destDir, L"hdmi-kiosk.exe");
    addAutostart(destExe);

    const std::wstring desktop = specialFolder(CSIDL_DESKTOPDIRECTORY);
    if (!desktop.empty())
        createShortcut(join(desktop, L"HDMI Kiosk.lnk"), destExe, destDir);

    const std::wstring programs = specialFolder(CSIDL_PROGRAMS);
    if (!programs.empty())
        createShortcut(join(programs, L"HDMI Kiosk.lnk"), destExe, destDir);

    const std::wstring done = L"Đã cài xong:\n" + destDir
        + L"\n\nTự chạy khi đăng nhập Windows.\nThoát kiosk: Ctrl+Alt+Shift+Q\n\nMở app ngay?";
    if (MessageBoxW(nullptr, done.c_str(), L"HDMI Kiosk", MB_ICONINFORMATION | MB_YESNO) == IDYES)
        ShellExecuteW(nullptr, L"open", destExe.c_str(), nullptr, destDir.c_str(), SW_SHOWNORMAL);

    CoUninitialize();
    return 0;
}
