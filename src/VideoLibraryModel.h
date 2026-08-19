#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QUrl>
#include <QVector>

class QFileSystemWatcher;
class RecordingManager;

class VideoLibraryModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(QUrl currentUrl READ currentUrl NOTIFY currentIndexChanged)
    Q_PROPERTY(QString currentName READ currentName NOTIFY currentIndexChanged)
    Q_PROPERTY(bool currentIsFolder READ currentIsFolder NOTIFY currentIndexChanged)
    Q_PROPERTY(QString rootPath READ rootPath NOTIFY pathChanged)
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY pathChanged)
    Q_PROPERTY(QString displayPath READ displayPath NOTIFY pathChanged)
    Q_PROPERTY(bool atRoot READ atRoot NOTIFY pathChanged)

public:
    enum Roles {
        FilePathRole = Qt::UserRole + 1,
        FileNameRole,
        CreatedRole,
        CreatedTextRole,
        SizeRole,
        SizeTextRole,
        UrlRole,
        IsFolderRole,
        DetailTextRole
    };
    Q_ENUM(Roles)

    explicit VideoLibraryModel(RecordingManager *recordings, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int currentIndex() const { return m_currentIndex; }
    void setCurrentIndex(int index);
    QUrl currentUrl() const;
    QString currentName() const;
    bool currentIsFolder() const;
    QString rootPath() const;
    QString currentPath() const { return m_currentPath; }
    QString displayPath() const;
    bool atRoot() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void goToRoot();
    Q_INVOKABLE bool goUp();
    Q_INVOKABLE bool openAt(int index);
    Q_INVOKABLE bool openCurrent();
    Q_INVOKABLE bool isFolderAt(int index) const;
    Q_INVOKABLE bool removeAt(int index);
    Q_INVOKABLE QUrl urlAt(int index) const;
    Q_INVOKABLE void moveCurrent(int delta);

signals:
    void countChanged();
    void currentIndexChanged();
    void pathChanged();

private:
    struct Item {
        QString filePath;
        QString fileName;
        QDateTime created;
        qint64 size = 0;
        bool isFolder = false;
    };

    void reload();
    bool isValidIndex(int index) const;
    bool isUnderRoot(const QString &path) const;
    void watchCurrentPath();
    QString normalized(const QString &path) const;

    RecordingManager *m_recordings = nullptr;
    QFileSystemWatcher *m_watcher = nullptr;
    QVector<Item> m_items;
    QString m_currentPath;
    int m_currentIndex = 0;
};
