#pragma once

#include <QObject>
#include <QString>
#include <functional>

class AppSettings;
class QFileSystemWatcher;
class QThread;

class RecordingManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString rootDirectory READ rootDirectory NOTIFY rootChanged)
    Q_PROPERTY(QString directory READ directory NOTIFY sessionChanged)
    Q_PROPERTY(QString sessionName READ sessionName NOTIFY sessionChanged)
    Q_PROPERTY(bool copying READ copying NOTIFY copyingChanged)
    Q_PROPERTY(int copyProgress READ copyProgress NOTIFY copyProgressChanged)
    Q_PROPERTY(QString copyMessage READ copyMessage NOTIFY copyMessageChanged)
    Q_PROPERTY(bool copyError READ copyError NOTIFY copyErrorChanged)
    Q_PROPERTY(QString flashMessage READ flashMessage NOTIFY flashMessageChanged)
    Q_PROPERTY(bool usbAvailable READ usbAvailable NOTIFY usbChanged)

public:
    explicit RecordingManager(AppSettings *settings, QObject *parent = nullptr);
    ~RecordingManager() override;

    QString rootDirectory() const { return m_rootDirectory; }
    QString directory() const;
    QString sessionName() const { return m_sessionName; }

    bool copying() const { return m_copying; }
    int copyProgress() const { return m_copyProgress; }
    QString copyMessage() const { return m_copyMessage; }
    bool copyError() const { return m_copyError; }
    QString flashMessage() const { return m_flashMessage; }
    bool usbAvailable() const;

    void setRootDirectory(const QString &directory);
    void setWriting(bool writing);

    QString createNewRecordingPath();
    QString createNewCapturePath();
    bool removeRecording(const QString &filePath);
    void mirrorToUsb(const QString &localFilePath);

    qint64 freeBytes() const;
    QString freeSpaceText() const;
    bool hasEnoughSpace(qint64 minimumBytes) const;
    void notifyChanged();

    Q_INVOKABLE bool startNewSession();
    Q_INVOKABLE void exportToUsb();

signals:
    void rootChanged();
    void sessionChanged();
    void recordingsChanged();
    void copyingChanged();
    void copyProgressChanged();
    void copyMessageChanged();
    void copyErrorChanged();
    void flashMessageChanged();
    void usbChanged();

private:
    struct CopyFile {
        QString source;
        QString destination;
        qint64 size = 0;
    };

    QString ensureSession();
    QString createSessionDirectory();
    void purgeOldFolders();
    void watchDirectory();
    void showFlash(const QString &message);
    void setCopyProgress(int percent);
    void setCopyMessage(const QString &message);
    void finishCopy(bool ok, const QString &message);
    QString usbPathForLocal(const QString &localFilePath) const;
    static bool copyFileSkippingExisting(const CopyFile &file, qint64 *copiedBytes,
                                        const std::function<void()> &onProgress = {});
    static bool copyFileAtomic(const QString &source, const QString &destination);

    AppSettings *m_settings = nullptr;
    QFileSystemWatcher *m_watcher = nullptr;
    QThread *m_copyThread = nullptr;
    QString m_rootDirectory;
    QString m_sessionDirectory;
    QString m_sessionName;
    QString m_flashMessage;
    QString m_copyMessage;
    bool m_writing = false;
    bool m_copying = false;
    bool m_copyError = false;
    bool m_usbAnnounce = false;
    int m_copyProgress = 0;
};
