#include "HidInputRouter.h"

#include <QGuiApplication>
#include <QKeyEvent>
#include <QMetaObject>
#include <QtGlobal>

namespace {
constexpr int kFootPressVk = 0x43;    // ElfKey: press = C
constexpr int kFootReleaseVk = 0x42;  // ElfKey: release = B
constexpr int kBit1 = 1 << 0;
constexpr int kBit2 = 1 << 1;
constexpr int kBit3 = 1 << 2;

int digitBitImpl(int key)
{
    switch (key) {
    case Qt::Key_1:
        return kBit1;
    case Qt::Key_2:
        return kBit2;
    case Qt::Key_3:
        return kBit3;
    default:
        return 0;
    }
}

int releaseBitImpl(int key)
{
    switch (key) {
    case Qt::Key_Q:
        return kBit1;
    case Qt::Key_W:
        return kBit2;
    case Qt::Key_E:
        return kBit3;
    default:
        return 0;
    }
}

int muteBitImpl(int key)
{
    switch (key) {
    case Qt::Key_A:
        return kBit1;
    case Qt::Key_S:
        return kBit2;
    case Qt::Key_D:
        return kBit3;
    default:
        return 0;
    }
}

bool isPadKey(int key)
{
    return digitBitImpl(key) != 0 || releaseBitImpl(key) != 0 || muteBitImpl(key) != 0
        || key == int(Qt::Key_N);
}
} // namespace

#ifdef Q_OS_WIN
HidInputRouter *HidInputRouter::s_instance = nullptr;
#endif

int HidInputRouter::digitBit(int key)
{
    return digitBitImpl(key);
}

int HidInputRouter::releaseBit(int key)
{
    return releaseBitImpl(key);
}

int HidInputRouter::muteBit(int key)
{
    return muteBitImpl(key);
}

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
namespace {
int qtKeyFromPadVk(DWORD vk)
{
    switch (vk) {
    case 0x31:
        return int(Qt::Key_1);
    case 0x32:
        return int(Qt::Key_2);
    case 0x33:
        return int(Qt::Key_3);
    case 0x41:
        return int(Qt::Key_A);
    case 0x53:
        return int(Qt::Key_S);
    case 0x44:
        return int(Qt::Key_D);
    case 0x51:
        return int(Qt::Key_Q);
    case 0x57:
        return int(Qt::Key_W);
    case 0x45:
        return int(Qt::Key_E);
    case 0x4E:
        return int(Qt::Key_N);
    default:
        return 0;
    }
}

bool isPadVk(DWORD vk)
{
    return qtKeyFromPadVk(vk) != 0;
}

bool modifiersDown()
{
    const auto down = [](int vk) {
        return (GetAsyncKeyState(vk) & 0x8000) != 0;
    };
    return down(VK_CONTROL) && down(VK_MENU) && down(VK_SHIFT);
}
} // namespace

LRESULT CALLBACK HidInputRouter::lowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam)
{
    if (nCode == HC_ACTION && s_instance) {
        const auto *info = reinterpret_cast<KBDLLHOOKSTRUCT *>(lParam);
        const bool keyDown = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;
        if (info->vkCode == static_cast<DWORD>(kFootPressVk)
            || info->vkCode == static_cast<DWORD>(kFootReleaseVk)) {
            const int key = info->vkCode == static_cast<DWORD>(kFootPressVk)
                                ? int(Qt::Key_C)
                                : int(Qt::Key_B);
            QMetaObject::invokeMethod(s_instance, [inst = s_instance, key, keyDown]() {
                inst->handleFootPedalKey(key, keyDown, false);
            }, Qt::QueuedConnection);
            return 1;
        }
        if (isPadVk(info->vkCode)) {
            if (info->vkCode == 0x51 && keyDown && modifiersDown()) {
                QMetaObject::invokeMethod(s_instance, [inst = s_instance]() {
                    emit inst->adminExit();
                }, Qt::QueuedConnection);
                return 1;
            }
            const int key = qtKeyFromPadVk(info->vkCode);
            QMetaObject::invokeMethod(s_instance, [inst = s_instance, key, keyDown]() {
                inst->handlePadEvent(key, keyDown, false);
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
        if (isPadKey(int(key->key())))
            return true;
    }
#endif

    if (event->type() == QEvent::KeyPress || event->type() == QEvent::KeyRelease) {
        auto *key = static_cast<QKeyEvent *>(event);
        const bool pressed = event->type() == QEvent::KeyPress;
        if (pressed && key->modifiers().testFlag(Qt::ControlModifier)
            && key->modifiers().testFlag(Qt::AltModifier)
            && key->modifiers().testFlag(Qt::ShiftModifier)
            && key->key() == Qt::Key_Q) {
            if (!key->isAutoRepeat())
                emit adminExit();
            return true;
        }
        if (handleFootPedalKey(int(key->key()), pressed, key->isAutoRepeat()))
            return true;
        if (handlePadEvent(int(key->key()), pressed, key->isAutoRepeat()))
            return true;
    }

    if (event->type() == QEvent::ShortcutOverride) {
        auto *key = static_cast<QKeyEvent *>(event);
        if (isPadKey(int(key->key())) || handleKey(key, false)) {
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

bool HidInputRouter::handleFootPedalKey(int key, bool pressed, bool autoRepeat)
{
    if (key != Qt::Key_C && key != Qt::Key_B)
        return false;
    if (autoRepeat || !pressed)
        return true;
    if (key == Qt::Key_C) {
        handleFootPedalPress();
        return true;
    }
    // B: nhả pedal chân nếu đang giữ C; không thì zoom out / tua −10s (thay 1+2).
    if (m_footPedalDown)
        handleFootPedalRelease();
    else
        emit seekBy(-10000);
    return true;
}

void HidInputRouter::handleFootPedalPress()
{
    if (m_footPedalDown)
        return;
    m_footPedalDown = true;
    qInfo() << "Pedal press (C) -> snapshot";
    emit pedalTap();
}

void HidInputRouter::handleFootPedalRelease()
{
    if (!m_footPedalDown)
        return;
    m_footPedalDown = false;
}

void HidInputRouter::setPreviewMode(bool previewMode)
{
    if (m_previewMode == previewMode)
        return;
    m_previewMode = previewMode;
    emit previewModeChanged();
}

bool HidInputRouter::handlePadEvent(int key, bool pressed, bool autoRepeat)
{
    if (!isPadKey(key))
        return false;
    if (autoRepeat || !pressed)
        return true;
    if (key == Qt::Key_N) {
        emit seekBy(10000);
        return true;
    }

    if (const int bit = digitBit(key)) {
        onDigitDown(bit);
        return true;
    }
    if (const int bit = muteBit(key)) {
        onMuteLetter(bit);
        return true;
    }
    if (const int bit = releaseBit(key)) {
        onReleaseLetter(bit);
        return true;
    }
    return true;
}

void HidInputRouter::onDigitDown(int bit)
{
    m_heldForChord |= bit;
    fireDigitTap(bit);
}

void HidInputRouter::onMuteLetter(int bit)
{
    const bool digitWasHeld = (m_heldForChord & bit) != 0;
    m_muteRelease |= bit;
    m_heldForChord &= ~bit;
    if (bit == kBit2 && !digitWasHeld)
        emit goLive();
}

void HidInputRouter::onReleaseLetter(int bit)
{
    m_heldForChord &= ~bit;

    if (m_muteRelease & bit) {
        m_muteRelease &= ~bit;
        return;
    }

    if (bit == kBit1)
        emit moveCurrent(-1);
    else if (bit == kBit3)
        emit moveCurrent(1);
}

void HidInputRouter::fireDigitTap(int bit)
{
    if (bit == kBit1) {
        if (!m_previewMode)
            emit captureSnapshot();
        return;
    }
    if (bit == kBit2) {
        emit togglePreview();
        return;
    }
    if (bit == kBit3 && !m_previewMode)
        emit toggleRecord();
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
    case Qt::Key_F8:
    case Qt::Key_Camera:
    case Qt::Key_Print:
        if (emitSignals)
            emit captureSnapshot();
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
    default:
        return false;
    }
}
