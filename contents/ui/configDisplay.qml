import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "ImmichApi.js" as API

KCM.SimpleKCM {
    id: displayPage

    // ------------------------------------------------------------------
    // cfg_ properties — auto-synced with KConfig
    // ------------------------------------------------------------------
    property string cfg_viewMode:          "slideshow"
    property int    cfg_slideshowInterval: 5
    property int    cfg_refreshInterval:   300
    property int    cfg_photoCount:        30
    property string cfg_contentSource:     "recent"
    property string cfg_albumId:           ""   // comma-separated IDs
    property string cfg_albumName:         ""   // comma-separated names
    property string cfg_personId:          ""   // comma-separated IDs
    property string cfg_personName:        ""   // comma-separated names
    property bool   cfg_shufflePhotos:     false
    property bool   cfg_useAllPhotos:      false
    property double cfg_widgetOpacity:     1.0
    property bool   cfg_noBorder:          false
    property int    cfg_dailyResetHour:    0
    property string cfg_fillMode:          "fill"

    // Read-only mirrors — needed for album/person API calls in pickers
    property string cfg_serverUrl: ""
    property string cfg_apiKey:    ""

    // cfg_*Default stubs — Plasma injects these alongside cfg_* properties
    property string cfg_serverUrlDefault:        ""
    property string cfg_apiKeyDefault:           ""
    property string cfg_viewModeDefault:         "slideshow"
    property int    cfg_slideshowIntervalDefault: 5
    property int    cfg_refreshIntervalDefault:   300
    property int    cfg_photoCountDefault:        30
    property string cfg_contentSourceDefault:    "recent"
    property string cfg_albumIdDefault:          ""
    property string cfg_albumNameDefault:        ""
    property string cfg_personIdDefault:         ""
    property string cfg_personNameDefault:       ""
    property bool   cfg_shufflePhotosDefault:    false
    property bool   cfg_useAllPhotosDefault:     false
    property double cfg_widgetOpacityDefault:    1.0
    property bool   cfg_noBorderDefault:         false
    property int    cfg_dailyResetHourDefault:   0
    property string cfg_fillModeDefault:          "fill"

    // ------------------------------------------------------------------
    // Local multi-select state (arrays, synced from cfg_ strings)
    // ------------------------------------------------------------------
    property var _albumIds:   []
    property var _albumNames: []
    property var _personIds:  []
    property var _personNames: []

    onCfg_albumIdChanged: {
        _albumIds = cfg_albumId
            ? cfg_albumId.split(",").filter(function(s) { return s !== ""; })
            : [];
    }
    onCfg_albumNameChanged: {
        _albumNames = cfg_albumName ? cfg_albumName.split(",") : [];
    }
    onCfg_personIdChanged: {
        _personIds = cfg_personId
            ? cfg_personId.split(",").filter(function(s) { return s !== ""; })
            : [];
    }
    onCfg_personNameChanged: {
        _personNames = cfg_personName ? cfg_personName.split(",") : [];
    }

    // ------------------------------------------------------------------
    // Sync ComboBoxes when framework writes cfg_ (happens after onCompleted)
    // ------------------------------------------------------------------
    onCfg_viewModeChanged: {
        viewModeCombo.currentIndex = (cfg_viewMode === "daily") ? 1 : 0;
    }
    onCfg_contentSourceChanged: {
        var idx = sourceCombo.sourceValues.indexOf(cfg_contentSource);
        sourceCombo.currentIndex = (idx >= 0) ? idx : 0;
    }
    onCfg_fillModeChanged: {
        var idx = sourceCombo.sourceValues.indexOf(cfg_contentSource);
        sourceCombo.currentIndex = (idx >= 0) ? idx : 0;
    }

    readonly property bool isSlideshow: cfg_viewMode === "slideshow"
    readonly property bool isAlbum:     cfg_contentSource === "album"
    readonly property bool isPeople:    cfg_contentSource === "people"

    // Picker models
    ListModel { id: albumModel }
    ListModel { id: personModel }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function _toggleAlbum(aId, aName) {
        var idx   = _albumIds.indexOf(aId);
        var ids   = _albumIds.slice();
        var names = _albumNames.slice();
        if (idx >= 0) { ids.splice(idx, 1); names.splice(idx, 1); }
        else          { ids.push(aId);      names.push(aName);     }
        _albumIds   = ids;
        _albumNames = names;
        cfg_albumId   = ids.join(",");
        cfg_albumName = names.join(",");
    }

    function _togglePerson(pId, pName) {
        var idx   = _personIds.indexOf(pId);
        var ids   = _personIds.slice();
        var names = _personNames.slice();
        if (idx >= 0) { ids.splice(idx, 1); names.splice(idx, 1); }
        else          { ids.push(pId);      names.push(pName);     }
        _personIds   = ids;
        _personNames = names;
        cfg_personId   = ids.join(",");
        cfg_personName = names.join(",");
    }

    // ------------------------------------------------------------------
    Kirigami.FormLayout {
        anchors.fill: parent

        // ── View mode ──────────────────────────────────────────────────
        QQC2.ComboBox {
            id: viewModeCombo
            Kirigami.FormData.label: i18n("View mode:")
            model: [ i18n("Slideshow"), i18n("Daily Photo") ]
            onActivated: cfg_viewMode = (currentIndex === 0) ? "slideshow" : "daily"
        }

        QQC2.SpinBox {
            id: slideshowIntervalSpin
            Kirigami.FormData.label: i18n("Slideshow interval (s):")
            from: 1; to: 3600
            value: cfg_slideshowInterval
            visible: isSlideshow
            onValueModified: cfg_slideshowInterval = value
        }

        QQC2.SpinBox {
            id: dailyResetHourSpin
            Kirigami.FormData.label: i18n("Daily reset hour:")
            from: 0; to: 23
            value: cfg_dailyResetHour
            visible: !isSlideshow
            onValueModified: cfg_dailyResetHour = value
            QQC2.ToolTip.text: i18n("Hour of day (0–23) when the daily photo changes. Default is 0 (midnight).")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: 500
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        // ── Photo list options ─────────────────────────────────────────
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Refresh interval (s):")
            from: 60; to: 86400
            value: cfg_refreshInterval
            onValueModified: cfg_refreshInterval = value
            QQC2.ToolTip.text: i18n("How often to re-fetch the photo list from your Immich server. Does not affect the slideshow speed.")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: 500
        }

        QQC2.SpinBox {
            id: photoCountSpin
            Kirigami.FormData.label: i18n("Photo count:")
            from: 1; to: 500
            value: cfg_photoCount
            enabled: !cfg_useAllPhotos
            onValueModified: cfg_photoCount = value
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: ""
            text: i18n("Use all photos (ignore count)")
            checked: cfg_useAllPhotos
            onToggled: cfg_useAllPhotos = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Order:")
            text: i18n("Shuffle")
            checked: cfg_shufflePhotos
            onToggled: cfg_shufflePhotos = checked
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        // ── Content source ─────────────────────────────────────────────
        QQC2.ComboBox {
            id: sourceCombo
            Kirigami.FormData.label: i18n("Content source:")
            model: [
                i18n("Recent"), i18n("Favorites"), i18n("Random"),
                i18n("Album"),  i18n("People")
            ]
            property var sourceValues: ["recent","favorites","random","album","people"]
            onActivated: cfg_contentSource = sourceValues[currentIndex]
        }

        // ── Album multi-picker ─────────────────────────────────────────
        ColumnLayout {
            Kirigami.FormData.label: i18n("Albums:")
            visible: isAlbum
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            // Summary line
            RowLayout {
                Layout.fillWidth: true

                QQC2.Label {
                    Layout.fillWidth: true
                    text: _albumIds.length === 0
                          ? i18n("No albums selected")
                          : _albumIds.length === 1
                            ? (_albumNames[0] || i18n("1 album"))
                            : i18n("%1 albums selected", _albumIds.length)
                    elide: Text.ElideRight
                }

                QQC2.Button {
                    text: i18n("Load")
                    icon.name: "view-refresh"
                    onClicked: {
                        albumModel.clear();
                        API.fetchAlbums(cfg_serverUrl, cfg_apiKey, function(err, albums) {
                            if (err || !albums) return;
                            for (var i = 0; i < albums.length; i++) {
                                albumModel.append({
                                    aId:   albums[i].id,
                                    aName: albums[i].albumName || i18n("Unnamed Album")
                                });
                            }
                        });
                    }
                }
            }

            // Multi-select list (shown after loading)
            QQC2.ScrollView {
                visible: albumModel.count > 0
                Layout.fillWidth: true
                implicitHeight: Math.min(albumModel.count * Kirigami.Units.gridUnit * 2.5, 250)
                clip: true

                ListView {
                    model: albumModel
                    delegate: QQC2.CheckDelegate {
                        width: ListView.view.width
                        text: model.aName
                        // checkable:false keeps the binding alive — clicking won't
                        // auto-toggle; we manage the state manually in onClicked.
                        checkable: false
                        checked: _albumIds.indexOf(model.aId) >= 0
                        onClicked: _toggleAlbum(model.aId, model.aName)
                    }
                }
            }
        }

        // ── People multi-picker ────────────────────────────────────────
        ColumnLayout {
            Kirigami.FormData.label: i18n("People:")
            visible: isPeople
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            // Summary line
            RowLayout {
                Layout.fillWidth: true

                QQC2.Label {
                    Layout.fillWidth: true
                    text: _personIds.length === 0
                          ? i18n("No people selected")
                          : _personIds.length === 1
                            ? (_personNames[0] || i18n("1 person"))
                            : i18n("%1 people selected", _personIds.length)
                    elide: Text.ElideRight
                }

                QQC2.Button {
                    text: i18n("Load")
                    icon.name: "view-refresh"
                    onClicked: {
                        personModel.clear();
                        API.fetchPeople(cfg_serverUrl, cfg_apiKey, function(err, people) {
                            if (err || !people) return;
                            for (var i = 0; i < people.length; i++) {
                                var p = people[i];
                                if (!p.id) continue;
                                if (!p.name || p.name.trim() === "") continue;
                                personModel.append({
                                    pId:   p.id,
                                    pName: p.name
                                });
                            }
                        });
                    }
                }
            }

            // Multi-select list (shown after loading)
            QQC2.ScrollView {
                visible: personModel.count > 0
                Layout.fillWidth: true
                implicitHeight: Math.min(personModel.count * Kirigami.Units.gridUnit * 2.5, 250)
                clip: true

                ListView {
                    model: personModel
                    delegate: QQC2.CheckDelegate {
                        width: ListView.view.width
                        text: model.pName
                        checkable: false
                        checked: _personIds.indexOf(model.pId) >= 0
                        onClicked: _togglePerson(model.pId, model.pName)
                    }
                }
            }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        // ── Display options ────────────────────────────────────────────
        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Border:")
            text: i18n("Remove widget border and background")
            checked: cfg_noBorder
            onToggled: cfg_noBorder = checked
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Opacity:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: opacitySlider
                from: 0.1; to: 1.0; stepSize: 0.05
                value: cfg_widgetOpacity
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                onMoved: cfg_widgetOpacity = value
            }

            QQC2.Label {
                text: Math.round(opacitySlider.value * 100) + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 2
            }
        }

        QQC2.ComboBox {
            id: fillCombo
            Kirigami.FormData.label: i18n("Fill mode:")
            model: [
                i18n("Fill"), i18n("Fit"), i18n("Stretch"),
                i18n("Tile")
            ]
            property var sourceValues: ["fill","fit","stretch","tile"]
            onActivated: cfg_fillMode = sourceValues[currentIndex]
        }
    }
}
