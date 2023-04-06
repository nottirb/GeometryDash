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

local Signal = require(Packages.Signal)

--[=[
	@class ClientData
	@client

	Handles user data on a per-player basis. Also handles data replication to the various clients via ReplicaService.
]=]
local ClientData = {}
ClientData.__index = ClientData

--[=[
	@prop _data [string: any]
	@within ClientData

	The dictionary containing player data, stored in <key: value> pairs, effectively.. just as a dictionary.
]=]
--[=[
	@prop Changed GoodSignal
	@within ClientData

	The event fired whenever the player's data changes. It is fired with:
	```
	string -- The key updated
	any -- The new value at the supplied key
	```
]=]

--[=[
	@within ClientData

	@param replica Replica -- The Replica to build the Data object off of

	@return ClientData -- The created object

	Creates a ClientData object from a given replica.
]=]
function ClientData.new(replica)
	-- create object
	local self = setmetatable({}, ClientData)

	-- public variables
	self.Changed = Signal.new()
	self._data = replica.Data

	for key, _ in next, replica.Data do
		replica:ListenToChange({ key }, function(newValue)
			-- fire the changed event
			self.Changed:Fire(key, newValue)
		end)
	end

	replica:ListenToRaw(function(actionName, pathArray)
		local key = pathArray[1]

		if actionName ~= "SetValue" or #pathArray > 1 then
			self.Changed:Fire(key, replica.Data[key])
		end
	end)

	-- return object
	return self
end

--[=[
	@within ClientData

	Destroys the ClientData object and cleans up any objects.
]=]
function ClientData:Destroy()
	-- destroy objects
	self.Changed:Destroy()

	-- remove pointers
	self._data = nil

	-- delete metatable
	setmetatable(self, nil)
end

--[=[
	@within ClientData

	@param key string -- The key to get the data from in the user's profile

	@return any? -- The data snagged from the user's profile at the given key

	Gets the player data at a given key
]=]
function ClientData:Get(key)
	return self._data[key]
end

-- return Class
return ClientData
