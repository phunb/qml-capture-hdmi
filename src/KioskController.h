#pragma once

#include <QAbstractNativeEventFilter>
#include <QObject>
#include <QPointer>
#include <QWindow>

#ifdef Q_OS_WIN
#  include <windows.h>
#endif

class KioskController : public QObject, public QAbstractNativeEventFilter
{
    Q_OBJECT
    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged)
    Q_PROPERTY(bool attached READ attached NOTIFY attachedChanged)

public:
    explicit KioskController(QObject *parent = nullptr);
    ~KioskController() override;

    bool locked() const { return m_locked; }
    bool attached() const { return m_window != nullptr; }

    Q_INVOKABLE void attachWindow(QObject *windowObject);
    Q_INVOKABLE void setLocked(bool locked);
    Q_INVOKABLE bool requestAdminExit();
    Q_INVOKABLE void exitApp();

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override;

signals:
    void lockedChanged();
    void attachedChanged();
    void adminExitRequested();

private:
    void applyWindowState();
    void installOsHooks();
    void removeOsHooks();
#ifdef Q_OS_WIN
    static LRESULT CALLBACK lowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam);
    static KioskController *s_instance;
    HHOOK m_keyboardHook = nullptr;
#endif

    QPointer<QWindow> m_window;
    bool m_locked = true;
};
