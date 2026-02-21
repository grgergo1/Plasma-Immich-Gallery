import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

/**
 * Double-buffered crossfade slideshow.
 *
 * imageA and imageB alternate as the "front" buffer.
 * showingA == true  → imageA is visible, imageB is the staging buffer.
 * showingA == false → imageB is visible, imageA is the staging buffer.
 *
 * Sequence for an advance():
 *   1. loadImage() fetches next photo as data URI (async).
 *   2. On success, set the staging Image.source to the data URI.
 *   3. Toggle showingA → Behavior animations handle the crossfade.
 */
Item {
    id: slideshowView

    property var  rootWidget:    null
    property int  localIndex:    0
    property bool showingA:      true  // which buffer is currently "front"
    property bool busy:          false // prevents overlapping loads
    property int  _errorStreak:  0    // consecutive load failures; reset on success

    // ------------------------------------------------------------------
    // Wiring to parent widget
    // ------------------------------------------------------------------
    onRootWidgetChanged: {
        if (!rootWidget) return;
        rootWidget.photoListChanged.connect(_onPhotoListChanged);
        if (rootWidget.photoList.length > 0) {
            _onPhotoListChanged();
        }
    }

    function _onPhotoListChanged() {
        if (!rootWidget || rootWidget.photoList.length === 0) return;
        localIndex = 0;
        _errorStreak = 0;
        _loadAndShow(localIndex);
    }

    // ------------------------------------------------------------------
    // Navigation
    // ------------------------------------------------------------------
    function advance() {
        if (!rootWidget || rootWidget.photoList.length === 0 || busy) return;
        localIndex = (localIndex + 1) % rootWidget.photoList.length;
        _loadAndShow(localIndex);
    }

    function goBack() {
        if (!rootWidget || rootWidget.photoList.length === 0 || busy) return;
        localIndex = (localIndex - 1 + rootWidget.photoList.length)
                     % rootWidget.photoList.length;
        _loadAndShow(localIndex);
    }

    // Load asset at the given list position and crossfade it in.
    function _loadAndShow(index) {
        if (!rootWidget) return;
        var asset = rootWidget.photoList[index];
        if (!asset) return;

        busy = true;
        rootWidget.loadImage(asset.id, function(err, dataUri) {
            busy = false;
            if (err) {
                _errorStreak++;
                if (_errorStreak >= rootWidget.photoList.length) {
                    _errorStreak = 0;
                    return;
                }
                localIndex = (localIndex + 1) % rootWidget.photoList.length;
                _loadAndShow(localIndex);
                return;
            }
            _errorStreak = 0;

            // Write into the background buffer, then swap
            if (showingA) {
                imageB.source = dataUri;
                showingA = false;
            } else {
                imageA.source = dataUri;
                showingA = true;
            }
        });
    }

    // ------------------------------------------------------------------
    // Image buffers
    // ------------------------------------------------------------------
    Image {
        id: imageA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: showingA ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 800; easing.type: Easing.InOutQuad }
        }
    }

    Image {
        id: imageB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: showingA ? 0.0 : 1.0
        Behavior on opacity {
            NumberAnimation { duration: 800; easing.type: Easing.InOutQuad }
        }
    }

    // ------------------------------------------------------------------
    // Auto-advance timer
    // ------------------------------------------------------------------
    Timer {
        id: slideshowTimer
        interval: (rootWidget ? rootWidget.slideshowInterval : 5) * 1000
        repeat:   true
        running:  rootWidget !== null && rootWidget.photoList.length > 0
        onTriggered: advance()
    }

    // ------------------------------------------------------------------
    // Navigation buttons (appear on hover)
    // ------------------------------------------------------------------
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        // Do not eat clicks so the overlay buttons work
        propagateComposedEvents: true

        QQC2.RoundButton {
            id: prevBtn
            anchors {
                left:           parent.left
                leftMargin:     Kirigami.Units.largeSpacing
                verticalCenter: parent.verticalCenter
            }
            visible: hoverArea.containsMouse
            icon.name: "arrow-left"
            background: null
            onClicked: {
                slideshowTimer.restart();
                goBack();
            }
        }

        QQC2.RoundButton {
            id: nextBtn
            anchors {
                right:          parent.right
                rightMargin:    Kirigami.Units.largeSpacing
                verticalCenter: parent.verticalCenter
            }
            visible: hoverArea.containsMouse
            icon.name: "arrow-right"
            background: null
            onClicked: {
                slideshowTimer.restart();
                advance();
            }
        }
    }
}
