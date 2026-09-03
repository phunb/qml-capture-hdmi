#pragma once

#include <QAbstractListModel>
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
    Q_PROPERTY(bool currentIsImage READ currentIsImage NOTIFY currentIndexChanged)
    Q_PROPERTY(bool atRoot READ atRoot NOTIFY pathChanged)

public:
    enum Roles {
        UrlRole = Qt::UserRole + 1,
        IsFolderRole,
        IsImageRole
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
    bool currentIsImage() const;
    bool atRoot() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void goToRoot();
    Q_INVOKABLE void goToSession();
    Q_INVOKABLE bool goUp();
    Q_INVOKABLE bool openAt(int index);
    Q_INVOKABLE bool openCurrent();
    Q_INVOKABLE bool isFolderAt(int index) const;
    Q_INVOKABLE bool isImageAt(int index) const;
    Q_INVOKABLE bool removeAt(int index);
    Q_INVOKABLE QUrl urlAt(int index) const;

signals:
    void countChanged();
    void currentIndexChanged();
    void pathChanged();

private:
    struct Item {
        QString filePath;
        QString fileName;
        bool isFolder = false;
        bool isImage = false;
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
