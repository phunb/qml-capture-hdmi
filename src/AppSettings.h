#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
#include <QUrl>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool kioskMode READ kioskMode WRITE setKioskMode NOTIFY kioskModeChanged)
    Q_PROPERTY(QString recordingsDir READ recordingsDir WRITE setRecordingsDir NOTIFY recordingsDirChanged)
    Q_PROPERTY(QString preferredDeviceId READ preferredDeviceId WRITE setPreferredDeviceId NOTIFY preferredDeviceIdChanged)
    Q_PROPERTY(int maxRecordingMinutes READ maxRecordingMinutes WRITE setMaxRecordingMinutes NOTIFY maxRecordingMinutesChanged)
    Q_PROPERTY(qint64 minFreeBytes READ minFreeBytes CONSTANT)
    Q_PROPERTY(bool usingUsb READ usingUsb NOTIFY recordingsDirChanged)
    Q_PROPERTY(bool storageReady READ storageReady NOTIFY recordingsDirChanged)
    Q_PROPERTY(QString storageLabel READ storageLabel NOTIFY recordingsDirChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    bool kioskMode() const { return m_kioskMode; }
    void setKioskMode(bool enabled);

    QString recordingsDir() const { return m_recordingsDir; }
    void setRecordingsDir(const QString &dir);

    QString preferredDeviceId() const { return m_preferredDeviceId; }
    void setPreferredDeviceId(const QString &id);

    int maxRecordingMinutes() const { return m_maxRecordingMinutes; }
    void setMaxRecordingMinutes(int minutes);

    qint64 minFreeBytes() const { return 500LL * 1024 * 1024; }

    bool usingUsb() const { return m_usingUsb; }
    bool storageReady() const { return m_usingUsb && !m_recordingsDir.isEmpty(); }
    QString storageLabel() const { return m_storageLabel; }

    Q_INVOKABLE QUrl recordingsDirUrl() const;
    Q_INVOKABLE void setDirectoryLocked(bool locked);
    Q_INVOKABLE void refreshOutputDir();

signals:
    void kioskModeChanged();
    void recordingsDirChanged();
    void preferredDeviceIdChanged();
    void maxRecordingMinutesChanged();

private:
    void load();
    void save() const;
    QString resolveOutputDir(bool *usingUsb, QString *label) const;

    bool m_kioskMode = true;
    bool m_directoryLocked = false;
    bool m_usingUsb = false;
    QString m_recordingsDir;
    QString m_storageLabel;
    QString m_preferredDeviceId;
    int m_maxRecordingMinutes = 240;
    QTimer m_outputPoll;
};
