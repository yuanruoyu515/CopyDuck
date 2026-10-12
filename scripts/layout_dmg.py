import pathlib
import sys
from ds_store import DSStore
from mac_alias import Alias

volume = pathlib.Path(sys.argv[1])
background = Alias.for_file(str(volume / ".background" / "install.png")).to_bytes()
with DSStore.open(str(volume / ".DS_Store"), "w+") as store:
    store["."]["bwsp"] = {
        "WindowBounds": "{{220, 160}, {660, 440}}",
        "ShowToolbar": False, "ShowStatusBar": False, "ShowPathbar": False,
        "ShowSidebar": False, "SidebarWidth": 0, "ContainerShowSidebar": False,
        "PreviewPaneVisibility": False,
    }
    store["."]["icvp"] = {
        "viewOptionsVersion": 1, "backgroundType": 2,
        "backgroundImageAlias": background,
        "backgroundColorRed": 1.0, "backgroundColorGreen": 1.0, "backgroundColorBlue": 1.0,
        "gridOffsetX": 0.0, "gridOffsetY": 0.0, "gridSpacing": 100.0,
        "arrangeBy": "none", "showItemInfo": False, "showIconPreview": True,
        "labelOnBottom": True, "textSize": 13.0, "iconSize": 80.0,
        "scrollPositionX": 0.0, "scrollPositionY": 0.0,
    }
    store["."]["vSrn"] = ("long", 1)
    store["."]["icvl"] = ("type", b"icnv")
    store["."]["vstl"] = ("type", b"icnv")
    store["复制鸭.app"]["Iloc"] = (166, 248)
    store["应用程序"]["Iloc"] = (494, 248)

print("DMG icon layout and background saved")
