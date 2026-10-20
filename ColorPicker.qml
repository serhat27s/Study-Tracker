import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Floating color picker for subjects (swatches, HSV sliders, hex input, random).
// Reads and writes the selection through `panel` (Panel.qml root).
Rectangle {
    id: colorPaletteCard
    required property var panel
    readonly property bool hexFocused: customHexInput.activeFocus

    component ColorSlider: RowLayout {
        id: cSlider
        property color fg: "#ffffff"
        property color dim: "#aaaaaa"
        property string label: ""
        property real value: 0.0
        property string displayValue: ""
        property color thumbColor: "#ffffff"
        property Gradient trackGradient: null
        signal moved(real newValue)
        signal released()

        width: parent ? parent.width : 0
        spacing: Style.space(6)

        Text {
            Layout.preferredWidth: Style.space(28)
            text: cSlider.label
            font.family: Style.font.family
            font.pixelSize: Style.font.caption * 0.88
            font.bold: true
            color: cSlider.dim
        }

        Item {
            id: trackBox
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(16)

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(10)
                radius: Style.space(5)
                border.width: 1
                border.color: Qt.rgba(cSlider.fg.r, cSlider.fg.g, cSlider.fg.b, 0.2)
                gradient: cSlider.trackGradient
            }

            Rectangle {
                id: thumb
                width: Style.space(16)
                height: Style.space(16)
                radius: width / 2
                x: Math.max(0, Math.min(trackBox.width - width, cSlider.value * (trackBox.width - width)))
                anchors.verticalCenter: parent.verticalCenter
                color: cSlider.thumbColor
                border.width: 2
                border.color: "#ffffff"
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function updateVal(mouse) {
                    var usable = trackBox.width - thumb.width
                    if (usable <= 0) return
                    var rx = Math.max(0, Math.min(usable, mouse.x - thumb.width / 2))
                    cSlider.moved(rx / usable)
                }

                onPressed: function(mouse) { updateVal(mouse) }
                onPositionChanged: function(mouse) { if (pressed) updateVal(mouse) }
                onReleased: cSlider.released()
            }
        }

        Text {
            Layout.preferredWidth: Style.space(36)
            horizontalAlignment: Text.AlignRight
            text: cSlider.displayValue
            font.family: Style.font.family
            font.pixelSize: Style.font.caption * 0.88
            color: cSlider.fg
        }
    }

    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    implicitHeight: colorPickerCol.implicitHeight + Style.space(16)
    radius: Style.space(8)
    color: Color.popups.background
    border.width: 1.5
    border.color: Color.accent
    visible: opacity > 0
    opacity: panel.activeColorTarget.length > 0 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    property real hueVal: 0.0
    property real satVal: 1.0
    property real briVal: 1.0
    property string initialHex: ""
    property bool isSyncing: false

    readonly property color currentColor: {
        if (panel.activeColorTarget === "__new__") {
            return panel.newTagColor.length > 0 ? panel.newTagColor : Color.accent
        }
        return panel.colorForTag(panel.activeColorTarget)
    }

    function syncFromTarget() {
        if (!panel.activeColorTarget || panel.activeColorTarget.length === 0) return
        var hex = ""
        if (panel.activeColorTarget === "__new__") {
            initialHex = panel.newTagColor
            hex = panel.newTagColor.length > 0 ? panel.newTagColor : (panel.w ? Model.tagColor("", null) : "#3b82f6")
        } else {
            var customMap = panel.w ? panel.w.tagColors : null
            initialHex = (customMap && customMap[panel.activeColorTarget]) ? String(customMap[panel.activeColorTarget]) : ""
            hex = panel.colorForTag(panel.activeColorTarget)
        }
        syncHsvFromHex(hex)
    }

    function cancelAndClose() {
        if (panel.activeColorTarget === "__new__") {
            panel.newTagColor = initialHex
        } else if (panel.w && panel.activeColorTarget.length > 0) {
            panel.w.setTagColor(panel.activeColorTarget, initialHex, false)
        }
        panel.activeColorTarget = ""
    }

    function syncHsvFromHex(hexStr) {
        if (!hexStr) return
        var hexNorm = String(hexStr).trim()
        if (hexNorm.indexOf("#") !== 0) hexNorm = "#" + hexNorm
        var hsv = Model.hexToHsv(hexNorm)
        isSyncing = true
        hueVal = hsv[0]
        satVal = hsv[1]
        briVal = hsv[2]
        customHexInput.text = hexNorm.toLowerCase()
        isSyncing = false
    }

    function applyFromSliders() {
        if (isSyncing) return
        var hex = Model.hsvToHex(hueVal, satVal, briVal)
        isSyncing = true
        customHexInput.text = hex
        isSyncing = false
        applyColorToTarget(hex, true)
    }

    function applyColorToTarget(hex, skipSave) {
        if (panel.activeColorTarget === "__new__") {
            panel.newTagColor = hex
        } else if (panel.w && panel.activeColorTarget.length > 0) {
            panel.w.setTagColor(panel.activeColorTarget, hex, skipSave)
        }
    }

    function selectSwatch(hex) {
        applyColorToTarget(hex, false)
        syncHsvFromHex(hex)
    }

    function pickRandomColor() {
        var hex = Model.randomCuratedOrHex(panel.colorPalette)
        selectSwatch(hex)
    }

    Component.onCompleted: syncFromTarget()

    // Do not propagate clicks inside palette to list underneath
    MouseArea { anchors.fill: parent }

    Column {
        id: colorPickerCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        // Title row
        RowLayout {
            width: parent.width
            spacing: Style.space(6)

            Rectangle {
                Layout.preferredWidth: Style.space(12)
                Layout.preferredHeight: Style.space(12)
                radius: Style.space(6)
                color: colorPaletteCard.currentColor
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.4)
            }

            Text {
                Layout.fillWidth: true
                text: panel.activeColorTarget === "__new__"
                    ? "Color for new subject:"
                    : "Color for “" + panel.activeColorTarget + "”:"
                elide: Text.ElideRight
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                color: panel.fg
            }

            Text {
                text: "✕"
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                color: closePalMouse.containsMouse ? panel.fg : panel.dim

                MouseArea {
                    id: closePalMouse
                    anchors.fill: parent
                    anchors.margins: -Style.space(4)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (panel.w) panel.w.saveToDisk()
                        panel.activeColorTarget = ""
                    }
                }
            }
        }

        // Curated Swatches Grid: A 2-row grid of 7 circular color swatches
        Grid {
            id: swatchesGrid
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7
            rows: 2
            rowSpacing: Style.space(6)
            columnSpacing: Style.space(6)

            Repeater {
                model: panel.colorPalette

                Rectangle {
                    id: swatchCircle
                    width: Style.space(24)
                    height: Style.space(24)
                    radius: width / 2
                    color: modelData
                    readonly property bool isCurrent: {
                        var cur = panel.activeColorTarget === "__new__"
                            ? panel.newTagColor
                            : (panel.w && panel.w.tagColors ? panel.w.tagColors[panel.activeColorTarget] : "")
                        return Boolean(cur && cur.toLowerCase() === modelData.toLowerCase())
                    }
                    border.width: isCurrent ? 2.5 : (swatchMouse.containsMouse ? 2 : 1)
                    border.color: isCurrent ? "#ffffff" : (swatchMouse.containsMouse ? Color.accent : Qt.rgba(0, 0, 0, 0.35))
                    scale: swatchMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        visible: parent.isCurrent
                        text: "✓"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption * 0.85
                        font.bold: true
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: colorPaletteCard.selectSwatch(modelData)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: panel.hairline
        }

        // Interactive HSV Chooser: Hue, Saturation, Brightness Sliders
        ColorSlider {
            fg: panel.fg
            dim: panel.dim
            label: "Hue"
            value: colorPaletteCard.hueVal
            displayValue: Math.round(colorPaletteCard.hueVal * 360) + "°"
            thumbColor: Qt.hsva(colorPaletteCard.hueVal, 1.0, 1.0, 1.0)
            trackGradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: "#ff0000" }
                GradientStop { position: 0.17; color: "#ffff00" }
                GradientStop { position: 0.33; color: "#00ff00" }
                GradientStop { position: 0.50; color: "#00ffff" }
                GradientStop { position: 0.67; color: "#0000ff" }
                GradientStop { position: 0.83; color: "#ff00ff" }
                GradientStop { position: 1.00; color: "#ff0000" }
            }
            onMoved: function(v) {
                colorPaletteCard.hueVal = v
                colorPaletteCard.applyFromSliders()
            }
            onReleased: if (panel.w) panel.w.saveToDisk()
        }

        ColorSlider {
            fg: panel.fg
            dim: panel.dim
            label: "Sat"
            value: colorPaletteCard.satVal
            displayValue: Math.round(colorPaletteCard.satVal * 100) + "%"
            thumbColor: Qt.hsva(colorPaletteCard.hueVal, colorPaletteCard.satVal, colorPaletteCard.briVal, 1.0)
            trackGradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.hsva(colorPaletteCard.hueVal, 0.0, colorPaletteCard.briVal, 1.0) }
                GradientStop { position: 1.0; color: Qt.hsva(colorPaletteCard.hueVal, 1.0, colorPaletteCard.briVal, 1.0) }
            }
            onMoved: function(v) {
                colorPaletteCard.satVal = v
                colorPaletteCard.applyFromSliders()
            }
            onReleased: if (panel.w) panel.w.saveToDisk()
        }

        ColorSlider {
            fg: panel.fg
            dim: panel.dim
            label: "Bri"
            value: colorPaletteCard.briVal
            displayValue: Math.round(colorPaletteCard.briVal * 100) + "%"
            thumbColor: Qt.hsva(colorPaletteCard.hueVal, colorPaletteCard.satVal, colorPaletteCard.briVal, 1.0)
            trackGradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#000000" }
                GradientStop { position: 1.0; color: Qt.hsva(colorPaletteCard.hueVal, colorPaletteCard.satVal, 1.0, 1.0) }
            }
            onMoved: function(v) {
                colorPaletteCard.briVal = v
                colorPaletteCard.applyFromSliders()
            }
            onReleased: if (panel.w) panel.w.saveToDisk()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: panel.hairline
        }

        // Bottom Row: Optional HEX field and 🎲 Random / Shuffle button
        RowLayout {
            width: parent.width
            spacing: Style.space(6)

            TextField {
                id: customHexInput
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(28)
                foreground: panel.fg
                placeholderText: "#HEX (e.g. #3b82f6)"
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                maximumLength: 7
                onTextChanged: {
                    if (colorPaletteCard.isSyncing) return
                    var h = text.trim()
                    if (h.indexOf("#") !== 0 && h.length > 0) h = "#" + h
                    if (Model.hexToRgb(h)) {
                        colorPaletteCard.isSyncing = true
                        var hsv = Model.hexToHsv(h)
                        colorPaletteCard.hueVal = hsv[0]
                        colorPaletteCard.satVal = hsv[1]
                        colorPaletteCard.briVal = hsv[2]
                        colorPaletteCard.applyColorToTarget(h, true)
                        colorPaletteCard.isSyncing = false
                    }
                }
                Keys.onReturnPressed: function(event) {
                    event.accepted = true
                    var h = text.trim()
                    if (h.indexOf("#") !== 0 && h.length > 0) h = "#" + h
                    if (Model.hexToRgb(h)) {
                        colorPaletteCard.selectSwatch(h)
                    }
                }
                Keys.onEnterPressed: function(event) {
                    event.accepted = true
                    var h = text.trim()
                    if (h.indexOf("#") !== 0 && h.length > 0) h = "#" + h
                    if (Model.hexToRgb(h)) {
                        colorPaletteCard.selectSwatch(h)
                    }
                }
                Keys.onEscapePressed: function(event) {
                    event.accepted = true
                    colorPaletteCard.cancelAndClose()
                }
            }

            Rectangle {
                id: randomBtn
                Layout.preferredHeight: Style.space(28)
                Layout.preferredWidth: Style.space(34)
                radius: Style.space(5)
                color: randomMouse.containsMouse ? panel.surfaceHover : panel.surface
                border.width: 1
                border.color: randomMouse.containsMouse ? Color.accent : panel.hairline

                Text {
                    anchors.centerIn: parent
                    text: "🎲"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                    id: randomMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: colorPaletteCard.pickRandomColor()
                }

                PanelToolTip {
                    visible: randomMouse.containsMouse
                    text: "Random color (🎲)"
                }
            }
        }
    }
}
