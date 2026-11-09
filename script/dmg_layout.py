files = [(defines["app"], "Flip H.app")]
symlinks = {"Applications": "/Applications"}
background = defines["background"]

format = "UDZO"
filesystem = "APFS"
size = "64m"
default_view = "icon-view"
# Finder uses part of the window height for its title and status bars.
window_rect = ((180, 160), (660, 440))
icon_size = 112
text_size = 14
icon_locations = {"Flip H.app": (164, 211), "Applications": (496, 211)}
