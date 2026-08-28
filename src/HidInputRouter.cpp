#include "HidInputRouter.h"

#include <QGuiApplication>
#include <QKeyEvent>
#include <QtGlobal>

namespace {
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
        if (handleDigitChord(int(key->key()), event->type() == QEvent::KeyPress, key->isAutoRepeat(),
                             event->type() == QEvent::KeyPress))
            return true;
    }

    if (event->type() == QEvent::ShortcutOverride) {
        auto *key = static_cast<QKeyEvent *>(event);
        if (key->key() == Qt::Key_3 || key->key() == Qt::Key_4) {
            event->accept();
            return true;
        }
        if (handleKey(key, false)) {
            event->accept();
            return true;
        }
    }
    if (event->type() == QEvent::KeyPress) {
        if (handleKey(static_cast<QKeyEvent *>(event), true))
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
    qInfo() << "Pedal press (C) -> snapshot";
    emit pedalTap();
}

void HidInputRouter::handlePedalRelease()
{
    if (!m_pedalDown)
        return;
    m_pedalDown = false;
}

bool HidInputRouter::handleDigitChord(int key, bool pressed, bool autoRepeat, bool emitSignals)
{
    if (key != Qt::Key_3 && key != Qt::Key_4)
        return false;
    if (autoRepeat)
        return true;

    if (key == Qt::Key_3)
        m_key3Down = pressed;
    else
        m_key4Down = pressed;

    if (!pressed) {
        if (!m_key3Down && !m_key4Down)
            m_chord34Fired = false;
        return true;
    }

    if (m_key3Down && m_key4Down) {
        if (emitSignals && !m_chord34Fired) {
            m_chord34Fired = true;
            emit goLive();
        }
        return true;
    }

    if (emitSignals && !m_chord34Fired) {
        if (key == Qt::Key_3)
            emit moveCurrent(1);
        else
            emit togglePreview();
    }
    return true;
}

bool HidInputRouter::handleKey(QKeyEvent *event, bool emitSignals)
{
    if (event->isAutoRepeat())
        return false;

    const Qt::KeyboardModifiers mods = event->modifiers();
    const bool ctrl = mods.testFlag(Qt::ControlModifier);
    const bool alt = mods.testFlag(Qt::AltModifier);
    const bool shift = mods.testFlag(Qt::ShiftModifier);

    if (ctrl && alt && shift && event->key() == Qt::Key_Q) {
        if (emitSignals)
            emit adminExit();
        return true;
    }

    if (alt && (event->key() == Qt::Key_F4 || event->key() == Qt::Key_Tab || event->key() == Qt::Key_Escape))
        return true;

    switch (event->key()) {
    case Qt::Key_2:
        if (emitSignals)
            emit toggleRecord();
        return true;
    case Qt::Key_1:
    case Qt::Key_S:
    case Qt::Key_F8:
    case Qt::Key_Camera:
    case Qt::Key_Print:
        if (emitSignals)
            emit captureSnapshot();
        return true;
    case Qt::Key_L:
    case Qt::Key_F2:
        if (emitSignals)
            emit openLibrary();
        return true;
    case Qt::Key_H:
    case Qt::Key_Home:
        if (emitSignals)
            emit goLive();
        return true;
    case Qt::Key_Escape:
    case Qt::Key_Backspace:
    case Qt::Key_Back:
        if (emitSignals)
            emit goBack();
        return true;
    case Qt::Key_Space:
    case Qt::Key_MediaPlay:
    case Qt::Key_MediaPause:
    case Qt::Key_MediaTogglePlayPause:
        if (emitSignals)
            emit playPause();
        return true;
    case Qt::Key_Return:
    case Qt::Key_Enter:
        if (emitSignals)
            emit selectItem();
        return true;
    case Qt::Key_Delete:
        if (emitSignals)
            emit deleteCurrent();
        return true;
    case Qt::Key_Left:
        if (emitSignals)
            emit seekBy(-10000);
        return true;
    case Qt::Key_Right:
        if (emitSignals)
            emit seekBy(10000);
        return true;
    default:
        return false;
    }
}
