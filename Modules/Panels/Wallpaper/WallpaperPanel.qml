import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../Helpers/FuzzySort.js" as FuzzySort
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root
  


  preferredWidth: isCollapsed ? (120 * Style.uiScaleRatio) : (800 * Style.uiScaleRatio)
  preferredHeight: isCollapsed ? (40 * Style.uiScaleRatio) : (screen ? (screen.height * (Settings.data.wallpaper.panelHeightPercentage / 100)) : (600 * Style.uiScaleRatio))
  preferredWidthRatio: isCollapsed ? 0 : 0.5
  preferredHeightRatio: isCollapsed ? 0 : 0.45

  panelBackgroundColor: isCollapsed ? Color.transparent : Color.mSurface
  panelBorderColor: isCollapsed ? Color.transparent : Color.mOutline

  // Positioning
  readonly property string panelPosition: {
    if (Settings.data.wallpaper.panelPosition === "follow_bar") {
      if (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") {
        return `center_${Settings.data.bar.position}`;
      } else {
        return `${Settings.data.bar.position}_center`;
      }
    } else {
      return Settings.data.wallpaper.panelPosition;
    }
  }
  
  // When collapsed, anchor to top (or bottom if bar is there)
  // When expanded, use default anchoring
  panelAnchorHorizontalCenter: panelPosition === "center" || panelPosition.endsWith("_center")
  panelAnchorVerticalCenter: !isCollapsed && (panelPosition === "center")
  panelAnchorLeft: panelPosition !== "center" && panelPosition.endsWith("_left")
  panelAnchorRight: panelPosition !== "center" && panelPosition.endsWith("_right")
  panelAnchorBottom: (isCollapsed && Settings.data.bar.position === "bottom") || panelPosition.startsWith("bottom_")
  panelAnchorTop: (isCollapsed && Settings.data.bar.position !== "bottom") || panelPosition.startsWith("top_")

  // Force attachment to bar when collapsed for clean look
  forceAttachToBar: isCollapsed

  // Explicitly trigger layout recalc when collapsed state changes
  onIsCollapsedChanged: {
    // This forces SmartPanel to re-evaluate size and position
    // Use Qt.callLater to ensure property bindings (height, anchors) have updated first
    Qt.callLater(() => root.setPosition());
  }

  // Store direct reference to content for instant access
  property var contentItem: null

  // Override keyboard handlers to enable grid navigation
  function onDownPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView) {
      if (!view.gridView.activeFocus) {
        view.gridView.forceActiveFocus();
        if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
          view.gridView.currentIndex = 0;
        }
      } else {
        if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
          view.gridView.currentIndex = 0;
        } else {
          view.gridView.moveCurrentIndexDown();
        }
      }
    }
  }

  function onUpPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.activeFocus) {
      if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
        view.gridView.currentIndex = 0;
      } else {
        view.gridView.moveCurrentIndexUp();
      }
    }
  }

  function onLeftPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.activeFocus) {
      if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
        view.gridView.currentIndex = 0;
      } else {
        view.gridView.moveCurrentIndexLeft();
      }
    }
  }

  function onRightPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.activeFocus) {
      if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
        view.gridView.currentIndex = 0;
      } else {
        view.gridView.moveCurrentIndexRight();
      }
    }
  }

  function onReturnPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.activeFocus) {
      let gridView = view.gridView;
      if (gridView.currentIndex >= 0 && gridView.currentIndex < gridView.model.length) {
        let path = gridView.model[gridView.currentIndex];
        if (Settings.data.wallpaper.setWallpaperOnAllMonitors) {
          WallpaperService.changeWallpaper(path, undefined);
        } else {
          WallpaperService.changeWallpaper(path, view.targetScreen.name);
        }
      }
    }
  }

  panelContent: Rectangle {
    id: wallpaperPanel

    property int currentScreenIndex: {
      if (screen !== null) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          if (Quickshell.screens[i].name == screen.name) {
            return i;
          }
        }
      }
      return 0;
    }
    property var currentScreen: Quickshell.screens[currentScreenIndex]
    property string filterText: ""
    property alias screenRepeater: screenRepeater
    
    // Multi-select state
    property bool selectionModeActive: false
    property var selectedFiles: []
    property int selectionRevision: 0

    function toggleSelection(path) {
      var strPath = String(path);
      var list = selectedFiles;
      var idx = -1;
      for (var i = 0; i < list.length; i++) {
        if (String(list[i]) === strPath) { idx = i; break; }
      }
      if (idx !== -1) {
        var newList = [];
        for (var j = 0; j < list.length; j++) { if (j !== idx) newList.push(list[j]); }
        list = newList;
      } else {
        list = list.concat([strPath]);
      }
      selectedFiles = list;
      selectionRevision++;
    }

    function clearSelection() {
      selectedFiles = [];
      selectionRevision++;
    }
    
    function requestBatchDelete() {
      if (selectedFiles.length === 0) return;
      deleteDialogOverlay.openBatch(selectedFiles);
    }

    Component.onCompleted: {
      root.contentItem = wallpaperPanel;
    }

    function requestDelete(path) {
      deleteDialogOverlay.open(path);
    }
    
    // Function to update Wallhaven resolution filter
    function updateWallhavenResolution() {
      if (typeof WallhavenService === "undefined") {
        return;
      }

      var width = Settings.data.wallpaper.wallhavenResolutionWidth || "";
      var height = Settings.data.wallpaper.wallhavenResolutionHeight || "";
      var mode = Settings.data.wallpaper.wallhavenResolutionMode || "atleast";

      if (width && height) {
        var resolution = width + "x" + height;
        if (mode === "atleast") {
          WallhavenService.minResolution = resolution;
          WallhavenService.resolutions = "";
        } else {
          WallhavenService.minResolution = "";
          WallhavenService.resolutions = resolution;
        }
      } else {
        WallhavenService.minResolution = "";
        WallhavenService.resolutions = "";
      }

      // Trigger new search with updated resolution
      if (Settings.data.wallpaper.useWallhaven) {
        if (wallhavenView) {
          wallhavenView.loading = true;
        }
        WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", 1);
      }
    }

    color: Color.transparent

    // Wallhaven settings popup
    Loader {
      id: wallhavenSettingsPopup
      source: "WallhavenSettingsPopup.qml"
      onLoaded: {
        if (item) {
          item.screen = screen;
        }
      }
    }

    // Focus management
    Connections {
      target: root
      function onOpened() {
        // Ensure contentItem is set
        if (!root.contentItem) {
          root.contentItem = wallpaperPanel;
        }
        // Reset grid view selections
        for (var i = 0; i < screenRepeater.count; i++) {
          let item = screenRepeater.itemAt(i);
          if (item && item.gridView) {
            item.gridView.currentIndex = -1;
          }
        }
        if (wallhavenView && wallhavenView.gridView) {
          wallhavenView.gridView.currentIndex = -1;
        }
        // Give initial focus to search input
        Qt.callLater(() => {
                       if (searchInput.inputItem) {
                         searchInput.inputItem.forceActiveFocus();
                       }
                     });
      }
    }

    // Debounce timer for search
    Timer {
      id: searchDebounceTimer
      interval: 150
      onTriggered: {
        wallpaperPanel.filterText = searchInput.text;
        // Trigger update on all screen views
        for (var i = 0; i < screenRepeater.count; i++) {
          let item = screenRepeater.itemAt(i);
          if (item && item.updateFiltered) {
            item.updateFiltered();
          }
        }
      }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: root.isCollapsed ? 0 : Style.marginL
      spacing: Style.marginM

      // Debounce timer for Wallhaven search
      Timer {
        id: wallhavenSearchDebounceTimer
        interval: 500
        onTriggered: {
          Settings.data.wallpaper.wallhavenQuery = searchInput.text;
          if (typeof WallhavenService !== "undefined") {
            wallhavenView.loading = true;
            WallhavenService.search(searchInput.text, 1);
          }
        }
      }

      // Header
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: root.isCollapsed ? (40 * Style.uiScaleRatio) : (headerColumn.implicitHeight + Style.marginL * 2)
        color: root.isCollapsed ? Color.transparent : Color.mSurfaceVariant
        border.color: root.isCollapsed ? Color.transparent : Color.mOutline

        // Normal Header Content
        ColumnLayout {
          id: headerColumn
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM
          visible: !root.isCollapsed

          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40 * Style.uiScaleRatio
            spacing: Style.marginM

            NIcon {
              icon: "settings-wallpaper-selector"
              pointSize: Style.fontSizeXXL
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("wallpaper.panel.title")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "settings"
              tooltipText: I18n.tr("settings.wallpaper.settings.section.label")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                var settingsPanel = PanelService.getPanel("settingsPanel", screen);
                settingsPanel.requestedTab = SettingsPanel.Tab.Wallpaper;
                settingsPanel.open();
              }
            }

            NIconButton {
              icon: "refresh"
              tooltipText: Settings.data.wallpaper.useWallhaven ? I18n.tr("tooltips.refresh-wallhaven") : I18n.tr("tooltips.refresh-wallpaper-list")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                if (Settings.data.wallpaper.useWallhaven) {
                  if (typeof WallhavenService !== "undefined") {
                     WallhavenService.search(Settings.data.wallpaper.wallhavenQuery, 1);
                  }
                } else {
                  WallpaperService.refreshWallpapersList();
                }
              }
            }



            NIconButton {
              icon: "close"
              tooltipText: I18n.tr("tooltips.close")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: root.close()
            }
            
            // Selection Mode Toggle / Actions
            NText {
               text: qsTr("Select")
               font.weight: Style.fontWeightBold
               color: wallpaperPanel.selectionModeActive ? Color.mPrimary : Color.mOnSurfaceVariant
               visible: !Settings.data.wallpaper.useWallhaven && !wallpaperPanel.selectionModeActive
               
               MouseArea {
                   anchors.fill: parent
                   cursorShape: Qt.PointingHandCursor
                   onClicked: wallpaperPanel.selectionModeActive = true
               }
            }
            
            // Action Buttons for Selection Mode
            RowLayout {
                visible: wallpaperPanel.selectionModeActive
                spacing: Style.marginM
                
                NButton {
                    text: qsTr("Cancel")
                    onClicked: {
                        wallpaperPanel.selectionModeActive = false
                        wallpaperPanel.clearSelection()
                    }
                }
                
                NButton {
                    text: qsTr("Delete (%1)").arg(wallpaperPanel.selectedFiles ? wallpaperPanel.selectedFiles.length : 0)
                    backgroundColor: Color.mError
                    textColor: Color.mOnError
                    hoverColor: Qt.lighter(Color.mError, 1.1)
                    enabled: wallpaperPanel.selectedFiles && wallpaperPanel.selectedFiles.length > 0
                    opacity: enabled ? 1 : 0.5
                    onClicked: wallpaperPanel.requestBatchDelete()
                }
            }
          }

          NDivider {
            Layout.fillWidth: true
          }

          NToggle {
            label: I18n.tr("wallpaper.panel.apply-all-monitors.label")
            description: I18n.tr("wallpaper.panel.apply-all-monitors.description")
            checked: Settings.data.wallpaper.setWallpaperOnAllMonitors
            onToggled: checked => Settings.data.wallpaper.setWallpaperOnAllMonitors = checked
            Layout.fillWidth: true
          }

          // Monitor tabs
          NTabBar {
            id: screenTabBar
            visible: (!Settings.data.wallpaper.setWallpaperOnAllMonitors || Settings.data.wallpaper.enableMultiMonitorDirectories)
            Layout.fillWidth: true
            currentIndex: currentScreenIndex
            onCurrentIndexChanged: currentScreenIndex = currentIndex
            spacing: Style.marginM

            Repeater {
              model: Quickshell.screens
              NTabButton {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                text: modelData.name || `Screen ${index + 1}`
                tabIndex: index
                checked: {
                  screenTabBar.currentIndex === index;
                }
              }
            }
          }

          // Unified search input and source
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NTextInput {
              id: searchInput
              placeholderText: Settings.data.wallpaper.useWallhaven ? I18n.tr("placeholders.search-wallhaven") : I18n.tr("placeholders.search-wallpapers")
              Layout.fillWidth: true

              property bool initializing: true
              Component.onCompleted: {
                // Initialize text based on current mode
                if (Settings.data.wallpaper.useWallhaven) {
                  searchInput.text = Settings.data.wallpaper.wallhavenQuery || "";
                } else {
                  searchInput.text = wallpaperPanel.filterText || "";
                }
                // Give focus to search input
                if (searchInput.inputItem && searchInput.inputItem.visible) {
                  searchInput.inputItem.forceActiveFocus();
                }
                // Mark initialization as complete after a short delay
                Qt.callLater(function () {
                  searchInput.initializing = false;
                });
              }

              Connections {
                target: Settings.data.wallpaper
                function onUseWallhavenChanged() {
                  // Update text when mode changes
                  if (Settings.data.wallpaper.useWallhaven) {
                    searchInput.text = Settings.data.wallpaper.wallhavenQuery || "";
                  } else {
                    searchInput.text = wallpaperPanel.filterText || "";
                  }
                }
              }

              onTextChanged: {
                // Don't trigger search during initialization - Component.onCompleted will handle initial search
                if (initializing) {
                  return;
                }
                if (Settings.data.wallpaper.useWallhaven) {
                  wallhavenSearchDebounceTimer.restart();
                } else {
                  searchDebounceTimer.restart();
                }
              }

              onEditingFinished: {
                if (Settings.data.wallpaper.useWallhaven) {
                   wallhavenSearchDebounceTimer.stop();
                   Settings.data.wallpaper.wallhavenQuery = text;
                   if (typeof WallhavenService !== "undefined") {
                     wallhavenView.loading = true;
                     WallhavenService.search(text, 1);
                   }
                }
              }

              Keys.onDownPressed: {
                if (Settings.data.wallpaper.useWallhaven) {
                  if (wallhavenView && wallhavenView.gridView) {
                    wallhavenView.gridView.forceActiveFocus();
                  }
                } else {
                  let currentView = screenRepeater.itemAt(currentScreenIndex);
                  if (currentView && currentView.gridView) {
                    currentView.gridView.forceActiveFocus();
                  }
                }
              }
            }

            NComboBox {
              id: sourceComboBox
              Layout.fillWidth: false
              
              // Match inactive workspace highlight (occupied inactive)
              highlightColor: Color.mSecondary

              model: [
                {
                  "key": "local",
                  "name": I18n.tr("wallpaper.panel.source.local")
                },
                {
                  "key": "wallhaven",
                  "name": I18n.tr("wallpaper.panel.source.wallhaven")
                }
              ]
              currentKey: Settings.data.wallpaper.useWallhaven ? "wallhaven" : "local"
              property bool skipNextSelected: false
              Component.onCompleted: {
                // Skip the first onSelected if it fires during initialization
                skipNextSelected = true;
                Qt.callLater(function () {
                  skipNextSelected = false;
                });
              }
              onSelected: key => {
                            if (skipNextSelected) {
                              return;
                            }
                            var useWallhaven = (key === "wallhaven");
                            Settings.data.wallpaper.useWallhaven = useWallhaven;
                            // Update search input text based on mode
                            if (useWallhaven) {
                              searchInput.text = Settings.data.wallpaper.wallhavenQuery || "";
                            } else {
                              searchInput.text = wallpaperPanel.filterText || "";
                            }
                            if (useWallhaven && typeof WallhavenService !== "undefined") {
                               // Update service properties when switching to Wallhaven
                               // Don't search here - Component.onCompleted will handle it when the component is created
                               // This prevents duplicate searches
                               WallhavenService.categories = Settings.data.wallpaper.wallhavenCategories;
                               WallhavenService.purity = Settings.data.wallpaper.wallhavenPurity;
                               WallhavenService.sorting = Settings.data.wallpaper.wallhavenSorting;
                               WallhavenService.order = Settings.data.wallpaper.wallhavenOrder;

                               // Update resolution settings
                               wallpaperPanel.updateWallhavenResolution();

                               // If the view is already initialized, trigger a new search when switching to it
                               if (wallhavenView && wallhavenView.initialized && !WallhavenService.fetching) {
                                 wallhavenView.loading = true;
                                 WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", 1);
                               }
                            }
                          }
            }

            // Settings button (only visible for Wallhaven)
            NIconButton {
              id: wallhavenSettingsButton
              icon: "settings"
              tooltipText: I18n.tr("wallpaper.panel.wallhaven-settings.title")
              baseSize: Style.baseWidgetSize * 0.8
              visible: Settings.data.wallpaper.useWallhaven
              onClicked: {
                if (searchInput.inputItem) {
                  searchInput.inputItem.focus = false;
                }
                if (wallhavenSettingsPopup.item) {
                  wallhavenSettingsPopup.item.showAt(wallhavenSettingsButton);
                }
              }
            }
          }
        }
        
        // Collapsed Header (Minimal)
        Item {
          anchors.fill: parent
          visible: root.isCollapsed
          
          NIconButton {
            id: expandBtn
            anchors.centerIn: parent
            icon: "chevron-down"
            tooltipText: I18n.tr("tooltips.expand")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.isCollapsed = false
          }
        }
      }

      // Content stack: Wallhaven or Local
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !root.isCollapsed
        color: Color.mSurfaceVariant

        StackLayout {
          id: contentStack
          anchors.fill: parent
          anchors.margins: Style.marginL

          currentIndex: Settings.data.wallpaper.useWallhaven ? 1 : 0

          // Local wallpapers
          StackLayout {
            id: screenStack
            currentIndex: currentScreenIndex

            Repeater {
              id: screenRepeater
              model: Quickshell.screens
              delegate: WallpaperScreenView {
                targetScreen: modelData
              }
            }
          }

          // Wallhaven wallpapers
          WallhavenView {
            id: wallhavenView
          }
        }


      }
    }
    
    // -------------------------------------------------------------------------
    // Delete Confirmation Dialog
    // -------------------------------------------------------------------------
    Item {
      id: deleteDialogOverlay
      anchors.fill: parent
      z: 999
      visible: false

      property string pendingPath: ""
      property var pendingPaths: []

      // Dimmer Background
      Rectangle {
        anchors.fill: parent
        color: Color.black
        opacity: deleteDialogOverlay.visible ? 0.6 : 0
        Behavior on opacity {
            NumberAnimation { duration: Style.animationFast }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: deleteDialogOverlay.close()
        }
      }

      // Dialog Box
      Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.marginL * 2, 400 * Style.uiScaleRatio)
        height: dialogColumn.implicitHeight + Style.marginL * 2
        
        color: Color.mSurface 
        radius: Style.radiusL
        border.color: Color.mOutline
        border.width: Style.borderS
        
        // Pop-in animation
        scale: deleteDialogOverlay.visible ? 1 : 0.95
        opacity: deleteDialogOverlay.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
        Behavior on scale { NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutQuad } }

        // Prevent clicking through the dialog
        MouseArea { anchors.fill: parent }

        ColumnLayout {
          id: dialogColumn
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginL

          NText {
            Layout.fillWidth: true
            text: deleteDialogOverlay.pendingPaths.length > 0 
                  ? qsTr("Delete %1 Wallpapers?").arg(deleteDialogOverlay.pendingPaths.length)
                  : qsTr("Delete Wallpaper?")
            horizontalAlignment: Text.AlignHCenter
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }

          NText {
            Layout.fillWidth: true
            text: deleteDialogOverlay.pendingPaths.length > 0 
                  ? qsTr("Are you sure you want to delete these %1 files?\nThis action cannot be undone.").arg(deleteDialogOverlay.pendingPaths.length)
                  : qsTr("Are you sure you want to delete this specific wallpaper file?\nThis action cannot be undone.")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            pointSize: Style.fontSizeM
            color: Color.mOnSurfaceVariant
          }

          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Style.marginM

            NButton {
              text: "Cancel"
              onClicked: deleteDialogOverlay.close()
            }

            NButton {
              text: "Delete"
              backgroundColor: Color.mError
              textColor: Color.mOnError
              hoverColor: Qt.lighter(Color.mError, 1.1)
              onClicked: {
                if (deleteDialogOverlay.pendingPaths.length > 0) {
                    WallpaperService.deleteLocalWallpapers(deleteDialogOverlay.pendingPaths);
                    wallpaperPanel.selectionModeActive = false;
                    wallpaperPanel.clearSelection();
                } else if (deleteDialogOverlay.pendingPath !== "") {
                   WallpaperService.deleteLocalWallpaper(deleteDialogOverlay.pendingPath);
                }
                deleteDialogOverlay.close();
              }
            }
          }
        }
      }

      function open(path) {
        pendingPath = path;
        pendingPaths = [];
        visible = true;
      }
      
      function openBatch(paths) {
        pendingPath = "";
        pendingPaths = paths;
        visible = true;
      }
      
      function close() {
        visible = false;
        pendingPath = "";
        pendingPaths = [];
      }
    }


  }

  // Component for each screen's wallpaper view
  component WallpaperScreenView: Item {
    property var targetScreen
    property alias gridView: wallpaperGridView

    // Local reactive state for this screen
    property list<string> wallpapersList: []
    property string currentWallpaper: ""
    property list<string> filteredWallpapers: []
    property var wallpapersWithNames: [] // Cached basenames

    // Expose updateFiltered as a proper function property
    function updateFiltered() {
      if (!wallpaperPanel.filterText || wallpaperPanel.filterText.trim().length === 0) {
        filteredWallpapers = wallpapersList;
        return;
      }

      const results = FuzzySort.go(wallpaperPanel.filterText.trim(), wallpapersWithNames, {
                                     "key": 'name',
                                     "limit": 200
                                   });
      // Map back to path list
      filteredWallpapers = results.map(function (r) {
        return r.obj.path;
      });
    }

    Component.onCompleted: {
      refreshWallpaperScreenData();
    }

    Connections {
      target: WallpaperService
      function onWallpaperChanged(screenName, path) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          currentWallpaper = WallpaperService.getWallpaper(targetScreen.name);
        }
      }
      function onWallpaperDirectoryChanged(screenName, directory) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          refreshWallpaperScreenData();
        }
      }
      function onWallpaperListChanged(screenName, count) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          refreshWallpaperScreenData();
        }
      }
    }

    function refreshWallpaperScreenData() {
      if (targetScreen === null) {
        return;
      }
      wallpapersList = WallpaperService.getWallpapersList(targetScreen.name);
      Logger.d("WallpaperPanel", "Got", wallpapersList.length, "wallpapers for screen", targetScreen.name);

      // Pre-compute basenames once for better performance
      wallpapersWithNames = wallpapersList.map(function (p) {
        return {
          "path": p,
          "name": p.split('/').pop()
        };
      });

      // Verify that current wallpaper still exists in the new list
      // If the file was deleted, this check prevents the UI from showing a ghost selection or crashing
      var cw = WallpaperService.getWallpaper(targetScreen.name);
      var exists = wallpapersList.indexOf(cw) !== -1;
      
      currentWallpaper = exists ? cw : "";
      
      updateFiltered();
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      GridView {
        id: wallpaperGridView
        
        property var selectionContext: wallpaperPanel

        Layout.fillWidth: true
        Layout.fillHeight: true

        visible: !WallpaperService.scanning
        interactive: true
        clip: true
        focus: true
        keyNavigationEnabled: true
        keyNavigationWraps: false
        currentIndex: -1

        model: filteredWallpapers

        onModelChanged: {
          // Reset selection when model changes
          currentIndex = -1;
        }

        // Capture clicks on empty areas to give focus to GridView
        MouseArea {
          anchors.fill: parent
          z: -1
          onClicked: {
            wallpaperGridView.forceActiveFocus();
          }
        }

        property int visibleRows: Settings.data.wallpaper.panelVisibleRows
        
        // Calculate cell height based on available grid height and desired rows
        cellHeight: Math.floor((height - topMargin - bottomMargin) / visibleRows)

        // Derive cell width to maintain aspect ratio (based on original 0.7 ratio)
        // Original: cellHeight = (itemSize * 0.7) + overhead
        // New: itemSize = (cellHeight - overhead) / 0.7
        property int overhead: Style.marginXS + Style.fontSizeXS + Style.marginM
        property int calculatedItemSize: Math.max(50, Math.floor((cellHeight - overhead) / 0.7))
        
        cellWidth: calculatedItemSize
        property int itemSize: cellWidth

        property int columns: {
             let avail = width - (leftMargin + rightMargin);
             let cols = Math.floor(avail / cellWidth);
             return Math.max(1, cols);
        }

        leftMargin: {
          if (!cellWidth || width <= 0) return Style.marginS;
          
          // Layout Logic with Centering
          // 1. Calculate safe available width (subtract margins + safety buffer for scrollbar)
          let availableWidth = width - (Style.marginS * 2) - Style.marginXL;
          
          // 2. Determine how many columns fit
          let cols = Math.floor(availableWidth / cellWidth);
          if (cols <= 0) cols = 1;
          
          // 3. Calculate remaining space to center the grid
          let contentWidth = cols * cellWidth;
          let remaining = width - contentWidth;
          
          return Math.max(Style.marginS, Math.floor(remaining / 2));
        }
        rightMargin: leftMargin
        topMargin: Style.marginS
        bottomMargin: Style.marginS

        onCurrentIndexChanged: {
          // Synchronize scroll with current item position
          if (currentIndex >= 0) {
            let row = Math.floor(currentIndex / columns);
            let itemY = row * cellHeight;
            let viewportTop = contentY;
            let viewportBottom = viewportTop + height;

            // If item is out of view, scroll
            if (itemY < viewportTop) {
              contentY = Math.max(0, itemY - cellHeight);
            } else if (itemY + cellHeight > viewportBottom) {
              contentY = itemY + cellHeight - height + cellHeight;
            }
          }
        }

        Keys.onPressed: event => {
                          if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                            if (currentIndex >= 0 && currentIndex < filteredWallpapers.length) {
                              let path = filteredWallpapers[currentIndex];
                              if (Settings.data.wallpaper.setWallpaperOnAllMonitors) {
                                WallpaperService.changeWallpaper(path, undefined);
                              } else {
                                WallpaperService.changeWallpaper(path, targetScreen.name);
                              }
                            }
                            event.accepted = true;
                          }
                        }

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
          parent: wallpaperGridView
          x: wallpaperGridView.mirrored ? 0 : wallpaperGridView.width - width
          y: 0
          height: wallpaperGridView.height

          property color handleColor: Qt.alpha(Color.mHover, 0.8)
          property color handleHoverColor: handleColor
          property color handlePressedColor: handleColor
          property real handleWidth: 6
          property real handleRadius: Style.radiusM

          contentItem: Rectangle {
            implicitWidth: parent.handleWidth
            implicitHeight: 100
            radius: parent.handleRadius
            color: parent.pressed ? parent.handlePressedColor : parent.hovered ? parent.handleHoverColor : parent.handleColor
            opacity: parent.policy === ScrollBar.AlwaysOn || parent.active ? 1.0 : 0.0

            Behavior on opacity {
              NumberAnimation {
                duration: Style.animationFast
              }
            }

            Behavior on color {
              ColorAnimation {
                duration: Style.animationFast
              }
            }
          }

          background: Rectangle {
            implicitWidth: parent.handleWidth
            implicitHeight: 100
            color: Color.transparent
            opacity: parent.policy === ScrollBar.AlwaysOn || parent.active ? 0.3 : 0.0
            radius: parent.handleRadius / 2

            Behavior on opacity {
              NumberAnimation {
                duration: Style.animationFast
              }
            }
          }
        }

        delegate: ColumnLayout {
          id: wallpaperItem

          property string wallpaperPath: modelData
          property bool isSelected: (wallpaperPath === currentWallpaper)
          property bool isSelectedInMode: {
              if (!wallpaperGridView || !wallpaperGridView.selectionContext) return false;
              var ctx = wallpaperGridView.selectionContext;
              if (!ctx.selectionModeActive) return false;
              var rev = ctx.selectionRevision;
              var strPath = String(wallpaperPath);
              var list = ctx.selectedFiles;
              if (!list) return false;
              for (var i = 0; i < list.length; i++) {
                 if (String(list[i]) === strPath) return true;
              }
              return false;
          }
          property string filename: wallpaperPath.split('/').pop()

          width: wallpaperGridView.itemSize
          spacing: Style.marginXS

          Rectangle {
            id: imageContainer
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(wallpaperGridView.itemSize * 0.67)
            color: Color.transparent
            
            MouseArea {
                id: cellMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                  var ctx = wallpaperGridView.selectionContext;
                   if (ctx && ctx.selectionModeActive) {
                       if (wallpaperPath === currentWallpaper) return;
                       ctx.toggleSelection(wallpaperPath);
                   } else {
                       wallpaperGridView.currentIndex = index
                       wallpaperGridView.forceActiveFocus()
                       
                       var path = wallpaperPath
                       if (Settings.data.wallpaper.setWallpaperOnAllMonitors) {
                           WallpaperService.changeWallpaper(path, undefined)
                       } else {
                           WallpaperService.changeWallpaper(path, targetScreen.name)
                       }
                   }
                }
            }

            NImageCached {
              id: img
              imagePath: wallpaperPath
              cacheFolder: Settings.cacheDirImagesWallpapers
              anchors.fill: parent
            }

            Rectangle {
              anchors.fill: parent
              color: Color.transparent
              border.color: {
                if (isSelectedInMode && wallpaperGridView.selectionContext.selectionModeActive) return Color.mPrimary;
                if (isSelected) return Color.mSecondary;
                if (wallpaperGridView.currentIndex === index) return Color.mHover;
                return Color.mSurface;
              }
              border.width: Math.max(1, Style.borderL * 1.5)
            }
            
            // Delete button overlay
            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Style.marginXS
                width: 28 * Style.uiScaleRatio
                height: 28 * Style.uiScaleRatio
                z: 10
                visible: (cellMouseArea.containsMouse || deleteBtnMouse.containsMouse) && !isSelected && !wallpaperGridView.selectionContext.selectionModeActive
                
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Color.mSurface
                    opacity: 0.9
                    border.color: Color.mOutline
                    border.width: 1
                }
                
                NIcon {
                    anchors.centerIn: parent
                    icon: "trash"
                    pointSize: Style.fontSizeS
                    color: Color.mError
                }
                
                MouseArea {
                    id: deleteBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        wallpaperPanel.requestDelete(wallpaperPath);
                    }
                }
            }

            // Multi-Select Indicator (Checkmark)
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Style.marginS
                width: 28 * Style.uiScaleRatio
                height: 28 * Style.uiScaleRatio
                radius: width / 2
                
                visible: wallpaperGridView.selectionContext.selectionModeActive && !isSelected
                color: isSelectedInMode ? Color.mPrimary : Qt.rgba(0,0,0,0.5)
                border.color: Color.mOutline
                border.width: 1
                
                NIcon {
                   anchors.centerIn: parent
                   icon: "check"
                   pointSize: Style.fontSizeS
                   color: Color.mOnPrimary
                   visible: isSelectedInMode
                }
            }

            Rectangle {
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: Style.marginS
              width: 28
              height: 28
              radius: width / 2
              color: Color.mSecondary
              border.color: Color.mOutline
              border.width: Style.borderS
              visible: isSelected && !wallpaperGridView.selectionContext.selectionModeActive

              NIcon {
                icon: "check"
                pointSize: Style.fontSizeM
                color: Color.mOnSecondary
                anchors.centerIn: parent
              }
            }

            Rectangle {
              anchors.fill: parent
              color: Color.mSurface
              opacity: (hoverHandler.hovered || isSelected || isSelectedInMode || wallpaperGridView.currentIndex === index) ? 0 : 0.3
              radius: parent.radius
              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                }
              }
            }

            // More efficient hover handling
            HoverHandler {
              id: hoverHandler
            }

            TapHandler {
              onTapped: {
                  var ctx = wallpaperGridView.selectionContext;
                   if (ctx && ctx.selectionModeActive) {
                       if (wallpaperPath === currentWallpaper) return;
                       ctx.toggleSelection(wallpaperPath);
                   } else {
                       wallpaperGridView.forceActiveFocus();
                       wallpaperGridView.currentIndex = index;
                       if (Settings.data.wallpaper.setWallpaperOnAllMonitors) {
                         WallpaperService.changeWallpaper(wallpaperPath, undefined);
                       } else {
                         WallpaperService.changeWallpaper(wallpaperPath, targetScreen.name);
                       }
                   }
              }
            }
          }

          NText {
            text: filename
            visible: !Settings.data.wallpaper.hideWallpaperFilenames
            color: (hoverHandler.hovered || isSelected || wallpaperGridView.currentIndex === index) ? Color.mOnSurface : Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            Layout.fillWidth: true
            Layout.leftMargin: Style.marginS
            Layout.rightMargin: Style.marginS
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }

      // Empty / scanning state
      Rectangle {
        color: Color.mSurface
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: Style.borderS
        visible: (filteredWallpapers.length === 0 && !WallpaperService.scanning) || WallpaperService.scanning
        Layout.fillWidth: true
        Layout.preferredHeight: 130

        ColumnLayout {
          anchors.fill: parent
          visible: WallpaperService.scanning
          NBusyIndicator {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
          }
        }

        ColumnLayout {
          anchors.fill: parent
          visible: filteredWallpapers.length === 0 && !WallpaperService.scanning
          Item {
            Layout.fillHeight: true
          }
          NIcon {
            icon: "folder-open"
            pointSize: Style.fontSizeXXL
            color: Color.mOnSurface
            Layout.alignment: Qt.AlignHCenter
          }
          NText {
            text: (wallpaperPanel.filterText && wallpaperPanel.filterText.length > 0) ? I18n.tr("wallpaper.no-match") : I18n.tr("wallpaper.no-wallpaper")
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            Layout.alignment: Qt.AlignHCenter
          }
          NText {
            text: (wallpaperPanel.filterText && wallpaperPanel.filterText.length > 0) ? I18n.tr("wallpaper.try-different-search") : I18n.tr("wallpaper.configure-directory")
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.alignment: Qt.AlignHCenter
          }
          Item {
            Layout.fillHeight: true
          }
        }
      }
    }
  }

  // Component for Wallhaven wallpapers view
  component WallhavenView: Item {
    id: wallhavenViewRoot
    property alias gridView: wallhavenGridView

    property var wallpapers: (typeof WallhavenService !== "undefined" && WallhavenService.currentResults) ? WallhavenService.currentResults : []
    property bool loading: false
    property string errorMessage: ""
    property bool initialized: false
    property bool searchScheduled: false

    Connections {
      target: typeof WallhavenService !== "undefined" ? WallhavenService : null
      function onSearchCompleted(results, meta) {
        wallhavenViewRoot.wallpapers = results || [];
        wallhavenViewRoot.loading = false;
        wallhavenViewRoot.errorMessage = "";
        wallhavenViewRoot.searchScheduled = false;
        // Imperatively update page input (Standard TextField)
        if (typeof pageInput !== "undefined") {
           pageInput.text = "" + WallhavenService.currentPage;
        }
      }
      function onSearchFailed(error) {
        wallhavenViewRoot.loading = false;
        wallhavenViewRoot.errorMessage = error || "";
        wallhavenViewRoot.searchScheduled = false;
      }
    }

    Component.onCompleted: {
      // Initialize service properties and perform initial search if Wallhaven is active
      if (typeof WallhavenService !== "undefined" && Settings.data.wallpaper.useWallhaven && !initialized) {
        // Set flags immediately to prevent race conditions
        if (WallhavenService.initialSearchScheduled) {
          // Another instance already scheduled the search, just initialize properties
          initialized = true;
          return;
        }

        // We're the first one - claim the search
        initialized = true;
        WallhavenService.initialSearchScheduled = true;
        WallhavenService.categories = Settings.data.wallpaper.wallhavenCategories;
        WallhavenService.purity = Settings.data.wallpaper.wallhavenPurity;
        WallhavenService.sorting = Settings.data.wallpaper.wallhavenSorting;
        WallhavenService.order = Settings.data.wallpaper.wallhavenOrder;

        // Initialize resolution settings
        var width = Settings.data.wallpaper.wallhavenResolutionWidth || "";
        var height = Settings.data.wallpaper.wallhavenResolutionHeight || "";
        var mode = Settings.data.wallpaper.wallhavenResolutionMode || "atleast";
        if (width && height) {
          var resolution = width + "x" + height;
          if (mode === "atleast") {
            WallhavenService.minResolution = resolution;
            WallhavenService.resolutions = "";
          } else {
            WallhavenService.minResolution = "";
            WallhavenService.resolutions = resolution;
          }
        } else {
          WallhavenService.minResolution = "";
          WallhavenService.resolutions = "";
        }

        // Check if we should retain previous results
        // If we have results and the query hasn't changed, reuse them to prevent resetting the user
        var queryMatch = (Settings.data.wallpaper.wallhavenQuery || "") === WallhavenService.currentQuery;
        
        // If we have results and a match, the declarative binding already handles the data.
        // We just need to handle the case where we NEED a search.
        if (WallhavenService.currentResults.length === 0 || !queryMatch) {
            // New search needed
            loading = true;
            WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", 1);
        } else {
             // Data preserved via binding. Restore error state if any.
             if (WallhavenService.lastError) {
                  errorMessage = WallhavenService.lastError;
             }
             Logger.d("WallhavenView", "Restoring previous results for query:", WallhavenService.currentQuery);
        }
      }
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        GridView {
          id: wallhavenGridView

          anchors.fill: parent

          visible: !loading && errorMessage === "" && (wallpapers && wallpapers.length > 0)
          interactive: true
          clip: true
          focus: true
          keyNavigationEnabled: true
          keyNavigationWraps: false
          currentIndex: -1

          model: wallpapers || []

          onModelChanged: {
            // Reset selection when model changes
            currentIndex = -1;
          }

          property int visibleRows: Settings.data.wallpaper.panelVisibleRows
          
          cellHeight: Math.floor((height - topMargin - bottomMargin) / visibleRows)
          
          property int overhead: Style.marginXS + (Settings.data.wallpaper.hideWallpaperFilenames ? 0 : Style.fontSizeXS + Style.marginM)
          property int calculatedItemSize: Math.max(50, Math.floor((cellHeight - overhead) / 0.7))
          
          cellWidth: calculatedItemSize

          property int columns: {
             let avail = width - (leftMargin + rightMargin);
             let cols = Math.floor(avail / cellWidth);
             return Math.max(1, cols);
          }
          property int itemSize: cellWidth

          leftMargin: {
            if (!cellWidth || width <= 0) return Style.marginS;
            
            // Layout Logic with Centering
            let availableWidth = width - (Style.marginS * 2) - Style.marginXL;
            
            let cols = Math.floor(availableWidth / cellWidth);
            if (cols <= 0) cols = 1;
            
            let contentWidth = cols * cellWidth;
            let remaining = width - contentWidth;
            
            return Math.max(Style.marginS, Math.floor(remaining / 2));
          }
          rightMargin: leftMargin
          topMargin: Style.marginS
          bottomMargin: Style.marginS

          onCurrentIndexChanged: {
            if (currentIndex >= 0) {
              let row = Math.floor(currentIndex / columns);
              let itemY = row * cellHeight;
              let viewportTop = contentY;
              let viewportBottom = viewportTop + height;

              if (itemY < viewportTop) {
                contentY = Math.max(0, itemY - cellHeight);
              } else if (itemY + cellHeight > viewportBottom) {
                contentY = itemY + cellHeight - height + cellHeight;
              }
            }
          }

          Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                              if (currentIndex >= 0 && currentIndex < wallpapers.length) {
                                let wallpaper = wallpapers[currentIndex];
                                wallhavenDownloadAndApply(wallpaper);
                              }
                              event.accepted = true;
                            }
                          }

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            parent: wallhavenGridView
            x: wallhavenGridView.mirrored ? 0 : wallhavenGridView.width - width
            y: 0
            height: wallhavenGridView.height

            property color handleColor: Qt.alpha(Color.mHover, 0.8)
            property color handleHoverColor: handleColor
            property color handlePressedColor: handleColor
            property real handleWidth: 6
            property real handleRadius: Style.radiusM

            contentItem: Rectangle {
              implicitWidth: parent.handleWidth
              implicitHeight: 100
              radius: parent.handleRadius
              color: parent.pressed ? parent.handlePressedColor : parent.hovered ? parent.handleHoverColor : parent.handleColor
              opacity: parent.policy === ScrollBar.AlwaysOn || parent.active ? 1.0 : 0.0

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                }
              }

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                }
              }
            }

            background: Rectangle {
              implicitWidth: parent.handleWidth
              implicitHeight: 100
              color: Color.transparent
              opacity: parent.policy === ScrollBar.AlwaysOn || parent.active ? 0.3 : 0.0
              radius: parent.handleRadius / 2

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                }
              }
            }
          }

          delegate: ColumnLayout {
            id: wallhavenItem

            required property var modelData
            required property int index
            property string thumbnailUrl: (modelData && typeof WallhavenService !== "undefined") ? WallhavenService.getThumbnailUrl(modelData, "large") : ""
            property string wallpaperId: (modelData && modelData.id) ? modelData.id : ""

            width: wallhavenGridView.itemSize
            spacing: Style.marginXS

            Rectangle {
              id: imageContainer
              Layout.fillWidth: true
              Layout.preferredHeight: Math.round(wallhavenGridView.itemSize * 0.67)
              color: Color.transparent

              Image {
                id: img
                source: thumbnailUrl
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
              }

              Rectangle {
                anchors.fill: parent
                color: Color.transparent
                border.color: wallhavenGridView.currentIndex === index ? Color.mHover : Color.mSurface
                border.width: Math.max(1, Style.borderL * 1.5)
              }

              Rectangle {
                anchors.fill: parent
                color: Color.mSurface
                opacity: hoverHandler.hovered || wallhavenGridView.currentIndex === index ? 0 : 0.3
                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                  }
                }
              }

              HoverHandler {
                id: hoverHandler
              }

              TapHandler {
                onTapped: {
                  wallhavenGridView.currentIndex = index;
                  wallhavenDownloadAndApply(modelData);
                }
              }
            }

            NText {
              text: wallpaperId || I18n.tr("wallpaper.unknown")
              visible: !Settings.data.wallpaper.hideWallpaperFilenames
              color: hoverHandler.hovered || wallhavenGridView.currentIndex === index ? Color.mOnSurface : Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              Layout.fillWidth: true
              Layout.leftMargin: Style.marginS
              Layout.rightMargin: Style.marginS
              Layout.alignment: Qt.AlignHCenter
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
            }
          }
        }

        // Loading overlay - fills same space as GridView to prevent jumping
        Rectangle {
          anchors.fill: parent
          color: Color.mSurface
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          visible: loading
          z: 10

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NBusyIndicator {
              size: Style.baseWidgetSize * 1.5
              color: Color.mPrimary
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: I18n.tr("wallpaper.wallhaven.loading")
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeM
              Layout.alignment: Qt.AlignHCenter
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }

        // Error overlay
        Rectangle {
          anchors.fill: parent
          color: Color.mSurface
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          visible: errorMessage !== "" && !loading
          z: 10

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "alert-circle"
              pointSize: Style.fontSizeXXL
              color: Color.mError
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: errorMessage
              color: Color.mOnSurface
              wrapMode: Text.WordWrap
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }

        // Empty state overlay
        Rectangle {
          anchors.fill: parent
          color: Color.mSurface
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          visible: (!wallpapers || wallpapers.length === 0) && !loading && errorMessage === ""
          z: 10

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "image"
              pointSize: Style.fontSizeXXL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: I18n.tr("wallpaper.wallhaven.no-results")
              color: Color.mOnSurface
              wrapMode: Text.WordWrap
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      // Pagination
      RowLayout {
        Layout.fillWidth: true
        visible: !loading && errorMessage === "" && typeof WallhavenService !== "undefined"
        spacing: Style.marginS

        Item {
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "chevron-left"
          enabled: WallhavenService.currentPage > 1 && !WallhavenService.fetching
          onClicked: WallhavenService.previousPage()
        }

        RowLayout {
          spacing: Style.marginXS

          TextField {
            id: pageInput
            // Standard TextField styling to match theme
            Layout.preferredWidth: 40 * Style.uiScaleRatio
            Layout.minimumWidth: 40 * Style.uiScaleRatio
            
            // Zero padding to align perfectly with NText
            padding: 0
            topPadding: 0
            bottomPadding: 0
            leftPadding: 0
            rightPadding: 0
            
            // Minimal styling - Transparent background
            background: null
            color: Color.mOnSurface
            
            // Replicate NText.qml font logic exactly
            font.family: Settings.data.ui.fontDefault
            font.weight: Style.fontWeightMedium
            // pointSize * (defaultScale * uiScaleRatio)
            font.pointSize: Style.fontSizeM * Settings.data.ui.fontDefaultScale * Style.uiScaleRatio
            
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            
            // Selection color
            selectedTextColor: Color.mOnPrimary
            selectionColor: Color.mPrimary
            
            // Decoupled: Initialize safely
            text: "1"
            
            // Robust key handling
            Keys.onReturnPressed: event => {
               event.accepted = true;
               focus = false;
               submitPage();
            }
            Keys.onEnterPressed: event => {
               event.accepted = true;
               focus = false;
               submitPage();
            }
            
            // Keep onEditingFinished as fallback or for focus loss
            onEditingFinished: {
               focus = false;
               submitPage();
            }
            
            function submitPage() {
               if (typeof WallhavenService === "undefined") return;

               var page = parseInt(text.trim())
               if (!isNaN(page) && page > 0 && page <= WallhavenService.lastPage) {
                 if (page !== WallhavenService.currentPage) {
                   wallhavenViewRoot.loading = true
                   // Revert to using the Settings value which is reliable
                   WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", page)
                 }
               } else {
                 text = "" + WallhavenService.currentPage
               }
            }
            
            Component.onCompleted: {
               if (typeof WallhavenService !== "undefined") {
                  text = "" + WallhavenService.currentPage;
               }
            }
          }

          NText {
             text: "of " + ((typeof WallhavenService !== "undefined") ? WallhavenService.lastPage : "1")
             color: Color.mOnSurface
          }
        }

        NIconButton {
          icon: "chevron-right"
          enabled: WallhavenService.currentPage < WallhavenService.lastPage && !WallhavenService.fetching
          onClicked: {
              // Custom Logic: Check if user entered a specific page manually
              if (typeof WallhavenService === "undefined" || typeof pageInput === "undefined") {
                  WallhavenService.nextPage()
                  return
              }

              var inputPage = parseInt(pageInput.text.trim())
              // If valid and explicitly different from current page, treat as manual jump
              if (!isNaN(inputPage) && inputPage > 0 && inputPage <= WallhavenService.lastPage && inputPage !== WallhavenService.currentPage) {
                  wallhavenViewRoot.loading = true
                  WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", inputPage)
              } else {
                  // Standard behavior
                  WallhavenService.nextPage()
              }
          }
        }

        Item {
          Layout.fillWidth: true
        }
      }
    }

    // -------------------------------
    function wallhavenDownloadAndApply(wallpaper, targetScreen) {
      if (typeof WallhavenService !== "undefined") {
        WallhavenService.downloadWallpaper(wallpaper, function (success, localPath) {
          if (success) {
            if (!Settings.data.wallpaper.setWallpaperOnAllMonitors && currentScreenIndex < Quickshell.screens.length) {
              WallpaperService.changeWallpaper(localPath, Quickshell.screens[currentScreenIndex].name);
            } else {
              WallpaperService.changeWallpaper(localPath, undefined);
            }
          }
        });
      }
    }
  }
}
