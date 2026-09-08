#pragma once

#include <QObject>

#ifdef Q_OS_WIN
#  include <windows.h>
#endif

class HidInputRouter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool previewMode READ previewMode WRITE setPreviewMode NOTIFY previewModeChanged)

public:
    explicit HidInputRouter(QObject *parent = nullptr);
    ~HidInputRouter() override;

    bool eventFilter(QObject *watched, QEvent *event) override;

    bool previewMode() const { return m_previewMode; }
    void setPreviewMode(bool previewMode);

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
    void previewModeChanged();

private:
    bool handleKey(class QKeyEvent *event, bool emitSignals = true);
    bool handleFootPedalKey(int key, bool pressed, bool autoRepeat);
    bool handlePadEvent(int key, bool pressed, bool autoRepeat);
    void handleFootPedalPress();
    void handleFootPedalRelease();
    void onDigitDown(int bit);
    void onReleaseLetter(int bit);
    void onMuteLetter(int bit);
    void fireDigitTap(int bit);
    static int digitBit(int key);
    static int releaseBit(int key);
    static int muteBit(int key);

#ifdef Q_OS_WIN
    static HidInputRouter *s_instance;
    HHOOK m_keyboardHook = nullptr;
#endif

    bool m_footPedalDown = false;
    bool m_previewMode = false;
    int m_heldForChord = 0;
    int m_muteRelease = 0;
};
