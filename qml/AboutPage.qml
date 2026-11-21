// SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("About") }
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 2 * Theme.horizontalPageMargin, Theme.itemSizeHuge * 1.4)
                height: width
                source: "harbour-felistermostat.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            SectionHeader { text: "FelisTermostat" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("Version %1").arg(Qt.application.version || "—")
                font.pixelSize: Theme.fontSizeSmall
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("An unofficial Sailfish OS app for controlling the EMOS GoSmart P56211 thermostat over your home network. It displays the temperature and heating status and lets you change the set temperature, operating mode and keypad lock.")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("Created by Michal Kasík (MiPal) with help from Klára (AI).")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Source code on GitHub")
                onClicked: Qt.openUrlExternally("https://github.com/MiPal666/FelisTermostat")
            }

            SectionHeader { text: qsTr("Connection") }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("The app communicates directly with the thermostat over Tuya LAN using its IP address, device ID and local key.")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            SectionHeader { text: qsTr("License") }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("This app is free software under the GNU General Public License, version 3 or any later version (GPL-3.0-or-later). It is provided without warranty. Third-party components retain their own licenses.")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("GNU GPL v3")
                onClicked: Qt.openUrlExternally("https://www.gnu.org/licenses/gpl-3.0.html")
            }
        }

        VerticalScrollDecorator {}
    }
}
