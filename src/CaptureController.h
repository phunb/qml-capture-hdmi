#pragma once

#include <QCamera>
#include <QCameraDevice>
#include <QElapsedTimer>
#include <QList>
#include <QMediaCaptureSession>
#include <QMediaDevices>
#include <QMediaRecorder>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVideoFrame>

class AppSettings;
class RecordingManager;

class CaptureController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList deviceNames READ deviceNames NOTIFY devicesChanged)
    Q_PROPERTY(int currentDeviceIndex READ currentDeviceIndex WRITE setCurrentDeviceIndex NOTIFY currentDeviceIndexChanged)
    Q_PROPERTY(QString currentDeviceName READ currentDeviceName NOTIFY currentDeviceIndexChanged)
    Q_PROPERTY(bool hasDevice READ hasDevice NOTIFY devicesChanged)
    Q_PROPERTY(bool previewActive READ previewActive NOTIFY previewActiveChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(qint64 recordingDurationMs READ recordingDurationMs NOTIFY recordingDurationMsChanged)
    Q_PROPERTY(QString recordingDurationText READ recordingDurationText NOTIFY recordingDurationMsChanged)
    Q_PROPERTY(QString recordingPath READ recordingPath NOTIFY recordingChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusChanged)
    Q_PROPERTY(bool signalPresent READ signalPresent NOTIFY signalPresentChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QString flashMessage READ flashMessage NOTIFY flashMessageChanged)

public:
    CaptureController(AppSettings *settings, RecordingManager *recordings, QObject *parent = nullptr);
    ~CaptureController() override;

    QStringList deviceNames() const { return m_deviceNames; }
    int currentDeviceIndex() const { return m_currentDeviceIndex; }
    void setCurrentDeviceIndex(int index);
    QString currentDeviceName() const;
    bool hasDevice() const { return !m_devices.isEmpty(); }
    bool previewActive() const { return m_previewActive; }
    bool recording() const { return m_recording; }
    qint64 recordingDurationMs() const { return m_recordingDurationMs; }
    QString recordingDurationText() const;
    QString recordingPath() const { return m_recordingPath; }
    QString status() const { return m_status; }
    QString statusMessage() const { return m_statusMessage; }
    bool signalPresent() const { return m_signalPresent; }
    QString lastError() const { return m_lastError; }
    QString flashMessage() const { return m_flashMessage; }

    Q_INVOKABLE void setPreviewOutput(QObject *output);
    Q_INVOKABLE void startPreview();
    Q_INVOKABLE void stopPreview();
    Q_INVOKABLE bool startRecording();
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void toggleRecording();
    Q_INVOKABLE bool captureSnapshot();
    Q_INVOKABLE void refreshDevices();

signals:
    void devicesChanged();
    void currentDeviceIndexChanged();
    void previewActiveChanged();
    void recordingChanged();
    void recordingDurationMsChanged();
    void statusChanged();
    void signalPresentChanged();
    void lastErrorChanged();
    void recordingFinished(const QString &path);
    void snapshotCaptured(const QString &path);
    void flashMessageChanged();

private:
    void applyDevice(int index);
    void choosePreferredDevice();
    void configureCameraFormat();
    void configureRecorder();
    void updateStatus();
    void setStatus(const QString &status, const QString &message);
    void setError(const QString &error);
    void setRecording(bool recording);
    void onFrame(const QVideoFrame &frame);
    bool frameLooksBlack(const QVideoFrame &frame) const;
    QString formatDuration(qint64 ms) const;
    void showFlash(const QString &message);

    AppSettings *m_settings = nullptr;
    RecordingManager *m_recordings = nullptr;
    QMediaDevices m_mediaDevices;
    QMediaCaptureSession m_session;
    QCamera m_camera;
    QMediaRecorder m_recorder;

    QList<QCameraDevice> m_devices;
    QStringList m_deviceNames;
    int m_currentDeviceIndex = -1;
    bool m_previewActive = false;
    bool m_recording = false;
    bool m_signalPresent = false;
    bool m_blackFrames = false;
    int m_frameCounter = 0;
    qint64 m_recordingDurationMs = 0;
    QString m_recordingPath;
    QString m_status = QStringLiteral("nodevice");
    QString m_statusMessage;
    QString m_lastError;
    QString m_flashMessage;
    QVideoFrame m_lastFrame;
    QElapsedTimer m_lastFrameTimer;
    QTimer m_watchdog;
    QTimer m_tick;
    QTimer m_flashTimer;
    QPointer<QObject> m_previewOutput;
};
