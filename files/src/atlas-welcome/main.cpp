// Запускалка служебных окон «Атласа»: страница выбирается по имени программы.
//   atlas-welcome → /usr/share/atlasos/welcome/Main.qml — первый вход;
//   atlas-updates → /usr/share/atlasos/updates/Main.qml — обновление и откат (ссылка на atlas-welcome).
// Здесь только запуск QML и мост к процессам. С --once окно выходит сразу, если его уже
// проходили (~/.config/atlasos/<страница>-done) — так приветствие стоит в автозапуске.
#include <QApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>

class System : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    static inline QString page;

    static QString doneFile()
    {
        return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/atlasos/") + page + QStringLiteral("-done");
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
    const QString name = QFileInfo(QString::fromLocal8Bit(argv[0])).fileName();
    System::page = name.startsWith(QStringLiteral("atlas-")) ? name.mid(6) : QStringLiteral("welcome");
    app.setApplicationName(QStringLiteral("atlas-") + System::page);
    app.setDesktopFileName(QStringLiteral("org.atlasos.") + System::page);

    if (app.arguments().contains(QStringLiteral("--once")) && QFile::exists(System::doneFile())) {
        return 0;
    }

    System system;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("sys"), &system);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.load(QUrl::fromLocalFile(QStringLiteral("/usr/share/atlasos/") + System::page + QStringLiteral("/Main.qml")));
    return app.exec();
}

#include "main.moc"
