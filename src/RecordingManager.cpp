#include "RecordingManager.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QLocale>
#include <QStorageInfo>

RecordingManager::RecordingManager(const QString &directory, QObject *parent)
    : QObject(parent)
    , m_watcher(new QFileSystemWatcher(this))
{
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        emit recordingsChanged();
        emit storageChanged();
    });
    setDirectory(directory);
}

void RecordingManager::setDirectory(const QString &directory)
{
    if (directory.isEmpty() || m_directory == directory)
        return;

    if (!m_directory.isEmpty())
        m_watcher->removePath(m_directory);

    m_directory = directory;
    QDir().mkpath(m_directory);
    watchDirectory();
    emit directoryChanged();
    emit recordingsChanged();
    emit storageChanged();
}

QStringList RecordingManager::listRecordings() const
{
    QDir dir(m_directory);
    const QStringList files = dir.entryList(
        {QStringLiteral("*.mp4"), QStringLiteral("*.mkv"), QStringLiteral("*.mov"),
         QStringLiteral("*.jpg"), QStringLiteral("*.jpeg"), QStringLiteral("*.png")},
        QDir::Files,
        QDir::Time);

    QStringList absolute;
    absolute.reserve(files.size());
    for (const QString &name : files)
        absolute.append(dir.filePath(name));
    return absolute;
}

QString RecordingManager::createNewRecordingPath()
{
    QDir().mkpath(m_directory);
    const QString stamp = QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd_HH-mm-ss"));
    QString path = QDir(m_directory).filePath(QStringLiteral("record_%1.mp4").arg(stamp));
    int suffix = 2;
    while (QFileInfo::exists(path)) {
        path = QDir(m_directory).filePath(QStringLiteral("record_%1_%2.mp4").arg(stamp).arg(suffix));
        ++suffix;
    }
    return path;
}

QString RecordingManager::createNewCapturePath()
{
    QDir().mkpath(m_directory);
    const QString stamp = QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd_HH-mm-ss"));
    QString path = QDir(m_directory).filePath(QStringLiteral("capture_%1.jpg").arg(stamp));
    int suffix = 2;
    while (QFileInfo::exists(path)) {
        path = QDir(m_directory).filePath(QStringLiteral("capture_%1_%2.jpg").arg(stamp).arg(suffix));
        ++suffix;
    }
    return path;
}

bool RecordingManager::removeRecording(const QString &filePath)
{
    const QFileInfo info(filePath);
    const QString canonical = QDir::cleanPath(info.canonicalFilePath());
    QString root = QDir::cleanPath(QFileInfo(m_directory).canonicalFilePath());
    if (canonical.isEmpty() || root.isEmpty())
        return false;
    if (!root.endsWith(QLatin1Char('/')))
        root += QLatin1Char('/');
    if (canonical != QDir::cleanPath(m_directory) && !canonical.startsWith(root))
        return false;

    const bool ok = QFile::remove(canonical);
    if (ok) {
        emit recordingsChanged();
        emit storageChanged();
    }
    return ok;
}

namespace {

QStorageInfo storageFor(const QString &directory)
{
    QStorageInfo info(directory);
    if (!info.isValid() || !info.isReady())
        info.setPath(QFileInfo(directory).absolutePath());
    if (!info.isValid() || !info.isReady())
        info = QStorageInfo::root();
    info.refresh();
    return info;
}

} // namespace

qint64 RecordingManager::freeBytes() const
{
    const QStorageInfo info = storageFor(m_directory);
    if (!info.isValid() || !info.isReady())
        return -1;
    return info.bytesAvailable();
}

QString RecordingManager::freeSpaceText() const
{
    const qint64 free = freeBytes();
    if (free < 0)
        return QStringLiteral("?");
    return QLocale().formattedDataSize(free);
}

bool RecordingManager::hasEnoughSpace(qint64 minimumBytes) const
{
    const qint64 free = freeBytes();
    if (free < 0)
        return QDir().mkpath(m_directory);
    return free >= minimumBytes;
}

void RecordingManager::notifyChanged()
{
    emit recordingsChanged();
    emit storageChanged();
}

void RecordingManager::watchDirectory()
{
    if (!m_directory.isEmpty() && !m_watcher->directories().contains(m_directory))
        m_watcher->addPath(m_directory);
}
