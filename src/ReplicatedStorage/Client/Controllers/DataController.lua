--[[
	MIT License

	Copyright (c) 2022 nottirb

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
--]]

-- Imports
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ClientSrc = ReplicatedStorage:WaitForChild("Client")
local ClientModules = ClientSrc:WaitForChild("Modules")
local Player = Players.LocalPlayer

local Data = require(ClientModules.Data)
local Knit = require(Packages.Knit)
local Signal = require(Packages.Signal)
local Promise = require(Packages.Promise)
local Janitor = require(Packages.Janitor)
local ReplicaController = require(Packages.ReplicaService)

-- Constants
local DATA_CLASS_TOKEN = "PlayerData"

--[=[
	@class DataController

	Controls anything related to player data.
	It should be noted that although the methods attached to this Controller are labelled ``Async``, that does not mean that it takes time to fetch the value's from the server.
	Instead, it just means that they return Promises that are resolved immediately if data is already cached on the client, or in the future if data is not yet cached on the client.
	If you happen to supply another player into any of the events, there is a possibility that the Promise will be rejected in the case that the player leaves before their data can be fetched.
	This typically shouldn't be an issue you have to catch.
]=]
local DataController = Knit.CreateController({
	Name = "DataController",
})

function DataController:KnitInit()
	-- private variables
	self._data = {}
	self._dataLoaded = {}
	self._dataDeleted = {}

	-- public variables
	self._playerDataLoaded = Signal.new()

	-- connect to ReplicaController
	ReplicaController.ReplicaOfClassCreated(DATA_CLASS_TOKEN, function(replica)
		-- create data
		local replicaPlayer = replica.Tags.Player
		local data = Data.new(replica)
		self._data[replicaPlayer] = data
		local deletedEvent = self._dataDeleted[replicaPlayer] or Signal.new()

		-- clean up memory
		replica:AddCleanupTask(function()
			data:Destroy()
			self._data[replicaPlayer] = nil

			if deletedEvent then
				deletedEvent:Fire()
				deletedEvent:Destroy()
				self._dataDeleted[replicaPlayer] = nil
			end
		end)

		-- fire data loaded events
		local loadedEvent = self._dataLoaded[replicaPlayer]
		if loadedEvent then
			loadedEvent:Fire(data)
			loadedEvent:Destroy()
			self._dataLoaded[replicaPlayer] = nil
		end

		self._playerDataLoaded:Fire(replicaPlayer, data)
	end)
end

--[=[
	@within DataController

	@param key string -- The key to get the data at
	@param player Player? -- The player to get the data for, defaults to Players.LocalPlayer

	@return any? -- The requested data, will return nil if the data doesn't exist
]=]
function DataController:GetAsync(key, player)
	return self:OnReady(player):andThen(function(playerData)
		return playerData:Get(key), playerData
	end):expect()
end

--[=[
	@within DataController

	@param key string -- The key to get the data at
	@param func function -- The function to bind to the .Changed event for a given key
	@param player Player? -- The player to get the data for, defaults to Players.LocalPlayer

	@return Promise -- See below

	Gets a player's data, and returns a Promise that will either be resolved with:
	```
	Connection -- The connection to the LocalData's .Changed event
	```
	or rejected.

	The bound function will always be called with:
	```
	any -- The new value of data[key]
	```
]=]
function DataController:BindToChange(key, func, player)
	return self:OnReady(player):andThen(function(data)
		func(data:Get(key))

		return data.Changed:Connect(function(keyChanged, value)
			if keyChanged == key then
				func(value)
			end
		end)
	end)
end

--[=[
	@within DataController

	@param player Player? -- The player to get the data object for, defaults to Players.LocalPlayer

	@return Promise -- A promise that is called with the player's LocalData object

	Gets a player's data, and returns a Promise that will either be resolved with:
	```
	LocalData -- The player's LocalData
	```
	or rejected.

	This consequently means you could do something like this:
	```lua
	DataController:OnReady():andThen(function(data)
		-- you can assume that all of your data has loaded at this point
		local coins = data:Get("Coins")
		local xp = data:Get("XP")
		local level = data:Get("Level")
	end):catch(print)
	```
]=]
function DataController:OnReady(player)
	player = player or Player

	return Promise.new(function(resolve, reject)
		local data = self._data[player]

		if data then
			-- just resolve the promise, the data exists
			resolve(data)
		else
			-- cleanup handler
			local janitor = Janitor.new()

			-- get/setup events
			local dataDeleted = self._dataDeleted[player]
				or (function()
					local event = Signal.new()
					self._dataDeleted[player] = event
					return event
				end)()

			local dataLoaded = self._dataLoaded[player]
				or (function()
					local event = Signal.new()
					self._dataLoaded[player] = event
					return event
				end)()

			-- cleanup and resolve/reject
			janitor:Add(dataDeleted:Connect(function()
				reject()
				janitor:Cleanup()
				janitor:Destroy()
			end))

			janitor:Add(dataLoaded:Connect(function(newData)
				resolve(newData)
				janitor:Cleanup()
				janitor:Destroy()
			end))
		end
	end)
end

-- return Controller
return DataController
