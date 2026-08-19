#include "CaptureController.h"

#include "AppSettings.h"
#include "RecordingManager.h"

#include <QAudioDevice>
#include <QCameraDevice>
#include <QCameraFormat>
#include <QColor>
#include <QImage>
#include <QMediaFormat>
#include <QPoint>
#include <QSize>
#include <QUrl>
#include <QVideoFrame>
#include <QVideoSink>

namespace {

bool looksLikeHdmiDevice(const QString &name)
{
    const QString n = name.toLower();
    const QStringList keys = {
        QStringLiteral("hdmi"),
        QStringLiteral("capture"),
        QStringLiteral("cam link"),
        QStringLiteral("camlink"),
        QStringLiteral("macrosilicon"),
        QStringLiteral("usb video"),
        QStringLiteral("uvc"),
        QStringLiteral("live gamer"),
        QStringLiteral("avermedia"),
        QStringLiteral("elgato"),
    };
    for (const QString &key : keys) {
        if (n.contains(key))
            return true;
    }
    return false;
}

QCameraFormat bestFormat(const QCameraDevice &device)
{
    QCameraFormat best;
    int bestScore = -1;
    for (const QCameraFormat &format : device.videoFormats()) {
        const QSize size = format.resolution();
        const int pixels = size.width() * size.height();
        const int fps = qRound(format.maxFrameRate());
        int score = pixels + fps * 1000;
        if (size.width() == 1920 && size.height() == 1080)
            score += 2'000'000;
        else if (size.width() == 1280 && size.height() == 720)
            score += 500'000;
        if (fps >= 50)
            score += 50'000;
        if (score > bestScore) {
            bestScore = score;
            best = format;
        }
    }
    return best;
}

} // namespace

CaptureController::CaptureController(AppSettings *settings, RecordingManager *recordings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_recordings(recordings)
{
    m_session.setCamera(&m_camera);
    m_session.setRecorder(&m_recorder);
    m_session.setAudioInput(&m_audioInput);
    m_session.setAudioOutput(&m_audioOutput);
    m_audioOutput.setVolume(1.0);

    configureRecorder();

    connect(&m_mediaDevices, &QMediaDevices::videoInputsChanged, this, &CaptureController::refreshDevices);
    connect(&m_mediaDevices, &QMediaDevices::audioInputsChanged, this, &CaptureController::configureAudio);

    connect(&m_camera, &QCamera::errorOccurred, this, [this](QCamera::Error, const QString &error) {
        setError(error);
    });
    connect(&m_camera, &QCamera::activeChanged, this, [this](bool active) {
        if (m_previewActive != active) {
            m_previewActive = active;
            emit previewActiveChanged();
        }
        if (!active) {
            m_signalPresent = false;
            emit signalPresentChanged();
        }
        updateStatus();
    });

    connect(&m_recorder, &QMediaRecorder::recorderStateChanged, this, [this](QMediaRecorder::RecorderState state) {
        const bool rec = state == QMediaRecorder::RecordingState;
        setRecording(rec);
        if (state == QMediaRecorder::StoppedState && !m_recordingPath.isEmpty()) {
            emit recordingFinished(m_recordingPath);
            m_recordings->notifyChanged();
        }
        updateStatus();
    });
    connect(&m_recorder, &QMediaRecorder::durationChanged, this, [this](qint64 duration) {
        if (m_recordingDurationMs == duration)
            return;
        m_recordingDurationMs = duration;
        emit recordingDurationMsChanged();
        const qint64 limitMs = qint64(m_settings->maxRecordingMinutes()) * 60 * 1000;
        if (m_recording && duration >= limitMs)
            stopRecording();
    });
    connect(&m_recorder, &QMediaRecorder::errorOccurred, this, [this](QMediaRecorder::Error, const QString &error) {
        setError(error);
        setRecording(false);
        updateStatus();
    });

    m_watchdog.setInterval(1500);
    connect(&m_watchdog, &QTimer::timeout, this, [this]() {
        const bool present = m_previewActive && m_lastFrameTimer.isValid()
            && m_lastFrameTimer.elapsed() < 1600 && !m_blackFrames;
        if (present != m_signalPresent) {
            m_signalPresent = present;
            emit signalPresentChanged();
            updateStatus();
        }
    });
    m_watchdog.start();

    m_tick.setInterval(1000);
    connect(&m_tick, &QTimer::timeout, this, [this]() {
        if (m_recording)
            emit recordingDurationMsChanged();
    });
    m_tick.start();

    m_statusMessage = tr("Đang tìm thiết bị HDMI...");
    refreshDevices();
}

CaptureController::~CaptureController()
{
    if (m_recorder.recorderState() == QMediaRecorder::RecordingState)
        m_recorder.stop();
    m_camera.stop();
    m_session.setVideoOutput(nullptr);
}

void CaptureController::setCurrentDeviceIndex(int index)
{
    applyDevice(index);
}

QString CaptureController::currentDeviceName() const
{
    if (m_currentDeviceIndex < 0 || m_currentDeviceIndex >= m_deviceNames.size())
        return tr("Không có thiết bị");
    return m_deviceNames.at(m_currentDeviceIndex);
}

void CaptureController::setMuted(bool muted)
{
    if (m_muted == muted)
        return;
    m_muted = muted;
    m_audioOutput.setMuted(muted);
    emit mutedChanged();
}

void CaptureController::setPreviewOutput(QObject *output)
{
    m_previewOutput = output;
    m_session.setVideoOutput(output);
    if (!output)
        return;

    if (QVideoSink *sink = output->property("videoSink").value<QVideoSink *>()) {
        connect(sink, &QVideoSink::videoFrameChanged, this, &CaptureController::onFrame, Qt::UniqueConnection);
    }
}

void CaptureController::startPreview()
{
    if (!hasDevice()) {
        refreshDevices();
        if (!hasDevice()) {
            setStatus(QStringLiteral("nodevice"), tr("Không tìm thấy thiết bị HDMI Capture."));
            return;
        }
    }
    m_camera.start();
}

void CaptureController::stopPreview()
{
    if (m_recording)
        return;
    m_camera.stop();
}

bool CaptureController::startRecording()
{
    if (m_recording)
        return true;
    if (!hasDevice()) {
        setError(tr("Không có thiết bị HDMI để ghi."));
        return false;
    }
    if (!m_recordings->hasEnoughSpace(m_settings->minFreeBytes())) {
        setError(tr("Không đủ dung lượng ổ đĩa để ghi video."));
        return false;
    }

    if (!m_camera.isActive())
        m_camera.start();

    m_recordingPath = m_recordings->createNewRecordingPath();
    m_recorder.setOutputLocation(QUrl::fromLocalFile(m_recordingPath));
    m_recorder.record();
    if (m_recorder.error() != QMediaRecorder::NoError) {
        setError(m_recorder.errorString());
        return false;
    }
    return true;
}

void CaptureController::stopRecording()
{
    if (m_recorder.recorderState() == QMediaRecorder::RecordingState)
        m_recorder.stop();
}

void CaptureController::toggleRecording()
{
    if (m_recording)
        stopRecording();
    else
        startRecording();
}

void CaptureController::refreshDevices()
{
    const QString previousId = (m_currentDeviceIndex >= 0 && m_currentDeviceIndex < m_devices.size())
        ? QString::fromUtf8(m_devices.at(m_currentDeviceIndex).id())
        : m_settings->preferredDeviceId();

    m_devices = QMediaDevices::videoInputs();
    m_deviceNames.clear();
    for (const QCameraDevice &device : m_devices)
        m_deviceNames.append(device.description());

    emit devicesChanged();

    if (m_devices.isEmpty()) {
        m_currentDeviceIndex = -1;
        emit currentDeviceIndexChanged();
        m_camera.stop();
        setStatus(QStringLiteral("nodevice"),
                  tr("Không tìm thấy HDMI Capture. Cắm USB capture hoặc HDMI IN rồi thử lại."));
        return;
    }

    int index = -1;
    for (int i = 0; i < m_devices.size(); ++i) {
        if (QString::fromUtf8(m_devices.at(i).id()) == previousId) {
            index = i;
            break;
        }
    }
    if (index < 0)
        choosePreferredDevice();
    else
        applyDevice(index);
}

void CaptureController::applyDevice(int index)
{
    if (index < 0 || index >= m_devices.size())
        return;
    if (m_currentDeviceIndex == index && m_camera.cameraDevice() == m_devices.at(index)) {
        if (!m_camera.isActive())
            m_camera.start();
        return;
    }

    const bool wasRecording = m_recording;
    if (wasRecording)
        stopRecording();

    m_currentDeviceIndex = index;
    m_camera.setCameraDevice(m_devices.at(index));
    configureCameraFormat();
    configureAudio();
    m_settings->setPreferredDeviceId(QString::fromUtf8(m_devices.at(index).id()));
    emit currentDeviceIndexChanged();

    m_camera.start();
    updateStatus();
}

void CaptureController::choosePreferredDevice()
{
    int hdmiIndex = -1;
    for (int i = 0; i < m_devices.size(); ++i) {
        if (looksLikeHdmiDevice(m_devices.at(i).description())) {
            hdmiIndex = i;
            break;
        }
    }
    applyDevice(hdmiIndex >= 0 ? hdmiIndex : 0);
}

void CaptureController::configureCameraFormat()
{
    const QCameraFormat format = bestFormat(m_camera.cameraDevice());
    if (!format.isNull())
        m_camera.setCameraFormat(format);
}

void CaptureController::configureAudio()
{
    const QString camName = currentDeviceName().toLower();
    QAudioDevice chosen = QMediaDevices::defaultAudioInput();
    int bestScore = -1;
    for (const QAudioDevice &device : QMediaDevices::audioInputs()) {
        const QString name = device.description().toLower();
        int score = 0;
        if (looksLikeHdmiDevice(name))
            score += 10;
        if (!camName.isEmpty() && name.contains(camName.left(8)))
            score += 5;
        if (score > bestScore) {
            bestScore = score;
            chosen = device;
        }
    }
    if (bestScore >= 0)
        m_audioInput.setDevice(chosen);
}

void CaptureController::configureRecorder()
{
    QMediaFormat format;
    format.setFileFormat(QMediaFormat::MPEG4);
    format.setVideoCodec(QMediaFormat::VideoCodec::H264);
    format.setAudioCodec(QMediaFormat::AudioCodec::AAC);
    m_recorder.setMediaFormat(format);
    m_recorder.setQuality(QMediaRecorder::HighQuality);
}

void CaptureController::updateStatus()
{
    if (m_devices.isEmpty()) {
        setStatus(QStringLiteral("nodevice"), tr("Không tìm thấy thiết bị HDMI Capture."));
        return;
    }
    if (!m_lastError.isEmpty() && !m_camera.isActive()) {
        setStatus(QStringLiteral("error"), m_lastError);
        return;
    }
    if (m_recording) {
        setStatus(QStringLiteral("recording"), tr("Đang ghi %1").arg(recordingDurationText()));
        return;
    }
    if (m_camera.isActive() && m_signalPresent) {
        setStatus(QStringLiteral("live"), tr("Tín hiệu HDMI trực tiếp"));
        return;
    }
    if (m_camera.isActive()) {
        setStatus(QStringLiteral("nosignal"), tr("Thiết bị đã kết nối, chưa có tín hiệu HDMI."));
        return;
    }
    setStatus(QStringLiteral("idle"), tr("Sẵn sàng nhận tín hiệu HDMI."));
}

void CaptureController::setStatus(const QString &status, const QString &message)
{
    if (m_status == status && m_statusMessage == message)
        return;
    m_status = status;
    m_statusMessage = message;
    emit statusChanged();
}

void CaptureController::setError(const QString &error)
{
    m_lastError = error;
    emit lastErrorChanged();
    if (!error.isEmpty())
        setStatus(QStringLiteral("error"), error);
}

void CaptureController::setRecording(bool recording)
{
    if (m_recording == recording)
        return;
    m_recording = recording;
    if (!recording)
        m_recordingDurationMs = 0;
    emit recordingChanged();
    emit recordingDurationMsChanged();
}

void CaptureController::onFrame(const QVideoFrame &frame)
{
    m_lastFrameTimer.restart();
    ++m_frameCounter;
    if (m_frameCounter % 20 == 0)
        m_blackFrames = frameLooksBlack(frame);

    if (!m_signalPresent && !m_blackFrames) {
        m_signalPresent = true;
        emit signalPresentChanged();
        m_lastError.clear();
        emit lastErrorChanged();
        updateStatus();
    }
}

bool CaptureController::frameLooksBlack(const QVideoFrame &frame) const
{
    const QImage image = frame.toImage();
    if (image.isNull() || image.width() < 8 || image.height() < 8)
        return false;

    const QPoint samples[] = {
        {image.width() / 2, image.height() / 2},
        {image.width() / 4, image.height() / 4},
        {image.width() * 3 / 4, image.height() / 4},
        {image.width() / 4, image.height() * 3 / 4},
        {image.width() * 3 / 4, image.height() * 3 / 4},
    };

    int total = 0;
    for (const QPoint &p : samples) {
        const QColor c = image.pixelColor(p);
        total += (c.red() + c.green() + c.blue()) / 3;
    }
    return (total / 5) < 12;
}

QString CaptureController::recordingDurationText() const
{
    return formatDuration(m_recordingDurationMs);
}

QString CaptureController::formatDuration(qint64 ms) const
{
    const int totalSec = int(ms / 1000);
    const int h = totalSec / 3600;
    const int m = (totalSec % 3600) / 60;
    const int s = totalSec % 60;
    if (h > 0)
        return QStringLiteral("%1:%2:%3")
            .arg(h, 2, 10, QChar('0'))
            .arg(m, 2, 10, QChar('0'))
            .arg(s, 2, 10, QChar('0'));
    return QStringLiteral("%1:%2")
        .arg(m, 2, 10, QChar('0'))
        .arg(s, 2, 10, QChar('0'));
}
