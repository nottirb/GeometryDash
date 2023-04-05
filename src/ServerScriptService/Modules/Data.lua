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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local ReplicaService = require(Packages.ReplicaService)
local Signal = require(Packages.Signal)

-- Constants
local DATA_CLASS_TOKEN = ReplicaService.NewClassToken("PlayerData")

--[=[
    @class Data
    @server

    Handles user data on a per-player basis. Also handles data replication to the various clients via ReplicaService.
]=]
local Data = {}
Data.__index = Data

--[=[
    @prop _profile Profile
    @within Data

    The ``Profile`` of the user that the Data is based on. See: [ProfileService](https://madstudioroblox.github.io/ProfileService/) for more information on Profile's.
]=]
--[=[
    @prop Replica Replica
    @within Data

    The ``Replica`` used to replicate the player's data. See [ReplicaService](https://madstudioroblox.github.io/ReplicaService) for more information on Replica's.
    You can access ``Replica`` directly to do manual data manipulation.
]=]
--[=[
    @prop Changed GoodSignal
    @within Data
    @tag events

    The event fired whenever the player's data changes. It is fired with:
    ```
    string -- The key updated
    any -- The new value at the supplied key
    any -- The old value at the supplied key
    ```
]=]

--[=[
    @within Data

    Creates a Data object from a given player and profile.

    @param player Player -- The player to create data for
    @param profile Profile -- The player's profile
    @param replicationType string? -- The replication type to use for player data, defaults to "All".
]=]
function Data.new(player, profile, replicationType)
	-- create object
	local self = setmetatable({}, Data)

	-- reconcile profile, loading missing values from the default profile
	profile:Reconcile()

	-- private variables
	self._profile = profile
	self.Replica = ReplicaService.NewReplica({
		ClassToken = DATA_CLASS_TOKEN,
		Tags = { Player = player },
		Data = profile.Data,
		Replication = replicationType == "Selective" and player or "All",
	})

	-- public variables
	self.Changed = Signal.new()

	-- return object
	return self
end

-- destructor
function Data:Destroy()
	-- destroy objects
	self.Replica:Destroy()
	self.Changed:Destroy()

	-- remove pointers
	self.Replica = nil

	-- delete metatable
	setmetatable(self, nil)
end

-- methods
--[[
	gets data at key from profile
	
	@param {string} key: key to get data from
	
	@returns {any} data: data gotten from profile at key
]]

--[=[
    @within Data

    @param key string -- The key to get the data from in the user's profile
    
    @return any? -- The data snagged from the user's profile at a given key

    Gets the player data at a given key
]=]
function Data:Get(key)
	return self._profile.Data[key]
end

--[[
	increments data at key in profile by increment
	
	@param {string} key: key to increment data at
	@param {int} increment: amount to increment value by
]]

--[=[
    @within Data

    @param key string -- The key to increment in the user's profile
    @param increment int -- The amount to increment the value by

    Increment's a player's data at a given key by a supplied increment. Then fires the ``.Changed`` event with:
    ```
    string -- The key incremented
    any -- The new value at the supplied key
    ```
]=]
function Data:Increment(key, increment)
	local oldValue = self._profile.Data[key]
	local newValue = oldValue + increment

	-- set the new value in the replica
	self.Replica:SetValue({ key }, newValue)

	-- call changed event with the new value
	self.Changed:Fire(key, newValue)
end

--[=[
    @within Data

    @param key string -- The key to set in the user's profile
    @param value any -- The value to set the key to in the user's profile

    Sets's a player's data at a given key. Then fires the ``.Changed`` event with:
    ```
    string -- The key set
    any -- The new value at the supplied key
    ```
]=]
function Data:Set(key, value)
	-- set the new value in the replica
	self.Replica:SetValue({ key }, value)

	-- call changed event
	self.Changed:Fire(key, value)
end

-- return Class
return Data
