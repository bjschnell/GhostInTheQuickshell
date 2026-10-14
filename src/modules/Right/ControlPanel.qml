import QtQuick
import "../../components"
import "../../"

IconBtn {
		text: "" 
		onClicked: {
        var next = !Popups.archMenuOpen
        Popups.closeAll()
        Popups.archMenuOpen = next
    }
}
