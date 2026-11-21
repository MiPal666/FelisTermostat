// SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.6
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5

ApplicationWindow {
    id: app

    property var confirmed: null
    property string problem: ""
    property bool writeUnconfirmed: false
    property bool busy: false
    property string activeCommand: ""
    readonly property bool changing: !!activeCommand
    readonly property var modes: ["auto", "manual", "temporary", "boost", "holiday"]
    readonly property int confirmationTimeout: 5000
    property var pendingTarget: null
    property var rollbackState: null
    property bool temperatureFailed: false
    property string pendingControl: ""
    readonly property bool pendingMode: modes.indexOf(pendingControl) !== -1
    property bool modeFailed: false
    property string queuedCommand: ""
    property bool ready: false
    property bool bridgeFailed: false
    property bool savingSettings: false
    property bool coverActive: false
    readonly property bool foreground: Qt.application.state === Qt.ApplicationActive
    readonly property bool editable: foreground && !!confirmed && !changing && !queuedCommand && !savingSettings
    readonly property bool keypadLockKnown: !!confirmed && typeof confirmed.keypadLocked === "boolean"
    property int activityGeneration: 0

    function modeLabel(mode, fullName) {
        switch (mode) {
        case "auto": return fullName ? qsTr("Automatic") : qsTr("Auto")
        case "temporary": return qsTr("Temporary")
        case "manual": return qsTr("Manual")
        case "boost": return qsTr("Boost")
        case "holiday": return qsTr("Holiday")
        default: return "—"
        }
    }

    function temperature(value) {
        return Number(value / 10).toLocaleString(Qt.locale(), "f", 1) + " °C"
    }

    function problemLabel(code) {
        switch (code) {
        case "configMissing": return qsTr("The thermostat is not configured. Open Settings from the pull-down menu and enter the thermostat details.")
        case "configPermissions": return qsTr("The settings file must have permissions set to 0600")
        case "configInvalid": return qsTr("The thermostat settings are invalid")
        case "configAddress": return qsTr("Enter the thermostat’s local IPv4 address.")
        case "configId": return qsTr("Enter the thermostat’s device ID.")
        case "configKey": return qsTr("The local key must be 16 ASCII characters long.")
        case "configSave": return qsTr("Could not save settings.")
        case "unreachable": return qsTr("Thermostat unavailable")
        case "session": return qsTr("Could not establish a Tuya LAN session")
        case "response": return qsTr("Invalid response from the thermostat")
        case "dependency": return qsTr("Could not load TinyTuya")
        case "bridge": return qsTr("Could not start the Python backend")
        case "range": return qsTr("Temperature is out of range")
        case "command": return qsTr("Invalid command")
        case "keypadLockUnknown": return qsTr("The thermostat did not report the keypad lock status")
        case "writeUnconfirmed": return qsTr("The thermostat did not confirm the change")
        default: return ""
        }
    }

    function callSettings(method, fields, callback) {
        if (!ready) {
            callback({error: "bridge"})
            return
        }
        var saving = method === "save_connection"
        if (saving)
            savingSettings = true
        python.call("felis_thermostat." + method, [thermostatConfigPath].concat(fields), function(result) {
            result = result || {error: "bridge"}
            if (saving)
                savingSettings = false
            if (saving && !result.error) {
                activityGeneration += 1
                confirmed = null
                problem = ""
                writeUnconfirmed = false
                temperatureFailed = false
                rollbackState = null
                finishControl(false)
                queuedCommand = ""
                request("")
            }
            callback(result)
        })
    }

    function request(command) {
        if (!ready || (!foreground && !coverActive) || savingSettings || (command && !editable))
            return
        var isTemperature = command.indexOf("target:") === 0
        var isMode = modes.indexOf(command) !== -1
        var isControl = isMode || command === "on" || command === "off"
        if (command) {
            temperatureFailed = false
            modeFailed = false
            problem = ""
            writeUnconfirmed = false
        }
        if (isTemperature) {
            pendingTarget = Number(command.slice("target:".length))
            rollbackState = null
        }
        if (isControl)
            pendingControl = command
        if (busy) {
            if (command)
                queuedCommand = command
            return
        }
        busy = true
        activeCommand = command
        var generation = activityGeneration
        var method = command ? "change" : "refresh"
        var args = command ? [thermostatConfigPath, command] : [thermostatConfigPath]
        if (isTemperature || isControl) {
            args.push(confirmationTimeout / 1000)
            if (isControl)
                controlTimer.restart()
            else
                temperatureTimer.restart()
        }
        python.call("felis_thermostat." + method, args, function(result) {
            if (bridgeFailed)
                return
            var nextCommand = queuedCommand
            queuedCommand = ""
            busy = false
            activeCommand = ""
            if (generation !== activityGeneration) {
                request("")
                return
            }
            if (isTemperature) {
                temperatureTimer.stop()
                if (pendingTarget === null)
                    return
            }
            if (!result) {
                failBridge()
                return
            }
            if (isControl) {
                if (pendingControl) {
                    if (!result.error && result.state)
                        confirmed = result.state
                    finishControl(!!result.error || !result.state)
                } else {
                    // The UI timed out. Read the current state without sending the change again.
                    request("")
                }
                return
            }
            if (nextCommand && nextCommand === pendingControl) {
                // Keep the displayed state while the queued change is confirmed.
                request(nextCommand)
                return
            }
            rollbackState = null
            if ((isTemperature && result.error) || (nextCommand && pendingTarget !== null && !result.state))
                failTemperature()
            confirmed = result.state || null
            if (isTemperature)
                pendingTarget = null
            problem = isTemperature && result.error === "writeUnconfirmed" ? "" : result.error
            writeUnconfirmed = !isTemperature && !!result.writeUnconfirmed
            if (nextCommand && confirmed)
                request(nextCommand)
        })
    }

    function failTemperature() {
        rollbackState = confirmed
        pendingTarget = null
        temperatureFailed = true
    }

    function finishControl(failed) {
        controlTimer.stop()
        modeFailed = failed && pendingMode
        writeUnconfirmed = failed && !pendingMode
        pendingControl = ""
    }

    function failBridge() {
        temperatureTimer.stop()
        if (pendingTarget !== null)
            failTemperature()
        if (pendingControl)
            finishControl(true)
        confirmed = null
        ready = false
        busy = false
        savingSettings = false
        activeCommand = ""
        queuedCommand = ""
        bridgeFailed = true
        problem = "bridge"
    }

    onForegroundChanged: {
        if (!pendingControl || activeCommand !== pendingControl) {
            activityGeneration += 1
            if (pendingControl)
                finishControl(false)
            if (foreground)
                confirmed = null
        }
        temperatureTimer.stop()
        pendingTarget = null
        rollbackState = null
        temperatureFailed = false
        queuedCommand = ""
        if (foreground || coverActive)
            request("")
    }

    onCoverActiveChanged: {
        if (coverActive && !foreground)
            request("")
    }

    Timer {
        id: temperatureTimer
        interval: app.confirmationTimeout
        onTriggered: app.failTemperature()
    }

    Timer {
        id: controlTimer
        interval: app.confirmationTimeout
        onTriggered: app.finishControl(true)
    }

    Python {
        id: python

        onError: app.failBridge()
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../python"))
            importModule("felis_thermostat", function() {
                if (!app.bridgeFailed) {
                    app.ready = true
                    app.request("")
                }
            })
        }
    }

    Timer {
        interval: app.foreground ? 8000 : 30000
        repeat: true
        running: (app.foreground || app.coverActive) && app.ready
        onTriggered: app.request("")
    }

    cover: Component {
        CoverBackground {
            onStatusChanged: app.coverActive = status === Cover.Active
            Component.onCompleted: app.coverActive = status === Cover.Active
            Component.onDestruction: {
                if (app)
                    app.coverActive = false
            }

            Column {
                id: coverContents
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.paddingLarge
                spacing: Theme.paddingSmall
                visible: !!app.confirmed
                readonly property real temperatureFontSize: Math.max(1, Math.min(Theme.fontSizeExtraLarge, width / 4))

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    text: qsTr("Current")
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: coverContents.temperatureFontSize
                    text: app.confirmed ? app.temperature(app.confirmed.current) : ""
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    text: qsTr("Set")
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: coverContents.temperatureFontSize
                    text: app.confirmed ? app.temperature(app.confirmed.target) : ""
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingSmall

                    StatusIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: app.confirmed && app.confirmed.heating ? "heat" : "idle"
                        color: coverHeatingLabel.color
                    }
                    Label {
                        id: coverHeatingLabel
                        font.pixelSize: Theme.fontSizeMedium
                        color: app.confirmed && app.confirmed.heating ? Theme.highlightColor : Theme.primaryColor
                        text: app.confirmed && app.confirmed.heating ? qsTr("Heating") : qsTr("Not heating")
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.paddingLarge
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: !app.confirmed
                font.pixelSize: Theme.fontSizeMedium
                text: app.problem === "configMissing" ? qsTr("Setup required")
                    : app.problem ? qsTr("Unavailable") : qsTr("Reading status…")
            }
        }
    }

    initialPage: Component {
        Page {
            id: mainPage

            SilicaFlickable {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: buildVersion.top
                }
                clip: true
                flickableDirection: Flickable.VerticalFlick
                contentHeight: content.height + Theme.paddingLarge
                VerticalScrollDecorator {}

                PullDownMenu {
                    MenuItem {
                        text: qsTr("About")
                        onDelayedClick: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                    }
                    Item { width: parent.width; height: Theme.paddingMedium }
                    MenuItem {
                        text: qsTr("Settings")
                        enabled: app.ready && !app.changing && !app.queuedCommand && !app.savingSettings
                        onDelayedClick: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"), {backend: app})
                    }
                    Item { width: parent.width; height: Theme.paddingMedium }
                    MenuItem {
                        text: app.keypadLockKnown && app.confirmed.keypadLocked
                              ? qsTr("Unlock keypad") : qsTr("Lock keypad")
                        enabled: app.editable && app.keypadLockKnown
                        onClicked: app.request(app.confirmed.keypadLocked ? "unlock" : "lock")
                    }
                    Item { width: parent.width; height: Theme.paddingMedium }
                    MenuItem {
                        text: qsTr("Heating mode…")
                        enabled: app.editable
                        onDelayedClick: {
                            if (app.editable)
                                modeMenu.open(modeAnchor)
                        }
                    }
                    Item { width: parent.width; height: Theme.paddingMedium }
                    MenuItem {
                        text: app.confirmed && app.confirmed.powered
                              ? qsTr("Turn off thermostat") : qsTr("Turn on thermostat")
                        enabled: app.editable
                        onClicked: app.request(app.confirmed.powered ? "off" : "on")
                    }
                }

                Column {
                    id: content
                    width: parent.width
                    spacing: Theme.paddingMedium

                    PageHeader { title: "FelisTermostat" }

                    Item {
                        id: modeAnchor
                        width: parent.width
                        height: modeMenu.parent === modeAnchor ? modeMenu.height : 0

                        ContextMenu {
                            id: modeMenu

                            Repeater {
                                model: app.modes

                                MenuItem {
                                    enabled: app.editable
                                    text: app.modeLabel(modelData, true)
                                    onClicked: {
                                        if (app.editable && app.confirmed.mode !== modelData)
                                            app.request(modelData)
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        wrapMode: Text.Wrap
                        color: Theme.secondaryHighlightColor
                        text: app.confirmed ? qsTr("Connected over LAN")
                             : app.problem ? app.problemLabel(app.problem) : qsTr("Reading status…")
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            text: qsTr("Set temperature")
                        }
                        Item {
                            id: dialPanel
                            width: parent.width
                            height: dial.height + Theme.paddingSmall + adjustmentSize
                            readonly property real adjustmentSize: Theme.itemSizeSmall * 0.8

                            Canvas {
                                id: dial
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(parent.width, mainPage.height)
                                height: width
                                readonly property real startAngle: 135
                                readonly property real sweepAngle: 270
                                readonly property real trackRadius: width * 0.44
                                readonly property color foregroundColor: Theme.primaryColor
                                readonly property color accentColor: Theme.highlightColor
                                readonly property var targetState: app.confirmed || app.rollbackState
                                readonly property bool hasTarget: !!targetState
                                readonly property real displayTarget: !hasTarget ? 0
                                    : app.pendingTarget !== null ? app.pendingTarget
                                    : dragging ? targetAtAngle(dragAngle, targetState.minTarget,
                                                               targetState.maxTarget, targetState.targetStep)
                                               : targetState.target
                                readonly property real fraction: hasTarget
                                    ? Math.max(0, Math.min(1, (displayTarget - targetState.minTarget)
                                               / (targetState.maxTarget - targetState.minTarget))) : 0
                                readonly property real handleAngle: startAngle + sweepAngle * fraction
                                property bool dragging: false
                                property real dragAngle: startAngle

                                function endpointX(angle) {
                                    return x + width / 2 + trackRadius * Math.cos(angle * Math.PI / 180)
                                }

                                function nearestAngle(angle, previous) {
                                    return angle + 360 * Math.round((previous - angle) / 360)
                                }

                                function targetAtAngle(angle, minimum, maximum, step) {
                                    var fraction = Math.max(0, Math.min(1, (angle - startAngle) / sweepAngle))
                                    return minimum + Math.round(fraction * (maximum - minimum) / step) * step
                                }

                                onFractionChanged: requestPaint()
                                onDraggingChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHasTargetChanged: requestPaint()
                                onForegroundColorChanged: requestPaint()
                                onAccentColorChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    var center = width / 2
                                    var radius = trackRadius
                                    var radians = Math.PI / 180
                                    var start = startAngle * radians
                                    var end = (startAngle + sweepAngle) * radians
                                    var selected = start + (end - start) * fraction
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.beginPath()
                                    ctx.arc(center, center, width * 0.48, 0, 2 * Math.PI)
                                    ctx.fillStyle = foregroundColor
                                    ctx.globalAlpha = 0.08
                                    ctx.fill()

                                    ctx.beginPath()
                                    for (var tick = 0; tick <= 12; tick++) {
                                        var angle = start + (end - start) * tick / 12
                                        var inner = radius * (tick % 2 === 0 ? 0.81 : 0.87)
                                        ctx.moveTo(center + Math.cos(angle) * inner, center + Math.sin(angle) * inner)
                                        ctx.lineTo(center + Math.cos(angle) * radius * 0.93,
                                                   center + Math.sin(angle) * radius * 0.93)
                                    }
                                    ctx.strokeStyle = foregroundColor
                                    ctx.lineWidth = width * 0.006
                                    ctx.globalAlpha = 0.38
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.arc(center, center, radius, start, end)
                                    ctx.lineWidth = width * 0.024
                                    ctx.lineCap = "round"
                                    ctx.globalAlpha = 0.32
                                    ctx.stroke()
                                    ctx.globalAlpha = 1
                                    if (hasTarget) {
                                        if (fraction > 0) {
                                            ctx.beginPath()
                                            ctx.arc(center, center, radius, start, selected)
                                            ctx.strokeStyle = accentColor
                                            ctx.stroke()
                                        }
                                        ctx.beginPath()
                                        ctx.arc(center + Math.cos(selected) * radius,
                                                center + Math.sin(selected) * radius,
                                                width * (dragging ? 0.043 : 0.036), 0, 2 * Math.PI)
                                        ctx.fillStyle = accentColor
                                        ctx.fill()
                                    }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.69
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: Math.min(Theme.fontSizeExtraLarge * 1.5, parent.width * 0.19)
                                    text: dial.hasTarget ? app.temperature(dial.displayTarget) : "—"
                                }

                                MouseArea {
                                    id: dialTouch
                                    anchors.fill: parent
                                    enabled: app.editable
                                    preventStealing: dial.dragging
                                    Accessible.name: qsTr("Set temperature")
                                    property real pressX: 0
                                    property real pressY: 0
                                    property real fingerAngle: 0
                                    property real grabOffset: 0
                                    property bool movedAlongDial: false

                                    function distance(dx, dy) {
                                        return Math.sqrt(dx * dx + dy * dy)
                                    }

                                    function angleAt(x, y) {
                                        return Math.atan2(y - height / 2, x - width / 2) * 180 / Math.PI
                                    }

                                    function updateDrag(x, y) {
                                        if (distance(x - width / 2, y - height / 2) < dial.trackRadius * 0.55)
                                            return
                                        fingerAngle = dial.nearestAngle(angleAt(x, y), fingerAngle)
                                        dial.dragAngle = fingerAngle + grabOffset
                                    }

                                    function resetGesture() {
                                        holdTimer.stop()
                                        dial.dragging = false
                                        movedAlongDial = false
                                    }

                                    Timer {
                                        id: holdTimer
                                        interval: 350
                                        onTriggered: {
                                            if (!dialTouch.pressed || !dialTouch.enabled)
                                                return
                                            dial.dragAngle = dial.handleAngle
                                            dialTouch.fingerAngle = dial.nearestAngle(
                                                dialTouch.angleAt(dialTouch.pressX, dialTouch.pressY), dial.dragAngle)
                                            dialTouch.grabOffset = dial.dragAngle - dialTouch.fingerAngle
                                            dial.dragging = true
                                        }
                                    }

                                    onPressed: {
                                        var angle = dial.handleAngle * Math.PI / 180
                                        var handleX = width / 2 + Math.cos(angle) * dial.trackRadius
                                        var handleY = height / 2 + Math.sin(angle) * dial.trackRadius
                                        var touchRadius = Math.max(width * 0.065, Theme.fontSizeSmall)
                                        if (distance(mouse.x - handleX, mouse.y - handleY) > touchRadius) {
                                            mouse.accepted = false
                                            return
                                        }
                                        pressX = mouse.x
                                        pressY = mouse.y
                                        holdTimer.restart()
                                    }
                                    onPositionChanged: {
                                        var moved = distance(mouse.x - pressX, mouse.y - pressY) > Theme.paddingSmall
                                        if (!dial.dragging) {
                                            if (moved)
                                                holdTimer.stop()
                                        } else if (movedAlongDial || moved) {
                                            movedAlongDial = true
                                            updateDrag(mouse.x, mouse.y)
                                        }
                                    }
                                    onReleased: {
                                        if (dial.dragging && movedAlongDial) {
                                            var target = dial.displayTarget
                                            if (app.editable && target !== app.confirmed.target)
                                                app.request("target:" + target)
                                        }
                                        resetGesture()
                                    }
                                    onCanceled: resetGesture()
                                    onEnabledChanged: {
                                        if (!enabled)
                                            resetGesture()
                                    }
                                }
                            }

                            Button {
                                x: dial.endpointX(dial.startAngle) - width / 2
                                anchors.top: dial.bottom
                                anchors.topMargin: Theme.paddingSmall
                                width: dialPanel.adjustmentSize
                                height: width
                                text: "−"
                                Accessible.name: qsTr("Lower the set temperature by half a degree")
                                enabled: app.editable && !dial.dragging && app.confirmed.canDecrease
                                onClicked: app.request("target:" + (app.confirmed.target - app.confirmed.targetStep))
                            }
                            Button {
                                x: dial.endpointX(dial.startAngle + dial.sweepAngle) - width / 2
                                anchors.top: dial.bottom
                                anchors.topMargin: Theme.paddingSmall
                                width: dialPanel.adjustmentSize
                                height: width
                                text: "+"
                                Accessible.name: qsTr("Raise the set temperature by half a degree")
                                enabled: app.editable && !dial.dragging && app.confirmed.canIncrease
                                onClicked: app.request("target:" + (app.confirmed.target + app.confirmed.targetStep))
                            }
                        }
                        Item {
                            id: feedback
                            width: parent.width
                            height: gap + Math.max(2 * feedbackFont.lineSpacing, Theme.itemSizeSmall)
                            readonly property real gap: 2 * feedbackFont.lineSpacing
                            readonly property string errorText: app.modeFailed ? qsTr("The thermostat did not confirm the mode change.")
                                : app.temperatureFailed ? qsTr("The thermostat did not confirm the change.")
                                : app.writeUnconfirmed ? app.problemLabel("writeUnconfirmed")
                                : app.confirmed ? app.problemLabel(app.problem) : ""

                            FontMetrics { id: feedbackFont; font: feedbackLabel.font }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: feedback.gap + (parent.height - feedback.gap - height) / 2
                                spacing: Theme.paddingSmall

                                BusyIndicator {
                                    id: feedbackSpinner
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: BusyIndicatorSize.Small
                                    visible: !!app.pendingControl
                                    running: visible
                                }
                                Label {
                                    id: feedbackLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, feedback.width
                                                    - (feedbackSpinner.visible ? feedbackSpinner.width + parent.spacing : 0))
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: feedback.errorText ? "#e94343" : Theme.secondaryColor
                                    text: app.pendingTarget !== null ? qsTr("Waiting for the thermostat to confirm…")
                                        : app.pendingMode ? qsTr("Waiting for the thermostat to confirm %1 mode…").arg(app.modeLabel(app.pendingControl, true))
                                        : app.pendingControl ? qsTr("Waiting for the thermostat to confirm…")
                                        : feedback.errorText ? feedback.errorText
                                        : app.changing ? qsTr("Checking the change…") : ""
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: qsTr("Current temperature %1").arg(app.confirmed
                                  ? app.temperature(app.confirmed.current) : "—")
                        }
                        Flow {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, heatingStatus.width + modeStatus.width + spacing)
                            spacing: Theme.paddingSmall
                            visible: !!app.confirmed

                            Row {
                                id: heatingStatus
                                spacing: Theme.paddingSmall
                                StatusIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    kind: app.confirmed && app.confirmed.heating ? "heat" : "idle"
                                    color: heatingLabel.color
                                }
                                Label {
                                    id: heatingLabel
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: app.confirmed && app.confirmed.heating ? Theme.highlightColor : Theme.secondaryColor
                                    text: app.confirmed && app.confirmed.heating ? qsTr("Heating") : qsTr("Not heating")
                                }
                            }
                            Row {
                                id: modeStatus
                                spacing: Theme.paddingSmall
                                StatusIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    kind: app.confirmed ? app.confirmed.mode : ""
                                    color: Theme.secondaryColor
                                }
                                Label {
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.secondaryColor
                                    text: app.confirmed ? app.modeLabel(app.confirmed.mode) : ""
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryColor
                            visible: !app.confirmed
                            text: "—"
                        }
                    }
                    DetailItem {
                        label: qsTr("Thermostat")
                        value: app.confirmed ? (app.confirmed.powered ? qsTr("On") : qsTr("Off")) : "—"
                    }
                    DetailItem {
                        label: qsTr("Thermostat keypad")
                        value: app.keypadLockKnown
                               ? (app.confirmed.keypadLocked ? qsTr("Locked") : qsTr("Unlocked"))
                               : app.confirmed ? qsTr("Unknown") : "—"
                    }
                }
            }

            Label {
                id: buildVersion
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.paddingSmall
                text: Qt.application.version
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }
    }
}
