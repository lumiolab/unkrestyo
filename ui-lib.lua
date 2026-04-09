-- ModernUI.lua (ListLayout version)

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local ModernUI = {}

local Theme = {
    Surface = Color3.fromRGB(18,23,31),
    SurfaceAlt = Color3.fromRGB(24,30,40),
    Border = Color3.fromRGB(48,58,74),
    Text = Color3.fromRGB(245,247,250),
    Muted = Color3.fromRGB(160,170,185),
    Accent = Color3.fromRGB(93,135,255),
}

-- utils
local function stroke(obj)
    local s = Instance.new("UIStroke")
    s.Color = Theme.Border
    s.Transparency = 0.2
    s.Parent = obj
end

local function padding(obj, p)
    local pad = Instance.new("UIPadding")
    p = p or 10
    pad.PaddingTop = UDim.new(0,p)
    pad.PaddingBottom = UDim.new(0,p)
    pad.PaddingLeft = UDim.new(0,p)
    pad.PaddingRight = UDim.new(0,p)
    pad.Parent = obj
end

local function drag(handle, root)
    local dragging, start, pos

    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            start = i.Position
            pos = root.Position
        end
    end)

    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - start
            root.Position = UDim2.new(pos.X.Scale, pos.X.Offset + delta.X, pos.Y.Scale, pos.Y.Offset + delta.Y)
        end
    end)

    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

function ModernUI.CreateScreenGui(name)
    local g = Instance.new("ScreenGui")
    g.Name = name or "UI"
    g.ResetOnSpawn = false
    g.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    return g
end

function ModernUI.new(opts)
    local root = Instance.new("Frame")
    root.Size = opts.Size or UDim2.fromOffset(400,300)
    root.Position = opts.Position or UDim2.fromScale(0.5,0.5)
    root.AnchorPoint = opts.AnchorPoint or Vector2.new(0.5,0.5)
    root.BackgroundColor3 = Theme.Surface
    root.BorderSizePixel = 0
    stroke(root)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,30)
    bar.BackgroundColor3 = Theme.SurfaceAlt
    bar.Parent = root
    stroke(bar)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-10,1,0)
    title.Position = UDim2.fromOffset(5,0)
    title.BackgroundTransparency = 1
    title.Text = opts.Title or "Window"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Theme.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = bar

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1,0,1,-30)
    body.Position = UDim2.fromOffset(0,30)
    body.BackgroundTransparency = 1
    body.Parent = root

    padding(body, opts.Padding or 10)

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, opts.Spacing or 8)
    list.FillDirection = Enum.FillDirection.Vertical
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = body

    drag(bar, root)

    if opts.Parent then root.Parent = opts.Parent end

    local obj = {Instance = root, Content = body, _order = 0}

    function obj:Add(child)
        self._order += 1
        child.Instance.LayoutOrder = self._order
        child.Instance.Parent = self.Content
    end

    return obj
end

function ModernUI.newTitle(o)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,40)
    l.BackgroundTransparency = 1
    l.Text = o.Text
    l.Font = Enum.Font.GothamBold
    l.TextSize = o.Size or 20
    l.TextColor3 = Theme.Text
    l.TextXAlignment = Enum.TextXAlignment.Left
    return {Instance = l}
end

function ModernUI.newText(o)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,25)
    l.BackgroundTransparency = 1
    l.Text = o.Text or ""
    l.Font = Enum.Font.Gotham
    l.TextSize = o.Size or 14
    l.TextColor3 = o.Color or Theme.Muted
    l.TextXAlignment = Enum.TextXAlignment.Left

    return {
        Instance = l,
        SetText = function(_, t) l.Text = t end
    }
end

function ModernUI.newButton(o)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,40)
    b.Text = o.Text or "Button"
    b.BackgroundColor3 = o.Color or Theme.Accent
    b.TextColor3 = Theme.Text
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 14
    b.BorderSizePixel = 0

    b.MouseButton1Click:Connect(function()
        if o.Callback then o.Callback() end
    end)

    return {Instance = b}
end

function ModernUI.newInput(o)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,40)
    f.BackgroundColor3 = Theme.SurfaceAlt
    f.BorderSizePixel = 0
    stroke(f)
    padding(f,8)

    local box = Instance.new("TextBox")
    box.Size = UDim2.fromScale(1,1)
    box.BackgroundTransparency = 1
    box.PlaceholderText = o.Placeholder or ""
    box.Text = ""
    box.TextColor3 = Theme.Text
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.Parent = f

    box.FocusLost:Connect(function(enter)
        if enter and o.OnSubmit then
            o.OnSubmit(box.Text)
        end
    end)

    return {Instance = f}
end

return ModernUI
