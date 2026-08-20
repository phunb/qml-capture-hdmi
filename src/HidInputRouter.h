#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>

#ifdef Q_OS_WIN
#  include <windows.h>
#endif

class HidInputRouter : public QObject
{
    Q_OBJECT

public:
    explicit HidInputRouter(QObject *parent = nullptr);
    ~HidInputRouter() override;

    bool eventFilter(QObject *watched, QEvent *event) override;
    Q_INVOKABLE void cancelPedalHold();

#ifdef Q_OS_WIN
    static LRESULT CALLBACK lowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam);
#endif

signals:
    void toggleRecord();
    void captureSnapshot();
    void openLibrary();
    void goLive();
    void goBack();
    void playPause();
    void selectItem();
    void moveCurrent(int delta);
    void seekBy(int milliseconds);
    void deleteCurrent();
    void adminExit();
    void pedalTap();
    void pedalHoldRecord();

private:
    bool handleKey(class QKeyEvent *event);
    bool handlePedalKey(int key, bool pressed, bool autoRepeat);
    void handlePedalPress();
    void handlePedalRelease();
    qint64 pedalHeldMs() const;

#ifdef Q_OS_WIN
    static HidInputRouter *s_instance;
    HHOOK m_keyboardHook = nullptr;
#endif

    QTimer m_pedalHoldTimer;
    QElapsedTimer m_pressClock;
    bool m_pedalDown = false;
    bool m_pedalHoldFired = false;
};
