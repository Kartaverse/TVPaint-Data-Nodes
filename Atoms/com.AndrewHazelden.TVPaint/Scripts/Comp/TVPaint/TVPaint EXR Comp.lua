--[[--
TVPaint EXR Comp - v1 2025-11-16 01.54 PM

Auto-build an EXR comp node-graph based upon the active TVPaintLoader node selection.

## Controls:

The "baseEXRFolder" control defines the folder where the LifeSaver content is rendered to.

The "baseImageFolder" control defines where the image layer folders are in relation to the active composite. This setting fills in the value used by the TVPaintLinkImage node.

The "adjustRenderRange" control sets the RenderEnd range to match the TVPaint image count.

The "reverseLayerOrder" control allows you to flip the layer sort order when the TVPaintLinkImage nodes are added to the comp, and they are then connected to the MultiMerge node.

The "skipShowingUI" control allows you to avoid displaying the UI Manager window. This improves compatibility of the script with Resolve Free v19.1-20.2+.

--]]--

-- Should the timeline frame range match the TVPaint range
adjustRenderRange = true

-- LifeSaver
baseEXRFolder = "Comp:/exr/"

-- TVPaintLinkImage Options
baseImageFolder = "Comp:/"
reverseLayerOrder = false

-- Should a TVPaintBackground node be added
addBackground = false

-- Should the UI Manager window be skipped
skipShowingUI = false

-- Should the nodes be built horizontal or vertical
direction = 1

-- Debugging log detail
local verbose = true

function get(t, key)
	local value = nil
	local found = false

	for k, v in pairs(t) do
		if k == key then
			value = v
			found = true
			break
		end
	end

	if not found then
		error(string.format("no key '%s' found in ScriptVal table", key))
	end

	return value
end


-------------------------------------------------------------------------------
-- Read a fusion specific preference value. If nothing exists set and return a default value
-- Example: splitDirection = getPreferenceData("TVPaint.sort", 1, true)
function getPreferenceData(pref, defaultValue, debugPrint)
	-- Choose if you are saving the preference to the comp or to all of fusion
	-- local newPreference = comp:GetData(pref)
	local newPreference = fu:GetData(pref)

	if newPreference ~= nil then
		-- List the existing preference value
		if (debugPrint == true) or (debugPrint == 1) then
			if newPreference == nil then
				print("[Reading " .. tostring(pref) .. " Preference Data] " .. "nil")
			else
				print("[Reading " .. tostring(pref) .. " Preference Data] " .. tostring(newPreference))
			end
		end
	else
		-- Force a default value into the preference & then list it
		newPreference = defaultValue

		-- Choose if you are saving the preference to the comp or to all of fusion
		-- comp:SetData(pref, defaultValue)
		fu:SetData(pref, defaultValue)

		if (debugPrint == true) or (debugPrint == 1) then
			if newPreference == nil then
				print("[Creating " .. tostring(pref) .. " Preference Data] " .. "nil")
			else
				print("[Creating ".. tostring(pref) .. " Preference Entry] " .. tostring(newPreference))
			end
		end
	end

	return newPreference
end


-------------------------------------------------------------------------------
-- Set a fusion specific preference value
-- Example: setPreferenceData("TVPaint.sort", 1, true)
function setPreferenceData(pref, value, debugPrint)
	-- Choose if you are saving the preference to the comp or to all of fusion
	-- comp:SetData(pref, value)
	fu:SetData(pref, value)

	-- List the preference value
	if (debugPrint == true) or (debugPrint == 1) then
		if value == nil then
			print("[Setting " .. tostring(pref) .. " Preference Data] " .. "nil")
		else
			print("[Setting " .. tostring(pref) .. " Preference Data] " .. tostring(value))
		end
	end
end


------------------------------------------------------------------------------
-- parseFilename() from bmd.scriptlib
--
-- this is a great function for ripping a filepath into little bits
-- returns a table with the following
--
-- FullPath : The raw, original path sent to the function
-- Path : The path, without filename
-- FullName : The name of the clip w\ extension
-- Name : The name without extension
-- CleanName: The name of the clip, without extension or sequence
-- SNum : The original sequence string, or "" if no sequence
-- Number : The sequence as a numeric value, or nil if no sequence
-- Extension: The raw extension of the clip
-- Padding : Amount of padding in the sequence, or nil if no sequence
-- UNC : A true or false value indicating whether the path is a UNC path or not
------------------------------------------------------------------------------
function parseFilename(filename)
	local seq = {}
	seq.FullPath = filename
	string.gsub(seq.FullPath, "^(.+[/\\])(.+)", function(path, name) seq.Path = path seq.FullName = name end)
	string.gsub(seq.FullName, "^(.+)(%..+)$", function(name, ext) seq.Name = name seq.Extension = ext end)

	if not seq.Name then -- no extension?
		seq.Name = seq.FullName
	end

	string.gsub(seq.Name, "^(.-)(%d+)$", function(name, SNum) seq.CleanName = name seq.SNum = SNum end)

	if seq.SNum then
		seq.Number = tonumber( seq.SNum )
		seq.Padding = string.len( seq.SNum )
	else
		seq.SNum = ""
		seq.CleanName = seq.Name
	end

	if seq.Extension == nil then seq.Extension = "" end
	seq.UNC = ( string.sub(seq.Path, 1, 2) == [[\\]] )

	return seq
end


function AskForInput()
	direction = getPreferenceData("TVPaint.Direction", 1, verbose)
	adjustRenderRange = getPreferenceData("TVPaint.adjustRenderRange", adjustRenderRange, verbose)
	addBackground = getPreferenceData("TVPaint.addBackground", addBackground, verbose)
	reverseLayerOrder = getPreferenceData("TVPaint.reverseLayerOrder", reverseLayerOrder, verbose)

	local ui = fu.UIManager
	local disp = bmd.UIDispatcher(ui)
	local width,height = 300,150

	win = disp:AddWindow({
		ID = "TVPaint",
		TargetID = "TVPaint",
		WindowTitle = "TVPaint EXR Comp",
		Geometry = {100, 100, width, height},
		Spacing = 10,

		ui:VGroup{
			ID = "root",
			ui:HGroup{
				Weight = 0.01,
				ui:Label{
					ID = "BuildDirectionLabel",
					Text = "Build Direction",
				},
				ui:ComboBox{
					ID = "BuildDirection",
					Text = "Build Direction",
				},
			},
			ui:CheckBox{
				ID = "AdjustRenderRange",
				Text = "Adjust Render Range",
				Checked = adjustRenderRange,
			},
			ui:CheckBox{
				ID = "AddBackground",
				Text = "Add Background",
				Checked = addBackground,
			},
			ui:CheckBox{
				ID = "ReverseLayerOrder",
				Text = "Reverse Layer Order",
				Checked = reverseLayerOrder,
			},
			ui:Button{
				Weight = 0.01,
				ID = "OKButton",
				Text = "OK",
			},
		},
	})

	-- The window was closed
	function win.On.TVPaint.Close(ev)
		disp:ExitLoop()
	end

	-- Add your GUI element based event functions here:
	itm = win:GetItems()

	-- Add the items to the ComboBox menu
	itm.BuildDirection:AddItem("Vertical")
	itm.BuildDirection:AddItem("Horizontal")
	-- Restore the BuildDirection preference
	itm.BuildDirection.CurrentIndex = direction

	-- The app:AddConfig() command that will capture the "Control + W" or "Control + F4" hotkeys so they will close the window instead of closing the foreground composite.
	app:AddConfig("TVPaint", {
		Target {
			ID = "TVPaint",
		},

		Hotkeys {
			Target = "TVPaint",
			Defaults = true,

			CONTROL_W = "Execute{cmd = [[app.UIManager:QueueEvent(obj, 'Close', {})]]}",
			CONTROL_F4 = "Execute{cmd = [[app.UIManager:QueueEvent(obj, 'Close', {})]]}",
			ESCAPE = "Execute{cmd = [[app.UIManager:QueueEvent(obj, 'Close', {})]]}"
		},
	})

	function win.On.OKButton.Clicked(ev)
		direction = itm.BuildDirection.CurrentIndex
		adjustRenderRange = itm.AdjustRenderRange.Checked
		addBackground = itm.AddBackground.Checked
		reverseLayerOrder = itm.ReverseLayerOrder.Checked

		setPreferenceData("TVPaint.Direction", itm.BuildDirection.Checked, verbose)
		setPreferenceData("TVPaint.adjustRenderRange", itm.AdjustRenderRange.Checked, verbose)
		setPreferenceData("TVPaint.addBackground", itm.AddBackground.Checked, verbose)
		setPreferenceData("TVPaint.reverseLayerOrder", itm.ReverseLayerOrder.Checked, verbose)

		disp:ExitLoop()
	end
	
	win:Show()
	disp:RunLoop()
	win:Hide()
end


function Main()
	print("[TVPaint] Build Comp Script")

	-- Read the node selection
	local selectedTool = comp.ActiveTool
	if selectedTool then
		-- Check the selected node's output type
		toolOutput = selectedTool:FindMainOutput(1)
		if toolOutput ~= nil then
			toolType = toolOutput:GetAttrs().OUTS_DataType

			if skipShowingUI == false then
				AskForInput()
			end

			print("[Base Image Folder] ", baseImageFolder)
			print("[Add Background] ", addBackground)
			print("[Reverse Layer Order] ", reverseLayerOrder)
			print("[Adjust Render Range] ", adjustRenderRange)
			print("[Node Build Direction] ", direction and "Horizontal" or "Vertical")

			-- Starting node position
			local flow = comp.CurrentFrame.FlowView
			local origin_x, origin_y = flow:GetPos(selectedTool)

			-- Process ScriptVal data
			if toolType == "ScriptVal" then
				-- Start Undo
				comp:StartUndo("Build Comp")
				
				-- Lock the comp flow area
				comp:Lock()

				local imgTbl = {}
				local imgNameTbl = {}

				local tbl = {}
				tbl = selectedTool["ScriptVal"][comp.CurrentTime] or {}

				-- Extract the number of clip layers
				local layer_max = 0
				if type(tbl) == "table" and tbl.project and tbl.project and tbl.project.clip and tbl.project.clip.layers and type(tbl.project.clip.layers) == "table" then
					layer_max = tonumber(table.getn(tbl.project.clip.layers)) - 2
				end

				-- Image count
				if adjustRenderRange == true and type(tbl) == "table" and tbl.project and tbl.project and tbl.project.clip and tbl.project.clip["image-count"] then
					local renderStart = 0
					local renderEnd = tonumber(tbl.project.clip["image-count"])

					-- Move the playhead
					comp.CurrentTime = renderStart

					-- Global Range
					comp:SetAttrs({COMPN_GlobalStart = renderStart})
					comp:SetAttrs({COMPN_GlobalEnd = renderEnd})

					-- Render Range
					comp:SetAttrs({COMPN_RenderStart = renderStart})
					comp:SetAttrs({COMPN_RenderEnd = renderEnd})
				end

				-- Default layer build order
				local startLayer = layer_max
				local endLayer = 1
				local stepBy = -1

				-- Build the layer stack backwards
				if reverseLayerOrder == true then
					startLayer = 1
					endLayer = layer_max
					stepBy = 1
				end

				-- Add the TVPaintBackground node
				if addBackground == true then
					local bg = comp:AddTool("Fuse.TVPaintBackground", -32768, -32768)

					-- Connect the inputs
					bg:ConnectInput("ScriptVal", selectedTool)

					local x, y = flow:GetPos(bg)
					if direction == 0 then
						-- vertical build
						flow:SetPos(bg, origin_x + 1, y)
					else
						-- horizontal build
						flow:SetPos(bg, origin_x + 1, y + 1)
					end

					-- Save the TVPainTVPaintBackgroundtLinkImage node to a table
					table.insert(imgTbl, bg)

					-- Save the layer name
					table.insert(imgNameTbl, "bg")
				end

				for i = startLayer, endLayer, stepBy do
					-- Add the TVPaintLinkImage node
					local img = comp:AddTool("Fuse.TVPaintLinkImage", -32768, -32768)

					-- Connect the inputs
					img:ConnectInput("ScriptVal", selectedTool)

					-- Time control
					img.TimeMode = 2

					-- Increment the Layer value
					img.Layer = tonumber(i)

					-- Working folder for TVPaint images
					img.BaseFolder = tostring(baseImageFolder)

					-- Extract the layer name
					groupTbl = get(tbl.project.clip.layers, i)
					if type(groupTbl) == "table" and groupTbl.name then
							local NewName = "layer_" .. tostring(groupTbl.name)
							img:SetAttrs({TOOLS_Name = NewName})

							-- Save the layer name
							table.insert(imgNameTbl, groupTbl.name)
					end

					local x, y = flow:GetPos(img)
					if direction == 0 then
						-- vertical build
						flow:SetPos(img, origin_x + 1, y)
					else
						-- horizontal build
						flow:SetPos(img, origin_x + 1, y + 1)
					end

					-- Save the TVPaintLinkImage node to a table
					table.insert(imgTbl, img)
				end

				-- Connect the TVPaintLinkImage nodes to a LifeSaver node
				local ls = comp:AddTool("Fuse.LifeSaver", -32768, -32768)

				-- Shift the node to the right
				local ls_x, ls_y = flow:GetPos(ls)
					if direction == 0 then
						-- vertical build
						flow:SetPos(ls, origin_x + 2, origin_y + 1)
					else
						-- horizontal build
						flow:SetPos(ls, origin_x + 2, origin_y + 1)
					end

				-- Name the EXR
				local baseJSONFilename = selectedTool["Filename"][fu.TIME_UNDEFINED]
				ls["Filename"][fu.TIME_UNDEFINED] = tostring(baseEXRFolder) .. tostring(parseFilename(baseJSONFilename).Name) .. "_${VERSION}.0000.exr"

				-- Connect the inputs
				for k,v in pairs(imgTbl) do
					-- Use the actual TVPaint layer name
					ls["Name" .. (k)][fu.TIME_UNDEFINED] = imgNameTbl[k]

					-- Connect the image Input
					ls:ConnectInput("Input" .. (k), imgTbl[k])

					print(string.format("[%03d][Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(ls.Name)  .. ".Name" .. (k)))
					
					-- Add a new image input to the node
					if k <= #imgTbl - 1 then
						ls.AddOutput[fu.TIME_UNDEFINED] = 1
					end
				end

				-- Unlock the comp flow area
				comp:Unlock()

				-- End Undo
				comp:EndUndo()
			end
		end
	else
		error("[Error] Please select a TVPaintLoader node before running this script.")
	end
end

Main()
print('[Done]')
