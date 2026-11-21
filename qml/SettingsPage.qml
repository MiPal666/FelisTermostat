// SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    property var backend
    property bool working: true
    property bool hasSavedKey: false
    property bool firstSetup: false
    property string statusText: ""
    property bool statusIsError: false
    property int draftRevision: 0
    readonly property bool canSubmit: backend.ready && !working
                                      && address.text.trim().length > 0
                                      && deviceId.text.trim().length > 0
                                      && (localKey.text.length > 0 || hasSavedKey)

    function showResult(error, successText) {
        statusIsError = !!error
        statusText = error ? backend.problemLabel(error) : successText
        working = false
    }

    function invalidateResult() {
        draftRevision += 1
        statusText = ""
        statusIsError = false
    }

    function submit(save) {
        Qt.inputMethod.commit()
        if (!canSubmit)
            return
        var fields = [address.text.trim(), deviceId.text.trim(), localKey.text]
        var submittedRevision = draftRevision
        page.forceActiveFocus()
        working = true
        statusText = ""
        backend.callSettings(save ? "save_connection" : "verify_connection",
                             fields,
                             function(result) {
            if (!page)
                return
            if (!save && submittedRevision !== draftRevision) {
                working = false
                return
            }
            if (save && !result.error) {
                hasSavedKey = true
                firstSetup = false
                localKey.text = ""
            }
            showResult(result.error, save ? qsTr("Settings saved.")
                                          : qsTr("Connected to the thermostat."))
        })
    }

    Component.onCompleted: {
        backend.callSettings("connection_settings", [], function(result) {
            if (!page)
                return
            firstSetup = result.error === "configMissing"
            if (result.settings) {
                address.text = result.settings.ip
                deviceId.text = result.settings.id
                hasSavedKey = true
            }
            showResult(result.error === "configMissing" ? "" : result.error, "")
        })
    }

    Connections {
        target: page.backend
        onBridgeFailedChanged: {
            if (page.backend.bridgeFailed)
                page.showResult("bridge", "")
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        clip: true
        flickableDirection: Flickable.VerticalFlick
        contentHeight: content.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Test connection")
                enabled: page.canSubmit
                onClicked: page.submit(false)
            }
            MenuItem {
                text: qsTr("Save")
                enabled: page.canSubmit
                onClicked: page.submit(true)
            }
        }

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("Settings") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.firstSetup
                text: qsTr("To obtain the local key (local_key) through Tuya, you need a Tuya account and temporary API access. If you already have the key, enter it below.")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.firstSetup
                text: qsTr("This app has only been tested with the EMOS P56211 thermostat.")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
            }

            TextField {
                id: address
                width: parent.width
                enabled: !page.working
                label: qsTr("Thermostat IP address")
                placeholderText: label
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                onTextChanged: page.invalidateResult()
            }
            TextField {
                id: deviceId
                width: parent.width
                enabled: !page.working
                label: qsTr("Device ID")
                placeholderText: label
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                onTextChanged: page.invalidateResult()
            }
            TextField {
                id: localKey
                width: parent.width
                enabled: !page.working
                label: qsTr("Local key")
                placeholderText: page.hasSavedKey ? qsTr("Local key is saved") : label
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                onTextChanged: page.invalidateResult()
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.hasSavedKey
                text: qsTr("Leave this field blank to keep the saved key.")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Small
                visible: page.working
                running: visible
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !page.working
                text: page.statusText || qsTr("Connection not yet tested.")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: page.statusIsError ? "#e94343" : page.statusText ? Theme.highlightColor : Theme.secondaryColor
            }
        }

        VerticalScrollDecorator {}
    }
}
