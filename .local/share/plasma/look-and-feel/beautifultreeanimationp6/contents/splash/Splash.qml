import QtQuick
import QtQuick.Window

Rectangle {
    id: root
    color: "#0a0a0a"

    property int stage

    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = true;
        } else if (stage == 5) {
            introAnimation.target = busyIndicator;
            introAnimation.from = 1;
            introAnimation.to = 0;
            introAnimation.running = true;
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        TextMetrics {
            id: units
            text: "M"
            property int gridUnit: boundingRect.height
            property int largeSpacing: units.gridUnit
            property int smallSpacing: Math.max(2, gridUnit/4)
        }

        // Full-screen GIF — 1920x1080 fills the whole background
        AnimatedImage {
            id: face
            source: "images/BeautifulTreeAnimation.gif"
            paused: false
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: true
        }

        // Loading spinner using 739.svg
        Image {
            id: busyIndicator
            y: parent.height - 150
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: units.gridUnit
            source: "images/739.svg"
            sourceSize.height: units.gridUnit * 2
            sourceSize.width: units.gridUnit * 2
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1500
                loops: Animation.Infinite
            }
        }

        // KDE logo bottom centre
        Row {
            spacing: units.smallSpacing * 2
            anchors {
                bottom: parent.bottom
                margins: units.gridUnit
            }
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                source: "images/kde.svgz"
                sourceSize.height: units.gridUnit * 2
                sourceSize.width: units.gridUnit * 2
            }
        }
    }

    OpacityAnimator {
        id: introAnimation
        running: false
        target: content
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.InOutQuad
    }
}
