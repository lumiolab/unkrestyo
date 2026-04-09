-- ModernUI.lua (Executor-safe version)
-- No Luau types, no chained calls, blocky UI, draggable

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ModernUI = {}
ModernUI.__index = ModernUI

ModernUI.Theme = {
	Surface = Color3.fromRGB(18,23,31),
	SurfaceAlt = Color3.fromRGB(24,30,40),
	Border = Color3.fromRGB(48,58,74),
	Text = Color3.fromRGB(245,247,250),
	MutedText = Color3.fromRGB(160,170,185),
	Accent = Color3.fromRGB(93,135,255),
}

local function applyCorner(inst)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0,0)
	c.Parent = inst
end

local function applyStroke(inst,color)
	local s = Instance.new("UIStroke")
	s.Color = color or ModernUI.Theme.Border
	s.Thickness = 1
	s.Transparency = 0.15
	s.Parent = inst
end

local function applyPadding(inst,p)
	local pad = Instance.new("UIPadding")
	p = p or 10
	pad.PaddingTop = UDim.new(0,p)
	pad.PaddingBottom = UDim.new(0,p)
	pad.PaddingLeft = UDim.new(0,p)
	pad.PaddingRight = UDim.new(0,p)
	pad.Parent = inst
end

local function quickTween(obj,props)
	local t = TweenService:Create(obj,TweenInfo.new(0.15),props)
	t:Play()
	return t
end

local function makeDraggable(handle,target)
	local dragging=false
	local startPos
	local dragStart

	handle.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging=true
			dragStart=input.Position
			startPos=target.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
			local delta=input.Position-dragStart
			target.Position=UDim2.new(
				startPos.X.Scale,startPos.X.Offset+delta.X,
				startPos.Y.Scale,startPos.Y.Offset+delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging=false
		end
	end)
end

function ModernUI.CreateScreenGui(name,parent)
	local g=Instance.new("ScreenGui")
	g.Name=name or "ModernUI"
	g.ResetOnSpawn=false
	g.Parent=parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	return g
end

function ModernUI.new(opts)
	local root=Instance.new("Frame")
	root.Size=opts.Size or UDim2.fromOffset(400,300)
	root.Position=opts.Position or UDim2.fromScale(0.5,0.5)
	root.AnchorPoint=opts.AnchorPoint or Vector2.new(0.5,0.5)
	root.BackgroundColor3=opts.BackgroundColor or ModernUI.Theme.Surface
	root.BorderSizePixel=0
	applyCorner(root)
	applyStroke(root)

	local bar=Instance.new("Frame")
	bar.Size=UDim2.new(1,0,0,30)
	bar.BackgroundColor3=ModernUI.Theme.SurfaceAlt
	bar.Parent=root
	applyStroke(bar)

	local title=Instance.new("TextLabel")
	title.Size=UDim2.new(1,-10,1,0)
	title.Position=UDim2.fromOffset(5,0)
	title.BackgroundTransparency=1
	title.Text=opts.Title or "Window"
	title.TextColor3=ModernUI.Theme.Text
	title.Font=Enum.Font.GothamBold
	title.TextSize=14
	title.TextXAlignment=Enum.TextXAlignment.Left
	title.Parent=bar

	local body=Instance.new("Frame")
	body.Size=UDim2.new(1,0,1,-30)
	body.Position=UDim2.fromOffset(0,30)
	body.BackgroundTransparency=1
	body.Parent=root

	applyPadding(body,opts.Padding or 10)

	local grid=Instance.new("UIGridLayout")
	grid.CellPadding=UDim2.fromOffset(opts.CellPadding or 8,opts.CellPadding or 8)
	grid.CellSize=opts.CellSize or UDim2.new(1,0,0,40)
	grid.FillDirection=(opts.Orientation=="Horizontal") and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	grid.Parent=body

	makeDraggable(bar,root)

	if opts.Parent then root.Parent=opts.Parent end

	local obj={Instance=root,Content=body}

	function obj:Add(child)
		child.Instance.Parent=body
	end

	return obj
end

function ModernUI.newText(o)
	local l=Instance.new("TextLabel")
	l.BackgroundTransparency=1
	l.Size=UDim2.new(1,0,0,20)
	l.Text=o.Text or ""
	l.TextColor3=o.Color or ModernUI.Theme.MutedText
	l.Font=Enum.Font.Gotham
	l.TextSize=o.Size or 14
	l.TextXAlignment=Enum.TextXAlignment.Left
	return {Instance=l,SetText=function(_,t) l.Text=t end}
end

function ModernUI.newTitle(o)
	local l=Instance.new("TextLabel")
	l.BackgroundTransparency=1
	l.Size=UDim2.new(1,0,0,24)
	l.Text=o.Text
	l.TextColor3=o.Color or ModernUI.Theme.Text
	l.Font=Enum.Font.GothamBold
	l.TextSize=o.Size or 20
	l.TextXAlignment=Enum.TextXAlignment.Left
	return {Instance=l}
end

function ModernUI.newButton(o)
	local b=Instance.new("TextButton")
	b.Size=UDim2.new(1,0,0,40)
	b.Text=o.Text or "Button"
	b.BackgroundColor3=o.Color or ModernUI.Theme.Accent
	b.TextColor3=ModernUI.Theme.Text
	b.Font=Enum.Font.GothamMedium
	b.TextSize=14
	b.BorderSizePixel=0
	applyCorner(b)

	b.MouseEnter:Connect(function()
		quickTween(b,{BackgroundTransparency=0.1})
	end)
	b.MouseLeave:Connect(function()
		quickTween(b,{BackgroundTransparency=0})
	end)

	b.MouseButton1Click:Connect(function()
		if o.Callback then o.Callback() end
	end)

	return {Instance=b}
end

function ModernUI.newInput(o)
	local f=Instance.new("Frame")
	f.Size=UDim2.new(1,0,0,40)
	f.BackgroundColor3=ModernUI.Theme.SurfaceAlt
	f.BorderSizePixel=0
	applyCorner(f)
	applyStroke(f)
	applyPadding(f,8)

	local box=Instance.new("TextBox")
	box.Size=UDim2.fromScale(1,1)
	box.BackgroundTransparency=1
	box.PlaceholderText=o.Placeholder or ""
	box.Text=""
	box.TextColor3=ModernUI.Theme.Text
	box.Font=Enum.Font.Gotham
	box.TextSize=14
	box.Parent=f

	box.FocusLost:Connect(function(enter)
		if enter and o.OnSubmit then
			o.OnSubmit(box.Text)
		end
	end)

	return {Instance=f}
end

function ModernUI.newToggle(o)
	local f=Instance.new("Frame")
	f.Size=UDim2.new(1,0,0,40)
	f.BackgroundColor3=ModernUI.Theme.SurfaceAlt
	f.BorderSizePixel=0
	applyCorner(f)
	applyStroke(f)
	applyPadding(f,8)

	local label=Instance.new("TextLabel")
	label.Size=UDim2.new(1,-50,1,0)
	label.BackgroundTransparency=1
	label.Text=o.Text or "Toggle"
	label.TextColor3=ModernUI.Theme.Text
	label.Font=Enum.Font.Gotham
	label.TextSize=14
	label.TextXAlignment=Enum.TextXAlignment.Left
	label.Parent=f

	local btn=Instance.new("TextButton")
	btn.Size=UDim2.fromOffset(40,20)
	btn.Position=UDim2.new(1,-45,0.5,-10)
	btn.Text=""
	btn.BackgroundColor3=ModernUI.Theme.Border
	btn.Parent=f
	applyCorner(btn)

	local state=false

	btn.MouseButton1Click:Connect(function()
		state=not state
		btn.BackgroundColor3=state and (o.Color or ModernUI.Theme.Accent) or ModernUI.Theme.Border
		if o.Callback then o.Callback(state) end
	end)

	return {Instance=f}
end

return ModernUI
