--[[--
TVPaint Comp Builder - v1 2025-11-18 04.58 PM

Auto-build a comp node-graph based upon the active TVPaintLoader node selection.

Usage:
1. Add a TVPaintLoader node to your Fusion comp. Use the node's (Browse) button to select a TVPaint exported .json file on your hard disk. The JSON document's filepath will be entered into the Filename field.
2. Select the TVPaintLoader node in the node graph area.
3. Launch the "Scripts > TVPaint > TVPaint Comp Builder" menu item. A dialog appears that allows you to customize the settings. Click the "Run" button to continue.
4. A TVPaint for Fusion nodegraph will be generated. Keep in mind, that a new undo state is created for you automatically so you can easily revert the changes made to your node graph.

## Controls:

The "addNode" control allows you to choose if you want to insert a Loader or TVPaint node.

The "mergeLoaders" control allows you to choose if you want to insert a MultiMerge or LifeSaver node.

The "missingFrames" control defines how should missing frames be handled with Loader nodes

The "baseImageFolder" control defines where the image layer folders are in relation to the active composite. This setting fills in the value used by the TVPaintLinkImage node.

The "exrSubFolder" control defines where the LifeSaver exported EXR images are saved to disk in relation to the TVPaint JSON file referenced media.

The "adjustRenderRange" control sets the RenderEnd range to match the TVPaint image count.

The "autoNameLayers" control is used to name each layer in the MultiMerge node

The "showTiles" control is used if source tiles enabled in the flow

The "tileColor" control is used if tile colors are enabled in the flow

The "alphaGain" control can be used to enable alpha compositing for each layer in the MultiMerge node

The "depthOffset" control can be used with Camera3D based texture projections to add multi-plane paralax between each layer.

The "reverseLayerOrder" control allows you to flip the layer sort order when the TVPaintLinkImage nodes are added to the comp, and they are then connected to the MultiMerge node.

The "skipShowingUI" control allows you to avoid displaying the UI Manager window. This improves compatibility of the script with Resolve Free v19.1-20.2+.

## Todos

3D
- ImagePlane3D size and aspect ratio from clip width/height
- Camera frustum "fit to image plane" size.

TVPaintLinkImage
- Sync Camera3D and ImagePlane3D features to match the Loader options
--]]--

adjustRenderRange = true

-- TVPaintLinkImage Options
baseImageFolder = "Comp:/"
reverseLayerOrder = false

-- MultiMerge Options
autoNameLayers = true
alphaGain = false

-- LifeSaver Options
exrSubFolder = "exr/"
-- exrSubFolder = "Render/"

-- Should a TVPaintBackground node be added
addBackground = false

-- Should the UI Manager window be skipped
skipShowingUI = false

-- Should the nodes be built horizontal or vertical
direction = 1

-- Should the a Loader or TVPaint Layer node be used
addNode = 0

-- Should textures be projected through cameras
textureProjection = 0

-- Should the 2D textures be merged before going into the 3D space
texturePreComps = 0

-- Allows Camera3D based texture projections to add multi-plane paralax between each layer.
depthOffset = 0.0

-- Are source tiles enabled in the flow
showTiles = false

-- Are tile colors enabled in the flow
tileColor = true

-- Should a LifeSaver or MultiMerge node be used
mergeLoaders = 1

-- How should missing frames be handled with Loader nodes
missingFrames = 1

-- The cancel button was pressed
cancelScript = false

-- Debugging log detail
verbose = true

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
		-- error(string.format("[Get Element] No key '%s' found in ScriptVal table", key))
		print(string.format("[Get Element] No key '%s' found in ScriptVal table", key))
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
--		if debugPrint == true then
--			if newPreference == nil then
--				print("[Reading " .. tostring(pref) .. " Preference Data] " .. "nil")
--			else
--				print("[Reading " .. tostring(pref) .. " Preference Data] " .. tostring(newPreference))
--			end
--		end
	else
		-- Force a default value into the preference & then list it
		newPreference = defaultValue

		-- Choose if you are saving the preference to the comp or to all of fusion
		-- comp:SetData(pref, defaultValue)
		fu:SetData(pref, defaultValue)

--		if debugPrint == true then
--			if newPreference == nil then
--				print("[Creating " .. tostring(pref) .. " Preference Data] " .. "nil")
--			else
--				print("[Creating ".. tostring(pref) .. " Preference Entry] " .. tostring(newPreference))
--			end
--		end
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
-- FullPathMap : The PathMap expanded original path sent to the function
-- Path : The path, without filename
-- PathMap : The PathMap expanded path, without filename
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
	seq.FullPathMap = comp:MapPath(filename)
	string.gsub(seq.FullPath, "^(.+[/\\])(.+)", function(path, name) seq.Path = path seq.FullName = name end)
	string.gsub(seq.FullPath, "^(.+[/\\])(.+)", function(path, name) seq.PathMap = comp:MapPath(path) seq.FullName = name end)
	string.gsub(seq.FullName, "^(.+)(%..+)$", function(name, ext) seq.Name = name seq.Extension = ext end)

	if not seq.Name then -- no extension?
			seq.Name = seq.FullName
	end

	string.gsub(seq.Name, "^(.-)(%d+)$", function(name, SNum) seq.CleanName = name seq.SNum = SNum end)

	if seq.SNum then
			seq.Number = tonumber(seq.SNum)
			seq.Padding = string.len(seq.SNum)
	else
			 seq.SNum = ""
			 seq.CleanName = seq.Name
	end

	if seq.Extension == nil then seq.Extension = "" end
	seq.UNC = (string.sub(seq.Path, 1, 2) == [[\\]])

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
	direction = getPreferenceData("TVPaint.direction", direction, verbose)
	addNode = getPreferenceData("TVPaint.addNode", addNode, verbose)
	mergeLoaders = getPreferenceData("TVPaint.mergeLoaders", mergeLoaders, verbose)
	adjustRenderRange = getPreferenceData("TVPaint.adjustRenderRange", adjustRenderRange, verbose)
	addBackground = getPreferenceData("TVPaint.addBackground", addBackground, verbose)
	autoNameLayers = getPreferenceData("TVPaint.autoNameLayers", autoNameLayers, verbose)
	alphaGain = getPreferenceData("TVPaint.alphaGain", alphaGain, verbose)
	reverseLayerOrder = getPreferenceData("TVPaint.reverseLayerOrder", reverseLayerOrder, verbose)
	showTiles = getPreferenceData("TVPaint.showTiles", showTiles, verbose)
	tileColor = getPreferenceData("TVPaint.tileColor", tileColor, verbose)
	textureProjection = getPreferenceData("TVPaint.textureProjection", textureProjection, verbose)
	texturePreComps = getPreferenceData("TVPaint.texturePreComps", texturePreComps, verbose)
	depthOffset = getPreferenceData("TVPaint.depthOffset", depthOffset, verbose)
	verbose = getPreferenceData("TVPaint.verbose", verbose, verbose)

	local ui = fu.UIManager
	local disp = bmd.UIDispatcher(ui)
	local width,height = 300,330

	win = disp:AddWindow({
		ID = "TVPaint",
		TargetID = "TVPaint",
		WindowTitle = "TVPaint Comp Builder",
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
					Text = "Merge Loaders",
				},
				ui:ComboBox{
					ID = "MergeLoaders",
					Text = "Merge Loaders",
				},
			},
			ui:HGroup{
				Weight = 0.01,
				ui:Label{
					ID = "TextureProjectionLabel",
					Text = "Texture Projection",
				},
				ui:ComboBox{
					ID = "TextureProjection",
					Text = "Texture Projection",
				},
			},
			ui:HGroup{
				Weight = 0.01,
				ui:Label{
					ID = "TexturePreCompsLabel",
					Text = "Texture PreComps",
				},
				ui:ComboBox{
					ID = "TexturePreComps",
					Text = "Texture PreComps",
				},
			},
			ui:HGroup{
				Weight = 0.01,
				ui:Label{
					ID = "DepthOffsetLabel",
					Text = "Texture Depth Offset",
				},
				ui:DoubleSpinBox{
					ID = "DepthOffset",
					Text = "Texture Depth Offset",
					Value = depthOffset,
					Minimum = 0.0,
					Maximum = 100.0,
					Decimals = 4,
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
			ui:HGroup{
				Weight = 0.5,
				ui:VGroup{
					Weight = 0.25,
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
						ID = "TileColor",
						Text = "Tile Color",
						Checked = tileColor,
					},
					ui:CheckBox{
						ID = "ShowTiles",
						Text = "Source Tiles Enabled",
						Checked = showTiles,
					},
				},
				ui:VGroup{
					Weight = 0.25,
					ui:CheckBox{
						ID = "AddBackground",
						Text = "Add Background",
						Checked = addBackground,
					},
					ui:CheckBox{
						ID = "AlphaGain",
						Text = "Alpha Gain Zero",
						Checked = alphaGain,
					},
					ui:CheckBox{
						ID = "ReverseLayerOrder",
						Text = "Reverse Layer Order",
						Checked = reverseLayerOrder,
					},
					ui:CheckBox{
						ID = "Verbose",
						Text = "Verbose",
						Checked = verbose,
					},
				},
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
	-- Restore the preference
	itm.BuildDirection.CurrentIndex = direction

	-- Add the items to the ComboBox menu
	itm.AddNode:AddItem("Using Loader")
	itm.AddNode:AddItem("Using TVPaint")
	-- Restore the preference
	itm.AddNode.CurrentIndex = addNode

	-- Add the items to the ComboBox menu
	itm.MergeLoaders:AddItem("Using LifeSaver")
	itm.MergeLoaders:AddItem("Using MultiMerge")
	itm.MergeLoaders:AddItem("Using Merge")
	itm.MergeLoaders:AddItem("Using Merge3D")
	itm.MergeLoaders:AddItem("Using Swizzler")
	-- Restore the preference
	itm.MergeLoaders.CurrentIndex = mergeLoaders

	-- Add the items to the ComboBox menu
	itm.TextureProjection:AddItem("Camera3D")
	itm.TextureProjection:AddItem("ImagePlane3D")
	-- Restore the preference
	itm.TextureProjection.CurrentIndex = textureProjection

	-- Add the items to the ComboBox menu
	itm.TexturePreComps:AddItem("Skip")
	itm.TexturePreComps:AddItem("MultiMerge")
	itm.TexturePreComps:AddItem("Merge")
	-- Restore the preference
	itm.TexturePreComps.CurrentIndex = texturePreComps

	-- Add the items to the ComboBox menu
	itm.MissingFrames:AddItem("Fail")
	itm.MissingFrames:AddItem("Hold Previous")
	itm.MissingFrames:AddItem("Output Color")
	itm.MissingFrames:AddItem("Wait")
	-- Restore the preference
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
		tileColor = itm.TileColor.Checked
		textureProjection = itm.TextureProjection.CurrentIndex
		texturePreComps = itm.TexturePreComps.CurrentIndex
		depthOffset = itm.DepthOffset.Value
		verbose = itm.Verbose.Checked

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
		setPreferenceData("TVPaint.tileColor", itm.TileColor.Checked, verbose)
		setPreferenceData("TVPaint.textureProjection", itm.TextureProjection.CurrentIndex, verbose)
		setPreferenceData("TVPaint.texturePreComps", itm.TexturePreComps.CurrentIndex, verbose)
		setPreferenceData("TVPaint.depthOffset", itm.DepthOffset.Value, verbose)
		setPreferenceData("TVPaint.verbose", itm.Verbose.Checked, verbose)

		disp:ExitLoop()
	end

	win:Show()
	disp:RunLoop()
	win:Hide()
end


function Main()
	print("[TVPaint] Comp Builder Script")

	-- Read the node selection
	local selectedTool = comp.ActiveTool
	if selectedTool then
		-- Check the node attributes
		toolAttrs = selectedTool:GetAttrs()
		nodeType = toolAttrs.TOOLS_RegID
		-- Check the selected node's output type
		toolOutput = selectedTool:FindMainOutput(1)
		if toolOutput ~= nil then
			toolType = toolOutput:GetAttrs().OUTS_DataType

			-- Starting node position
			local flow = comp.CurrentFrame.FlowView
			local origin_x, origin_y = flow:GetPos(selectedTool)
	
			-- Process ScriptVal data
			if toolType == "ScriptVal" and nodeType == "Fuse.TVPaintLoader" then
				-- Name the EXR
				local baseJSONFilename = selectedTool["Filename"][fu.TIME_UNDEFINED]
				
				if baseJSONFilename == "" then
					error("[Error][TVPaintLoader] Please enter a JSON filename in the TVPaintLoader node.")
				end
				if not bmd.fileexists(comp:MapPath(baseJSONFilename)) then
					error("[Error][TVPaintLoader] The selected TVPaint .json file does not exist on disk: " .. tostring(baseJSONFilename))
				end
	
				if skipShowingUI == false then
					AskForInput()
	
					-- Stop running the script
					if cancelScript == true then
						return
					end
				end
	
				if verbose == true then
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
					print("[Tile Color] ", tileColor)
					print("[Texture Projection] ", textureProjection)
					print("[Texture Pre-Comps] ", texturePreComps)
					print("[Depth Offset] ", depthOffset)
				end

				-- Start Undo
				comp:StartUndo("TVPaint Comp Builder")

				-- Disable the file browser dialog
				local AutoClipBrowse = app:GetPrefs("Global.UserInterface.AutoClipBrowse")
				app:SetPrefs("Global.UserInterface.AutoClipBrowse", false)

				-- Lock the comp flow area
				comp:Lock()

				local imgTbl = {}
				local imgNameTbl = {}

				local tbl = {}
				tbl = selectedTool["ScriptVal"][comp.CurrentTime] or {}

				-- Get the TVPaint .json file defined image path
				baseImageFolder = tostring(parseFilename(baseJSONFilename).PathMap)
				if verbose == true then
					print("[Base JSON Filepath] ", baseJSONFilename)
					print("[Revised Base Image Folder] ", baseImageFolder)
				end

				-- Extract the number of clip layers
				local layer_max = 0
				if type(tbl) == "table" and tbl.project and tbl.project.clip and tbl.project.clip.layers and type(tbl.project.clip.layers) == "table" then
					layer_max = tonumber(table.getn(tbl.project.clip.layers)) - 2
				end

				-- Image count
				if adjustRenderRange == true and type(tbl) == "table" and tbl.project and tbl.project.clip and tbl.project.clip["image-count"] then
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

				local offsetX = 2
				local bg

				-- Shift the nodes to compensate for the 2D texture precomp nodes
				local preCompOffset = 0
				if texturePreComps == 1 then
					preCompOffset = 4
				end

				if addNode == 0 then
					-- Loader Node
					-- Deselect all nodes
					comp.CurrentFrame.FlowView:Select() 

					-- Add the Background node
					if addBackground == true then
						if direction == 0 then
							-- Build vertical
							if mergeLoaders == 2 or mergeLoaders == 3 then
								-- Add a Background node to the final Merge node in the heap
								local c = layer_max + 1
								bg = comp:AddTool("Background", origin_x + 2, origin_y + (offsetY * (c - 1)))
							else
								bg = comp:AddTool("Background", origin_x + 2, origin_y + (offsetY * (0 - 1)))
							end
						else
							-- Build horizontal
							if mergeLoaders == 2 or mergeLoaders == 3 then
								-- Add a Background node to the final Merge node in the heap
								local c = layer_max + 1
								bg = comp:AddTool("Background", origin_x + (offsetX * (c - 1)), origin_y + 2)
							else
								bg = comp:AddTool("Background", origin_x + (offsetX * (0 - 1)), origin_y + 2)
							end
						end

						-- Set the color
						if type(tbl) == "table" and tbl.project and tbl.project.clip and type(tbl.project.clip) == "table" and tbl.project.clip.bg and type(tbl.project.clip.bg) == "table" then
							bg.TopLeftRed[fu.TIME_UNDEFINED]  = tbl.project.clip.bg.red * (1 / 255)
							bg.TopLeftGreen[fu.TIME_UNDEFINED] = tbl.project.clip.bg.green * (1 / 255)
							bg.TopLeftBlue[fu.TIME_UNDEFINED] = tbl.project.clip.bg.blue * (1 / 255)
							bg.TopLeftAlpha[fu.TIME_UNDEFINED] = 1.0
						end

						-- Set the dimensions
						if type(tbl) == "table" and tbl.project and tbl.project.clip and type(tbl.project.clip) == "table" and tbl.project.clip.width and tbl.project.clip.height then
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

						-- Add the Loader node
						local ldr
						if direction == 0 then
							-- Build vertical
							ldr = comp:AddTool("Loader", origin_x + 2, origin_y + (offsetY * (i - 1)))
						else
							-- Build horizontal
							ldr = comp:AddTool("Loader", origin_x + (offsetX * (i - 1)), origin_y + 2)
						end

						-- Extract the layer name
						if verbose == true then print("[Clip Layers] ", i) end
						groupTbl = get(tbl.project.clip.layers, i)
						if type(groupTbl) == "table" and groupTbl.name then
								local NewName = "layer_" .. tostring(groupTbl.name)
								ldr:SetAttrs({TOOLS_Name = NewName})

								-- Save the layer name
								table.insert(imgNameTbl, groupTbl.name)
						end

						-- Tile Color
						if tileColor == true then
							if type(groupTbl) == "table" and groupTbl.group and type(groupTbl.group) == "table" then
								local tileR = groupTbl.group.red
								local tileG = groupTbl.group.green
								local tileB = groupTbl.group.blue
								ldr.TileColor = {R = tileR, G = tileG, B = tileB}
							end
						end

						-- Hold previous frames
						ldr.MissingFrames[fu.TIME_UNDEFINED] = missingFrames

						-- Update the Loader node filename
						local link = groupTbl.link
						local link_min = 0
						if #groupTbl.link >= 1 then
							link_min = 1
							if verbose == true then print("[Clip Link] ", link_min) end
							local groupLinkTbl = get(link, link_min)
							if type(groupLinkTbl) == "table" and groupLinkTbl.file then
								local ldrFilename = tostring(baseImageFolder) .. tostring(groupLinkTbl.file)
								ldr.Clip[fu.TIME_UNDEFINED] = ldrFilename
							end
						end

						-- Save the Loader node to a table
						table.insert(imgTbl, ldr)
					end

					-- When adding Merge or Merge3D nodes sort the image table
					if mergeLoaders == 2 or mergeLoaders == 3 then
						if direction == 0 then
							-- Build vertical
							-- Sort using the vertical position
							table.sort(imgTbl, function(a,b) return select(2, comp.CurrentFrame.FlowView:GetPos(a)) < select(2, comp.CurrentFrame.FlowView:GetPos(b)) end)
						else
							-- Build horizontal
							-- Sort using the horizontal position
							table.sort(imgTbl, function(a,b) return select(1, comp.CurrentFrame.FlowView:GetPos(a)) < select(1, comp.CurrentFrame.FlowView:GetPos(b)) end)
						end
					end

					-- What output node should be used?
					if mergeLoaders == 0 then
						-- Add a LifeSaver node

						-- Connect the TVPaintLinkImage nodes to a LifeSaver node
						local ls
						if direction == 0 then
							-- Build vertical
							ls = comp:AddTool("Fuse.LifeSaver", origin_x + 4, origin_y)
						else
							-- Build horizontal
							ls = comp:AddTool("Fuse.LifeSaver", origin_x, origin_y + 5)
						end

						ls["Filename"][fu.TIME_UNDEFINED] = tostring(baseImageFolder) .. tostring(exrSubFolder) .. tostring(parseFilename(baseJSONFilename).Name) .. "_${VERSION}.0000.exr"

						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							-- Use the actual TVPaint layer name
							ls["Name" .. (k)][fu.TIME_UNDEFINED] = imgNameTbl[k]

							-- Connect the image Input
							ls:ConnectInput("Input" .. (k), imgTbl[k])

							print(string.format("[%03d][LifeSaver Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(ls.Name)  .. ".Name" .. (k)))

							-- Add a new image input to the node
							if k <= #imgTbl - 1 then
								ls.AddOutput[fu.TIME_UNDEFINED] = 1
							end
						end
					elseif mergeLoaders == 1 then
						-- Add a MultiMerge node
						-- Connect the Loader nodes to a MultiMerge node
						local mmrg
						if direction == 0 then
							-- Build vertical
							mmrg = comp:AddTool("MultiMerge", origin_x + 4, origin_y)
						else
							-- Build horizontal
							mmrg = comp:AddTool("MultiMerge", origin_x, origin_y + 5)
						end

						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							if k == 1 then
								-- Connect the Background Input
								mmrg:ConnectInput("Background", imgTbl[k])
								print(string.format("[%03d][MultiMerge Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mmrg.Name) .. ".Background"))
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
								print(string.format("[%03d][MultiMerge Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mmrg.Name)  .. ".Layer" .. (k-1)  .. ".Foreground"))
							end
						end
					elseif mergeLoaders == 2 then
						-- Add a Merge node
						local mrgTbl = {}

						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							-- Y axis shift value
							local kStepBy = 1
							if addBackground == false then
								kStepBy = 1
							end

							local mrg
							-- Control Merge node fg vs bg input ordering
							if reverseLayerOrder == false then
								-- Use the standard Merge node fb and bg input order
								if k == 1 then
									-- Do nothing
								elseif k == 2 then
									if direction == 0 then
										-- Build vertical
										mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
									else
										-- Build horizontal
										mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - kStepBy)), origin_y + 5)
									end
									mrg:ConnectInput("Foreground", imgTbl[k-1])
									mrg:ConnectInput("Background", imgTbl[k])
								else
									if direction == 0 then
										-- Build vertical
										mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
									else
										-- Build horizontal
										mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - kStepBy)), origin_y + 5)
									end
									mrg:ConnectInput("Foreground", mrgTbl[#mrgTbl])
									mrg:ConnectInput("Background", imgTbl[k])
								end
							else
								-- flip the Merge node fb and bg input order
								if k == 1 then
									-- Do nothing
								elseif k == 2 then
									if direction == 0 then
										-- Build vertical
										mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
									else
										-- Build horizontal
										mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - kStepBy)), origin_y + 5)
									end
									mrg:ConnectInput("Foreground", imgTbl[k])
									mrg:ConnectInput("Background", imgTbl[k-1])
								else
									if direction == 0 then
										-- Build vertical
										mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
									else
										-- Build horizontal
										mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - kStepBy)), origin_y + 5)
									end
									mrg:ConnectInput("Foreground", imgTbl[k])
									mrg:ConnectInput("Background", mrgTbl[#mrgTbl])
								end
							end

							if mrg then
								if alphaGain == true then
									mrg["Gain"][fu.TIME_UNDEFINED] = 0
								end

								print(string.format("[%03d][Merge Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mrg.Name)  .. ".Input" .. (k)))

								table.insert(mrgTbl, mrg)
							end
						end
					elseif mergeLoaders == 3 then
						-- Add Merge3D nodes
						local img3DTbl = {}
						local mrgTbl = {}
						local cam3D
						local mmrg

						-- Y axis shift value
						local kStepBy = 1
						if addBackground == false then
							kStepBy = 1
						end

						if texturePreComps == 0 then
							-- Skip
						elseif texturePreComps == 1 then
							-- MultiMerge
							preCompOffset = 4

							-- Add a MultiMerge node
							-- Connect the Loader nodes to a MultiMerge node
							if direction == 0 then
								-- Build vertical
								mmrg = comp:AddTool("MultiMerge", origin_x + 4, origin_y)
							else
								-- Build horizontal
								mmrg = comp:AddTool("MultiMerge", origin_x , origin_y + 7)
							end

							-- Adjust the layer connection ordering
							local reversedImgTbl =  {}
							local reversedImgNameTbl = {}

							-- Add the bg element as the base layer
							if addBackground == true then
								table.insert(reversedImgTbl, bg)
								table.insert(reversedImgNameTbl, "bg")
							end

							-- Flip the read order for the images table
							for i = #imgTbl, 1, -1 do
								-- Remove the pre-existing bg node
								if imgTbl[i] ~= bg then
									table.insert(reversedImgTbl, imgTbl[i])
									table.insert(reversedImgNameTbl, imgNameTbl[i])
								end
							end
							-- dump("[Image Layer Name]")
							-- dump(reversedImgNameTbl)

							-- Connect the inputs
							-- for k, v in pairs(imgTbl) do
							for k, v in pairs(reversedImgTbl) do
								if k == 1 then
									-- Connect the Background Input
									mmrg:ConnectInput("Background", reversedImgTbl[k])
									print(string.format("[%03d][MultiMerge Connection] %30s -> %s", k, tostring(reversedImgTbl[k].Name), tostring(mmrg.Name) .. ".Background"))
								else
									-- Connect the "Layer#.Foreground" Inputs
									mmrg:ConnectInput("Layer" .. (k-1)  .. ".Foreground", reversedImgTbl[k])
									if autoNameLayers == true then
										mmrg["LayerName" .. (k-1)][fu.TIME_UNDEFINED] = reversedImgNameTbl[k]
									end
									if alphaGain == true then
										mmrg["Layer" .. (k-1)  .. ".Gain"][fu.TIME_UNDEFINED] = 0
									end
									print(string.format("[%03d][MultiMerge Connection] %30s -> %s", k, tostring(reversedImgTbl[k].Name), tostring(mmrg.Name)  .. ".Layer" .. (k-1)  .. ".Foreground"))
								end
							end
						elseif texturePreComps == 2 then
							-- Merge
							preCompOffset = 4

							-- Add a Merge2D node
							-- Connect the inputs
							for k, v in pairs(imgTbl) do
								local mrg
								-- Control Merge node fg vs bg input ordering
								if reverseLayerOrder == true then
									-- flip the Merge node fb and bg input order
									if k == 1 then
										-- Do nothing
										if verbose == true then print("[Merge2D] Flipped FG and BG Input ordering") end
									elseif k == 2 then
										if direction == 0 then
											-- Build vertical
											mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
										else
											-- Build horizontal
											mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - 1 - kStepBy)) + offsetX, origin_y + 5)
										end
										mrg:ConnectInput("Foreground", imgTbl[k-1])
										mrg:ConnectInput("Background", imgTbl[k])
									else
										if direction == 0 then
											-- Build vertical
											mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
										else
											-- Build horizontal
											mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - 1 - kStepBy)) + offsetX, origin_y + 5)
										end
										mrg:ConnectInput("Foreground", mrgTbl[#mrgTbl])
										mrg:ConnectInput("Background", imgTbl[k])
									end
								else
									-- Use the standard Merge node fg and bg input order
									if k == 1 then
										-- Do nothing
										if verbose == true then print("[Merge2D] Standard FG and BG Input ordering") end
									elseif k == 2 then
										if direction == 0 then
											-- Build vertical
											mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
										else
											-- Build horizontal
											mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - 1 - kStepBy)) + offsetX, origin_y + 5)
										end
										--mrg:ConnectInput("Foreground", imgTbl[k])
										--mrg:ConnectInput("Background", imgTbl[k-1])
										mrg:ConnectInput("Background", imgTbl[k])
										mrg:ConnectInput("Foreground", imgTbl[k-1])
									else
										if direction == 0 then
											-- Build vertical
											mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
										else
											-- Build horizontal
											mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - 1 - kStepBy)) + offsetX, origin_y + 5)
										end
										--mrg:ConnectInput("Foreground", imgTbl[k])
										--mrg:ConnectInput("Background", mrgTbl[#mrgTbl])
										mrg:ConnectInput("Background", imgTbl[k])
										mrg:ConnectInput("Foreground", mrgTbl[#mrgTbl])
									end
								end
								if mrg then
									if alphaGain == true then
										mrg["Gain"][fu.TIME_UNDEFINED] = 0
									end

									print(string.format("[%03d][Merge2D Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mrg.Name)  .. ".Input" .. (k)))

									table.insert(mrgTbl, mrg)
								end
							end
						end

						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							-- Add a Camera3D node
							if k == 1 then
								-- Control Camera3D node
								if direction == 0 then
									-- Build vertical
									cam3D = comp:AddTool("Camera3D", origin_x + 4 + preCompOffset, origin_y + (offsetY * (k - 1 - kStepBy)) + preCompOffset)
								else
									-- Build horizontal
									cam3D = comp:AddTool("Camera3D", origin_x + (offsetX * (k - 1 - kStepBy)) + preCompOffset, origin_y + 6 + preCompOffset)
								end

								if textureProjection == 0 then
									-- Move the camera back to fit the texture input connection
									cam3D["Transform3DOp.Translate.Z"] = 2
								else
									-- Move the camera back to fit the ImagePlane3D
									cam3D["Transform3DOp.Translate.Z"] = 1.66
								end

								-- Sneak the camera3D node into the list of ImagePlane3D nodes
								table.insert(img3DTbl, cam3D)
							end

							local img3D
							if texturePreComps == 0 or (texturePreComps >= 1 and k == 1) then
								-- If the texturePreComps "Skip" control is active add a 3D node for each element. Otherwise only add one 3D node for all the 2D merged elements
								-- Control ImagePlane3D node
								if direction == 0 then
									-- Build vertical
									if textureProjection == 0 then
										img3D = comp:AddTool("Camera3D", origin_x + 4 + preCompOffset , origin_y + (offsetY * (k - kStepBy)) + preCompOffset)

										-- Move the camera back to fit the ImagePlane3D
										img3D["Transform3DOp.Translate.Z"] = 2
									else
										img3D = comp:AddTool("ImagePlane3D", origin_x + 4 + preCompOffset , origin_y + (offsetY * (k - kStepBy)) + preCompOffset)
									end
								else
									-- Build horizontal
									if textureProjection == 0 then
										img3D = comp:AddTool("Camera3D", origin_x + (offsetX * (k - kStepBy)), origin_y + 6 + preCompOffset)

										-- Move the camera back to fit the ImagePlane3D
										img3D["Transform3DOp.Translate.Z"] = 2
									else
										img3D = comp:AddTool("ImagePlane3D", origin_x + (offsetX * (k - kStepBy)), origin_y + 6 + preCompOffset)
									end
								end

								-- Connect the inputs
								if texturePreComps == 0 then
									-- Skip mode
									if textureProjection == 0 then
										-- Camera3D Node
										img3D:ConnectInput("ImageInput", imgTbl[k])

										-- Texture Depth Offset
										img3D.IDepth = 100 + (tonumber(depthOffset) * k)
									else
										-- ImagePlane3D Node
										img3D:ConnectInput("MaterialInput", imgTbl[k])
									end

									print(string.format("[%03d][3D Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(img3D.Name)  .. ".Input" .. (k)))
								elseif texturePreComps == 1 then
									-- MultiMerge
									if textureProjection == 0 then
										-- Camera3D Node
										img3D:ConnectInput("ImageInput", mmrg)

										-- Texture Depth Offset
										img3D.IDepth = 100 + (tonumber(depthOffset) * k)
									else
										-- ImagePlane3D Node
										img3D:ConnectInput("MaterialInput", mmrg)
									end

									print(string.format("[%03d][3D Connection] %30s -> %s", k, tostring(mmrg.Name), tostring(img3D.Name)  .. ".Input" .. (k)))
								elseif texturePreComps == 2 then
									-- Merge2D mode
									if #mrgTbl and #mrgTbl >= 1 then
										if textureProjection == 0 then
											-- Camera3D Node
											img3D:ConnectInput("ImageInput", mrgTbl[#mrgTbl])

											-- Texture Depth Offset
											img3D.IDepth = 100 + (tonumber(depthOffset) * k)
										else
											-- ImagePlane3D Node
											img3D:ConnectInput("MaterialInput", mrgTbl[#mrgTbl])
										end
										print(string.format("[%03d][3D Connection] %30s -> %s", k, tostring(mrgTbl[#mrgTbl].Name), tostring(img3D.Name)  .. ".Input" .. (k)))
									end
								end

								table.insert(img3DTbl, img3D)
							end
						end

						local mrg3D
						if direction == 0 then
							-- Build vertical
							mrg3D = comp:AddTool("Merge3D", origin_x + 7 + preCompOffset, origin_y + offsetY)
						else
							-- Build horizontal
							mrg3D = comp:AddTool("Merge3D", origin_x, origin_y + 10 + preCompOffset)
						end

						-- Connect the inputs
						for k,v in pairs(img3DTbl) do
							-- Connect the inputs
							mrg3D:ConnectInput("SceneInput" .. (k), img3DTbl[k])
						end

						local rnd3D
						if direction == 0 then
							-- Build vertical
							rnd3D = comp:AddTool("Renderer3D", origin_x + 9 + preCompOffset, origin_y + offsetY)
						else
							-- Build horizontal
							rnd3D = comp:AddTool("Renderer3D", origin_x, origin_y + 12 + preCompOffset)
						end

						-- Connect the inputs
						rnd3D:ConnectInput("SceneInput", mrg3D)

						-- Enable hardware rendering
						rnd3D.RendererType = "RendererOpenGL"

						-- Set the dimensions
						if type(tbl) == "table" and tbl.project and tbl.project.camera and type(tbl.project.camera) == "table" and tbl.project.camera.width and tbl.project.camera.height then
							rnd3D.Width[fu.TIME_UNDEFINED] = tonumber(tbl.project.camera.width)
							rnd3D.Height[fu.TIME_UNDEFINED] = tonumber(tbl.project.camera.height)

							if tbl.project.camera.pixelaspectratio then
								rnd3D.PixelAspect[fu.TIME_UNDEFINED] = {tonumber(tbl.project.camera.pixelaspectratio), 1}
							end

							-- Turn off auto sizing
							rnd3D.UseFrameFormatSettings[fu.TIME_UNDEFINED] = 0
						end

						-- Select the camera
						if cam3D and cam3D.Name then
							rnd3D.CameraSelector = tostring(cam3D.Name)
						end
					elseif mergeLoaders == 4 then
						-- Add a Swizzler node
						local sz
						if direction == 0 then
							-- Build vertical
							sz = comp:AddTool("Swizzler", origin_x + 4, origin_y)
						else
							-- Build horizontal
							sz = comp:AddTool("Swizzler", origin_x, origin_y + 5)
						end

						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							-- Use the actual node name
							sz["LayerName" .. (k)][fu.TIME_UNDEFINED] = imgNameTbl[k]

							-- Connect the image Input
							sz:ConnectInput("Input" .. (k), imgTbl[k])

							print(string.format("[%03d][Swizzler Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(sz.Name)  .. ".Input" .. (k)))

							-- Select the source
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
						if mergeLoaders == 2 then
							-- Add a Background node to the final Merge node in the heap
							local c = layer_max + 1
							if direction == 0 then
								-- Build vertical
								bg = comp:AddTool("Fuse.TVPaintBackground", origin_x + 2, origin_y + (offsetY * (c - 1)))
							else
								-- Build horizontal
								bg = comp:AddTool("Fuse.TVPaintBackground", origin_x + (offsetX * (c - 1)), origin_y + 2)
							end
						else
							if direction == 0 then
								-- Build vertical
								bg = comp:AddTool("Fuse.TVPaintBackground", origin_x + 2, origin_y + (offsetY * (0 - 1)))
							else
								-- Build horizontal
								bg = comp:AddTool("Fuse.TVPaintBackground", origin_x + (offsetX * (0 - 1)), origin_y + 2)
							end
						end

						-- Connect the inputs
						bg:ConnectInput("ScriptVal", selectedTool)

						-- Save the TVPainTVPaintBackgroundtLinkImage node to a table
						table.insert(imgTbl, bg)

						table.insert(imgNameTbl, "bg")
					end

					for i = startLayer, endLayer, stepBy do
						-- Add the TVPaintLinkImage node
						local img
						if direction == 0 then
							-- Build vertical
							img = comp:AddTool("Fuse.TVPaintLinkImage", origin_x + 2, origin_y + (offsetY * (i - 1)))
						else
							-- Build horizontal
							img = comp:AddTool("Fuse.TVPaintLinkImage", origin_x + (offsetX * (i - 1)), origin_y + 2)
						end
						-- Connect the inputs
						img:ConnectInput("ScriptVal", selectedTool)

						-- Time control
						img.TimeMode = 2

						-- Increment the Layer value
						img.Layer = tonumber(i)

						-- Working folder for TVPaint images
						img.BaseFolder = tostring(baseImageFolder)

						-- Extract the layer name
						if verbose == true then print("[Clip Layers] ", i) end
						groupTbl = get(tbl.project.clip.layers, i)
						if type(groupTbl) == "table" and groupTbl.name then
								local NewName = "layer_" .. tostring(groupTbl.name)
								img:SetAttrs({TOOLS_Name = NewName})

								-- Save the layer name
								table.insert(imgNameTbl, groupTbl.name)
						end

						-- Tile Color
						if tileColor == true then
							if type(groupTbl) == "table" and groupTbl.group and type(groupTbl.group) == "table" then
								local tileR = groupTbl.group.red
								local tileG = groupTbl.group.green
								local tileB = groupTbl.group.blue
								img.TileColor = {R = tileR, G = tileG, B = tileB}
							end
						end

						-- Save the TVPaintLinkImage node to a table
						table.insert(imgTbl, img)
					end

					-- When adding Merge or Merge3D nodes sort the image table
					if mergeLoaders == 2 or mergeLoaders == 3 then
						if direction == 0 then
							-- Build vertical
							-- Sort using the vertical position
							table.sort(imgTbl, function(a,b) return select(2, comp.CurrentFrame.FlowView:GetPos(a)) < select(2, comp.CurrentFrame.FlowView:GetPos(b)) end)
						else
							-- Build horizontal
							-- Sort using the horizontal position
							table.sort(imgTbl, function(a,b) return select(1, comp.CurrentFrame.FlowView:GetPos(a)) < select(1, comp.CurrentFrame.FlowView:GetPos(b)) end)
						end
					end

					-- What output node should be used?
					if mergeLoaders == 0 then
						-- Add a LifeSaver node

						-- Connect the TVPaintLinkImage nodes to a LifeSaver node
						local ls
						if direction == 0 then
							-- Build vertical
							ls = comp:AddTool("Fuse.LifeSaver", origin_x + 4, origin_y)
						else
							-- Build horizontal
							ls = comp:AddTool("Fuse.LifeSaver", origin_x, origin_y + 5)
						end

						-- Name the EXR
						local baseJSONFilename = selectedTool["Filename"][fu.TIME_UNDEFINED]
						ls["Filename"][fu.TIME_UNDEFINED] = tostring(baseImageFolder) .. tostring(exrSubFolder) .. tostring(parseFilename(baseJSONFilename).Name) .. "_${VERSION}.0000.exr"

						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							-- Use the actual TVPaint layer name
							ls["Name" .. (k)][fu.TIME_UNDEFINED] = imgNameTbl[k]

							-- Connect the image Input
							ls:ConnectInput("Input" .. (k), imgTbl[k])

							print(string.format("[%03d][LifeSaver Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(ls.Name)  .. ".Name" .. (k)))

							-- Add a new image input to the node
							if k <= #imgTbl - 1 then
								ls.AddOutput[fu.TIME_UNDEFINED] = 1
							end
						end
					elseif mergeLoaders == 1 then
						-- Add a MultiMerge node
						-- Connect the TVPaintLinkImage nodes to a MultiMerge node
						local mmrg
						if direction == 0 then
							-- Build vertical
							mmrg = comp:AddTool("MultiMerge", origin_x + 4, origin_y)
						else
							-- Build horizontal
							mmrg = comp:AddTool("MultiMerge", origin_x, origin_y + 5)
						end
						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							if k == 1 then
								-- Connect the Background Input
								mmrg:ConnectInput("Background", imgTbl[k])
								print(string.format("[%03d][MultiMerge Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mmrg.Name) .. ".Background"))
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
								print(string.format("[%03d][MultiMerge Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mmrg.Name)  .. ".Layer" .. (k-1)  .. ".Foreground"))
							end
						end
					elseif mergeLoaders == 2 then
						-- Add a Merge node
						local mrgTbl = {}

						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							-- Y axis shift value
							local kStepBy = 1
							if addBackground == false then
								kStepBy = 1
							end

							local mrg
							-- Control Merge node fg vs bg input ordering
							if reverseLayerOrder == false then
								-- Use the standard Merge node fb and bg input order
								if k == 1 then
									-- Do nothing
								elseif k == 2 then
									if direction == 0 then
										-- Build vertical
										mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
									else
										-- Build horizontal
										mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - kStepBy)), origin_y + 5)
									end
									mrg:ConnectInput("Foreground", imgTbl[k-1])
									mrg:ConnectInput("Background", imgTbl[k])
								else
									if direction == 0 then
										-- Build vertical
										mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
									else
										-- Build horizontal
										mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - kStepBy)), origin_y + 5)
									end
									mrg:ConnectInput("Foreground", mrgTbl[#mrgTbl])
									mrg:ConnectInput("Background", imgTbl[k])
								end
							else
								-- flip the Merge node fb and bg input order
								if k == 1 then
									-- Do nothing
								elseif k == 2 then
									if direction == 0 then
										-- Build vertical
										mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
									else
										-- Build horizontal
										mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - kStepBy)), origin_y + 5)
									end
									mrg:ConnectInput("Foreground", imgTbl[k])
									mrg:ConnectInput("Background", imgTbl[k-1])
								else
									if direction == 0 then
										-- Build vertical
										mrg = comp:AddTool("Merge", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
									else
										-- Build horizontal
										mrg = comp:AddTool("Merge", origin_x + (offsetX * (k - kStepBy)), origin_y + 5)
									end
									mrg:ConnectInput("Foreground", imgTbl[k])
									mrg:ConnectInput("Background", mrgTbl[#mrgTbl])
								end
							end

							if mrg then
								if alphaGain == true then
									mrg["Gain"][fu.TIME_UNDEFINED] = 0
								end

								print(string.format("[%03d][Merge2D Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mrg.Name)  .. ".Input" .. (k)))

								table.insert(mrgTbl, mrg)
							end
						end
					elseif mergeLoaders == 3 then
						-- Add Merge3D nodes
						local img3DTbl = {}
						local tex2DTbl = {}
						local cam3D

						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							-- Y axis shift value
							local kStepBy = 1
							if addBackground == false then
								kStepBy = 1
							end

							-- Add a Texture2D to avoid fuse graphics from crashing a 3D surface material node
							local tex2D
							if direction == 0 then
								-- Build vertical
								tex2D = comp:AddTool("Texture2DOperator", origin_x + 4, origin_y + (offsetY * (k - kStepBy)))
							else
								-- Build horizontal
								tex2D = comp:AddTool("Texture2DOperator", origin_x + (offsetX * (k - kStepBy)), origin_y + 6)
							end

							-- Connect the inputs
							tex2D:ConnectInput("Input", imgTbl[k])

							table.insert(tex2DTbl, tex2D)

							-- Add a Camera3D node
							if k == 1 then
								-- Control Camera3D node
								if direction == 0 then
									-- Build vertical
									cam3D = comp:AddTool("Camera3D", origin_x + 6, origin_y + (offsetY * (k - 1 - kStepBy)))
								else
									-- Build horizontal
									cam3D = comp:AddTool("Camera3D", origin_x + (offsetX * (k - 1 - kStepBy)), origin_y + 8)
								end

								if textureProjection == 0 then
									-- Move the camera back to fit the texture input connection
									cam3D["Transform3DOp.Translate.Z"] = 2
								else
									-- Move the camera back to fit the ImagePlane3D
									cam3D["Transform3DOp.Translate.Z"] = 1.66
								end

								-- Sneak the camera3D node into the list of ImagePlane3D nodes
								table.insert(img3DTbl, cam3D)
							end

							local img3D
							-- Control ImagePlane3D node
							if direction == 0 then
								-- Build vertical
								if textureProjection == 0 then
									img3D = comp:AddTool("Camera3D", origin_x + 6, origin_y + (offsetY * (k - kStepBy)))
								else
									img3D = comp:AddTool("ImagePlane3D", origin_x + 6, origin_y + (offsetY * (k - kStepBy)))
								end
							else
								-- Build horizontal
								if textureProjection == 0 then
									img3D = comp:AddTool("Camera3D", origin_x + (offsetX * (k - kStepBy)), origin_y + 8)
								else
									img3D = comp:AddTool("ImagePlane3D", origin_x + (offsetX * (k - kStepBy)), origin_y + 8)
								end
							end

							-- Connect the inputs
							if textureProjection == 0 then
								img3D:ConnectInput("ImageInput", tex2DTbl[k])

								-- Texture Depth Offset
								img3D.IDepth = 100 + (tonumber(depthOffset) * k)
							else
								img3D:ConnectInput("MaterialInput", tex2DTbl[k])
							end

							print(string.format("[%03d][3D Connection] %30s -> %30s -> %s", k, tostring(imgTbl[k].Name), tostring(tex2DTbl[k].Name), tostring(img3D.Name)  .. ".Input" .. (k)))

							table.insert(img3DTbl, img3D)
						end

						local mrg3D
						if direction == 0 then
							-- Build vertical
							mrg3D = comp:AddTool("Merge3D", origin_x + 8, origin_y)
						else
							-- Build horizontal
							mrg3D = comp:AddTool("Merge3D", origin_x, origin_y + 12)
						end

						-- Connect the inputs
						for k,v in pairs(img3DTbl) do
							-- Connect the inputs
							mrg3D:ConnectInput("SceneInput" .. (k), img3DTbl[k])
						end

						local rnd3D
						if direction == 0 then
							-- Build vertical
							rnd3D = comp:AddTool("Renderer3D", origin_x + 10, origin_y)
						else
							-- Build horizontal
							rnd3D = comp:AddTool("Renderer3D", origin_x, origin_y + 14)
						end

						-- Connect the inputs
						rnd3D:ConnectInput("SceneInput", mrg3D)

						-- Enable hardware rendering
						rnd3D.RendererType = "RendererOpenGL"

						-- Set the dimensions
						if type(tbl) == "table" and tbl.project and tbl.project.camera and type(tbl.project.camera) == "table" and tbl.project.camera.width and tbl.project.camera.height then
							rnd3D.Width[fu.TIME_UNDEFINED] = tonumber(tbl.project.camera.width)
							rnd3D.Height[fu.TIME_UNDEFINED] = tonumber(tbl.project.camera.height)

							if tbl.project.camera.pixelaspectratio then
								rnd3D.PixelAspect[fu.TIME_UNDEFINED] = {tonumber(tbl.project.camera.pixelaspectratio), 1}
							end

							-- Turn off auto sizing
							rnd3D.UseFrameFormatSettings[fu.TIME_UNDEFINED] = 0
						end

						-- Select the camera
						if cam3D and cam3D.Name then
							rnd3D.CameraSelector = tostring(cam3D.Name)
						end
					elseif mergeLoaders == 4 then
						-- Add a Swizzler node
						local sz
						if direction == 0 then
							-- Build vertical
							sz = comp:AddTool("Swizzler", origin_x + 4, origin_y)
						else
							-- Build horizontal
							sz = comp:AddTool("Swizzler", origin_x, origin_y + 5)
						end

						-- Connect the inputs
						for k,v in pairs(imgTbl) do
							-- Use the actual node name
							sz["LayerName" .. (k)][fu.TIME_UNDEFINED] = imgNameTbl[k]

							-- Connect the image Input
							sz:ConnectInput("Input" .. (k), imgTbl[k])

							print(string.format("[%03d][Sizzler Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(sz.Name)  .. ".Input" .. (k)))

							-- Select the source
							sz["Layer" .. (k) .. ".RInput"][fu.TIME_UNDEFINED] = k

							-- Add a new image input to the node
							if k <= #imgTbl - 1 then
								sz.AddLayer[fu.TIME_UNDEFINED] = 1
							end
						end
					end
				end

				-- Re-enable the file browser dialog
				app:SetPrefs("Global.UserInterface.AutoClipBrowse", AutoClipBrowse)

				-- Unlock the comp flow area
				comp:Unlock()

				-- End Undo
				comp:EndUndo()
			else
				error("[Error] Please select a TVPaintLoader node before running this script.")
			end
		end
	else
		error("[Error] Please select a TVPaintLoader node before running this script.")
	end
end

Main()
print("[Done]")
