import QtQuick

import "ImmichApi.js" as API

/**
 * Daily Photo mode.
 *
 * Picks one random photo per calendar day and sticks with it.
 * The choice is persisted in a LocalStorage SQLite table so it survives
 * widget restarts.  At midnight, main.qml fetches a fresh photo list and
 * photoListChanged fires, causing a new selection.
 */
Item {
    id: dailyView

    property var rootWidget: null

    // ------------------------------------------------------------------
    // Wiring to parent widget
    // ------------------------------------------------------------------
    onRootWidgetChanged: {
        if (!rootWidget) return;
        rootWidget.photoListChanged.connect(_selectDailyPhoto);
        if (rootWidget.photoList.length > 0) {
            _selectDailyPhoto();
        }
    }

    function _selectDailyPhoto() {
        if (!rootWidget || rootWidget.photoList.length === 0) return;

        var today    = API.todayString(rootWidget ? rootWidget.dailyResetHour : 0);
        var stored   = API.loadDailyPhoto();
        var assetId  = null;
        var list     = rootWidget.photoList;

        // Reuse today's stored photo if it still exists in the current list
        if (stored && stored.date === today) {
            for (var i = 0; i < list.length; i++) {
                if (list[i].id === stored.id) {
                    assetId = stored.id;
                    break;
                }
            }
        }

        // Otherwise pick a new random photo
        if (!assetId) {
            var randomIndex = Math.floor(Math.random() * list.length);
            assetId = list[randomIndex].id;
            API.saveDailyPhoto(assetId, today);
        }

        // Fetch and display
        rootWidget.loadImage(assetId, function(err, dataUri) {
            if (err) return;
            photoImage.source = dataUri;
        });
    }

    // ------------------------------------------------------------------
    // Image display
    // ------------------------------------------------------------------
    Image {
        id: photoImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false

        Behavior on source {
            // Simple fade in when the source changes
            SequentialAnimation {
                NumberAnimation {
                    target: photoImage
                    property: "opacity"
                    to: 0
                    duration: 300
                    easing.type: Easing.InQuad
                }
                PropertyAction { target: photoImage; property: "source" }
                NumberAnimation {
                    target: photoImage
                    property: "opacity"
                    to: 1
                    duration: 500
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

}
