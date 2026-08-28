#include "AppSettings.h"

#include <QDir>
#include <QSettings>
#include <QStorageInfo>
#include <QUrl>
#include <QtGlobal>

#ifdef Q_OS_WIN
#  include <windows.h>
#endif

namespace {

const QString kNeedUsb = QStringLiteral("Bạn cần cắm USB để lưu file");

bool isOsVolume(const QString &rootPath)
{
    const QString root = QDir::cleanPath(rootPath);
#ifdef Q_OS_WIN
    return root.compare(QLatin1String("C:"), Qt::CaseInsensitive) == 0
        || root.compare(QLatin1String("C:/"), Qt::CaseInsensitive) == 0;
#else
    return root == QLatin1String("/")
        || root == QLatin1String("/boot")
        || root.startsWith(QLatin1String("/boot/"));
#endif
}

bool isRemovableVolume(const QStorageInfo &vol)
{
#ifdef Q_OS_WIN
    QString root = QDir::toNativeSeparators(vol.rootPath());
    if (!root.endsWith(QLatin1Char('\\')))
        root += QLatin1Char('\\');
    const UINT type = GetDriveTypeW(reinterpret_cast<LPCWSTR>(root.utf16()));
    return type == DRIVE_REMOVABLE;
#else
    if (isOsVolume(vol.rootPath()))
        return false;
    const QString root = vol.rootPath();
    if (root.startsWith(QLatin1String("/media/")) || root.startsWith(QLatin1String("/run/media/")))
        return true;
    const QByteArray fs = vol.fileSystemType().toLower();
    return fs == "vfat" || fs == "exfat";
#endif
}

QString recorderOutputOn(const QString &rootPath)
{
    return QDir(rootPath).filePath(QStringLiteral("recorder/output"));
}

QString volumeLabel(const QStorageInfo &vol)
{
    const QString name = vol.name().trimmed();
    const QString root = QDir::toNativeSeparators(vol.rootPath());
    if (!name.isEmpty())
        return QStringLiteral("USB %1 (%2)").arg(root, name);
    return QStringLiteral("USB %1").arg(root);
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

    refreshOutputDir();

    m_outputPoll.setInterval(2000);
    connect(&m_outputPoll, &QTimer::timeout, this, &AppSettings::refreshOutputDir);
    m_outputPoll.start();
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
    Q_UNUSED(dir)
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

void AppSettings::setDirectoryLocked(bool locked)
{
    m_directoryLocked = locked;
    if (!locked)
        refreshOutputDir();
}

void AppSettings::refreshOutputDir()
{
    if (m_directoryLocked)
        return;

    bool usb = false;
    QString label;
    QString dir = resolveOutputDir(&usb, &label);
    if (usb && !dir.isEmpty() && !QDir().mkpath(dir)) {
        usb = false;
        dir.clear();
        label = kNeedUsb;
    }
    if (!usb) {
        dir.clear();
        label = kNeedUsb;
    }

    const bool changed = (m_recordingsDir != dir || m_usingUsb != usb || m_storageLabel != label);
    m_usingUsb = usb;
    m_storageLabel = label;
    if (m_recordingsDir != dir) {
        m_recordingsDir = dir;
        save();
        emit recordingsDirChanged();
    } else if (changed) {
        emit recordingsDirChanged();
    }
}

QString AppSettings::resolveOutputDir(bool *usingUsb, QString *label) const
{
    if (qEnvironmentVariableIntValue("HDMI_KIOSK_SMOKE_TEST") > 0) {
        const QString fromEnv = qEnvironmentVariable("HDMI_KIOSK_OUTPUT_DIR");
        if (!fromEnv.isEmpty()) {
            if (usingUsb)
                *usingUsb = true;
            if (label)
                *label = QDir::toNativeSeparators(fromEnv);
            return fromEnv;
        }
    }

    for (const QStorageInfo &vol : QStorageInfo::mountedVolumes()) {
        if (!vol.isValid() || !vol.isReady() || vol.isReadOnly() || !isRemovableVolume(vol))
            continue;
        if (isOsVolume(vol.rootPath()))
            continue;

        const QString dir = recorderOutputOn(vol.rootPath());
        if (usingUsb)
            *usingUsb = true;
        if (label)
            *label = volumeLabel(vol);
        return dir;
    }

    if (usingUsb)
        *usingUsb = false;
    if (label)
        *label = kNeedUsb;
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
