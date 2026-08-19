#include "HidInputRouter.h"

#include <QGuiApplication>
#include <QKeyEvent>

HidInputRouter::HidInputRouter(QObject *parent)
    : QObject(parent)
{
    qApp->installEventFilter(this);
}

bool HidInputRouter::eventFilter(QObject *watched, QEvent *event)
{
    Q_UNUSED(watched)
    if (event->type() == QEvent::KeyPress) {
        if (handleKey(static_cast<QKeyEvent *>(event)))
            return true;
    }
    return false;
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
