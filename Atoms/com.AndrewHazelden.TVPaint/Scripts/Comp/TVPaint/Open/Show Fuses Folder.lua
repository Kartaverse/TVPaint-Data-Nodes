-- "Show Fuses Folder" menu item

local path = app:MapPath("Fuses:/Kartaverse/TVPaint")
print("\n[Show Fuses Folder] ", path)

bmd.openfileexternal("Open", path)
