// «Добро пожаловать в Атлас» — окно первого входа.
// Здесь только запуск QML и мост к процессам; сам интерфейс в /usr/share/atlasos/welcome/Main.qml.
// Автозапуск при входе — с --once: если окно уже проходили (~/.config/atlasos/welcome-done), выходим.
#include <QApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIcon>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>

class System : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    static QString doneFile()
    {
        return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/atlasos/welcome-done");
    }

    // Запустить программу; по завершении — finished(tag, код, вывод)
    Q_INVOKABLE void run(const QString &tag, const QString &program, const QStringList &args)
    {
        auto *p = new QProcess(this);
        p->setProcessChannelMode(QProcess::MergedChannels);
        connect(p, &QProcess::finished, this, [this, p, tag](int code, QProcess::ExitStatus status) {
            Q_EMIT finished(tag, status == QProcess::NormalExit ? code : -1, QString::fromUtf8(p->readAll()));
            p->deleteLater();
        });
        connect(p, &QProcess::errorOccurred, this, [this, p, tag](QProcess::ProcessError e) {
            if (e == QProcess::FailedToStart) {
                Q_EMIT finished(tag, -1, p->errorString());
                p->deleteLater();
            }
        });
        p->start(program, args);
    }

    Q_INVOKABLE void markDone()
    {
        QDir().mkpath(QFileInfo(doneFile()).path());
        QFile f(doneFile());
        f.open(QIODevice::WriteOnly);
    }

Q_SIGNALS:
    void finished(const QString &tag, int code, const QString &output);
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("atlas-welcome"));
    app.setApplicationDisplayName(QStringLiteral("Добро пожаловать"));
    app.setDesktopFileName(QStringLiteral("org.atlasos.welcome"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("preferences-desktop-theme-global")));

    if (app.arguments().contains(QStringLiteral("--once")) && QFile::exists(System::doneFile())) {
        return 0;
    }

    System system;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("sys"), &system);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.load(QUrl::fromLocalFile(QStringLiteral("/usr/share/atlasos/welcome/Main.qml")));
    return app.exec();
}

#include "main.moc"
