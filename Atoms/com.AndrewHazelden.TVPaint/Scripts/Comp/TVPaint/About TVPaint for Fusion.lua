_VERSION = [[v1 2025-11-17]]
--[[--
==============================================================================
About TVPaint for Fusion.lua - v1 2025-11-17 11.50 PM
==============================================================================

--]]--
-- Open a Webpage
-- Example: OpenURL("GitHub", "https://github.com/Kartaverse/TVPaint-Data-Nodes")
function OpenURL(siteName, path)
	if platform == "Windows" then
		-- Running on Windows
		command = "explorer \"" .. path .. "\""
	elseif platform == "Mac" then
		-- Running on Mac
		command = "open \"" .. path .. "\" &"
	elseif platform == "Linux" then
		-- Running on Linux
		command = "xdg-open \"" .. path .. "\" &"
	else
		comp:Print("[Error] There is an invalid Fusion platform detected\n")
		return
	end

	os.execute(command)

	-- comp:Print("[Launch Command] " tostring(command) .. "\n")
	comp:Print("[Opening URL] " .. tostring(path) .. "\n")
end


-- Create the UI Manager dialog
function AboutWin()
	-- Configure the window Size
	local originX, originY, width, height = 200, 200, 595, 212

	-- Create the new UI Manager Window
	local win = disp:AddWindow({
		ID = "AboutWin",
		TargetID = "AboutWin",
		WindowTitle = "About TVPaint for Fusion",
		WindowFlags = {
			Window = true,
			WindowStaysOnTopHint = true,
		},
		Geometry = {
			originX,
			originY,
			width,
			height,
		},

		ui:VGroup {
			ID = "root",

			ui:HGroup{
				Weight = 0,
				
				ui:VGroup {
					Weight = 1,
					Margin = 0,
					Spacing = 0,
					Padding = 0,
					ui:Label {
						ID = "Title",
						Weight = 0.2,

						Text = "TVPaint for Fusion",
						ReadOnly = true,
						Alignment = {
							AlignHCenter = true,
							AlignVCenter = true,
						},
						Font = ui:Font{
							PixelSize = 36,
						},
					},
					ui:Label {
						ID = "VersionLabel",
						Weight = 0.25,
						Text = _VERSION,
						WordWrap = true,
						Alignment = {
							AlignHCenter = true,
							AlignVCenter = true,
						},
					},
				},
			},
			ui:VGroup{
				ui:Label {
					ID = "AboutLabel",
					Text = [[The toolset allows you to interact with 2D cell animation data inside a BMD Fusion Studio node graph. A series of nodal operators allow you to work with TVPaint exported JSON data on the fly.]],
					OpenExternalLinks = true,
					WordWrap = true,
					Alignment = {
						AlignHCenter = true,
						AlignVCenter = true,
					},
				},
				ui:Label {
					ID = "URLLabel",
					Weight = 0.5,
					Text = [[<p><a href="https://tvpaint.com/en" style="color: rgb(139,155,216)">TVPaint</a> is a trademark of TVPaint Développement. The "<a href="https://github.com/Kartaverse/TVPaint-Data-Nodes" style="color: rgb(139,155,216)">TVPaint for Fusion</a>" toolset is an unoffical addon created by the Kartaverse open-source project.</p>]],
					OpenExternalLinks = true,
					WordWrap = true,
					Alignment = {
						AlignHCenter = true,
					},
				},
			},
		},
	})


	-- Add your GUI element based event functions here:
	itm = win:GetItems()

	-- The window was closed
	function win.On.AboutWin.Close(ev)
		disp:ExitLoop()
	end

	-- The app:AddConfig() command that will capture the "Control + W" or "Control + F4" hotkeys so they will close the window instead of closing the foreground composite.
	app:AddConfig("AboutWin", {
		Target {
			ID = "AboutWin",
		},

		Hotkeys {
			Target = "AboutWin",
			Defaults = true,

			CONTROL_W  = "Execute{ cmd = [[ app.UIManager:QueueEvent(obj, 'Close', {}) ]] }",
			CONTROL_F4 = "Execute{ cmd = [[ app.UIManager:QueueEvent(obj, 'Close', {}) ]] }",
			ESCAPE = "Execute{ cmd = [[ app.UIManager:QueueEvent(obj, 'Close', {}) ]] }",
		},
	})

	-- Init the window
	win:Show()
	disp:RunLoop()
	win:Hide()
	app:RemoveConfig('AboutWin')
	collectgarbage()

	return win,win:GetItems()
end

-- The Main function
function Main()
	-- Find out the current Fusion host platform (Windows/Mac/Linux)
	platform = (FuPLATFORM_WINDOWS and "Windows") or (FuPLATFORM_MAC and "Mac") or (FuPLATFORM_LINUX and "Linux")

	-- Display the About dialog
	ui = app.UIManager
	disp = bmd.UIDispatcher(ui)
	AboutWin()
end


Main()
print("[Done]")
