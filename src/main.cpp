#include "AppSettings.h"
#include "CaptureController.h"
#include "HidInputRouter.h"
#include "KioskController.h"
#include "RecordingManager.h"
#include "VideoLibraryModel.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>

namespace {

QFile *g_logFile = nullptr;

void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    Q_UNUSED(context)
    const char *level = "INFO";
    switch (type) {
    case QtDebugMsg:    level = "DEBUG"; break;
    case QtInfoMsg:     level = "INFO"; break;
    case QtWarningMsg:  level = "WARN"; break;
    case QtCriticalMsg: level = "ERROR"; break;
    case QtFatalMsg:    level = "FATAL"; break;
    }

    const QString line = QStringLiteral("%1 %2 %3\n")
                             .arg(QDateTime::currentDateTime().toString(Qt::ISODate),
                                  QString::fromLatin1(level),
                                  msg);
    QTextStream(stderr) << line;
    if (g_logFile && g_logFile->isOpen()) {
        QTextStream(g_logFile) << line;
        g_logFile->flush();
    }
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QGuiApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral("HdmiKiosk"));
    app.setOrganizationDomain(QStringLiteral("hdmi-kiosk.local"));
    app.setApplicationName(QStringLiteral("HdmiKiosk"));
    app.setApplicationVersion(QStringLiteral(APP_VERSION));

    const QString logDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(logDir);
    static QFile logFile(QDir(logDir).filePath(QStringLiteral("hdmi-kiosk.log")));
    if (logFile.open(QIODevice::Append | QIODevice::Text)) {
        g_logFile = &logFile;
    }
    qInstallMessageHandler(messageHandler);

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    AppSettings settings;
    RecordingManager recordings(settings.recordingsDir());
    QObject::connect(&settings, &AppSettings::recordingsDirChanged, &recordings, [&]() {
        recordings.setDirectory(settings.recordingsDir());
    });

    CaptureController capture(&settings, &recordings);
    VideoLibraryModel library(&recordings);
    KioskController kiosk;
    HidInputRouter hidInput;
    kiosk.setLocked(settings.kioskMode());

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("AppSettings"), &settings);
    engine.rootContext()->setContextProperty(QStringLiteral("Capture"), &capture);
    engine.rootContext()->setContextProperty(QStringLiteral("Library"), &library);
    engine.rootContext()->setContextProperty(QStringLiteral("Kiosk"), &kiosk);
    engine.rootContext()->setContextProperty(QStringLiteral("HidInput"), &hidInput);
    engine.rootContext()->setContextProperty(QStringLiteral("Recordings"), &recordings);
    engine.rootContext()->setContextProperty(QStringLiteral("AppVersion"), QStringLiteral(APP_VERSION));

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    if (qEnvironmentVariableIntValue("HDMI_KIOSK_SMOKE_TEST") > 0) {
        QObject::connect(
            &engine,
            &QQmlApplicationEngine::objectCreated,
            &app,
            [&](QObject *object, const QUrl &) {
                if (!object) {
                    QCoreApplication::exit(1);
                    return;
                }
                QTimer::singleShot(2500, &app, &QCoreApplication::quit);
            },
            Qt::QueuedConnection);
    }

    engine.loadFromModule("HdmiKiosk", "Main");

    return app.exec();
}
