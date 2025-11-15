-- Show Comps Folder menu item


local path = app:MapPath("Reactor:/Deploy/Comps/Kartaverse/TVPaint")

print("\n[Show Comps Folder] ", path)
bmd.openfileexternal("Open", path)
