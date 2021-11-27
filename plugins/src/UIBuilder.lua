--[=[
	@class UIBuilder
	
	Builds a user interface programatically, specifically for plugin usage.
]=]
local UIBuilder = {}
UIBuilder.__index = UIBuilder

function UIBuilder.new()
	local self = {}

	local uiHolder = Instance.new("Frame")
	uiHolder.Size = UDim2.new(1,0,1,0)
	uiHolder.BackgroundTransparency = 1

	local scrollBar = Instance.new("ScrollingFrame")
	scrollBar.Size = UDim2.new(1,0,1,0)
	scrollBar.BackgroundColor3 = Color3.fromRGB(9,12,16)
	scrollBar.BorderColor3 = Color3.fromRGB(27,42,53)
	scrollBar.AutomaticSize = Enum.AutomaticSize.None
	scrollBar.AutomaticCanvasSize = Enum.AutomaticSize.None
	scrollBar.ScrollBarThickness = 4
    scrollBar.Parent = uiHolder

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.new(1,1,1)
	title.Font = Enum.Font.Code
	title.Size = UDim2.new(1,-20,0,30)
	title.Position = UDim2.new(0,10,0,10)
	title.TextScaled = true
	title.ZIndex = 2
	title.Text = ""
    title.Parent = scrollBar

	self.ui = uiHolder
	self.scroll = scrollBar
	self.title = title
	self.size = 50

	local object = setmetatable(self, UIBuilder)
	object:_resizeCanvas()

	return object
end

--[[
	@within UIBuilder
	@private
	
	@param addition number -- The size to increase the canvas size by
	
	Resizes a canvas by an additional pixel size, intended to create white space in the UI by internal methods.
]]
function UIBuilder:_resizeCanvas(addition)
	if addition ~= nil and type(addition) == "number" then
		self.size += addition
	end

	self.scroll.CanvasSize = UDim2.new(0,0,0,self.size)
end

--[=[
	@within UIBuilder
	
	@param parent Instance -- new parent instance
	
	Sets the .Parent property of the highest level UI instance to the provided value.
]=]
function UIBuilder:SetParent(parent)
	self.ui.Parent = parent
end

--[=[
	@within UIBuilder
	
	@param text string -- new title
	
	Sets the title of the UI
]=]
function UIBuilder:SetTitle(text)
	self.title.Text = text or ""
end

--[=[
	@within UIBuilder
	
	@param text string? -- text to put on the button, defaults to ""
	@param color Color3? -- color of the button, defaults to <3,80,163>
	
	@return button TextButton -- highest level button instance, used to connect events
	@return textLabel TextLabel -- label containing the button text
]=]
function UIBuilder:CreateButton(text, color)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -20, 0, 40)
	button.Position = UDim2.new(0, 10, 0, self.size)
	button.BackgroundColor3 = color or Color3.fromRGB(3, 80, 163)
	button.ZIndex = 2
	button.Text = ""
    button.Parent = self.scroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = button

	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1,0,0.6,0)
	textLabel.Position = UDim2.new(0,10,0.2,0)
	textLabel.Font = Enum.Font.Code
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1,1,1)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Text = text or ""
	textLabel.ZIndex = 3
    textLabel.Parent = button

	self:_resizeCanvas(50)
	return button, textLabel
end

--[=[
	@within UIBuilder
	
	@param text string? -- text to put on the label, defaults to ""
	
	@return label TextLabel -- label containing the text
]=]
function UIBuilder:CreateLabel(text)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -30, 0, 20)
	label.Position = UDim2.new(0, 20, 0, self.size)
	label.BackgroundTransparency = 1
	label.ZIndex = 2
	label.Font = Enum.Font.Code
	label.Text = text or ""
	label.TextColor3 = Color3.new(1,1,1)
	label.TextSize = 20
	label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = self.scroll

	self:_resizeCanvas(30)
	return label
end

--[=[
	@within UIBuilder
	
	@param placeholderText string? -- text to put on the label when it has no user-input text, defaults to ""
	@param color Color3? -- color of the button, defaults to <3,37,47>
	
	@return textBox TextBox -- textbox instance, used to connect events
	@return frame Frame -- highest level frame instance, containing the textbox
]=]
function UIBuilder:CreateTextBox(placeholderText, color)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -20, 0, 40)
	frame.Position = UDim2.new(0, 10, 0, self.size)
	frame.BackgroundColor3 = color or Color3.fromRGB(30, 37, 47)
	frame.ZIndex = 2
    frame.Parent = self.scroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = frame

	local textBox = Instance.new("TextBox")
	textBox.BackgroundTransparency = 1
	textBox.Size = UDim2.new(1,-20,0.6,0)
	textBox.Position = UDim2.new(0,10,0.2,0)
	textBox.Font = Enum.Font.Code
	textBox.TextScaled = true
	textBox.TextSize = 22
	textBox.PlaceholderColor3 = Color3.fromRGB(178, 178, 178)
	textBox.TextColor3 = Color3.new(1,1,1)
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.PlaceholderText = placeholderText or ""
	textBox.ZIndex = 3
	textBox.Text = ""
    textBox.Parent = frame

	self:_resizeCanvas(50)
	return textBox, frame
end


--[[
	@within UIBuilder
	
	@param height number -- The size to increase the canvas size by
	
	Resizes a canvas by an additional pixel size, intended to create white space in the UI by internal methods. 
	Will not update the scrolling canvas size.
]]
function UIBuilder:AddSpace(height)
	self.size += height
end

-- return class
return UIBuilder