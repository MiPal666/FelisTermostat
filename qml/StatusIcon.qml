// SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.6
import Sailfish.Silica 1.0

Canvas {
    property string kind
    property color color: Theme.secondaryColor

    width: Theme.fontSizeSmall
    height: width
    onKindChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onVisibleChanged: {
        if (visible && available)
            requestPaint()
    }
    onAvailableChanged: {
        if (available && visible)
            requestPaint()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.save()
        ctx.scale(width / 24, height / 24)
        ctx.strokeStyle = color
        ctx.fillStyle = color
        ctx.lineWidth = 1.75
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()

        switch (kind) {
        case "auto":
            ctx.arc(12, 12, 9, 0, 2 * Math.PI)
            ctx.moveTo(8.6, 16)
            ctx.lineTo(12, 8)
            ctx.lineTo(15.4, 16)
            ctx.moveTo(9.7, 13.5)
            ctx.lineTo(14.3, 13.5)
            break
        case "manual":
            ctx.moveTo(7, 13)
            ctx.lineTo(7, 6)
            ctx.quadraticCurveTo(8.5, 4, 10, 6)
            ctx.lineTo(10, 11)
            ctx.lineTo(10, 4)
            ctx.quadraticCurveTo(11.5, 2, 13, 4)
            ctx.lineTo(13, 11)
            ctx.lineTo(13, 5)
            ctx.quadraticCurveTo(14.5, 3, 16, 5)
            ctx.lineTo(16, 11)
            ctx.lineTo(16, 8)
            ctx.quadraticCurveTo(17.5, 6, 19, 8)
            ctx.lineTo(19, 15)
            ctx.quadraticCurveTo(18, 22, 13, 22)
            ctx.quadraticCurveTo(8, 22, 4, 15)
            ctx.quadraticCurveTo(3, 12, 5.6, 13)
            ctx.lineTo(7, 14.5)
            break
        case "temporary":
            ctx.arc(12, 12, 8.5, -0.65, 4.95)
            ctx.moveTo(19, 4)
            ctx.lineTo(19, 7)
            ctx.lineTo(15.5, 7)
            break
        case "holiday":
            ctx.moveTo(7, 21)
            ctx.quadraticCurveTo(12, 14, 12, 9)
            ctx.quadraticCurveTo(6, 6, 3, 12)
            ctx.moveTo(12, 9)
            ctx.quadraticCurveTo(8, 2, 4, 5)
            ctx.moveTo(12, 9)
            ctx.quadraticCurveTo(15, 2, 20, 5)
            ctx.moveTo(12, 9)
            ctx.quadraticCurveTo(18, 6, 21, 12)
            ctx.moveTo(4, 21)
            ctx.lineTo(14, 21)
            break
        case "boost":
            ctx.arc(12, 12.5, 7.5, 0, 2 * Math.PI)
            ctx.moveTo(12, 8)
            ctx.lineTo(12, 12.5)
            ctx.lineTo(15, 14)
            ctx.moveTo(3.5, 6)
            ctx.lineTo(7, 2.5)
            ctx.moveTo(17, 2.5)
            ctx.lineTo(20.5, 6)
            ctx.moveTo(7, 18.5)
            ctx.lineTo(5, 21)
            ctx.moveTo(17, 18.5)
            ctx.lineTo(19, 21)
            break
        case "heat":
        case "idle":
            ctx.moveTo(12, 2.5)
            ctx.quadraticCurveTo(14.7, 6.5, 15.6, 10)
            ctx.quadraticCurveTo(17.1, 9.2, 17.6, 7.5)
            ctx.quadraticCurveTo(23, 17, 16.4, 20.8)
            ctx.quadraticCurveTo(12, 23.2, 7.6, 20.8)
            ctx.quadraticCurveTo(2, 17.5, 6.4, 11)
            ctx.quadraticCurveTo(6.8, 13, 8.2, 13.2)
            ctx.quadraticCurveTo(7.9, 8.9, 12, 2.5)
            ctx.closePath()
            if (kind === "heat")
                ctx.fill()
            break
        }
        ctx.stroke()
        ctx.restore()
    }
}
