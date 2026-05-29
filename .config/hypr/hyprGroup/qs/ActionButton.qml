import QtQuick

Rectangle {
	id: root

	property string label
	property bool danger: false
	signal triggered()

	height: 44
	color: mouse.containsMouse ? "#242b35" : "#151a22"
	border.color: danger ? "#6b7280" : "#3a414b"
	border.width: 1
	radius: 6

	Text {
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		anchors.leftMargin: 14
		anchors.rightMargin: 14
		text: root.label
		color: "#f8fafc"
		elide: Text.ElideRight
		font.pixelSize: 14
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		hoverEnabled: true
		onClicked: root.triggered()
	}
}
