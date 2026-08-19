#include "AppSettings.h"

#include <QDir>
#include <QSettings>
#include <QUrl>
#include <QtGlobal>

namespace {

QString defaultRecordingsDir()
{
    const QString fromEnv = qEnvironmentVariable("HDMI_KIOSK_OUTPUT_DIR");
    if (!fromEnv.isEmpty())
        return fromEnv;
#ifdef Q_OS_WIN
    return QStringLiteral("C:/Users/Administrator/Desktop/output");
#else
    return QDir::home().filePath(QStringLiteral("output"));
#endif
}

} // namespace

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    load();
    const QString envKiosk = qEnvironmentVariable("HDMI_KIOSK_KIOSK_MODE");
    if (!envKiosk.isEmpty()) {
        m_kioskMode = !(envKiosk == QLatin1String("0")
                        || envKiosk.compare(QLatin1String("false"), Qt::CaseInsensitive) == 0
                        || envKiosk.compare(QLatin1String("off"), Qt::CaseInsensitive) == 0);
    }
    m_recordingsDir = defaultRecordingsDir();
    QDir().mkpath(m_recordingsDir);
    save();
}

void AppSettings::setKioskMode(bool enabled)
{
    if (m_kioskMode == enabled)
        return;
    m_kioskMode = enabled;
    save();
    emit kioskModeChanged();
}

void AppSettings::setRecordingsDir(const QString &dir)
{
    if (dir.isEmpty() || m_recordingsDir == dir)
        return;
    m_recordingsDir = dir;
    QDir().mkpath(m_recordingsDir);
    save();
    emit recordingsDirChanged();
}

void AppSettings::setPreferredDeviceId(const QString &id)
{
    if (m_preferredDeviceId == id)
        return;
    m_preferredDeviceId = id;
    save();
    emit preferredDeviceIdChanged();
}

void AppSettings::setMaxRecordingMinutes(int minutes)
{
    minutes = qBound(5, minutes, 24 * 60);
    if (m_maxRecordingMinutes == minutes)
        return;
    m_maxRecordingMinutes = minutes;
    save();
    emit maxRecordingMinutesChanged();
}

QUrl AppSettings::recordingsDirUrl() const
{
    return QUrl::fromLocalFile(m_recordingsDir);
}

void AppSettings::load()
{
    QSettings s;
    m_kioskMode = s.value(QStringLiteral("kioskMode"), true).toBool();
    m_recordingsDir = s.value(QStringLiteral("recordingsDir"), m_recordingsDir).toString();
    m_preferredDeviceId = s.value(QStringLiteral("preferredDeviceId")).toString();
    m_maxRecordingMinutes = s.value(QStringLiteral("maxRecordingMinutes"), 240).toInt();
}

void AppSettings::save() const
{
    QSettings s;
    s.setValue(QStringLiteral("kioskMode"), m_kioskMode);
    s.setValue(QStringLiteral("recordingsDir"), m_recordingsDir);
    s.setValue(QStringLiteral("preferredDeviceId"), m_preferredDeviceId);
    s.setValue(QStringLiteral("maxRecordingMinutes"), m_maxRecordingMinutes);
}
