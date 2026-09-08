#pragma once

#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QWindow>

#ifdef Q_OS_WIN
#  include <windows.h>
#endif

class CaptureController;
class RecordingManager;

class KioskController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged)
    Q_PROPERTY(int idlePowerOffRemainingSec READ idlePowerOffRemainingSec NOTIFY idlePowerOffRemainingSecChanged)

public:
    explicit KioskController(QObject *parent = nullptr);
    ~KioskController() override;

    bool locked() const { return m_locked; }
    int idlePowerOffRemainingSec() const;

    void watchIdlePowerOff(CaptureController *capture, RecordingManager *recordings);

    Q_INVOKABLE void attachWindow(QObject *windowObject);
    Q_INVOKABLE void setLocked(bool locked);
    Q_INVOKABLE bool requestAdminExit();
    Q_INVOKABLE void exitApp();

signals:
    void lockedChanged();
    void adminExitRequested();
    void idlePowerOffRemainingSecChanged();

private:
    void applyWindowState();
    void installOsHooks();
    void removeOsHooks();
    void syncIdleTimer();
    void onIdleTimeout();
    void performOsShutdown();
#ifdef Q_OS_WIN
    static LRESULT CALLBACK lowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam);
    static KioskController *s_instance;
    HHOOK m_keyboardHook = nullptr;
#endif

    QPointer<QWindow> m_window;
    CaptureController *m_capture = nullptr;
    RecordingManager *m_recordings = nullptr;
    QTimer m_idleTimer;
    QTimer m_idleTick;
    bool m_locked = true;
    bool m_idleWatchEnabled = false;
    bool m_shuttingDown = false;
    bool m_powerOffIssued = false;
};
