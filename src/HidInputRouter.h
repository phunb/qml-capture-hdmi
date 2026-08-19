#pragma once

#include <QObject>

class HidInputRouter : public QObject
{
    Q_OBJECT

public:
    explicit HidInputRouter(QObject *parent = nullptr);

    bool eventFilter(QObject *watched, QEvent *event) override;

signals:
    void toggleRecord();
    void openLibrary();
    void goLive();
    void goBack();
    void playPause();
    void selectItem();
    void moveCurrent(int delta);
    void seekBy(int milliseconds);
    void deleteCurrent();
    void adminExit();

private:
    bool handleKey(class QKeyEvent *event);
};
