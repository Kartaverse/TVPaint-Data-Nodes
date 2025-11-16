--[[--
TVPaint Build Comp - v1 2025-11-16 01.36 AM

Auto-build a comp node-graph based upon the active TVPaintLoader node selection.


## Controls:

The "baseImageFolder" control defines where the image layer folders are in relation to the active composite. This setting fills in the value used by the TVPaintLinkImage node.

The "adjustRenderRange" control sets the RenderEnd range to match the TVPaint image count.

The "autoNameLayers" control is used to name each layer in the MultiMerge node

The "alphaGain" control can be used to enable alpha compositing for each layer in the MultiMerge node

The "reverseLayerOrder" control allows you to flip the layer sort order when the TVPaintLinkImage nodes are added to the comp, and they are then connected to the MultiMerge node.


The "skipShowingUI" control allows you to avoid displaying the UI Manager window. This improves compatibility of the script with Resolve Free v19.1-20.2+.

--]]--

adjustRenderRange = false

-- TVPaintLinkImage Options
baseImageFolder = "Comp:/"
reverseLayerOrder = false

-- MultiMerge Options
autoNameLayers = true
alphaGain = false

-- Should the UI Manager window be skipped
skipShowingUI = false

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

function AskForInput()
	-- Debugging log detail
	local verbose = true

	adjustRenderRange = getPreferenceData("TVPaint.adjustRenderRange", adjustRenderRange, verbose)
	autoNameLayers = getPreferenceData("TVPaint.autoNameLayers", autoNameLayers, verbose)
	alphaGain = getPreferenceData("TVPaint.alphaGain", alphaGain, verbose)
	reverseLayerOrder = getPreferenceData("TVPaint.reverseLayerOrder", reverseLayerOrder, verbose)

	local ui = fu.UIManager
	local disp = bmd.UIDispatcher(ui)
	local width,height = 300,155

	win = disp:AddWindow({
		ID = "TVPaint",
		TargetID = "TVPaint",
		WindowTitle = "TVPaint Build Comp",
		Geometry = {100, 100, width, height},
		Spacing = 10,

		ui:VGroup{
			ID = "root",

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
		adjustRenderRange = itm.AdjustRenderRange.Checked
		autoNameLayers = itm.AutoNameLayers.Checked
		alphaGain = itm.AlphaGain.Checked
		reverseLayerOrder = itm.ReverseLayerOrder.Checked

		setPreferenceData("TVPaint.adjustRenderRange", itm.AdjustRenderRange.Checked, verbose)
		setPreferenceData("TVPaint.autoNameLayers", itm.AutoNameLayers.Checked, verbose)
		setPreferenceData("TVPaint.alphaGain", itm.AlphaGain.Checked, verbose)
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
			print("[Auto Name Layers] ", autoNameLayers)
			print("[Alpha Gain Zero] ", alphaGain)
			print("[Reverse Layer Order] ", reverseLayerOrder)
			print("[Adjust Render Range] ", adjustRenderRange)

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

				for i = startLayer, endLayer, stepBy do
					-- Add the node
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
					end

					local x, y = flow:GetPos(img)
					flow:SetPos(img, origin_x + 1, y)

					-- Save the TVPaintLinkImage node to a table
					table.insert(imgTbl, img)
				end

				-- Connect the TVPaintLinkImage nodes to a MultiMerge node
				local mmrg = comp:AddTool("MultiMerge", -32768, -32768)

				-- Shift the node to the right
				local mrg_x, mrg_y = flow:GetPos(mmrg)
				flow:SetPos(mmrg, origin_x + 2, origin_y + 1)

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
						end
						if alphaGain == true then
							mmrg["Layer" .. (k-1)  .. ".Gain"][fu.TIME_UNDEFINED] = 0
						end
						print(string.format("[%03d][Connection] %30s -> %s", k, tostring(imgTbl[k].Name), tostring(mmrg.Name)  .. ".Layer" .. (k-1)  .. ".Foreground"))
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
