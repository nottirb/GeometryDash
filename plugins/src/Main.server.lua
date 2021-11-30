-- imports
local Selection = game:GetService("Selection")
local Rodux = require(script.Parent.Packages.Rodux)
local UIBuilder = require(script.Parent.UIBuilder)

local ACTION_MENU_COLOR = Color3.fromRGB(62,79,104)
local TITLE = "Compile Map"
local DESCRIPTION = "Compiles a map to be usable with the GD gameplay engine."
local ICON = "http://www.roblox.com/asset/?id=7225939800"

-- toolbar
local Toolbar = plugin:CreateToolbar("GD Utility")

-- gui/functionality
do
	-- toolbar
	local buildToolbarButton = Toolbar:CreateButton(TITLE, DESCRIPTION, ICON)
	
	-- gui/functionality
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Left,
		false,
		false,
		250,
		340
	)
	
	-- create main gui
	local buildWidget = plugin:CreateDockWidgetPluginGui(TITLE, widgetInfo)
	buildWidget.Title = TITLE
	
	local builder = UIBuilder.new()
	builder:SetParent(buildWidget)
	builder:SetTitle(TITLE)
	
	-- create custom/plugin-specific UI
	local nameText = builder:CreateTextBox("Map name")

	local blocksButton = builder:CreateButton("Set blocks", ACTION_MENU_COLOR)
	local blocksLabel = builder:CreateLabel("Unselected")

	local staticButton = builder:CreateButton("Set static blocks", ACTION_MENU_COLOR)
	local staticLabel = builder:CreateLabel("Unselected")

	local actionButton = builder:CreateButton("Set action blocks", ACTION_MENU_COLOR)
	local actionLabel = builder:CreateLabel("Unselected")

	local startButton = builder:CreateButton("Set start location", ACTION_MENU_COLOR)
	local startLabel = builder:CreateLabel("Unselected")
	
	builder:AddSpace(20)
	
	local buildButton = builder:CreateButton("Compile Map")
	
	-- utility methods
	local function getSelectionInfo(selection)
		local newText = ""
		
		if #selection == 1 then
			newText = selection[1]:GetFullName():gsub("%.", "\\")
		else
			newText = #selection .. " objects selected"
		end
		
		return newText
	end

	local function blockIterator(set, func)
		for _, instance in next, set do
			if instance:IsA("BasePart") then
				func(instance)
			end

			blockIterator(instance:GetChildren(), func)
		end
	end
	
	-- handle plugin state
	-- reducers
	local enabledReducer = function(state, action)
		state = state or false

		if action.type == "switchEnable" then
			return not state
		end

		return state
	end

	local setReducer = function(state, action)
		state = state or {
			blocks = {};
			statics = {};
			actions = {};
			start = false;
		}

		local newState = {}
		for index, value in next, state do
			newState[index] = value
		end

		local actionType = action.type

		if actionType:len() > 4 then
			local target = actionType:sub(5, actionType:len())

			if state[target] ~= nil then
				newState[target] = action.payload
			end
		end

		return newState
	end

	local mainReducer = Rodux.combineReducers{
		enabled = enabledReducer;
		sets = setReducer;
	}

	-- store
	local store = Rodux.Store.new(mainReducer)

	store.changed:connect(function(newState, oldState)
		-- update User Interface
		if #newState.sets.blocks > 0 then
			blocksLabel.Text = getSelectionInfo(newState.sets.blocks)
		else
			blocksLabel.Text = "Unselected"
		end
		
		if #newState.sets.statics > 0 then
			staticLabel.Text = getSelectionInfo(newState.sets.statics)
		else
			staticLabel.Text = "Unselected"
		end
		
		if #newState.sets.actions > 0 then
			actionLabel.Text = getSelectionInfo(newState.sets.actions)
		else
			actionLabel.Text = "Unselected"
		end
		
		if newState.sets.start ~= false then
			startLabel.Text = getSelectionInfo({newState.sets.start})
		else
			startLabel.Text = "Unselected"
		end
		
		-- update top level UI visibility
		if newState.enabled ~= oldState.enabled then
			buildWidget.Enabled = newState.enabled
		end
	end)
	
	-- top level gui opening/closing
	buildToolbarButton.Click:Connect(function()
		store:dispatch{
			type = "switchEnable"
		}
	end)
	
	-- selection handling
	local function dispatchSelection(actionName)
		store:dispatch{
			type = "set_" .. actionName;
			payload = Selection:Get();
		}
	end

	blocksButton.MouseButton1Click:Connect(function()
		dispatchSelection("blocks")
	end)
	
	staticButton.MouseButton1Click:Connect(function()
		dispatchSelection("statics")
	end)
	
	actionButton.MouseButton1Click:Connect(function()
		dispatchSelection("actions")
	end)
	
	startButton.MouseButton1Click:Connect(function()
		local selection = Selection:Get()
		
		if #selection == 1 then
			store:dispatch{
				type = "set_start";
				payload = selection[1];
			}
			
		elseif #selection < 1 then
			store:dispatch{
				type = "set_start";
				payload = false;
			}
			
		else
			warn("GD Map Compiler: You cannot select more than one starting point")
		end
	end)
	
	-- compiling
	buildButton.MouseButton1Click:Connect(function()
		local start = os.clock()
		print("[Map Compiler]: Beginning map compilation")

		-- get state
		local state = store:getState()
		assert(state.sets.start ~= false, "You must select a starting point")
		
		-- create map folder
		local mapFolder = Instance.new("Folder")
		mapFolder.Parent = game:GetService("ReplicatedStorage") -- TEMP
		mapFolder.Name = nameText.Text
		
		local staticFolder = Instance.new("Folder")
		staticFolder.Parent = mapFolder
		staticFolder.Name = "Statics"

		local chunkFolder = Instance.new("Folder")
		chunkFolder.Parent = mapFolder
		chunkFolder.Name = "Chunks"
		
		for _, item in ipairs(state.sets.statics) do
			item:Clone().Parent = staticFolder
		end
		
		-- build chunks
		print("[Map Compiler]: Getting starting position")

		local startPos = state.sets.start.Position
		local smallestZPosition = startPos.Z
		
		-- fix for bad users
		blockIterator(state.sets.blocks, function(block)
			if block.Position.Z < smallestZPosition then
				smallestZPosition = block.Position.Z
			end
		end)

		blockIterator(state.sets.actions, function(block)
			if block.Position.Z < smallestZPosition then
				smallestZPosition = block.Position.Z
			end
		end)
		
		-- chunks
		print("[Map Compiler]: Compiling chunks")

		local chunks = {}
		local zOffset = -smallestZPosition
		
		local function getChunk(position)
			local zPosition = position.Z + zOffset
			local chunkPosition = (zPosition - zPosition%2)/2 + 1
			local chunk = chunks[chunkPosition]
			
			if not chunk then
				local chunkInstance = Instance.new("Folder")
				local collidablesInstance = Instance.new("Folder")
				local uncollidablesInstance = Instance.new("Folder")
				local actionInstance = Instance.new("Folder")

				chunkInstance.Parent = chunkFolder
				collidablesInstance.Parent = chunkInstance
				uncollidablesInstance.Parent = chunkInstance
				actionInstance.Parent = chunkInstance
				
				chunkInstance.Name = tostring(chunkPosition)
				collidablesInstance.Name = "Collidables"
				uncollidablesInstance.Name = "Uncollidables"
				actionInstance.Name = "Actions"
				
				chunk = {
					Instance = chunkInstance;
					Collidables = collidablesInstance;
					Uncollidables = uncollidablesInstance;
					Actions = actionInstance;
				}
				
				chunks[chunkPosition] = chunk
			end
			
			return chunk
		end

		-- place blocks into chunks
		blockIterator(state.sets.blocks, function(block)
			local chunk = getChunk(block.Position)
			local newPart = block:Clone()
			newPart.CFrame = newPart.CFrame + Vector3.new(0,0,zOffset)
			newPart.Parent = newPart.CanCollide and chunk.Collidables or chunk.Uncollidables

			for _, child in ipairs(newPart:GetChildren()) do
				if child:IsA("BasePart") then
					child:Destroy()
				end
			end
		end)
		
		blockIterator(state.sets.actions, function(block)
			local chunk = getChunk(block.Position)
			local newPart = block:Clone()
			newPart.CFrame = newPart.CFrame + Vector3.new(0,0,zOffset)
			newPart.Parent = chunk.Actions
		end)

		blockIterator(staticFolder:GetChildren(), function(block)
			block.CFrame = block.CFrame + Vector3.new(0,0,zOffset)
		end)
		
		print("[Map Compiler]: Compiling final map")
		
		-- build settings module script
		local _settings = Instance.new("ModuleScript")
		local source = ([[-- Settings for %s
local Settings = {}

-- static information
Settings.Name = "%s"

Settings.StartPosition = Vector3.new(%s, %s, %s)

Settings.AnimationZones = {
	-- example start:
	[1] = {
		Insert = function(part, endCFrame, imageLabel)
			-- animate the part into existence here
		end;
		Delete = function(part, startCFrame, imageLabel)
			-- animate the part out of existence here
		end;
		ZoneReached = function(character, map)
			-- called once whenever you reach this zone
		end,
	};
	
	-- example continuation:
	[20] = {
		-- keeps the same insert animation zone from the previous one ([1])
		Delete = function(part, startCFrame, imageLabel)
			-- animate the part out of existence here
		end;
	};

	[30] = {
		Insert = function(part, endCFrame, imageLabel)
			-- animate the part into existence here
		end;
		-- keeps the same delete animation zone from the previous one ([20])
	};
}

return Settings]]
		):format(nameText.Text, nameText.Text,
			startPos.X, startPos.Y, startPos.Z + zOffset
		)
		
		_settings.Name = "Settings"
		_settings.Source = source
		_settings.Parent = mapFolder

		mapFolder.Parent = game:GetService("ReplicatedStorage")
		
		print(("[Map Compiler]: Map compilation finished (%sms)"):format((math.ceil((os.clock() - start)*10000))/10))
	end)
end