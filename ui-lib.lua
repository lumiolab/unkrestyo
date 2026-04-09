--!strict
-- ModernUI.lua
-- Simple modern Luau UI library for Roblox
-- Grid-first layout with vertical / horizontal flow
-- Blocky look by default: radius is always 0
-- Root containers are always draggable

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ModernUI = {}
ModernUI.__index = ModernUI

export type Theme = {
	Background: Color3,
	Surface: Color3,
	SurfaceAlt: Color3,
	Border: Color3,
	Text: Color3,
	MutedText: Color3,
	Accent: Color3,
	Danger: Color3,
}

export type LayoutOptions = {
	Parent: Instance?,
	Name: string?,
	Orientation: "Vertical" | "Horizontal"?,
	Padding: number?,
	CellPadding: number?,
	CellSize: UDim2?,
	Columns: number?,
	Rows: number?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	BackgroundColor: Color3?,
	Title: string?,
	ShowCloseButton: boolean?,
	AutoCanvas: boolean?,
}

export type CardOptions = {
	bgcolor: Color3?,
	bordercolor: Color3?,
	borderradius: number?,
	Size: UDim2?,
	Title: string?,
	Padding: number?,
}

export type ButtonOptions = {
	Text: string?,
	Color: Color3?,
	Radius: number?,
	Callback: (() -> ())?,
	TextColor: Color3?,
	Size: UDim2?,
}

export type ToggleOptions = {
	Text: string?,
	Color: Color3?,
	Radius: number?,
	Default: boolean?,
	Callback: ((boolean) -> ())?,
	Size: UDim2?,
	TextColor: Color3?,
}

export type TitleOptions = {
	Text: string,
	Color: Color3?,
	Size: number?,
}

export type TextOptions = {
	Text: string,
	Color: Color3?,
	Size: number?,
}

export type InputOptions = {
	Placeholder: string?,
	Color: Color3?,
	Radius: number?,
	TextColor: Color3?,
	OnSubmit: ((string) -> ())?,
	Size: UDim2?,
}

export type DividerOptions = {
	Color: Color3?,
	Thickness: number?,
	Transparency: number?,
	Size: UDim2?,
}

ModernUI.Theme = {
	Background = Color3.fromRGB(10, 13, 18),
	Surface = Color3.fromRGB(18, 23, 31),
	SurfaceAlt = Color3.fromRGB(24, 30, 40),
	Border = Color3.fromRGB(48, 58, 74),
	Text = Color3.fromRGB(245, 247, 250),
	MutedText = Color3.fromRGB(160, 170, 185),
	Accent = Color3.fromRGB(93, 135, 255),
	Danger = Color3.fromRGB(255, 93, 93),
}

ModernUI.ForceRadius = 0

local function applyCorner(instance: Instance, _radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, ModernUI.ForceRadius)
	corner.Parent = instance
	return corner
end

local function applyStroke(instance: Instance, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or ModernUI.Theme.Border
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.15
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

local function applyPadding(instance: Instance, px: number?)
	local padding = Instance.new("UIPadding")
	local value = px or 12
	padding.PaddingTop = UDim.new(0, value)
	padding.PaddingBottom = UDim.new(0, value)
	padding.PaddingLeft = UDim.new(0, value)
	padding.PaddingRight = UDim.new(0, value)
	padding.Parent = instance
	return padding
end

local function quickTween(object: Instance, properties: {[string]: any}, duration: number?)
	return TweenService:Create(object, TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
end

local function makeDraggable(dragHandle: GuiObject, target: GuiObject)
	local dragging = false
	local dragStart: Vector2
	local startPos: UDim2

	local function update(input: InputObject)
		local delta = input.Position - dragStart
		target.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input)
		end
	end)
end

local BaseComponent = {}
BaseComponent.__index = BaseComponent

function BaseComponent:SetVisible(state: boolean)
	self.Instance.Visible = state
	return self
end

function BaseComponent:SetText(text: string)
	if self.Label then
		self.Label.Text = text
	end
	if self.Button then
		self.Button.Text = text
	end
	return self
end

function BaseComponent:Destroy()
	self.Instance:Destroy()
end

local Container = {}
Container.__index = Container
setmetatable(Container, BaseComponent)

function Container:_updateGrid(layoutOptions: LayoutOptions)
	local orientation = layoutOptions.Orientation or "Vertical"
	local cols = math.max(layoutOptions.Columns or (orientation == "Vertical" and 1 or 3), 1)
	local rows = math.max(layoutOptions.Rows or (orientation == "Horizontal" and 1 or 3), 1)

	self.Grid.FillDirection = orientation == "Vertical" and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	self.Grid.CellPadding = UDim2.fromOffset(layoutOptions.CellPadding or 10, layoutOptions.CellPadding or 10)
	self.Grid.CellSize = layoutOptions.CellSize or UDim2.new(1 / cols, -((cols - 1) * (layoutOptions.CellPadding or 10)), 0, 48)
	self.Grid.SortOrder = Enum.SortOrder.LayoutOrder
	self.Grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	self.Grid.VerticalAlignment = Enum.VerticalAlignment.Top
	self.Grid.StartCorner = Enum.StartCorner.TopLeft

	if self.Scrolling then
		task.defer(function()
			self.Scrolling.CanvasSize = UDim2.fromOffset(0, self.Grid.AbsoluteContentSize.Y + (layoutOptions.Padding or 16) * 2)
		end)
		self.Grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			self.Scrolling.CanvasSize = UDim2.fromOffset(0, self.Grid.AbsoluteContentSize.Y + (layoutOptions.Padding or 16) * 2)
		end)
	end
end

function Container:SetOrientation(orientation: "Vertical" | "Horizontal")
	self.Options.Orientation = orientation
	self:_updateGrid(self.Options)
	return self
end

function Container:SetCellSize(cellSize: UDim2)
	self.Options.CellSize = cellSize
	self:_updateGrid(self.Options)
	return self
end

function Container:Add(child: any)
	child.Instance.Parent = self.Content
	return child
end

function Container:new(options: LayoutOptions)
	local root = Instance.new("Frame")
	root.Name = options.Name or "Container"
	root.BackgroundColor3 = options.BackgroundColor or ModernUI.Theme.Surface
	root.BorderSizePixel = 0
	root.Size = options.Size or UDim2.fromScale(1, 1)
	root.Position = options.Position or UDim2.fromScale(0, 0)
	root.AnchorPoint = options.AnchorPoint or Vector2.zero
	applyCorner(root, 0)
	applyStroke(root, ModernUI.Theme.Border, 1)

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.BackgroundColor3 = ModernUI.Theme.SurfaceAlt
	titleBar.BorderSizePixel = 0
	titleBar.Size = UDim2.new(1, 0, 0, 34)
	titleBar.Parent = root
	applyCorner(titleBar, 0)
	applyStroke(titleBar, ModernUI.Theme.Border, 1)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(10, 0)
	titleLabel.Size = UDim2.new(1, -20, 1, 0)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = ModernUI.Theme.Text
	titleLabel.Text = options.Title or options.Name or "Window"
	titleLabel.Parent = titleBar

	local contentHolder = Instance.new("Frame")
	contentHolder.Name = "Body"
	contentHolder.BackgroundTransparency = 1
	contentHolder.Position = UDim2.fromOffset(0, 34)
	contentHolder.Size = UDim2.new(1, 0, 1, -34)
	contentHolder.Parent = root

	local content: Instance
	local scrolling: ScrollingFrame? = nil

	if options.AutoCanvas == false then
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = contentHolder
		content = frame
	else
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Content"
		scroll.BackgroundTransparency = 1
		scroll.Size = UDim2.fromScale(1, 1)
		scroll.CanvasSize = UDim2.fromOffset(0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
		scroll.ScrollBarThickness = 4
		scroll.BorderSizePixel = 0
		scroll.Parent = contentHolder
		scrolling = scroll
		content = scroll
	end

	applyPadding(content, options.Padding or 16)

	local grid = Instance.new("UIGridLayout")
	grid.Parent = content

	makeDraggable(titleBar, root)

	local self = setmetatable({
		Instance = root,
		Content = content,
		Scrolling = scrolling,
		Grid = grid,
		TitleBar = titleBar,
		TitleLabel = titleLabel,
		Options = options,
	}, Container)

	self:_updateGrid(options)

	if options.Parent then
		root.Parent = options.Parent
	end

	return self
end

local function createBaseFrame(name: string, size: UDim2?, bg: Color3?, _radius: number?, border: Color3?)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size or UDim2.new(1, 0, 0, 48)
	frame.BackgroundColor3 = bg or ModernUI.Theme.SurfaceAlt
	frame.BorderSizePixel = 0
	applyCorner(frame, 0)
	applyStroke(frame, border or ModernUI.Theme.Border, 1)
	return frame
end

function ModernUI.new(options: LayoutOptions)
	return Container:new(options)
end

function ModernUI.CreateScreenGui(name: string?, parent: Instance?)
	local gui = Instance.new("ScreenGui")
	gui.Name = name or "ModernUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function ModernUI.newCard(options: CardOptions)
	local frame = createBaseFrame("Card", options.Size or UDim2.new(1, 0, 0, 120), options.bgcolor or ModernUI.Theme.SurfaceAlt, 0, options.bordercolor or ModernUI.Theme.Border)
	applyPadding(frame, options.Padding or 14)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local card = setmetatable({ Instance = frame, Content = frame }, BaseComponent)

	if options.Title then
		local label = Instance.new("TextLabel")
		label.Name = "CardTitle"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 24)
		label.Font = Enum.Font.GothamBold
		label.Text = options.Title
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = ModernUI.Theme.Text
		label.TextSize = 16
		label.Parent = frame
		card.Label = label
	end

	function card:Add(child: any)
		child.Instance.Parent = frame
		return child
	end

	return card
end

function ModernUI.newButton(options: ButtonOptions)
	local frame = createBaseFrame("ButtonFrame", options.Size or UDim2.new(1, 0, 0, 40), Color3.fromRGB(0, 0, 0), 0, options.Color or ModernUI.Theme.Accent)
	frame.BackgroundTransparency = 1

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = options.Color or ModernUI.Theme.Accent
	button.Text = options.Text or "Button"
	button.TextColor3 = options.TextColor or ModernUI.Theme.Text
	button.TextSize = 14
	button.Font = Enum.Font.GothamMedium
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Parent = frame
	applyCorner(button, 0)

	button.MouseEnter:Connect(function()
		quickTween(button, {BackgroundTransparency = 0.08}):Play()
	end)
	button.MouseLeave:Connect(function()
		quickTween(button, {BackgroundTransparency = 0}):Play()
	end)
	button.MouseButton1Down:Connect(function()
		quickTween(button, {Size = UDim2.new(1, -2, 1, -2)}, 0.08):Play()
	end)
	button.MouseButton1Up:Connect(function()
		quickTween(button, {Size = UDim2.fromScale(1, 1)}, 0.08):Play()
	end)
	button.MouseButton1Click:Connect(function()
		if options.Callback then
			options.Callback()
		end
	end)

	return setmetatable({ Instance = frame, Button = button }, BaseComponent)
end

function ModernUI.newToggle(options: ToggleOptions)
	local holder = createBaseFrame("Toggle", options.Size or UDim2.new(1, 0, 0, 40), ModernUI.Theme.SurfaceAlt, 0, ModernUI.Theme.Border)
	applyPadding(holder, 10)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -56, 1, 0)
	label.Position = UDim2.fromOffset(0, 0)
	label.Font = Enum.Font.GothamMedium
	label.Text = options.Text or "Toggle"
	label.TextColor3 = options.TextColor or ModernUI.Theme.Text
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = holder

	local switch = Instance.new("TextButton")
	switch.Name = "Switch"
	switch.AnchorPoint = Vector2.new(1, 0.5)
	switch.Position = UDim2.new(1, -8, 0.5, 0)
	switch.Size = UDim2.fromOffset(42, 20)
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.BackgroundColor3 = ModernUI.Theme.Border
	switch.BorderSizePixel = 0
	switch.Parent = holder
	applyCorner(switch, 0)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Position = UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = switch
	applyCorner(knob, 0)

	local state = options.Default == true

	local function render()
		quickTween(switch, {
			BackgroundColor3 = state and (options.Color or ModernUI.Theme.Accent) or ModernUI.Theme.Border,
		}):Play()
		quickTween(knob, {
			Position = state and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2),
		}):Play()
		(holder :: any).State = state
	end

	render()

	switch.MouseButton1Click:Connect(function()
		state = not state
		render()
		if options.Callback then
			options.Callback(state)
		end
	end)

	local toggle = setmetatable({ Instance = holder, Label = label, State = state }, BaseComponent)

	function toggle:Set(value: boolean)
		state = value
		self.State = state
		render()
		if options.Callback then
			options.Callback(state)
		end
		return self
	end

	function toggle:Get()
		return state
	end

	return toggle
end

function ModernUI.newTitle(options: TitleOptions)
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, math.max((options.Size or 20) + 8, 24))
	label.Font = Enum.Font.GothamBold
	label.Text = options.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = options.Color or ModernUI.Theme.Text
	label.TextSize = options.Size or 20
	label.RichText = true
	return setmetatable({ Instance = label, Label = label }, BaseComponent)
end

function ModernUI.newText(options: TextOptions)
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, math.max((options.Size or 14) + 10, 22))
	label.Font = Enum.Font.Gotham
	label.Text = options.Text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = options.Color or ModernUI.Theme.MutedText
	label.TextSize = options.Size or 14
	label.AutomaticSize = Enum.AutomaticSize.Y
	return setmetatable({ Instance = label, Label = label }, BaseComponent)
end

function ModernUI.newInput(options: InputOptions)
	local frame = createBaseFrame("Input", options.Size or UDim2.new(1, 0, 0, 40), ModernUI.Theme.SurfaceAlt, 0, options.Color or ModernUI.Theme.Border)
	applyPadding(frame, 10)

	local box = Instance.new("TextBox")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Gotham
	box.PlaceholderText = options.Placeholder or "Type here..."
	box.PlaceholderColor3 = ModernUI.Theme.MutedText
	box.Text = ""
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextColor3 = options.TextColor or ModernUI.Theme.Text
	box.TextSize = 14
	box.Parent = frame

	box.FocusLost:Connect(function(enterPressed)
		if enterPressed and options.OnSubmit then
			options.OnSubmit(box.Text)
		end
	end)

	return setmetatable({ Instance = frame, Input = box }, BaseComponent)
end

function ModernUI.newDivider(options: DividerOptions?)
	options = options or {}
	local line = Instance.new("Frame")
	line.Name = "Divider"
	line.Size = options.Size or UDim2.new(1, 0, 0, options.Thickness or 1)
	line.BackgroundColor3 = options.Color or ModernUI.Theme.Border
	line.BackgroundTransparency = options.Transparency or 0.3
	line.BorderSizePixel = 0
	return setmetatable({ Instance = line }, BaseComponent)
end

function ModernUI.newSpacer(height: number?)
	local frame = Instance.new("Frame")
	frame.Name = "Spacer"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height or 8)
	return setmetatable({ Instance = frame }, BaseComponent)
end

function ModernUI.newBadge(text: string, color: Color3?, _radius: number?)
	local label = Instance.new("TextLabel")
	label.Name = "Badge"
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.BackgroundColor3 = color or ModernUI.Theme.Accent
	label.Text = "  " .. text .. "  "
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextColor3 = ModernUI.Theme.Text
	label.BorderSizePixel = 0
	applyCorner(label, 0)
	return setmetatable({ Instance = label, Label = label }, BaseComponent)
end

return ModernUI
