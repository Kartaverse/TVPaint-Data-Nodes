--[[--
TVPaint Build Comp 2025-11-15 08.26 PM

Auto-build a comp node-graph based upon the active TVPaintLoader node selection.

--]]--

-- TVPaintLinkImage Options
BaseImageFolder = "Comp:/"

-- MultiMerge Options
autoNameLayers = true
alphaGain = false

print("[TVPaint] Build Comp Script")
print("[Auto Name Layers] ", autoNameLayers)
print("[Alpha Gain Zero] ", alphaGain)

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

function Main()
	-- Read the node selection
	local selectedTool = comp.ActiveTool
	if selectedTool then
		-- Check the selected node's output type
		toolOutput = selectedTool:FindMainOutput(1)
		if toolOutput ~= nil then
			toolType = toolOutput:GetAttrs().OUTS_DataType

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

				-- for i = 1, layer_max do
				for i = layer_max, 1, -1 do

					-- Add the node
					local img = comp:AddTool("Fuse.TVPaintLinkImage", -32768, -32768)

					-- Connect the inputs
					img:ConnectInput("ScriptVal", selectedTool)

					-- Increment the Layer value
					img.Layer = tonumber(i)

					-- Working folder for TVPaint images
					img.BaseFolder = tostring(BaseImageFolder)

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
