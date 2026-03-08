import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

import "ImmichApi.js" as API

PlasmoidItem {
    id: root

    // -----------------------------------------------------------------------
    // State shared with child views
    // -----------------------------------------------------------------------
    property var photoList: []
    property bool isLoading: false
    property string errorMessage: ""

    // KConfig aliases (read-only mirrors; config object is the real source)
    // Strip trailing slashes so URL construction never produces "//api/..."
    readonly property string serverUrl: Plasmoid.configuration.serverUrl.replace(/\/+$/, "")
    readonly property string apiKey:           Plasmoid.configuration.apiKey
    readonly property string viewMode:         Plasmoid.configuration.viewMode
    readonly property int    slideshowInterval: Plasmoid.configuration.slideshowInterval
    readonly property int    refreshInterval:   Plasmoid.configuration.refreshInterval
    readonly property int    photoCount:        Plasmoid.configuration.photoCount
    readonly property string contentSource:    Plasmoid.configuration.contentSource
    readonly property string albumId:          Plasmoid.configuration.albumId
    readonly property string personId:         Plasmoid.configuration.personId
    readonly property bool   shufflePhotos:    Plasmoid.configuration.shufflePhotos
    readonly property bool   useAllPhotos:     Plasmoid.configuration.useAllPhotos
    readonly property double widgetOpacity:    Plasmoid.configuration.widgetOpacity
    readonly property bool   noBorder:         Plasmoid.configuration.noBorder
    readonly property int    dailyResetHour:   Plasmoid.configuration.dailyResetHour
    readonly property string fillMode:         Plasmoid.configuration.fillMode

    Plasmoid.backgroundHints: noBorder ? PlasmaCore.Types.NoBackground
                                       : PlasmaCore.Types.DefaultBackground

    preferredRepresentation: fullRepresentation

    // -----------------------------------------------------------------------
    // Full representation – the visible widget
    // -----------------------------------------------------------------------
    fullRepresentation: Item {
        id: widgetRoot
        implicitWidth:  Kirigami.Units.gridUnit * 20
        implicitHeight: Kirigami.Units.gridUnit * 15

        // View loader – swaps SlideshowView / DailyPhotoView on mode change
        Loader {
            id: viewLoader
            anchors.fill: parent
            opacity: root.widgetOpacity
            source: root.viewMode === "slideshow"
                    ? "SlideshowView.qml"
                    : "DailyPhotoView.qml"
            onLoaded: {
                item.rootWidget = root;
            }
        }

        // Spinner while initially loading (no photos yet)
        QQC2.BusyIndicator {
            anchors.centerIn: parent
            running: root.isLoading && root.photoList.length === 0
            visible: running
        }

        // Error overlay – shows full diagnostic text so no journalctl needed
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.75)
            visible: root.errorMessage !== "" && !root.isLoading && root.photoList.length === 0

            PlasmaComponents3.Label {
                anchors {
                    fill: parent
                    margins: Kirigami.Units.largeSpacing
                }
                color: "white"
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
                font.family: "monospace"
                font.pixelSize: 11
                text: "Immich Gallery — error\n\n"
                    + root.errorMessage + "\n\n"
                    + "serverUrl : " + (root.serverUrl || "(empty)") + "\n"
                    + "source    : " + root.contentSource + "\n"
                    + "photoCount: " + root.photoCount + "\n"
                    + "apiKey set: " + (root.apiKey !== "" ? "yes" : "NO")
            }
        }

        // "Not configured" message
        PlasmaComponents3.Label {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.largeSpacing * 4
            visible: root.serverUrl === "" && !root.isLoading
            text: i18n("Immich Gallery\n\nRight-click → Configure to get started.")
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // -----------------------------------------------------------------------
    // Photo fetching
    // -----------------------------------------------------------------------
    function fetchPhotos() {
        if (root.serverUrl === "" || root.apiKey === "") return;

        root.isLoading = true;
        root.errorMessage = "";

        var cb = function(err, assets) {
            root.isLoading = false;
            if (err) {
                root.photoList = [];
                // Store raw string — no i18n so the URL is never stripped
                root.errorMessage = err;
                retryTimer.start();
                return;
            }
            if (!assets || assets.length === 0) {
                root.photoList = [];
                root.errorMessage = i18n("No photos found for this source.");
                return;
            }
            retryTimer.stop();
            root.errorMessage = "";
            root.photoList = root.shufflePhotos ? API.fisherYates(assets) : assets;
        };

        // null count → ImmichApi paginates through all results
        var fetchCount = root.useAllPhotos ? null : root.photoCount;

        var src = root.contentSource;
        if (src === "recent") {
            API.fetchRecent(root.serverUrl, root.apiKey, fetchCount, cb);
        } else if (src === "favorites") {
            API.fetchFavorites(root.serverUrl, root.apiKey, fetchCount, cb);
        } else if (src === "random") {
            API.fetchRandom(root.serverUrl, root.apiKey, root.photoCount, cb);
        } else if (src === "album") {
            if (root.albumId === "") {
                root.isLoading = false;
                root.errorMessage = i18n("No album selected. Go to Configure → Display.");
                return;
            }
            API.fetchAlbum(root.serverUrl, root.apiKey, root.albumId, cb);
        } else if (src === "people") {
            if (root.personId === "") {
                root.isLoading = false;
                root.errorMessage = i18n("No person selected. Go to Configure → Display.");
                return;
            }
            API.fetchPerson(root.serverUrl, root.apiKey, root.personId, fetchCount, cb);
        }
    }

    // Return a thumbnail URL directly — Immich accepts ?apiKey= as a query param,
    // so QML Image can load it without any XHR/base64 gymnastics.
    function loadImage(assetId, callback) {
        if (!assetId) {
            callback("No asset ID", null);
            return;
        }
        var url = root.serverUrl + "/api/assets/" + assetId
                  + "/thumbnail?size=preview&apiKey=" + root.apiKey;
        callback(null, url);
    }

    // -----------------------------------------------------------------------
    // Timers
    // -----------------------------------------------------------------------

    // Retry after a fetch error (e.g. no network yet on boot)
    Timer {
        id: retryTimer
        interval: 7000
        repeat: false
        onTriggered: root.fetchPhotos()
    }

    // Periodic refresh of the photo list
    Timer {
        id: refreshTimer
        interval: root.refreshInterval * 1000
        repeat:  true
        running: root.serverUrl !== "" && root.apiKey !== ""
        onTriggered: root.fetchPhotos()
    }

    // Midnight refresh so Daily Photo advances at the correct time
    Timer {
        id: midnightTimer
        repeat: false
        onTriggered: {
            root.fetchPhotos();
            root._scheduleMidnightTimer();
        }
    }

    function _scheduleMidnightTimer() {
        var now   = new Date();
        var reset = new Date(now);
        reset.setHours(root.dailyResetHour, 0, 0, 0);
        // If the reset time has already passed today, schedule for tomorrow
        if (reset <= now) {
            reset.setDate(reset.getDate() + 1);
        }
        midnightTimer.interval = reset - now;
        midnightTimer.start();
    }

    // -----------------------------------------------------------------------
    // React to config changes
    // -----------------------------------------------------------------------
    Connections {
        target: Plasmoid.configuration
        function onServerUrlChanged()    { root.fetchPhotos(); }
        function onApiKeyChanged()       { root.fetchPhotos(); }
        function onContentSourceChanged(){ root.fetchPhotos(); }
        function onPhotoCountChanged()   { root.fetchPhotos(); }
        function onShufflePhotosChanged()  { root.fetchPhotos(); }
        function onUseAllPhotosChanged()   { root.fetchPhotos(); }
        function onAlbumIdChanged()  {
            if (root.contentSource === "album") root.fetchPhotos();
        }
        function onPersonIdChanged() {
            if (root.contentSource === "people") root.fetchPhotos();
        }
        function onDailyResetHourChanged() { root._scheduleMidnightTimer(); }
    }

    // -----------------------------------------------------------------------
    // Startup
    // -----------------------------------------------------------------------
    Component.onCompleted: {
        if (root.serverUrl !== "" && root.apiKey !== "") {
            root.fetchPhotos();
        }
        root._scheduleMidnightTimer();
    }
}
