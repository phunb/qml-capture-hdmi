#include "RecordingManager.h"

#include "AppSettings.h"

#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QLocale>
#include <QMetaObject>
#include <QRegularExpression>
#include <QStorageInfo>
#include <QThread>
#include <QTimer>
#include <QtGlobal>
#include <QVector>

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

QString uniquePath(const QString &directory, const QString &baseName)
{
    QString path = QDir(directory).filePath(baseName);
    if (!QFileInfo::exists(path))
        return path;
    const QFileInfo info(baseName);
    const QString stem = info.completeBaseName();
    const QString suffix = info.suffix();
    int n = 2;
    while (QFileInfo::exists(path)) {
        path = QDir(directory).filePath(QStringLiteral("%1_%2.%3").arg(stem).arg(n).arg(suffix));
        ++n;
    }
    return path;
}

bool parseDateFolder(const QString &name, QDate *date)
{
    static const QRegularExpression isoRe(QStringLiteral("^(\\d{4})-(\\d{2})-(\\d{2})$"));
    const QRegularExpressionMatch iso = isoRe.match(name);
    if (iso.hasMatch()) {
        const QDate parsed(iso.captured(1).toInt(), iso.captured(2).toInt(), iso.captured(3).toInt());
        if (!parsed.isValid())
            return false;
        if (date)
            *date = parsed;
        return true;
    }

    static const QRegularExpression legacyRe(QStringLiteral("^(\\d{2})-(\\d{2})-(\\d{4})$"));
    const QRegularExpressionMatch legacy = legacyRe.match(name);
    if (!legacy.hasMatch())
        return false;
    const QDate parsed(legacy.captured(3).toInt(), legacy.captured(2).toInt(), legacy.captured(1).toInt());
    if (!parsed.isValid())
        return false;
    if (date)
        *date = parsed;
    return true;
}

QString timedFileName(const QString &extension)
{
    const QDateTime now = QDateTime::currentDateTime();
    const QString stamp = now.toString(QStringLiteral("HH-mm-ss-"))
        + QStringLiteral("%1").arg(now.time().msec(), 3, 10, QChar('0'));
    return stamp + QLatin1Char('.') + extension;
}

} // namespace

RecordingManager::RecordingManager(AppSettings *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_watcher(new QFileSystemWatcher(this))
{
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        emit recordingsChanged();
    });
    connect(m_settings, &AppSettings::recordingsDirChanged, this, [this]() {
        setRootDirectory(m_settings->recordingsDir());
    });
    connect(m_settings, &AppSettings::usbChanged, this, [this]() {
        emit usbChanged();
        if (!m_usbAnnounce || m_copying)
            return;
        showFlash(usbAvailable() ? tr("Đã cắm USB") : tr("USB đã rút"));
    });

    setRootDirectory(m_settings->recordingsDir());
    QTimer::singleShot(2000, this, [this]() { m_usbAnnounce = true; });
}

RecordingManager::~RecordingManager()
{
    if (m_copyThread) {
        m_copyThread->disconnect();
        m_copyThread->wait(120000);
        delete m_copyThread;
        m_copyThread = nullptr;
    }
}

QString RecordingManager::directory() const
{
    return m_sessionDirectory.isEmpty() ? m_rootDirectory : m_sessionDirectory;
}

bool RecordingManager::usbAvailable() const
{
    return m_settings && m_settings->usbAvailable();
}

void RecordingManager::setRootDirectory(const QString &directory)
{
    if (directory.isEmpty())
        return;

    const QString next = QDir::cleanPath(directory);
    if (m_rootDirectory == next) {
        QDir().mkpath(m_rootDirectory);
        if (m_sessionDirectory.isEmpty())
            createSessionDirectory();
        return;
    }

    if (!m_rootDirectory.isEmpty())
        m_watcher->removePath(m_rootDirectory);

    m_rootDirectory = next;
    QDir().mkpath(m_rootDirectory);
    purgeOldFolders();
    m_sessionDirectory.clear();
    m_sessionName.clear();
    watchDirectory();
    emit rootChanged();
    createSessionDirectory();
}

void RecordingManager::setWriting(bool writing)
{
    m_writing = writing;
}

QString RecordingManager::createNewRecordingPath()
{
    const QString dir = ensureSession();
    QDir().mkpath(dir);
    return uniquePath(dir, timedFileName(QStringLiteral("mp4")));
}

QString RecordingManager::createNewCapturePath()
{
    const QString dir = ensureSession();
    QDir().mkpath(dir);
    return uniquePath(dir, timedFileName(QStringLiteral("jpg")));
}

bool RecordingManager::removeRecording(const QString &filePath)
{
    const QFileInfo info(filePath);
    const QString canonical = QDir::cleanPath(info.canonicalFilePath());
    QString root = QDir::cleanPath(QFileInfo(m_rootDirectory).canonicalFilePath());
    if (canonical.isEmpty() || root.isEmpty())
        return false;
    if (!root.endsWith(QLatin1Char('/')))
        root += QLatin1Char('/');
    if (canonical != QDir::cleanPath(m_rootDirectory) && !canonical.startsWith(root))
        return false;

    const bool ok = QFile::remove(canonical);
    if (ok)
        emit recordingsChanged();
    return ok;
}

qint64 RecordingManager::freeBytes() const
{
    const QStorageInfo info = storageFor(directory());
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
        return QDir().mkpath(directory());
    return free >= minimumBytes;
}

void RecordingManager::notifyChanged()
{
    emit recordingsChanged();
}

bool RecordingManager::startNewSession()
{
    if (m_writing)
        return false;
    return !createSessionDirectory().isEmpty();
}

void RecordingManager::exportToUsb()
{
    if (m_copying)
        return;
    if (m_writing) {
        showFlash(tr("Đang ghi hình\nKhông chép USB được"));
        return;
    }
    if (!usbAvailable()) {
        m_copyError = true;
        m_copyProgress = 0;
        setCopyMessage(tr("Chưa có USB"));
        emit copyErrorChanged();
        emit copyProgressChanged();
        QTimer::singleShot(4000, this, [this]() {
            if (!m_copying) {
                m_copyError = false;
                setCopyMessage(QString());
                emit copyErrorChanged();
            }
        });
        return;
    }

    const QString srcRoot = m_rootDirectory;
    const QString dstRoot = m_settings->usbOutputDir();
    if (srcRoot.isEmpty() || dstRoot.isEmpty() || !QDir(srcRoot).exists()) {
        m_copyError = true;
        m_copyProgress = 0;
        setCopyMessage(tr("Không có dữ liệu để chép"));
        emit copyErrorChanged();
        emit copyProgressChanged();
        QTimer::singleShot(4000, this, [this]() {
            if (!m_copying) {
                m_copyError = false;
                setCopyMessage(QString());
                emit copyErrorChanged();
            }
        });
        return;
    }

    m_copying = true;
    m_copyError = false;
    m_copyProgress = 0;
    setCopyMessage(tr("Đang copy sang USB"));
    emit copyingChanged();
    emit copyErrorChanged();
    emit copyProgressChanged();

    if (m_copyThread) {
        m_copyThread->wait(120000);
        delete m_copyThread;
        m_copyThread = nullptr;
    }

    m_copyThread = QThread::create([this, srcRoot, dstRoot]() {
        QDir().mkpath(dstRoot);

        QDirIterator dirIt(srcRoot, QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (dirIt.hasNext()) {
            const QString absDir = dirIt.next();
            const QString relative = QDir(srcRoot).relativeFilePath(absDir);
            QDir().mkpath(QDir(dstRoot).filePath(relative));
        }

        QVector<CopyFile> pending;
        qint64 totalBytes = 0;
        qint64 copiedBytes = 0;
        QDirIterator it(srcRoot, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            const QFileInfo info = it.fileInfo();
            if (info.suffix().compare(QLatin1String("tmp"), Qt::CaseInsensitive) == 0)
                continue;

            const QString relative = QDir(srcRoot).relativeFilePath(info.absoluteFilePath());
            const QString dest = QDir(dstRoot).filePath(relative);
            totalBytes += info.size();
            if (QFileInfo::exists(dest)) {
                copiedBytes += info.size();
                continue;
            }
            CopyFile file;
            file.source = info.absoluteFilePath();
            file.destination = dest;
            file.size = info.size();
            pending.append(file);
        }

        int lastPercent = -1;
        const auto report = [this, totalBytes, &lastPercent](qint64 copied) {
            const int percent = totalBytes > 0
                ? qBound(0, int(copied * 100 / totalBytes), 100)
                : 100;
            if (percent == lastPercent)
                return;
            lastPercent = percent;
            QMetaObject::invokeMethod(this, [this, percent]() {
                setCopyProgress(percent);
            }, Qt::QueuedConnection);
        };
        report(copiedBytes);

        if (pending.isEmpty()) {
            QMetaObject::invokeMethod(this, [this]() {
                finishCopy(true, tr("USB đã có đủ file"));
            }, Qt::QueuedConnection);
            return;
        }

        QMetaObject::invokeMethod(this, [this]() {
            setCopyMessage(tr("Đang copy sang USB"));
        }, Qt::QueuedConnection);

        for (const CopyFile &file : pending) {
            QDir().mkpath(QFileInfo(file.destination).absolutePath());
            const CopyFileResult result =
                copyFileSkippingExisting(file, &copiedBytes, [&]() { report(copiedBytes); });
            if (result == CopyFileResult::DiskFull) {
                QMetaObject::invokeMethod(this, [this]() {
                    finishCopy(false, tr("USB đã đầy, không tiếp tục thực hiện được"));
                }, Qt::QueuedConnection);
                return;
            }
            if (result == CopyFileResult::Failed) {
                QMetaObject::invokeMethod(this, [this]() {
                    finishCopy(false, tr("Lỗi khi chép USB"));
                }, Qt::QueuedConnection);
                return;
            }
            report(copiedBytes);
        }

        QMetaObject::invokeMethod(this, [this]() {
            finishCopy(true, tr("Đã copy xong"));
        }, Qt::QueuedConnection);
    });

    connect(m_copyThread, &QThread::finished, this, [this]() {
        m_copyThread->deleteLater();
        m_copyThread = nullptr;
    });
    m_copyThread->start();
}

QString RecordingManager::ensureSession()
{
    const QString todayPath = QDir(m_rootDirectory).filePath(QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd")));
    if (m_sessionDirectory == todayPath && QDir(m_sessionDirectory).exists())
        return m_sessionDirectory;
    return createSessionDirectory();
}

QString RecordingManager::createSessionDirectory()
{
    if (m_rootDirectory.isEmpty())
        return {};

    const QString dateFolder = QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"));
    const QString path = QDir(m_rootDirectory).filePath(dateFolder);
    if (!QDir().mkpath(path))
        return {};

    if (!m_sessionDirectory.isEmpty() && m_sessionDirectory != path)
        m_watcher->removePath(m_sessionDirectory);

    m_sessionDirectory = path;
    m_sessionName = dateFolder;
    watchDirectory();
    if (usbAvailable()) {
        const QString usbDir = usbPathForLocal(path);
        if (!usbDir.isEmpty())
            QDir().mkpath(usbDir);
    }
    emit sessionChanged();
    emit recordingsChanged();
    return m_sessionDirectory;
}

void RecordingManager::purgeOldFolders()
{
    if (m_rootDirectory.isEmpty())
        return;

    // Keep today and yesterday. Remove date folders from 2 days ago and older.
    const QDate keepFrom = QDate::currentDate().addDays(-1);
    QDir root(m_rootDirectory);
    const QFileInfoList folders = root.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &info : folders) {
        QDate folderDate;
        bool old = false;
        if (parseDateFolder(info.fileName(), &folderDate))
            old = folderDate < keepFrom;
        else
            old = info.lastModified().date() < keepFrom;
        if (!old)
            continue;
        if (QDir(info.absoluteFilePath()).removeRecursively())
            qInfo() << "Purged output folder older than 2 days" << info.absoluteFilePath();
    }
}

void RecordingManager::mirrorToUsb(const QString &localFilePath)
{
    const QString dest = usbPathForLocal(localFilePath);
    if (dest.isEmpty() || !QFileInfo::exists(localFilePath))
        return;

    const qint64 size = QFileInfo(localFilePath).size();
    const auto job = [localFilePath, dest]() {
        copyFileAtomic(localFilePath, dest);
    };
    if (size <= 16LL * 1024 * 1024) {
        job();
        return;
    }

    QThread *thread = QThread::create(job);
    QObject::connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

QString RecordingManager::usbPathForLocal(const QString &localFilePath) const
{
    if (!usbAvailable() || m_rootDirectory.isEmpty() || localFilePath.isEmpty())
        return {};

    const QString relative = QDir(m_rootDirectory).relativeFilePath(localFilePath);
    if (relative.isEmpty() || relative.startsWith(QLatin1String("..")))
        return {};
    return QDir(m_settings->usbOutputDir()).filePath(relative);
}

void RecordingManager::watchDirectory()
{
    const QStringList watched = m_watcher->directories();
    if (!watched.isEmpty())
        m_watcher->removePaths(watched);
    if (!m_rootDirectory.isEmpty())
        m_watcher->addPath(m_rootDirectory);
    if (!m_sessionDirectory.isEmpty() && m_sessionDirectory != m_rootDirectory) {
        m_watcher->addPath(m_sessionDirectory);
        const QString dateDir = QFileInfo(m_sessionDirectory).absolutePath();
        if (!dateDir.isEmpty() && dateDir != m_rootDirectory)
            m_watcher->addPath(dateDir);
    }
}

void RecordingManager::showFlash(const QString &message)
{
    m_flashMessage = message;
    emit flashMessageChanged();
    QTimer::singleShot(3500, this, [this]() {
        if (!m_flashMessage.isEmpty()) {
            m_flashMessage.clear();
            emit flashMessageChanged();
        }
    });
}

void RecordingManager::setCopyProgress(int percent)
{
    percent = qBound(0, percent, 100);
    if (m_copyProgress == percent)
        return;
    m_copyProgress = percent;
    emit copyProgressChanged();
}

void RecordingManager::setCopyMessage(const QString &message)
{
    if (m_copyMessage == message)
        return;
    m_copyMessage = message;
    emit copyMessageChanged();
}

void RecordingManager::finishCopy(bool ok, const QString &message)
{
    m_copying = false;
    m_copyError = !ok;
    m_copyProgress = ok ? 100 : m_copyProgress;
    setCopyMessage(message);
    emit copyingChanged();
    emit copyErrorChanged();
    emit copyProgressChanged();
    QTimer::singleShot(ok ? 5000 : 6000, this, [this]() {
        if (!m_copying) {
            m_copyProgress = 0;
            m_copyError = false;
            setCopyMessage(QString());
            emit copyErrorChanged();
            emit copyProgressChanged();
        }
    });
}

RecordingManager::CopyFileResult RecordingManager::copyFileSkippingExisting(
    const CopyFile &file, qint64 *copiedBytes, const std::function<void()> &onProgress)
{
    if (QFileInfo::exists(file.destination)) {
        if (copiedBytes)
            *copiedBytes += file.size;
        if (onProgress)
            onProgress();
        return CopyFileResult::SkippedExisting;
    }

    const QString destDir = QFileInfo(file.destination).absolutePath();
    QStorageInfo destStorage = storageFor(destDir);
    destStorage.refresh();
    if (destStorage.isValid() && destStorage.isReady()
        && destStorage.bytesAvailable() < file.size + 65536) {
        return CopyFileResult::DiskFull;
    }

    QFile in(file.source);
    if (!in.open(QIODevice::ReadOnly))
        return CopyFileResult::Failed;

    QFile out(file.destination);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        destStorage.refresh();
        if (destStorage.isValid() && destStorage.isReady() && destStorage.bytesAvailable() < 65536)
            return CopyFileResult::DiskFull;
        return CopyFileResult::Failed;
    }

    char buffer[256 * 1024];
    while (!in.atEnd()) {
        const qint64 n = in.read(buffer, sizeof(buffer));
        if (n < 0) {
            out.close();
            QFile::remove(file.destination);
            return CopyFileResult::Failed;
        }
        if (out.write(buffer, n) != n) {
            out.close();
            QFile::remove(file.destination);
            destStorage.refresh();
            if (destStorage.isValid() && destStorage.isReady() && destStorage.bytesAvailable() < 65536)
                return CopyFileResult::DiskFull;
            return CopyFileResult::Failed;
        }
        if (copiedBytes)
            *copiedBytes += n;
        if (onProgress)
            onProgress();
    }
    return CopyFileResult::Ok;
}

bool RecordingManager::copyFileAtomic(const QString &source, const QString &destination)
{
    if (QFileInfo::exists(destination))
        return true;

    QDir().mkpath(QFileInfo(destination).absolutePath());
    const QString tempPath = destination + QStringLiteral(".tmp");
    QFile::remove(tempPath);

    CopyFile file;
    file.source = source;
    file.destination = tempPath;
    file.size = QFileInfo(source).size();
    qint64 copied = 0;
    const CopyFileResult copiedResult = copyFileSkippingExisting(file, &copied);
    if (copiedResult == CopyFileResult::Failed || copiedResult == CopyFileResult::DiskFull) {
        QFile::remove(tempPath);
        return false;
    }
    if (QFileInfo::exists(destination)) {
        QFile::remove(tempPath);
        return true;
    }
    if (!QFile::rename(tempPath, destination)) {
        QFile::remove(tempPath);
        return false;
    }
    return true;
}
