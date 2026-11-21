// SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
// SPDX-License-Identifier: GPL-3.0-or-later

#include <sailfishapp.h>
#include <QGuiApplication>
#include <QLocale>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QStandardPaths>
#include <QTranslator>
#include <QUrl>

#define FELISTERMOSTAT_STRINGIFY_IMPL(value) #value
#define FELISTERMOSTAT_STRINGIFY(value) FELISTERMOSTAT_STRINGIFY_IMPL(value)

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setOrganizationName(QStringLiteral("cz.feliscatus"));
    app->setApplicationName(QStringLiteral("felistermostat"));
#ifdef FELISTERMOSTAT_BUILD_VERSION
    app->setApplicationVersion(QString::fromLatin1(FELISTERMOSTAT_STRINGIFY(FELISTERMOSTAT_BUILD_VERSION)));
#endif

    QTranslator translator;
    if (translator.load(QLocale::system(), QStringLiteral("harbour-felistermostat"),
                        QStringLiteral("-"), SailfishApp::pathTo(QStringLiteral("translations")).toLocalFile()))
        app->installTranslator(&translator);

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    const QString configPath = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)
        + QStringLiteral("/thermostat.json");
    view->rootContext()->setContextProperty(QStringLiteral("thermostatConfigPath"), configPath);
    view->setSource(SailfishApp::pathTo(QStringLiteral("qml/harbour-felistermostat.qml")));
    if (view->status() == QQuickView::Error)
        return 1;
    view->show();
    return app->exec();
}
