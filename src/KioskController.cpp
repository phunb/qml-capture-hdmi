#include "KioskController.h"
#include "CaptureController.h"
#include "RecordingManager.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QProcess>
#ifdef Q_OS_WIN
#  include <QMetaObject>
#endif
#include <QtGlobal>

#ifdef Q_OS_WIN
KioskController *KioskController::s_instance = nullptr;
#endif

namespace {

bool idleShutdownDisabled()
{
    if (qEnvironmentVariableIntValue("HDMI_KIOSK_SMOKE_TEST") > 0)
        return true;
    const QString flag = qEnvironmentVariable("HDMI_KIOSK_IDLE_SHUTDOWN");
    if (flag.isEmpty())
        return false;
    return flag == QLatin1String("0")
        || flag.compare(QLatin1String("false"), Qt::CaseInsensitive) == 0
        || flag.compare(QLatin1String("off"), Qt::CaseInsensitive) == 0;
}

int idleShutdownMinutes()
{
    const int minutes = qEnvironmentVariableIntValue("HDMI_KIOSK_IDLE_MINUTES");
    return minutes > 0 ? minutes : 15;
}

#ifdef Q_OS_WIN
bool enableShutdownPrivilege()
{
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &token))
        return false;

    TOKEN_PRIVILEGES privileges{};
    privileges.PrivilegeCount = 1;
    privileges.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    if (!LookupPrivilegeValueW(nullptr, SE_SHUTDOWN_NAME, &privileges.Privileges[0].Luid)) {
        CloseHandle(token);
        return false;
    }

    AdjustTokenPrivileges(token, FALSE, &privileges, 0, nullptr, nullptr);
    const DWORD err = GetLastError();
    CloseHandle(token);
    return err == ERROR_SUCCESS;
}
#endif

} // namespace

KioskController::KioskController(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_WIN
    s_instance = this;
#endif
    m_idleTimer.setSingleShot(true);
    m_idleTick.setInterval(1000);
    connect(&m_idleTimer, &QTimer::timeout, this, &KioskController::onIdleTimeout);
    connect(&m_idleTick, &QTimer::timeout, this, [this]() {
        emit idlePowerOffRemainingSecChanged();
    });
}

KioskController::~KioskController()
{
    removeOsHooks();
#ifdef Q_OS_WIN
    if (s_instance == this)
        s_instance = nullptr;
#endif
}

void KioskController::attachWindow(QObject *windowObject)
{
    auto *window = qobject_cast<QWindow *>(windowObject);
    if (m_window == window)
        return;
    m_window = window;
    applyWindowState();
    installOsHooks();
}

void KioskController::setLocked(bool locked)
{
    if (m_locked == locked)
        return;
    m_locked = locked;
    applyWindowState();
    if (m_locked)
        installOsHooks();
    else
        removeOsHooks();
    emit lockedChanged();
}

bool KioskController::requestAdminExit()
{
    emit adminExitRequested();
    return true;
}

void KioskController::exitApp()
{
    setLocked(false);
#ifndef Q_OS_WIN
    QFile flag(QDir::home().filePath(QStringLiteral(".hdmi-kiosk-maintenance")));
    if (flag.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        flag.write("maintenance\n");
        flag.close();
        qInfo() << "Admin exit: skip kiosk autostart until reboot";
    } else {
        qWarning() << "Could not write kiosk maintenance flag" << flag.fileName();
    }
#endif
    QGuiApplication::quit();
}

int KioskController::idlePowerOffRemainingSec() const
{
    if (!m_idleTimer.isActive())
        return 0;
    const int ms = m_idleTimer.remainingTime();
    return ms > 0 ? (ms + 999) / 1000 : 0;
}

void KioskController::watchIdlePowerOff(CaptureController *capture, RecordingManager *recordings)
{
    m_capture = capture;
    m_recordings = recordings;
    if (!capture || idleShutdownDisabled()) {
        qInfo() << "Idle OS power-off disabled";
        return;
    }

    m_idleWatchEnabled = true;
    m_idleTimer.setInterval(idleShutdownMinutes() * 60 * 1000);
    connect(capture, &CaptureController::videoPresentChanged, this, &KioskController::syncIdleTimer);
    connect(capture, &CaptureController::recordingChanged, this, &KioskController::syncIdleTimer);
    if (recordings)
        connect(recordings, &RecordingManager::copyingChanged, this, &KioskController::syncIdleTimer);

    qInfo() << "Idle OS power-off after" << idleShutdownMinutes() << "min without HDMI video";
    syncIdleTimer();
}

void KioskController::syncIdleTimer()
{
    if (!m_idleWatchEnabled || m_shuttingDown || !m_capture)
        return;

    const bool busy = m_capture->recording() || (m_recordings && m_recordings->copying());
    const bool idle = !m_capture->videoPresent() && !busy;
    if (idle) {
        if (!m_idleTimer.isActive()) {
            m_idleTimer.start();
            m_idleTick.start();
            qInfo() << "No HDMI video; OS power-off in" << idleShutdownMinutes() << "min";
            emit idlePowerOffRemainingSecChanged();
        }
        return;
    }

    if (m_idleTimer.isActive()) {
        m_idleTimer.stop();
        m_idleTick.stop();
        emit idlePowerOffRemainingSecChanged();
        qInfo() << "HDMI video present; idle power-off cancelled";
    }
}

void KioskController::onIdleTimeout()
{
    m_idleTick.stop();
    emit idlePowerOffRemainingSecChanged();
    if (!m_capture || m_capture->videoPresent()) {
        syncIdleTimer();
        return;
    }
    qWarning() << "No HDMI video for" << idleShutdownMinutes() << "min; powering off OS";
    performOsShutdown();
}

void KioskController::performOsShutdown()
{
    if (m_powerOffIssued)
        return;

    m_shuttingDown = true;
    m_idleTimer.stop();
    m_idleTick.stop();

    if (m_capture && m_capture->recording()) {
        m_capture->stopRecording();
        QTimer::singleShot(2000, this, &KioskController::performOsShutdown);
        return;
    }
    if (m_recordings && m_recordings->copying()) {
        qInfo() << "Waiting for USB copy before OS power-off";
        QTimer::singleShot(1000, this, &KioskController::performOsShutdown);
        return;
    }

    m_powerOffIssued = true;

#ifdef Q_OS_WIN
    if (enableShutdownPrivilege()) {
        if (ExitWindowsEx(EWX_POWEROFF | EWX_FORCEIFHUNG,
                          SHTDN_REASON_MAJOR_APPLICATION | SHTDN_REASON_MINOR_MAINTENANCE
                              | SHTDN_REASON_FLAG_PLANNED)) {
            return;
        }
        qWarning() << "ExitWindowsEx failed" << GetLastError();
    }
    if (!QProcess::startDetached(QStringLiteral("shutdown"),
                                 {QStringLiteral("/s"), QStringLiteral("/t"), QStringLiteral("0"),
                                  QStringLiteral("/f")})) {
        qWarning() << "Windows shutdown command failed";
    }
#else
    if (QProcess::startDetached(QStringLiteral("systemctl"), {QStringLiteral("poweroff")}))
        return;
    if (QProcess::startDetached(QStringLiteral("loginctl"), {QStringLiteral("poweroff")}))
        return;
    if (QProcess::startDetached(QStringLiteral("sudo"),
                                {QStringLiteral("-n"), QStringLiteral("systemctl"), QStringLiteral("poweroff")}))
        return;
    if (QProcess::startDetached(QStringLiteral("sudo"),
                                {QStringLiteral("-n"), QStringLiteral("/usr/sbin/poweroff")}))
        return;
    if (!QProcess::startDetached(QStringLiteral("shutdown"), {QStringLiteral("-h"), QStringLiteral("now")}))
        qWarning() << "Linux power-off commands failed";
#endif
}

void KioskController::applyWindowState()
{
    if (!m_window)
        return;

    Qt::WindowFlags flags = Qt::Window;
    if (m_locked) {
        flags |= Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint;
        m_window->setFlags(flags);
        m_window->showFullScreen();
        m_window->setKeyboardGrabEnabled(true);
    } else {
        m_window->setFlags(flags);
        m_window->show();
        m_window->setKeyboardGrabEnabled(false);
    }
    m_window->requestActivate();
}

void KioskController::installOsHooks()
{
#ifdef Q_OS_WIN
    if (!m_locked || m_keyboardHook)
        return;
    m_keyboardHook = SetWindowsHookExW(WH_KEYBOARD_LL, lowLevelKeyboardProc, GetModuleHandleW(nullptr), 0);
#endif
}

void KioskController::removeOsHooks()
{
#ifdef Q_OS_WIN
    if (m_keyboardHook) {
        UnhookWindowsHookEx(m_keyboardHook);
        m_keyboardHook = nullptr;
    }
#endif
    if (m_window)
        m_window->setKeyboardGrabEnabled(false);
}

#ifdef Q_OS_WIN
LRESULT CALLBACK KioskController::lowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam)
{
    if (nCode == HC_ACTION && s_instance && s_instance->m_locked) {
        const auto *info = reinterpret_cast<KBDLLHOOKSTRUCT *>(lParam);
        const bool keyDown = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;
        if (keyDown) {
            const DWORD vk = info->vkCode;
            const bool alt = (GetAsyncKeyState(VK_MENU) & 0x8000) != 0;
            const bool ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
            const bool shift = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;

            const bool adminExit = ctrl && alt && shift && (vk == 'Q');
            if (adminExit) {
                QMetaObject::invokeMethod(s_instance, "requestAdminExit", Qt::QueuedConnection);
                return 1;
            }

            const bool block =
                vk == VK_LWIN || vk == VK_RWIN
                || vk == VK_APPS
                || (alt && (vk == VK_TAB || vk == VK_ESCAPE || vk == VK_F4))
                || (ctrl && vk == VK_ESCAPE)
                || (ctrl && shift && vk == VK_ESCAPE)
                || vk == VK_SNAPSHOT;
            if (block)
                return 1;
        }
    }
    return CallNextHookEx(s_instance ? s_instance->m_keyboardHook : nullptr, nCode, wParam, lParam);
}
#endif
