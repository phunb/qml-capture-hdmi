#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>

class QFileSystemWatcher;

class RecordingManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString directory READ directory NOTIFY directoryChanged)
    Q_PROPERTY(qint64 freeBytes READ freeBytes NOTIFY storageChanged)
    Q_PROPERTY(QString freeSpaceText READ freeSpaceText NOTIFY storageChanged)

public:
    explicit RecordingManager(const QString &directory, QObject *parent = nullptr);

    QString directory() const { return m_directory; }
    void setDirectory(const QString &directory);

    QStringList listRecordings() const;
    QString createNewRecordingPath();
    QString createNewCapturePath();
    bool removeRecording(const QString &filePath);

    qint64 freeBytes() const;
    QString freeSpaceText() const;
    bool hasEnoughSpace(qint64 minimumBytes) const;
    void notifyChanged();

signals:
    void directoryChanged();
    void recordingsChanged();
    void storageChanged();

private:
    void watchDirectory();

    QString m_directory;
    QFileSystemWatcher *m_watcher = nullptr;
};
