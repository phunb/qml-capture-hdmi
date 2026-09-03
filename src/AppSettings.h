#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

class AppSettings : public QObject
{
    Q_OBJECT

public:
    explicit AppSettings(QObject *parent = nullptr);

    bool kioskMode() const { return m_kioskMode; }

    QString recordingsDir() const { return m_recordingsDir; }

    QString preferredDeviceId() const { return m_preferredDeviceId; }
    void setPreferredDeviceId(const QString &id);

    int maxRecordingMinutes() const { return m_maxRecordingMinutes; }

    qint64 minFreeBytes() const { return 500LL * 1024 * 1024; }

    bool usbAvailable() const { return !m_usbOutputDir.isEmpty(); }
    QString usbOutputDir() const { return m_usbOutputDir; }

signals:
    void recordingsDirChanged();
    void usbChanged();

private:
    void load();
    void save() const;
    QString resolveLocalOutputDir() const;
    QString resolveUsbOutputDir() const;
    void refreshPaths();

    bool m_kioskMode = true;
    QString m_recordingsDir;
    QString m_usbOutputDir;
    QString m_preferredDeviceId;
    int m_maxRecordingMinutes = 240;
    QTimer m_pathPoll;
};
