# SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
# SPDX-License-Identifier: GPL-3.0-or-later

TARGET = harbour-felistermostat
CONFIG += sailfishapp_no_deploy_qml sailfishapp c++11
SOURCES += src/main.cpp
TRANSLATIONS += $$files(translations/harbour-felistermostat-*.ts)
!isEmpty(FELISTERMOSTAT_BUILD_VERSION): DEFINES += FELISTERMOSTAT_BUILD_VERSION=$$FELISTERMOSTAT_BUILD_VERSION

app_qml.files = qml/harbour-felistermostat.qml qml/SettingsPage.qml qml/AboutPage.qml qml/StatusIcon.qml icons/172x172/harbour-felistermostat.png
app_qml.path = /usr/share/$${TARGET}/qml

backend.files = python/felis_thermostat.py python/felis_thermostat_protocol.py
backend.path = /usr/share/$${TARGET}/python

INSTALLS += app_qml backend
SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
