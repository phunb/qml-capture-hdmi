#include "KioskController.h"

#include <QGuiApplication>
#include <QMetaObject>
#include <QWindow>

#ifdef Q_OS_WIN
KioskController *KioskController::s_instance = nullptr;
#endif

KioskController::KioskController(QObject *parent)
    : QObject(parent)
{
    qApp->installNativeEventFilter(this);
#ifdef Q_OS_WIN
    s_instance = this;
#endif
}

KioskController::~KioskController()
{
    removeOsHooks();
    if (qApp)
        qApp->removeNativeEventFilter(this);
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
    emit attachedChanged();
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
    QGuiApplication::quit();
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

bool KioskController::nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result)
{
    Q_UNUSED(eventType)
    Q_UNUSED(message)
    Q_UNUSED(result)
    return false;
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
