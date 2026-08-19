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
        {QStringLiteral("*.mp4"), QStringLiteral("*.mkv"), QStringLiteral("*.mov")},
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
    return QDir(m_directory).filePath(QStringLiteral("hdmi_%1.mp4").arg(stamp));
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

qint64 RecordingManager::freeBytes() const
{
    return QStorageInfo(m_directory).bytesAvailable();
}

QString RecordingManager::freeSpaceText() const
{
    return QLocale().formattedDataSize(qMax<qint64>(0, freeBytes()));
}

bool RecordingManager::hasEnoughSpace(qint64 minimumBytes) const
{
    return freeBytes() >= minimumBytes;
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
