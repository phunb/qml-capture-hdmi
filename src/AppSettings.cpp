#include "AppSettings.h"

#include <QDir>
#include <QSettings>
#include <QStorageInfo>
#include <QtGlobal>

#ifdef Q_OS_WIN
#  include <windows.h>
#endif

namespace {

bool isRemovableVolume(const QStorageInfo &vol)
{
#ifdef Q_OS_WIN
    QString root = QDir::toNativeSeparators(vol.rootPath());
    if (!root.endsWith(QLatin1Char('\\')))
        root += QLatin1Char('\\');
    const UINT type = GetDriveTypeW(reinterpret_cast<LPCWSTR>(root.utf16()));
    return type == DRIVE_REMOVABLE;
#else
    const QString root = vol.rootPath();
    if (root.startsWith(QLatin1String("/media/")) || root.startsWith(QLatin1String("/run/media/")))
        return true;
    const QByteArray fs = vol.fileSystemType().toLower();
    return fs == "vfat" || fs == "exfat";
#endif
}

bool isSystemRoot(const QString &rootPath)
{
    const QString root = QDir::cleanPath(rootPath);
#ifdef Q_OS_WIN
    return root.compare(QLatin1String("C:"), Qt::CaseInsensitive) == 0
        || root.compare(QLatin1String("C:/"), Qt::CaseInsensitive) == 0;
#else
    return root == QLatin1String("/");
#endif
}

QString outputOn(const QString &rootPath)
{
    return QDir(rootPath).filePath(QStringLiteral("output"));
}

QString defaultLocalOutputDir()
{
#ifdef Q_OS_WIN
    return QStringLiteral("C:/output");
#else
    const QString systemOutput = QStringLiteral("/output");
    if (QDir().mkpath(systemOutput))
        return systemOutput;
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

    refreshPaths();

    m_pathPoll.setInterval(2000);
    connect(&m_pathPoll, &QTimer::timeout, this, &AppSettings::refreshPaths);
    m_pathPoll.start();
}

void AppSettings::setPreferredDeviceId(const QString &id)
{
    if (m_preferredDeviceId == id)
        return;
    m_preferredDeviceId = id;
    save();
}

void AppSettings::refreshPaths()
{
    QString local = resolveLocalOutputDir();
    if (!QDir().mkpath(local)) {
        local = QDir::home().filePath(QStringLiteral("output"));
        QDir().mkpath(local);
    }

    if (m_recordingsDir != local) {
        m_recordingsDir = local;
        save();
        emit recordingsDirChanged();
    }

    const QString usb = resolveUsbOutputDir();
    if (m_usbOutputDir != usb) {
        m_usbOutputDir = usb;
        emit usbChanged();
    }
}

QString AppSettings::resolveLocalOutputDir() const
{
    const QString fromEnv = qEnvironmentVariable("HDMI_KIOSK_OUTPUT_DIR");
    if (!fromEnv.isEmpty())
        return fromEnv;
    return defaultLocalOutputDir();
}

QString AppSettings::resolveUsbOutputDir() const
{
    for (const QStorageInfo &vol : QStorageInfo::mountedVolumes()) {
        if (!vol.isValid() || !vol.isReady() || vol.isReadOnly() || !isRemovableVolume(vol))
            continue;
        if (isSystemRoot(vol.rootPath()))
            continue;
        const QString dir = outputOn(vol.rootPath());
        if (QDir().mkpath(dir))
            return dir;
    }
    return {};
}

void AppSettings::load()
{
    QSettings s;
    m_kioskMode = s.value(QStringLiteral("kioskMode"), true).toBool();
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
