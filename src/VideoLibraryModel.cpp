#include "VideoLibraryModel.h"

#include "RecordingManager.h"

#include <QDir>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QLocale>
#include <QUrl>

VideoLibraryModel::VideoLibraryModel(RecordingManager *recordings, QObject *parent)
    : QAbstractListModel(parent)
    , m_recordings(recordings)
    , m_watcher(new QFileSystemWatcher(this))
{
    m_currentPath = normalized(m_recordings->directory());
    connect(m_recordings, &RecordingManager::directoryChanged, this, &VideoLibraryModel::goToRoot);
    connect(m_recordings, &RecordingManager::recordingsChanged, this, &VideoLibraryModel::refresh);
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, &VideoLibraryModel::refresh);
    watchCurrentPath();
    reload();
}

int VideoLibraryModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.size();
}

QVariant VideoLibraryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};

    const Item &item = m_items.at(index.row());
    switch (role) {
    case FilePathRole:
        return item.filePath;
    case FileNameRole:
        return item.fileName;
    case CreatedRole:
        return item.created;
    case CreatedTextRole:
        return item.created.toString(QStringLiteral("dd/MM/yyyy  HH:mm"));
    case SizeRole:
        return item.size;
    case SizeTextRole:
        return item.isFolder ? QString() : QLocale().formattedDataSize(item.size);
    case UrlRole:
        return item.isFolder ? QUrl() : QUrl::fromLocalFile(item.filePath);
    case IsFolderRole:
        return item.isFolder;
    case IsImageRole:
        return item.isImage;
    case DetailTextRole:
        if (item.isFolder)
            return QStringLiteral("Thư mục  •  %1")
                .arg(item.created.toString(QStringLiteral("dd/MM/yyyy  HH:mm")));
        return QStringLiteral("%1   •   %2")
            .arg(item.created.toString(QStringLiteral("dd/MM/yyyy  HH:mm")),
                 QLocale().formattedDataSize(item.size));
    default:
        return {};
    }
}

QHash<int, QByteArray> VideoLibraryModel::roleNames() const
{
    return {
        {FilePathRole, "filePath"},
        {FileNameRole, "fileName"},
        {CreatedRole, "created"},
        {CreatedTextRole, "createdText"},
        {SizeRole, "size"},
        {SizeTextRole, "sizeText"},
        {UrlRole, "url"},
        {IsFolderRole, "isFolder"},
        {IsImageRole, "isImage"},
        {DetailTextRole, "detailText"},
    };
}

void VideoLibraryModel::setCurrentIndex(int index)
{
    if (m_items.isEmpty()) {
        if (m_currentIndex != 0) {
            m_currentIndex = 0;
            emit currentIndexChanged();
        }
        return;
    }

    index = qBound(0, index, m_items.size() - 1);
    if (m_currentIndex == index)
        return;
    m_currentIndex = index;
    emit currentIndexChanged();
}

QUrl VideoLibraryModel::currentUrl() const
{
    return urlAt(m_currentIndex);
}

QString VideoLibraryModel::currentName() const
{
    if (!isValidIndex(m_currentIndex))
        return {};
    return m_items.at(m_currentIndex).fileName;
}

bool VideoLibraryModel::currentIsFolder() const
{
    return isFolderAt(m_currentIndex);
}

bool VideoLibraryModel::currentIsImage() const
{
    return isImageAt(m_currentIndex);
}

QString VideoLibraryModel::rootPath() const
{
    return QDir::toNativeSeparators(normalized(m_recordings->directory()));
}

QString VideoLibraryModel::displayPath() const
{
    const QString root = normalized(m_recordings->directory());
    const QString current = normalized(m_currentPath);
    if (current == root)
        return QDir::toNativeSeparators(root);

    QString relative = QDir(root).relativeFilePath(current);
    relative.replace(QLatin1Char('/'), QDir::separator());
    return QDir::toNativeSeparators(root) + QDir::separator() + relative;
}

bool VideoLibraryModel::atRoot() const
{
    return normalized(m_currentPath) == normalized(m_recordings->directory());
}

void VideoLibraryModel::refresh()
{
    reload();
}

void VideoLibraryModel::goToRoot()
{
    m_currentPath = normalized(m_recordings->directory());
    watchCurrentPath();
    reload();
    emit pathChanged();
}

bool VideoLibraryModel::goUp()
{
    if (atRoot())
        return false;

    const QString parent = normalized(QFileInfo(m_currentPath).absolutePath());
    if (!isUnderRoot(parent))
        return false;

    m_currentPath = parent;
    watchCurrentPath();
    reload();
    emit pathChanged();
    return true;
}

bool VideoLibraryModel::openAt(int index)
{
    if (!isFolderAt(index))
        return false;

    const QString next = normalized(m_items.at(index).filePath);
    if (!isUnderRoot(next))
        return false;

    m_currentPath = next;
    watchCurrentPath();
    reload();
    emit pathChanged();
    return true;
}

bool VideoLibraryModel::openCurrent()
{
    return openAt(m_currentIndex);
}

bool VideoLibraryModel::isFolderAt(int index) const
{
    return isValidIndex(index) && m_items.at(index).isFolder;
}

bool VideoLibraryModel::isImageAt(int index) const
{
    return isValidIndex(index) && m_items.at(index).isImage;
}

bool VideoLibraryModel::removeAt(int index)
{
    if (!isValidIndex(index) || m_items.at(index).isFolder)
        return false;
    return m_recordings->removeRecording(m_items.at(index).filePath);
}

QUrl VideoLibraryModel::urlAt(int index) const
{
    if (!isValidIndex(index) || m_items.at(index).isFolder)
        return {};
    return QUrl::fromLocalFile(m_items.at(index).filePath);
}

void VideoLibraryModel::moveCurrent(int delta)
{
    if (m_items.isEmpty())
        return;
    setCurrentIndex(m_currentIndex + delta);
}

void VideoLibraryModel::reload()
{
    const QString currentPath = isValidIndex(m_currentIndex) ? m_items.at(m_currentIndex).filePath : QString();
    QDir dir(m_currentPath);
    if (!dir.exists()) {
        m_currentPath = normalized(m_recordings->directory());
        dir.setPath(m_currentPath);
        QDir().mkpath(m_currentPath);
        watchCurrentPath();
    }

    beginResetModel();
    m_items.clear();

    const QFileInfoList folders = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QFileInfo &info : folders) {
        Item item;
        item.filePath = info.absoluteFilePath();
        item.fileName = info.fileName();
        item.created = info.lastModified();
        item.size = 0;
        item.isFolder = true;
        item.isImage = false;
        m_items.append(item);
    }

    const QFileInfoList files = dir.entryInfoList(
        {QStringLiteral("*.mp4"), QStringLiteral("*.mkv"), QStringLiteral("*.mov"), QStringLiteral("*.avi"),
         QStringLiteral("*.jpg"), QStringLiteral("*.jpeg"), QStringLiteral("*.png")},
        QDir::Files,
        QDir::Time);
    for (const QFileInfo &info : files) {
        Item item;
        item.filePath = info.absoluteFilePath();
        item.fileName = info.fileName();
        item.created = info.lastModified();
        item.size = info.size();
        item.isFolder = false;
        const QString suffix = info.suffix().toLower();
        item.isImage = (suffix == QLatin1String("jpg")
                        || suffix == QLatin1String("jpeg")
                        || suffix == QLatin1String("png"));
        m_items.append(item);
    }
    endResetModel();

    int next = 0;
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).filePath == currentPath) {
            next = i;
            break;
        }
    }
    m_currentIndex = m_items.isEmpty() ? 0 : qBound(0, next, m_items.size() - 1);

    emit countChanged();
    emit currentIndexChanged();
}

bool VideoLibraryModel::isValidIndex(int index) const
{
    return index >= 0 && index < m_items.size();
}

bool VideoLibraryModel::isUnderRoot(const QString &path) const
{
    const QString root = normalized(m_recordings->directory());
    const QString candidate = normalized(path);
    return candidate == root || candidate.startsWith(root + QLatin1Char('/'));
}

void VideoLibraryModel::watchCurrentPath()
{
    const QStringList watched = m_watcher->directories();
    if (!watched.isEmpty())
        m_watcher->removePaths(watched);
    if (!m_currentPath.isEmpty())
        m_watcher->addPath(m_currentPath);
}

QString VideoLibraryModel::normalized(const QString &path) const
{
    return QDir::cleanPath(QFileInfo(path).absoluteFilePath());
}
