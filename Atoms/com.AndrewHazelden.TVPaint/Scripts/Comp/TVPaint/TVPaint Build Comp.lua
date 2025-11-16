--[[--
TVPaint Build Comp - v1 2025-11-16 07.33 PM

Auto-build a comp node-graph based upon the active TVPaintLoader node selection.

## Controls:

The "addNode" control allows you to choose if you want to insert a Loader or TVPaintLayer node.

The "mergeLoaders" control allows you to choose if you want to insert a MultiMerge or LifeSaver node.

The "missingFrames" control defines how should missing frames be handled with Loader nodes

The "baseImageFolder" control defines where the image layer folders are in relation to the active composite. This setting fills in the value used by the TVPaintLinkImage node.

The "adjustRenderRange" control sets the RenderEnd range to match the TVPaint image count.

The "autoNameLayers" control is used to name each layer in the MultiMerge node

The "showTiles" control is used if source tiles enabled in the flow

The "alphaGain" control can be used to enable alpha compositing for each layer in the MultiMerge node

The "reverseLayerOrder" control allows you to flip the layer sort order when the TVPaintLinkImage nodes are added to the comp, and they are then connected to the MultiMerge node.

The "skipShowingUI" control allows you to avoid displaying the UI Manager window. This improves compatibility of the script with Resolve Free v19.1-20.2+.

--]]--

adjustRenderRange = true

-- TVPaintLinkImage Options
baseImageFolder = "Comp:/"
reverseLayerOrder = false

-- MultiMerge Options
autoNameLayers = true
alphaGain = false

-- Should a TVPaintBackground node be added
addBackground = false

-- Should the UI Manager window be skipped
skipShowingUI = false

-- Should the nodes be built horizontal or vertical
direction = 1

-- Should the a Loader or TVPaint Layer node be used
addNode = 1

-- Are source tiles enabled in the flow
showTiles = false

-- Should a LifeSaver or MultiMerge node be used
mergeLoaders = 1

-- How should missing frames be handled with Loader nodes
missingFrames = 1

-- The cancel button was pressed
cancelScript = false

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

function AskForInput()
	direction = getPreferenceData("TVPaint.direction", 1, verbose)
	addNode = getPreferenceData("TVPaint.addNode", 1, verbose)
	mergeLoaders = getPreferenceData("TVPaint.mergeLoaders", 1, verbose)
	adjustRenderRange = getPreferenceData("TVPaint.adjustRenderRange", adjustRenderRange, verbose)
	addBackground = getPreferenceData("TVPaint.addBackground", addBackground, verbose)
	autoNameLayers = getPreferenceData("TVPaint.autoNameLayers", autoNameLayers, verbose)
	alphaGain = getPreferenceData("TVPaint.alphaGain", alphaGain, verbose)
	reverseLayerOrder = getPreferenceData("TVPaint.reverseLayerOrder", reverseLayerOrder, verbose)
	showTiles = getPreferenceData("TVPaint.showTiles", showTiles, verbose)

	local ui = fu.UIManager
	local disp = bmd.UIDispatcher(ui)
	local width,height = 300,310

	win = disp:AddWindow({
		ID = "TVPaint",
		TargetID = "TVPaint",
		WindowTitle = "TVPaint Build Comp",
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
			ui:HGroup{
				Weight = 0.01,
				ui:Label{
					ID = "AddNodeLabel",
					Text = "Add Media Node",
				},
				ui:ComboBox{
					ID = "AddNode",
					Text = "Add Media Node",
				},
			},
			ui:HGroup{
				Weight = 0.01,
				ui:Label{
					ID = "MergeLoadersLabel",
					Text = "Add Output Node",
				},
				ui:ComboBox{
					ID = "MergeLoaders",
					Text = "Add Output Node",
				},
			},
			ui:HGroup{
				Weight = 0.01,
				ui:Label{
					ID = "MissingFramesLabel",
					Text = "Missing Frames",
				},
				ui:ComboBox{
					ID = "MissingFrames",
					Text = "Missing Frames",
				},
			},
			ui:CheckBox{
				ID = "AdjustRenderRange",
				Text = "Adjust Render Range",
				Checked = adjustRenderRange,
			},
			ui:CheckBox{
				ID = "AutoNameLayers",
				Text = "Auto Name Layers",
				Checked = autoNameLayers,
			},
			ui:CheckBox{
				ID = "AlphaGain",
				Text = "Alpha Gain Zero",
				Checked = alphaGain,
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
			ui:CheckBox{
				ID = "ShowTiles",
				Text = "Source Tiles Enabled",
				Checked = showTiles,
			},
			ui:HGroup{
				Weight = 0.01,
				ui:Button{
					Weight = 0.01,
					ID = "OKButton",
					Text = "Run",
				},
				ui:Button{
					Weight = 0.01,
					ID = "CancelButton",
					Text = "Cancel",
				},
			},
		},
	})

	-- The window was closed
	function win.On.TVPaint.Close(ev)
		cancelScript = true
		disp:ExitLoop()
	end

	-- Add your GUI element based event functions here:
	itm = win:GetItems()

	-- Add the items to the ComboBox menu
	itm.BuildDirection:AddItem("Vertical")
	itm.BuildDirection:AddItem("Horizontal")
	-- Restore the BuildDirection preference
	itm.BuildDirection.CurrentIndex = direction
	
	-- Add the items to the ComboBox menu
	itm.AddNode:AddItem("Using Loader")
	itm.AddNode:AddItem("Using TVPaintLayer")
	-- Restore the AddNode preference
	itm.AddNode.CurrentIndex = addNode

	-- Add the items to the ComboBox menu
	itm.MergeLoaders:AddItem("Using LifeSaver")
	itm.MergeLoaders:AddItem("Using MultiMerge")
	itm.MergeLoaders:AddItem("Using Swizzler")
	-- Restore the AddNode preference
	itm.MergeLoaders.CurrentIndex = mergeLoaders

	-- Add the items to the ComboBox menu
	itm.MissingFrames:AddItem("Fail")
	itm.MissingFrames:AddItem("Hold Prevous")
	itm.MissingFrames:AddItem("Output Color")
	itm.MissingFrames:AddItem("Wait")
	-- Restore the AddNode preference
	itm.MissingFrames.CurrentIndex = missingFrames

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

	function win.On.CancelButton.Clicked(ev)
		cancelScript = true
		disp:ExitLoop()
	end

	function win.On.OKButton.Clicked(ev)
		direction = itm.BuildDirection.CurrentIndex
		addNode = itm.AddNode.CurrentIndex
		mergeLoaders = itm.MergeLoaders.CurrentIndex
		missingFrames = itm.MissingFrames.CurrentIndex
		adjustRenderRange = itm.AdjustRenderRange.Checked
		addBackground = itm.AddBackground.Checked
		autoNameLayers = itm.AutoNameLayers.Checked
		alphaGain = itm.AlphaGain.Checked
		reverseLayerOrder = itm.ReverseLayerOrder.Checked
		showTiles = itm.ShowTiles.Checked

		setPreferenceData("TVPaint.direction", itm.BuildDirection.CurrentIndex, verbose)
		setPreferenceData("TVPaint.addNode", itm.AddNode.CurrentIndex, verbose)
		setPreferenceData("TVPaint.mergeLoaders", itm.MergeLoaders.CurrentIndex, verbose)
		setPreferenceData("TVPaint.missingFrames", itm.MissingFrames.CurrentIndex, verbose)
		setPreferenceData("TVPaint.adjustRenderRange", itm.AdjustRenderRange.Checked, verbose)
		setPreferenceData("TVPaint.addBackground", itm.AddBackground.Checked, verbose)
		setPreferenceData("TVPaint.autoNameLayers", itm.AutoNameLayers.Checked, verbose)
		setPreferenceData("TVPaint.alphaGain", itm.AlphaGain.Checked, verbose)
		setPreferenceData("TVPaint.reverseLayerOrder", itm.ReverseLayerOrder.Checked, verbose)
		setPreferenceData("TVPaint.showTiles", itm.ShowTiles.Checked, verbose)

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
				
				-- Stop running the script
				if cancelScript == true then
					return
				end
			end

			print("[Base Image Folder] ", baseImageFolder)
			print("[Auto Media Node] ", addNode)
			print("[Auto Output Node] ", mergeLoaders)
			print("[Auto Name Layers] ", autoNameLayers)
			print("[Alpha Gain Zero] ", alphaGain)
			print("[Add Background] ", addBackground)
			print("[Reverse Layer Order] ", reverseLayerOrder)
			print("[Adjust Render Range] ", adjustRenderRange)
			print("[Node Build Direction] ", direction and "Horizontal" or "Vertical")
			print("[Missing Frames] ", missingFrames)

			-- Starting node position
			local flow = comp.CurrentFrame.FlowView
			local origin_x, origin_y = flow:GetPos(selectedTool)

			-- Process ScriptVal data
			if toolType == "ScriptVal" then
				-- Start Undo
				comp:StartUndo("Build Comp")

				-- Disable the file browser dialog
				local AutoClipBrowse = app:GetPrefs('Global.UserInterface.AutoClipBrowse')
				app:SetPrefs('Global.UserInterface.AutoClipBrowse', false)

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

				-- Source Tiles
				local offsetY = 1
				if showTiles == true then
					offsetY = 3
				end

				if addNode == 0 then
					-- Loader Node
	
					-- Deselect all nodes
					comp.CurrentFrame.FlowView:Select() 

					-- Add the Background node
					if addBackground == true then
						local bg = comp:AddTool("Background", -32768, -32768)

						local x, y = flow:GetPos(bg)
						if direction == 0 then
							-- vertical build
							flow:SetPos(bg, origin_x + 2, origin_y)
						else
							-- horizontal build
							flow:SetPos(bg, origin_x + 2, origin_y)
						end

						-- Set the color
						if type(tbl) == "table" and tbl.project and tbl.project and tbl.project.clip and type(tbl.project.clip) == "table" and tbl.project.clip.bg and type(tbl.project.clip.bg) == "table" then
							bg.TopLeftRed[fu.TIME_UNDEFINED]  = tbl.project.clip.bg.red * (1 / 255)
							bg.TopLeftGreen[fu.TIME_UNDEFINED] = tbl.project.clip.bg.green * (1 / 255)
							bg.TopLeftBlue[fu.TIME_UNDEFINED] = tbl.project.clip.bg.blue * (1 / 255)
							bg.TopLeftAlpha[fu.TIME_UNDEFINED] = 1.0
						end

						-- Set the dimensions
						if type(tbl) == "table" and tbl.project and tbl.project and tbl.project.clip and type(tbl.project.clip) == "table" and tbl.project.clip.width and tbl.project.clip.height then
							bg.Width[fu.TIME_UNDEFINED] = tonumber(tbl.project.clip.width)
							bg.Height[fu.TIME_UNDEFINED] = tonumber(tbl.project.clip.height)

							-- Turn off auto sizing
							bg.UseFrameFormatSettings[fu.TIME_UNDEFINED] = 0
						end

						-- Save the Background node to a table
						table.insert(imgTbl, bg)
						
						table.insert(imgNameTbl, "bg")
					end

					for i = startLayer, endLayer, stepBy do
						-- Deselect all nodes
						comp.CurrentFrame.FlowView:Select() 

						-- Add the TVPaintLinkImage node
						local ldr = comp:AddTool("Loader", -32768, -32768)

						-- Extract the layer name
						groupTbl = get(tbl.project.clip.layers, i)
						if type(groupTbl) == "table" and groupTbl.name then
								local NewName = "layer_" .. tostring(groupTbl.name)
								ldr:SetAttrs({TOOLS_Name = NewName})

								-- Save the layer name
								table.insert(imgNameTbl, groupTbl.name)
						end

						-- Hold previous frames
						ldr.MissingFrames[fu.TIME_UNDEFINED] = missingFrames

						-- Update the Loader node filename
						local link = groupTbl.link
						local groupLinkTbl = get(link, i)
						if type(groupLinkTbl) == "table" and groupLinkTbl.file then
							local ldrFilename = tostring(baseImageFolder) .. tostring(groupLinkTbl.file)
							ldr.Clip[fu.TIME_UNDEFINED] = ldrFilename
						end

						local x, y = flow:GetPos(ldr)
						if direction == 0 then
							-- vertical build
							flow:SetPos(ldr, origin_x + 2, origin_y + (offsetY * i))
						else
							-- horizontal build
							flow:SetPos(ldr, origin_x + 2, origin_y + (offsetY * i))
						end
	
						-- Save the Loader node to a table
						table.insert(imgTbl, ldr)
					end

					-- What output node should be used?
					if mergeLoaders == 0 then
						-- Add a LifeSaver node
						
						-- Connect the TVPaintLinkImage nodes to a LifeSaver node
						local ls = comp:AddTool("Fuse.LifeSaver", origin_x + 4, origin_y)

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
					elseif mergeLoaders == 1 then
						-- Add a MultiMerge node
						-- Connect the Loader nodes to a MultiMerge node
						local mmrg = comp:AddTool("MultiMerge", -32768, -32768)
		
						-- Shift the node to the right
						local mrg_x, mrg_y = flow:GetPos(mmrg)
						if direction == 0 then
							-- vertical build
							flow:SetPos(mmrg, origin_x + 3, origin_y + offsetY)
						else
							-- horizontal build
							flow:SetPos(mmrg, origin_x + 3, origin_y + offsetY)
						end
		
						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							if k == 1 then
								-- Connect the Background Input
								mmrg:ConnectInput("Background", imgTbl[k])
								print(string.format("[%03d][Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mmrg.Name) .. ".Background"))
							else
								-- Connect the "Layer#.Foreground" Inputs
								mmrg:ConnectInput("Layer" .. (k-1)  .. ".Foreground", imgTbl[k])
								if autoNameLayers == true then
									-- mmrg["LayerName" .. (k-1)][fu.TIME_UNDEFINED] = imgTbl[k].Name
									mmrg["LayerName" .. (k-1)][fu.TIME_UNDEFINED] = imgNameTbl[k]
								end
								if alphaGain == true then
									mmrg["Layer" .. (k-1)  .. ".Gain"][fu.TIME_UNDEFINED] = 0
								end
								print(string.format("[%03d][Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mmrg.Name)  .. ".Layer" .. (k-1)  .. ".Foreground"))
							end
						end
					elseif mergeLoaders == 2 then
						-- Add a Swizzler node
						local sz = comp:AddTool("Swizzler", origin_x + 3, origin_y)
	
						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							-- Use the actual node name
							sz["LayerName" .. (k)][fu.TIME_UNDEFINED] = imgNameTbl[k]
		
							-- Connect the image Input
							sz:ConnectInput("Input" .. (k), imgTbl[k])
		
							print(string.format("[%03d][Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(sz.Name)  .. ".Input" .. (k)))
		
							-- Select the soruce
							sz["Layer" .. (k) .. ".RInput"][fu.TIME_UNDEFINED] = k
		
							-- Add a new image input to the node
							if k <= #imgTbl - 1 then
								sz.AddLayer[fu.TIME_UNDEFINED] = 1
							end
						end
					end
				else
					-- TVPaint Layer Node
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
							flow:SetPos(bg, origin_x + 1, y + offsetY)
						end
	
						-- Save the TVPainTVPaintBackgroundtLinkImage node to a table
						table.insert(imgTbl, bg)
						
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
							flow:SetPos(img, origin_x + 1, y + offsetY)
						end
	
						-- Save the TVPaintLinkImage node to a table
						table.insert(imgTbl, img)
					end
	
					-- What output node should be used?
					if mergeLoaders == 0 then
						-- Add a LifeSaver node

						-- Connect the TVPaintLinkImage nodes to a LifeSaver node
						local ls = comp:AddTool("Fuse.LifeSaver", -32768, -32768)
		
						-- Shift the node to the right
						local ls_x, ls_y = flow:GetPos(ls)
							if direction == 0 then
								-- vertical build
								flow:SetPos(ls, origin_x + 2, origin_y + offsetY)
							else
								-- horizontal build
								flow:SetPos(ls, origin_x + 2, origin_y + offsetY)
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
					else
						-- Add a MultiMerge node
						-- Connect the TVPaintLinkImage nodes to a MultiMerge node
						local mmrg = comp:AddTool("MultiMerge", -32768, -32768)
		
						-- Shift the node to the right
						local mrg_x, mrg_y = flow:GetPos(mmrg)
							if direction == 0 then
								-- vertical build
								flow:SetPos(mmrg, origin_x + 2, origin_y + offsetY)
							else
								-- horizontal build
								flow:SetPos(mmrg, origin_x + 2, origin_y + offsetY)
							end
		
						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							if k == 1 then
								-- Connect the Background Input
								mmrg:ConnectInput("Background", imgTbl[k])
								print(string.format("[%03d][Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mmrg.Name) .. ".Background"))
							else
								-- Connect the "Layer#.Foreground" Inputs
								mmrg:ConnectInput("Layer" .. (k-1)  .. ".Foreground", imgTbl[k])
								if autoNameLayers == true then
									mmrg["LayerName" .. (k-1)][fu.TIME_UNDEFINED] = imgTbl[k].Name
									-- mmrg["LayerName" .. (k-1)][fu.TIME_UNDEFINED] = imgNameTbl[k]
								end
								if alphaGain == true then
									mmrg["Layer" .. (k-1)  .. ".Gain"][fu.TIME_UNDEFINED] = 0
								end
								print(string.format("[%03d][Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mmrg.Name)  .. ".Layer" .. (k-1)  .. ".Foreground"))
							end
						end
					end
				end

				-- Re-enable the file browser dialog
				app:SetPrefs('Global.UserInterface.AutoClipBrowse', AutoClipBrowse)

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
