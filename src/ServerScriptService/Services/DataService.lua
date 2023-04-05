-- Imports
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerModules = ServerScriptService:WaitForChild("Modules")
local ServerPackages = ServerScriptService:WaitForChild("ServerPackages")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local ProfileService = require(ServerPackages.ProfileService)
local Knit = require(Packages.Knit)
local Signal = require(Packages.Signal)
local Promise = require(Packages.Promise)
local Data = require(ServerModules.Data)

-- Constants
local DATA_RESET = 5
local REPLICATION_TYPE = "All" -- All or Selective
local PROFILE_STORE_INDEX = "SavedData" .. DATA_RESET .. "-" .. HttpService:GenerateGUID()
local NOT_RELEASED_HANDLER = "ForceLoad"
local BASE_PROFILE = {
	Coins = 0,
}

local PROFILE_STORE = ProfileService.GetProfileStore(PROFILE_STORE_INDEX, BASE_PROFILE)

--[=[
	@class DataService

	Handles the data for all Player's currently in the server. 
	Uses [ProfileService](https://madstudioroblox.github.io/ProfileService/) and [ReplicaService](https://madstudioroblox.github.io/ReplicaService/) for data storage and replication.
	Abstracts data handling to 3 methods, ``:Get()``, ``:Set()``, and ``:Increment()``
]=]
local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {},
})

--[=[
	@prop DataLoaded Signal
	@within DataService
	@tag events

	An event that is fired whenever a new player's data is loaded. 
	You might consider using ``:BindToDataLoaded()`` if you need it to also call the function you want to connect with all existing player data aswell.

	Fired with:
	```
	Player -- The player who "owns" the Data object
	Data -- The Data object for the specific Player
	```
]=]
--[=[
	@prop DataReleased Signal
	@within DataService
	@tag events

	An event that is fired whenever a player's data is released.

	Fired with:
	```
	Player -- The player who "owned" the Data object that has since been destroyed
	```
]=]
--[=[
	@prop DataChanged { [string]: Signal }
	@within DataService
	@tag events

	An event that is fired whenever a player's data changes. 
	You might consider using ``:BindToDataChanged()`` if you need it to also call the function you want to connect with all current player data aswell.

	Each event for a specific key is fired with:
	```
	Player -- The player who "owns" the Data object
	any -- The new value of the player's data at the provided key
	```

	See BASE_PROFILE for information on what data key's exist.
]=]
function DataService:KnitInit()
	-- private variables
	self._dataLoading = {}
	self._data = {}
	self._profiles = {}

	-- setup events
	self.DataLoaded = Signal.new()
	self.DataReleased = Signal.new()
	self.DataChanged = {}

	for key, _baseValue in next, BASE_PROFILE do
		self.DataChanged[key] = Signal.new()
	end

	-- setup player data connections
	Players.PlayerRemoving:Connect(function(player)
		-- get player profile
		local profile = self._profiles[player]

		-- delete player data
		if profile then
			profile:Release()
		else
			local data = self._data[player]
			if data then
				data:Destroy()
			end
		end

		-- clear player indecies
		self._data[player] = nil
		self._profiles[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		self:_loadData(player)
	end)

	-- load existing player data
	for _, player in ipairs(Players:GetPlayers()) do
		self:_loadData(player)
	end
end

--[=[
	@within DataService
	@private

	@param player Player -- The player to load the data for

	Load's a player's data, if not yet loaded/loading. Abstracts interaction with ProfileService to strictly be through ``DataService``.
]=]
function DataService:_loadData(player)
	-- if we're already loading data, then return
	if self._dataLoading[player] or self._data[player] then
		return
	else
		self._dataLoading[player] = true
	end

	-- load player data
	Promise.new(function(resolve, reject)
		-- use ProfileService to load player data
		local response = PROFILE_STORE:LoadProfileAsync(tostring(player.UserId), NOT_RELEASED_HANDLER)

		if response ~= nil then
			resolve(response) -- this is a Profile
		else
			reject(response)
		end
	end)
		:andThen(function(profile)
			profile:ListenToRelease(function()
				local playerData = self._data[player]
				if playerData then
					playerData:Destroy()
				end

				self._data[player] = nil
				self._profiles[player] = nil
				self.DataReleased:Fire(player)

				if player ~= nil then
					player:Kick(
						"Your game session is no longer valid., someone logged into your account on another server."
					)
				end
			end)

			if player:IsDescendantOf(Players) then
				return profile
			else
				profile:Release()
				player:Kick(
					"Your current session is invalid.\n\nYour connection has been terminated to prevent your data from being overwritten."
				)
				error("Invalid session")
			end
		end)
		:andThen(function(profile)
			-- reconcile profile
			profile:Reconcile()

			-- setup data component
			local data = Data.new(player, profile, REPLICATION_TYPE)

			-- connect the data changed event to the global changed event
			data.Changed:Connect(function(key, newValue, oldValue)
				local changedSignal = self.DataChanged[key]

				if changedSignal ~= nil then
					changedSignal:Fire(player, newValue, oldValue)
				end
			end)

			-- save the data object
			self._data[player] = data
			self._profiles[player] = profile

			-- cleanup loading tie
			self._dataLoading[player] = nil

			-- fire the data loaded event
			self.DataLoaded:Fire(player, data)
		end)
		:catch(function(err)
			-- cleanup loading tie
			self._dataLoading[player] = nil

			-- warn
			warn(err)
			player:Kick(
				"An error occured when trying to fetch your data.\n\nYour connection has been terminated to prevent your data from being overwritten."
			)
		end)
		:catch(warn)
end

--[=[
	@within DataService

	@param callback (player: Player, data: { [string]: any }) -> () -- The function to call whenever a player's data loads

	@return Connection -- Connection for the player's data loaded, call :Disconnect() to destroy this connection

	Binds a function to be called whenever player data loads. 
	Will also call the function with player data that has already been loaded, unlike the ``.DataLoaded`` event.

	See ``.DataLoaded`` for information on what this event is fired with.
]=]
function DataService:BindToDataLoaded(callback: (player: Player, data: { [string]: any }) -> ())
	local connection = self.DataLoaded:Connect(callback)

	for player, data in next, self._data do
		callback(player, data)
	end

	return connection
end

--[=[
	@within DataService

	@param key string -- The key to bind the function to
	@param func (...any) -> () -- The function to call whenever a player's data changes at a given key

	@return Connection -- Connection for the player's data changes, call :Disconnect() to destroy this connection

	@error "KeyNotString" -- If key is not a string
	@error "KeyDoesNotExist" -- If the provided key does not exist within the data structure

	Binds a function to be called whenever player data changes for a given key. 
	Will also call the function with player data that has already been loaded, unlike the ``.DataChanged`` events.

	See ``.DataChanged`` for information on what this event is fired with.
]=]
function DataService:BindToDataChanged(key: string, func: (...any) -> ())
	assert(typeof(key) == "string", "[KeyNotString]: Key must be a string")
	assert(
		self.DataChanged[key],
		"[KeyDoesNotExist]: The provided key does not exist within the data structure. Key: " .. tostring(key)
	)

	local disconnect = self.DataChanged[key]:Connect(func)

	for player, data in next, self._data do
		func(player, data:Get(key))
	end

	return disconnect
end

--[=[
	@within DataService

	@param player Player -- The player to get the data for
	@param key string -- The key to use as the index for the player data

	@return any? -- The value at data[key] for a player's data, nil if the data at the given key does not exist

	@error "KeyNotString" -- If key is not a string
	@error "KeyDoesNotExist" -- If the key does not exist within the data structure (BASE_PROFILE dictionary)
	@error "DataDoesNotExist" -- If the player's profile has been released

	Gets a player's data from the data system. The same as calling ``Data:Get(key)`` on the player's ``Data`` object.
]=]
function DataService:Get(player: Player, key: string)
	assert(typeof(key) == "string", "[KeyNotString]: Key must be a string")
	assert(BASE_PROFILE[key] ~= nil, "[KeyDoesNotExist]: Key does not exist within the data structure. Key: " .. key)

	local data = self._data[player]
	if data then
		return data:Get(key)
	else
		error("[DataDoesNotExist]: The player's profile has been released.")
	end
end

--[=[
	@within DataService
	@yields

	@param player Player -- The player to get the data for
	@param key string -- The key to use as the index for the player data

	@return Promise -- A promise that is either resolved with the value at data[key] for a player's data, or nil if the
	data at the given key does not exist. It will reject with a "DataDoesNotExist" error if the player's profile is
	released.

	@error "KeyNotString" -- If key is not a string
	@error "KeyDoesNotExist" -- If the key does not exist within the data structure (BASE_PROFILE dictionary)

	Asynchronously gets a player's data from the data system. The same as calling ``Data:Get(key)`` on the player's
	``Data`` object.
]=]
function DataService:GetAsync(player: Player, key: string)
	assert(typeof(key) == "string", "[KeyNotString]: Key must be a string")
	assert(BASE_PROFILE[key] ~= nil, "[KeyDoesNotExist]: Key does not exist within the data structure. Key: " .. key)

	return self
		:GetDataPromise(player)
		:andThen(function(data)
			return data:Get(key)
		end)
		:expect()
end

--[=[
	@within DataService

	@param player Player -- The player to get the data for

	@return Promise -- Promise that resolves with the player's Data component, or throws an error.

	@error "DataDoesNotExist" -- If the player's profile has been released

	Gets a player's data from the data system. The same as calling ``Data:Get(key)`` on the player's ``Data`` object.
	This is used internally for certain methods, and externally so that you can do custom data manipulation.
]=]
function DataService:GetDataPromise(player: Player)
	return Promise.new(function(resolve)
		local data = self._data[player]

		if data then
			resolve(data)
		else
			local connection
			connection = self.DataLoaded:Connect(function(eventPlayer, newData)
				if eventPlayer == player then
					connection:Disconnect()
					resolve(newData)
				elseif not player or not player:IsDescendantOf(Players) then
					connection:Disconnect()
					error("[DataDoesNotExist]: The player's profile has been released.")
				end
			end)
		end
	end)
end

--[=[
	@within DataService
	@yields

	@param player Player -- The player to get the data for
	@param key string -- The key to use as the index for the player data
	@param value any -- The value to set the player data at key to

	@return Promise -- A promise that is either resolved automatically, or rejected with a "DataDoesNotExist" error if 
	the player's profile is released.

	@error "KeyNotString" -- If key is not a string
	@error "KeyDoesNotExist" -- If the key does not exist within the data structure (BASE_PROFILE dictionary)
	@error "DataDoesNotExist" -- If the player's profile has been released
	@error "ValueIsNil" -- If no value was provided, you cannot set a data value to nil

	Sets a player's data in the data system asynchronously. The same as calling ``Data:Set(key)`` on the player's
	``Data`` object. It returns a promise that will reject with "DataDoesNotExist" if the player's profile has been
	released.
]=]
function DataService:SetAsync(player: Player, key: string, value: any)
	assert(typeof(key) == "string", "[KeyNotString]: Key must be a string")
	assert(BASE_PROFILE[key] ~= nil, "[KeyDoesNotExist]: Key does not exist within the data structure. Key: " .. key)
	assert(value ~= nil, "[ValueIsNil]: Value cannot be nil, you cannot set a data value to nil")

	self
		:GetDataPromise(player)
		:andThen(function(data)
			data:Set(key, value)
		end)
		:await()
end

--[=[
	@within DataService
	@yields

	@param player Player -- The player to get the data for
	@param key string -- The key to use as the index for the player data
	@param increment number -- The amount to increment the player data at key by

	@return any -- The value at data[key] for a player's data

	@error "KeyNotString" -- If key is not a string
	@error "KeyDoesNotExist" -- If the key does not exist within the data structure (BASE_PROFILE dictionary)
	@error "DataDoesNotExist" -- If the player's profile has been released
	@error "ValueIsNotANumber" -- If the value at data[key] is not a number, you cannot increment anything that isn't a number
	@error "IncrementIsNotANumber" -- If the increment is not a number

	Gets a player's data from the data system. The same as calling ``Data:Get(key)`` on the player's ``Data`` object.
]=]
function DataService:IncrementAsync(player: Player, key: string, increment: number)
	assert(typeof(key) == "string", "[KeyNotString]: Key must be a string")
	assert(BASE_PROFILE[key] ~= nil, "[KeyDoesNotExist]: Key does not exist within the data structure. Key: " .. key)
	assert(typeof(increment) == "number", "[IncrementIsNotANumber]: Increment must be a number")

	self
		:GetDataPromise(player)
		:andThen(function(data)
			assert(typeof(data:Get(key)) == "number", "[ValueIsNotANumber]: The value at data[key] must be a number.")
			data:Increment(key, increment)
		end)
		:await()
end

return DataService
