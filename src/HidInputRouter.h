#pragma once

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

#ifdef Q_OS_WIN
    static LRESULT CALLBACK lowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam);
#endif

signals:
    void toggleRecord();
    void captureSnapshot();
    void goLive();
    void goBack();
    void playPause();
    void selectItem();
    void moveCurrent(int delta);
    void seekBy(int milliseconds);
    void deleteCurrent();
    void adminExit();
    void pedalTap();
    void togglePreview();
    void exportToUsb();

private:
    bool handleKey(class QKeyEvent *event, bool emitSignals = true);
    bool handlePedalKey(int key, bool pressed, bool autoRepeat);
    bool handleDigitChord(int key, bool pressed, bool autoRepeat);
    void handlePedalPress();
    void handlePedalRelease();
    void flushDigitChord();
    static int digitBit(int key);

#ifdef Q_OS_WIN
    static HidInputRouter *s_instance;
    HHOOK m_keyboardHook = nullptr;
#endif

    QTimer m_chordTimer;
    bool m_pedalDown = false;
    int m_keyMask = 0;
    int m_gestureMask = 0;
    bool m_chordFired = false;
};
