#include "HidInputRouter.h"

#include <QGuiApplication>
#include <QKeyEvent>
#include <QtGlobal>

namespace {
constexpr int kPedalHoldMs = 3000;
constexpr int kPedalPressVk = 0x43;   // ElfKey Double trigger: press = C
constexpr int kPedalReleaseVk = 0x42; // ElfKey Double trigger: release = B
}

#ifdef Q_OS_WIN
HidInputRouter *HidInputRouter::s_instance = nullptr;
#endif

HidInputRouter::HidInputRouter(QObject *parent)
    : QObject(parent)
{
    qApp->installEventFilter(this);
    m_pedalHoldTimer.setSingleShot(true);
    m_pedalHoldTimer.setInterval(kPedalHoldMs);
    connect(&m_pedalHoldTimer, &QTimer::timeout, this, [this]() {
        if (!m_pedalDown)
            return;
        m_pedalHoldFired = true;
        qInfo() << "Pedal hold 3s -> record after" << pedalHeldMs() << "ms";
        emit pedalHoldRecord();
    });

#ifdef Q_OS_WIN
    s_instance = this;
    m_keyboardHook = SetWindowsHookExW(WH_KEYBOARD_LL, lowLevelKeyboardProc,
                                       GetModuleHandleW(nullptr), 0);
    if (!m_keyboardHook)
        qWarning() << "Pedal keyboard hook failed" << GetLastError();
#endif
}

HidInputRouter::~HidInputRouter()
{
#ifdef Q_OS_WIN
    if (m_keyboardHook) {
        UnhookWindowsHookEx(m_keyboardHook);
        m_keyboardHook = nullptr;
    }
    if (s_instance == this)
        s_instance = nullptr;
#endif
}

qint64 HidInputRouter::pedalHeldMs() const
{
    return m_pressClock.isValid() ? m_pressClock.elapsed() : 0;
}

#ifdef Q_OS_WIN
LRESULT CALLBACK HidInputRouter::lowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam)
{
    if (nCode == HC_ACTION && s_instance) {
        const auto *info = reinterpret_cast<KBDLLHOOKSTRUCT *>(lParam);
        const bool keyDown = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;
        if (info->vkCode == static_cast<DWORD>(kPedalPressVk)
            || info->vkCode == static_cast<DWORD>(kPedalReleaseVk)) {
            const int key = info->vkCode == static_cast<DWORD>(kPedalPressVk)
                                ? int(Qt::Key_C)
                                : int(Qt::Key_B);
            QMetaObject::invokeMethod(s_instance, [inst = s_instance, key, keyDown]() {
                inst->handlePedalKey(key, keyDown, false);
            }, Qt::QueuedConnection);
            return 1;
        }
    }
    return CallNextHookEx(s_instance ? s_instance->m_keyboardHook : nullptr, nCode, wParam, lParam);
}
#endif

bool HidInputRouter::eventFilter(QObject *watched, QEvent *event)
{
    Q_UNUSED(watched)

#ifdef Q_OS_WIN
    if (m_keyboardHook && (event->type() == QEvent::KeyPress || event->type() == QEvent::KeyRelease)) {
        auto *key = static_cast<QKeyEvent *>(event);
        if (key->key() == Qt::Key_C || key->key() == Qt::Key_B)
            return true;
    }
#endif

    if (event->type() == QEvent::KeyPress || event->type() == QEvent::KeyRelease) {
        auto *key = static_cast<QKeyEvent *>(event);
        if (handlePedalKey(int(key->key()), event->type() == QEvent::KeyPress, key->isAutoRepeat()))
            return true;
    }

    if (event->type() == QEvent::KeyPress) {
        if (handleKey(static_cast<QKeyEvent *>(event)))
            return true;
    }
    return false;
}

bool HidInputRouter::handlePedalKey(int key, bool pressed, bool autoRepeat)
{
    if (key != Qt::Key_C && key != Qt::Key_B)
        return false;
    if (autoRepeat || !pressed)
        return true;
    if (key == Qt::Key_C)
        handlePedalPress();
    else
        handlePedalRelease();
    return true;
}

void HidInputRouter::handlePedalPress()
{
    if (m_pedalDown)
        return;
    m_pedalDown = true;
    m_pedalHoldFired = false;
    m_pressClock.restart();
    m_pedalHoldTimer.start();
    qInfo() << "Pedal press (C), wait 3s to record";
}

void HidInputRouter::handlePedalRelease()
{
    if (!m_pedalDown)
        return;
    m_pedalDown = false;
    const qint64 heldMs = pedalHeldMs();
    const bool holdFired = m_pedalHoldFired;
    m_pedalHoldTimer.stop();
    if (!holdFired) {
        qInfo() << "Pedal release (B) tap -> snapshot after" << heldMs << "ms";
        emit pedalTap();
    } else {
        qInfo() << "Pedal release (B) after hold, keep recording. held" << heldMs << "ms";
    }
}

bool HidInputRouter::handleKey(QKeyEvent *event)
{
    if (event->isAutoRepeat()
        && event->key() != Qt::Key_Left
        && event->key() != Qt::Key_Right
        && event->key() != Qt::Key_Up
        && event->key() != Qt::Key_Down) {
        return false;
    }

    const Qt::KeyboardModifiers mods = event->modifiers();
    const bool ctrl = mods.testFlag(Qt::ControlModifier);
    const bool alt = mods.testFlag(Qt::AltModifier);
    const bool shift = mods.testFlag(Qt::ShiftModifier);

    if (ctrl && alt && shift && event->key() == Qt::Key_Q) {
        emit adminExit();
        return true;
    }

    if (alt && (event->key() == Qt::Key_F4 || event->key() == Qt::Key_Tab || event->key() == Qt::Key_Escape))
        return true;

    switch (event->key()) {
    case Qt::Key_R:
    case Qt::Key_F9:
    case Qt::Key_MediaRecord:
        emit toggleRecord();
        return true;
    case Qt::Key_S:
    case Qt::Key_F8:
    case Qt::Key_Camera:
    case Qt::Key_Print:
        emit captureSnapshot();
        return true;
    case Qt::Key_L:
    case Qt::Key_F2:
        emit openLibrary();
        return true;
    case Qt::Key_H:
    case Qt::Key_Home:
    case Qt::Key_F1:
        emit goLive();
        return true;
    case Qt::Key_Escape:
    case Qt::Key_Backspace:
    case Qt::Key_Back:
        emit goBack();
        return true;
    case Qt::Key_Space:
    case Qt::Key_MediaPlay:
    case Qt::Key_MediaPause:
    case Qt::Key_MediaTogglePlayPause:
        emit playPause();
        return true;
    case Qt::Key_Return:
    case Qt::Key_Enter:
        emit selectItem();
        return true;
    case Qt::Key_Delete:
        emit deleteCurrent();
        return true;
    case Qt::Key_Up:
        emit moveCurrent(-1);
        return true;
    case Qt::Key_Down:
        emit moveCurrent(1);
        return true;
    case Qt::Key_Left:
        emit seekBy(shift ? -30000 : -10000);
        return true;
    case Qt::Key_Right:
        emit seekBy(shift ? 30000 : 10000);
        return true;
    default:
        return false;
    }
}
