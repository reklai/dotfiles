import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
	id: root

	property bool menuVisible: false
	property string commandPath: "/home/reklai/.config/hypr/hyprGroup/bin/hyprgroup"
	property bool pointerKnown: false
	property int pointerX: 0
	property int pointerY: 0
	property string snapshotAddress: ""
	property string snapshotClass: ""
	property string snapshotTitle: "No Active Window"
	property bool snapshotHasContainer: false
	property var snapshotGrouped: []
	property bool tabDragActive: false
	property string draggedTabAddress: ""
	property int draggedTabStartIndex: -1
	property int tabDropIndex: -1
	readonly property int tabWidth: 150
	readonly property int tabGap: 2
	readonly property int tabDragThreshold: 8

	function clamp(value, minValue, maxValue) {
		return Math.max(minValue, Math.min(maxValue, value));
	}

	function focusedScreen() {
		const monitor = Hyprland.focusedMonitor;

		if (monitor) {
			for (let i = 0; i < Quickshell.screens.length; i++) {
				const screen = Quickshell.screens[i];

				if (screen.name === monitor.name) {
					return screen;
				}
			}
		}

		return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
	}

	function openMenu() {
		captureActiveWindow();
		menuVisible = true;
		Qt.callLater(() => focusTrap.forceActiveFocus());
	}

	function openMenuAt(x, y) {
		setPointer(x, y);
		openMenu();
	}

	function closeMenu() {
		menuVisible = false;
	}

	function toggleMenu() {
		if (menuVisible) {
			closeMenu();
		} else {
			openMenu();
		}
	}

	function toggleMenuAt(x, y) {
		if (menuVisible) {
			closeMenu();
		} else {
			openMenuAt(x, y);
		}
	}

	function run(action, argument, keepOpen) {
		const command = [commandPath, action];

		if (argument) {
			command.push(argument);
		}

		Quickshell.execDetached(command);

		if (keepOpen) {
			refreshSnapshotTimer.restart();
		} else {
			closeMenu();
		}
	}

	function runReorder(address, targetIndex) {
		Quickshell.execDetached([commandPath, "reorder", address, String(targetIndex)]);
		refreshSnapshotTimer.restart();
	}

	function setPointer(x, y) {
		const parsedX = Number(x);
		const parsedY = Number(y);

		if (Number.isFinite(parsedX) && Number.isFinite(parsedY)) {
			pointerX = parsedX;
			pointerY = parsedY;
			pointerKnown = true;
		} else {
			pointerKnown = false;
		}
	}

	function copyGroupedAddresses(grouped) {
		const addresses = [];

		if (!grouped) {
			return addresses;
		}

		for (let i = 0; i < grouped.length; i++) {
			addresses.push(String(grouped[i]));
		}

		return addresses;
	}

	function actualGroupedAddresses(grouped, activeAddress) {
		const addresses = [];
		const source = copyGroupedAddresses(grouped);

		if (activeAddress && source.length > 0 && !hasAddress(source, activeAddress)) {
			source.unshift(activeAddress);
		}

		for (let i = 0; i < source.length; i++) {
			const address = source[i];

			if (hasAddress(addresses, address)) {
				continue;
			}

			if (address === activeAddress || clientForAddress(address)) {
				addresses.push(address);
			}
		}

		return addresses;
	}

	function hasAddress(addresses, address) {
		for (let i = 0; i < addresses.length; i++) {
			if (addresses[i] === address) {
				return true;
			}
		}

		return false;
	}

	function clearSnapshot() {
		snapshotAddress = "";
		snapshotTitle = "No Active Window";
		snapshotClass = "";
		snapshotHasContainer = false;
		snapshotGrouped = [];
	}

	function captureActiveWindowFromHyprland() {
		const active = Hyprland.activeToplevel;
		const ipc = active && active.lastIpcObject ? active.lastIpcObject : null;
		const grouped = actualGroupedAddresses(ipc && ipc.grouped ? ipc.grouped : [], active ? active.address : "");

		if (!active || grouped.length === 0) {
			clearSnapshot();
			return;
		}

		snapshotAddress = active.address;
		snapshotTitle = active.title || "Untitled window";
		snapshotClass = ipc && ipc.class ? ipc.class : "";
		snapshotHasContainer = true;
		snapshotGrouped = grouped;
	}

	function applyContainerSnapshot(snapshot) {
		if (!snapshot || !snapshot.hasContainer || !snapshot.grouped || snapshot.grouped.length === 0) {
			clearSnapshot();
			return;
		}

		snapshotAddress = String(snapshot.address || "");
		snapshotTitle = snapshot.title || "Untitled window";
		snapshotClass = snapshot.className || "";
		snapshotHasContainer = true;
		snapshotGrouped = copyGroupedAddresses(snapshot.grouped);
	}

	function applySnapshotText(text) {
		const trimmed = String(text || "").trim();

		if (trimmed.length === 0) {
			return;
		}

		try {
			applyContainerSnapshot(JSON.parse(trimmed));
		} catch (error) {
			captureActiveWindowFromHyprland();
		}
	}

	function captureActiveWindow() {
		captureActiveWindowFromHyprland();

		if (!snapshotProcess.running) {
			snapshotProcess.exec([commandPath, "snapshot"]);
		}
	}

	function clientForAddress(address) {
		const clients = Hyprland.toplevels ? Hyprland.toplevels.values : [];

		for (let i = 0; i < clients.length; i++) {
			const client = clients[i];

			if (client && client.address === address) {
				return client;
			}
		}

		return null;
	}

	function groupWindowEntries() {
		const entries = [];

		for (let i = 0; i < snapshotGrouped.length; i++) {
			const address = snapshotGrouped[i];
			const client = clientForAddress(address);
			const ipc = client && client.lastIpcObject ? client.lastIpcObject : null;

			entries.push({
				address: address,
				active: address === snapshotAddress,
				className: ipc && ipc.class ? ipc.class : "",
				title: client && client.title ? client.title : address
			});
		}

		return entries;
	}

	function activeWindowPositionLabel() {
		if (!snapshotHasContainer || snapshotGrouped.length === 0) {
			return "";
		}

		for (let i = 0; i < snapshotGrouped.length; i++) {
			if (snapshotGrouped[i] === snapshotAddress) {
				return String(i + 1) + " / " + String(snapshotGrouped.length);
			}
		}

		return "1 / " + String(snapshotGrouped.length);
	}

	function clampedTabIndex(index) {
		if (snapshotGrouped.length === 0) {
			return -1;
		}

		return root.clamp(index, 0, snapshotGrouped.length - 1);
	}

	function tabIndexForLocalX(localX) {
		const slotWidth = tabWidth + tabGap;
		const centeredIndex = Math.floor((localX + (tabWidth / 2)) / slotWidth);

		return clampedTabIndex(centeredIndex);
	}

	function beginTabDrag(address, startIndex) {
		if (snapshotGrouped.length < 2) {
			return;
		}

		tabDragActive = true;
		draggedTabAddress = address;
		draggedTabStartIndex = startIndex;
		tabDropIndex = startIndex;
	}

	function updateTabDropIndex(localX) {
		if (!tabDragActive) {
			return;
		}

		tabDropIndex = tabIndexForLocalX(localX);
	}

	function cancelTabDrag() {
		tabDragActive = false;
		draggedTabAddress = "";
		draggedTabStartIndex = -1;
		tabDropIndex = -1;
	}

	function moveAddressInSnapshot(address, targetIndex) {
		const addresses = copyGroupedAddresses(snapshotGrouped);
		const sourceIndex = addresses.indexOf(address);
		const clampedIndex = clampedTabIndex(targetIndex);

		if (sourceIndex < 0 || clampedIndex < 0 || sourceIndex === clampedIndex) {
			return false;
		}

		addresses.splice(sourceIndex, 1);
		addresses.splice(clampedIndex, 0, address);
		snapshotGrouped = addresses;

		return true;
	}

	function finishTabDrag(address) {
		const targetIndex = tabDropIndex;
		const startIndex = draggedTabStartIndex;

		cancelTabDrag();

		if (targetIndex < 0 || targetIndex === startIndex) {
			return;
		}

		moveAddressInSnapshot(address, targetIndex);
		runReorder(address, targetIndex);
	}

	Timer {
		id: refreshSnapshotTimer
		interval: 80
		repeat: false
		onTriggered: root.captureActiveWindow()
	}

	Process {
		id: snapshotProcess
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: data => root.applySnapshotText(data)
		}
		onExited: (exitCode, exitStatus) => {
			if (exitCode !== 0) {
				root.captureActiveWindowFromHyprland();
			}
		}
	}

	IpcHandler {
		target: "hyprgroup"

		function open() {
			root.openMenu();
		}

		function openAt(x: string, y: string) {
			root.openMenuAt(x, y);
		}

		function close() {
			root.closeMenu();
		}

		function toggle() {
			root.toggleMenu();
		}

		function toggleAt(x: string, y: string) {
			root.toggleMenuAt(x, y);
		}
	}

	PanelWindow {
		id: menuWindow

		visible: true
		screen: root.focusedScreen()
		color: "#00000000"
		aboveWindows: true
		exclusiveZone: 0
		exclusionMode: ExclusionMode.Ignore
		focusable: root.menuVisible
		mask: Region { item: root.menuVisible ? surface : emptyInputRegion }
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: root.menuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
		WlrLayershell.namespace: "hyprgroup-menu"

		anchors {
			top: true
			right: true
			bottom: true
			left: true
		}

		Item {
			id: emptyInputRegion
			width: 0
			height: 0
		}

		Item {
			id: surface
			anchors.fill: parent
			enabled: root.menuVisible
			visible: root.menuVisible

			MouseArea {
				anchors.fill: parent
				onClicked: root.closeMenu()
			}

			Rectangle {
				id: card
				readonly property int edgeMargin: 18
				readonly property int monitorWidth: menuWindow.screen ? menuWindow.screen.width : surface.width
				readonly property int monitorHeight: menuWindow.screen ? menuWindow.screen.height : surface.height
				readonly property int pointerGap: 8
				readonly property int screenX: menuWindow.screen ? menuWindow.screen.x : 0
				readonly property int screenY: menuWindow.screen ? menuWindow.screen.y : 0
				readonly property int surfaceOriginX: Math.max(0, Math.round((monitorWidth - surface.width) / 2))
				readonly property int surfaceOriginY: Math.max(0, Math.round(monitorHeight - surface.height))

				function targetX() {
					if (!root.pointerKnown) {
						return Math.round((surface.width - width) / 2);
					}

					const localPointerX = root.pointerX - screenX - surfaceOriginX;
					const target = localPointerX - Math.round(width / 2);

					return root.clamp(Math.round(target), edgeMargin, Math.max(edgeMargin, surface.width - width - edgeMargin));
				}

				function targetY() {
					if (!root.pointerKnown) {
						return Math.round((surface.height - height) / 2);
					}

					const localPointerY = root.pointerY - screenY - surfaceOriginY;
					let target = localPointerY + pointerGap;

					if (target + height + edgeMargin > surface.height) {
						target = localPointerY - height - pointerGap;
					}

					return root.clamp(Math.round(target), edgeMargin, Math.max(edgeMargin, surface.height - height - edgeMargin));
				}

				width: Math.max(420, Math.min(560, monitorWidth - 36))
				height: Math.max(280, Math.min(330, monitorHeight - 74))
				x: targetX()
				y: targetY()
				color: "#0b0f14"
				border.color: "#30363d"
				border.width: 1
				radius: 8

				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.AllButtons
					onClicked: mouse => mouse.accepted = true
				}

				Item {
					id: focusTrap
					anchors.fill: parent
					focus: true

					Keys.onPressed: event => {
						if (event.key === Qt.Key_Escape) {
							root.closeMenu();
							event.accepted = true;
						}
					}
				}

				Column {
					anchors.fill: parent
					anchors.margins: 16
					spacing: 12

					Item {
						width: parent.width
						height: 34

						Row {
							id: headerControls
							anchors.right: parent.right
							anchors.verticalCenter: parent.verticalCenter
							spacing: 6

							Rectangle {
								id: prevButton
								width: 30
								height: 30
								color: prevMouse.containsMouse ? "#242b35" : "#141922"
								border.color: "#3a414b"
								border.width: 1
								radius: 6

								Text {
									anchors.centerIn: parent
									text: "<"
									color: "#f8fafc"
									font.pixelSize: 16
									font.weight: Font.DemiBold
								}

								MouseArea {
									id: prevMouse
									anchors.fill: parent
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onClicked: root.run("prev", "", true)
								}
							}

							Rectangle {
								id: nextButton
								width: 30
								height: 30
								color: nextMouse.containsMouse ? "#242b35" : "#141922"
								border.color: "#3a414b"
								border.width: 1
								radius: 6

								Text {
									anchors.centerIn: parent
									text: ">"
									color: "#f8fafc"
									font.pixelSize: 16
									font.weight: Font.DemiBold
								}

								MouseArea {
									id: nextMouse
									anchors.fill: parent
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onClicked: root.run("next", "", true)
								}
							}

							Rectangle {
								id: closeButton
								width: 30
								height: 30
								color: closeMouse.containsMouse ? "#242b35" : "#141922"
								border.color: "#3a414b"
								border.width: 1
								radius: 6

								Text {
									anchors.centerIn: parent
									text: "X"
									color: "#f8fafc"
									font.pixelSize: 13
									font.weight: Font.DemiBold
								}

								MouseArea {
									id: closeMouse
									anchors.fill: parent
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onClicked: root.closeMenu()
								}
							}
						}

						Text {
							anchors.left: parent.left
							anchors.right: headerControls.left
							anchors.rightMargin: 12
							anchors.verticalCenter: parent.verticalCenter
							text: "HyprGroup"
							color: "#f8fafc"
							elide: Text.ElideRight
							font.pixelSize: 18
							font.weight: Font.DemiBold
						}
					}

					Row {
						width: parent.width
						height: parent.height - 34 - parent.spacing
						spacing: 12

						Column {
							id: actionPane
							width: 172
							height: parent.height
							spacing: 8

							ActionButton {
								width: parent.width
								label: "Add"
								onTriggered: root.run("add")
							}

							ActionButton {
								width: parent.width
								label: "Swap"
								onTriggered: root.run("swap")
							}

							ActionButton {
								width: parent.width
								label: "Remove"
								danger: true
								onTriggered: root.run("remove")
							}
						}

						Rectangle {
							width: 1
							height: parent.height
							color: "#30363d"
						}

						Column {
							id: detailPane
							width: parent.width - actionPane.width - 1 - (parent.spacing * 2)
							height: parent.height
							spacing: 0

							Rectangle {
								id: containerPanel
								width: parent.width
								height: parent.height
								color: "#08090c"
								border.color: "#383a40"
								border.width: 1
								radius: 8
								clip: true

								Column {
									anchors.fill: parent
									spacing: 0

									Rectangle {
										id: windowTabsPanel
										width: parent.width
										height: 48
										color: "#1f2025"

										Text {
											anchors.centerIn: parent
											visible: root.groupWindowEntries().length === 0
											text: "No Active Window"
											color: "#8f949e"
											elide: Text.ElideRight
											font.pixelSize: 12
											maximumLineCount: 1
										}

										Flickable {
											id: tabFlickable
											anchors.fill: parent
											anchors.margins: 4
											visible: root.groupWindowEntries().length > 0
											clip: true
											boundsBehavior: Flickable.StopAtBounds
											contentWidth: tabRow.width
											contentHeight: height
											interactive: contentWidth > width && !root.tabDragActive

											Row {
												id: tabRow
												height: parent.height
												spacing: root.tabGap

												Repeater {
													model: root.groupWindowEntries()

													delegate: Item {
														id: groupTab
														readonly property bool dragged: root.tabDragActive && root.draggedTabAddress === modelData.address
														readonly property bool dropTarget: root.tabDragActive && root.tabDropIndex === index && !dragged

														width: root.tabWidth
														height: tabRow.height
														opacity: dragged ? 0.72 : 1
														z: dragged || dropTarget ? 1 : 0

														Rectangle {
															anchors.fill: parent
															anchors.topMargin: modelData.active ? 0 : 3
															anchors.leftMargin: 1
															anchors.rightMargin: 1
															anchors.bottomMargin: 0
															color: groupTab.dropTarget ? "#34363d" : modelData.active ? "#3d3e44" : tabMouse.containsMouse ? "#303137" : "#26272d"
															border.color: groupTab.dropTarget ? "#d4d4d8" : modelData.active ? "#5a5c64" : "#3d3f47"
															border.width: 1
															radius: modelData.active ? 7 : 5
														}

														Rectangle {
															width: 1
															height: parent.height - 14
															anchors.right: parent.right
															anchors.verticalCenter: parent.verticalCenter
															visible: index < root.groupWindowEntries().length - 1
															color: "#4a4c54"
														}

														Rectangle {
															height: 2
															anchors.left: parent.left
															anchors.right: parent.right
															anchors.leftMargin: 12
															anchors.rightMargin: 12
															anchors.bottom: parent.bottom
															visible: modelData.active
															color: "#d4d4d8"
															radius: 1
														}

														Text {
															anchors.left: parent.left
															anchors.right: parent.right
															anchors.leftMargin: 14
															anchors.rightMargin: 14
															anchors.verticalCenter: parent.verticalCenter
															text: modelData.title
															color: modelData.active ? "#f4f4f5" : "#c5c8cf"
															elide: Text.ElideRight
															horizontalAlignment: Text.AlignHCenter
															font.pixelSize: 12
															font.weight: modelData.active ? Font.DemiBold : Font.Normal
															maximumLineCount: 1
														}

														MouseArea {
															id: tabMouse
															property real pressX: 0
															property real pressY: 0
															property bool dragStarted: false

															anchors.fill: parent
															hoverEnabled: true
															preventStealing: true
															cursorShape: groupTab.dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor

															onPressed: mouse => {
																pressX = mouse.x;
																pressY = mouse.y;
																dragStarted = false;
															}

															onPositionChanged: mouse => {
																const dx = Math.abs(mouse.x - pressX);
																const dy = Math.abs(mouse.y - pressY);

																if (!dragStarted && (dx > root.tabDragThreshold || dy > root.tabDragThreshold)) {
																	dragStarted = true;
																	root.beginTabDrag(modelData.address, index);
																}

																if (root.tabDragActive && root.draggedTabAddress === modelData.address) {
																	const point = tabMouse.mapToItem(tabRow, mouse.x, mouse.y);
																	root.updateTabDropIndex(point.x - pressX);
																}
															}

															onReleased: {
																if (root.tabDragActive && root.draggedTabAddress === modelData.address) {
																	root.finishTabDrag(modelData.address);
																} else {
																	root.run("jump", modelData.address, true);
																}
															}

															onCanceled: {
																if (root.draggedTabAddress === modelData.address) {
																	root.cancelTabDrag();
																}
															}
														}
													}
												}
											}
										}
									}

									Rectangle {
										width: parent.width
										height: 1
										color: "#383a40"
									}

									Item {
										id: activeWindowPanel
										width: parent.width
										height: parent.height - windowTabsPanel.height - 1

										Column {
											anchors.fill: parent
											anchors.margins: 14
											spacing: 8

											Row {
												width: parent.width
												height: 18

												Text {
													width: parent.width - positionText.width - 10
													anchors.verticalCenter: parent.verticalCenter
													text: "Active Window"
													color: "#9ca3af"
													elide: Text.ElideRight
													font.pixelSize: 12
													font.weight: Font.DemiBold
													maximumLineCount: 1
												}

												Text {
													id: positionText
													anchors.verticalCenter: parent.verticalCenter
													text: root.activeWindowPositionLabel()
													color: "#d4d4d8"
													font.pixelSize: 12
													font.weight: Font.DemiBold
												}
											}

											Text {
												width: parent.width
												text: root.snapshotHasContainer ? root.snapshotTitle : "No Active Window"
												color: "#f8fafc"
												elide: Text.ElideRight
												font.pixelSize: 16
												font.weight: Font.DemiBold
												maximumLineCount: 1
											}

											Text {
												width: parent.width
												visible: root.snapshotHasContainer
												text: root.snapshotClass || root.snapshotAddress
												color: "#9ca3af"
												elide: Text.ElideMiddle
												font.pixelSize: 12
												maximumLineCount: 1
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
