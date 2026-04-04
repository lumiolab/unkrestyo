local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local ACCENT  = Color3.fromRGB(255,200,0)
local WHITE   = Color3.fromRGB(240,240,240)
local BG      = Color3.fromRGB(18,18,24)
local CARD    = Color3.fromRGB(28,28,38)
local OFF_CLR = Color3.fromRGB(50,50,65)

local autoGrabEnabled = false
local isGrabbing = false
local grabStartTime = nil
local autoGrabConn = nil
local progressConn = nil
local GRAB_RADIUS = 20
local GRAB_DURATION = 0.35

local animalCache = {}
local promptCache = {}
local grabCache = {}

local CONFIG_KEY = "TicGrab_Config"

local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- GRAB MECHANICS
local function isMyBase(plotName)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(plotName)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if not sign then return false end
    local yb = sign:FindFirstChild("YourBase")
    return yb and yb:IsA("BillboardGui") and yb.Enabled == true
end

local function scanPlot(plot)
    if not plot or not plot:IsA("Model") then return end
    if isMyBase(plot.Name) then return end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return end
    for _, pod in ipairs(podiums:GetChildren()) do
        if pod:IsA("Model") and pod:FindFirstChild("Base") then
            table.insert(animalCache, {
                plot = plot.Name,
                slot = pod.Name,
                worldPosition = pod:GetPivot().Position,
                uid = plot.Name .. "_" .. pod.Name
            })
        end
    end
end

local function findPromptForAnimal(ad)
    if not ad then return nil end
    local cp = promptCache[ad.uid]
    if cp and cp.Parent then return cp end
    
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local plot = plots:FindFirstChild(ad.plot)
    if not plot then return nil end
    local pods = plot:FindFirstChild("AnimalPodiums")
    if not pods then return nil end
    local pod = pods:FindFirstChild(ad.slot)
    if not pod then return nil end
    local base = pod:FindFirstChild("Base")
    if not base then return nil end
    local sp = base:FindFirstChild("Spawn")
    if not sp then return nil end
    local att = sp:FindFirstChild("PromptAttachment")
    if not att then return nil end
    
    for _, p in ipairs(att:GetChildren()) do
        if p:IsA("ProximityPrompt") then
            promptCache[ad.uid] = p
            return p
        end
    end
end

local function buildCallbacks(prompt)
    if grabCache[prompt] then return end
    local data = { hold = {}, trigger = {}, ready = true }
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                if type(c.Function) == "function" then
                    table.insert(data.hold, c.Function)
                end
            end
            for _, c in ipairs(getconnections(prompt.Triggered)) do
                if type(c.Function) == "function" then
                    table.insert(data.trigger, c.Function)
                end
            end
        end
    end)
    if #data.hold > 0 or #data.trigger > 0 then
        grabCache[prompt] = data
    end
end

local function execGrab(prompt)
    local data = grabCache[prompt]
    if not data or not data.ready then return false end
    data.ready = false
    isGrabbing = true
    grabStartTime = tick()
    
    task.spawn(function()
        for _, f in ipairs(data.hold) do
            task.spawn(f)
        end
        task.wait(GRAB_DURATION)
        for _, f in ipairs(data.trigger) do
            task.spawn(f)
        end
        data.ready = true
        isGrabbing = false
    end)
    return true
end

local function nearestAnimal()
    local h = getHRP()
    if not h then return nil end
    local best, bestD = nil, math.huge
    for _, ad in ipairs(animalCache) do
        if not isMyBase(ad.plot) and ad.worldPosition then
            local d = (h.Position - ad.worldPosition).Magnitude
            if d < bestD then
                bestD = d
                best = ad
            end
        end
    end
    return best
end

local function startAutoGrab()
    if autoGrabConn then return end
    autoGrabConn = RunService.Heartbeat:Connect(function()
        if not autoGrabEnabled or isGrabbing then return end
        local target = nearestAnimal()
        if not target then return end
        local h = getHRP()
        if not h then return end
        if (h.Position - target.worldPosition).Magnitude > GRAB_RADIUS then return end
        
        local prompt = promptCache[target.uid]
        if not prompt or not prompt.Parent then
            prompt = findPromptForAnimal(target)
        end
        if prompt then
            buildCallbacks(prompt)
            execGrab(prompt)
        end
    end)
end

local function stopAutoGrab()
    if autoGrabConn then
        autoGrabConn:Disconnect()
        autoGrabConn = nil
    end
    isGrabbing = false
end

-- Scan plots on startup
task.spawn(function()
    task.wait(2)
    local plots = workspace:WaitForChild("Plots", 10)
    if not plots then return end
    
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") then
            scanPlot(plot)
        end
    end
    
    plots.ChildAdded:Connect(function(plot)
        if plot:IsA("Model") then
            task.wait(0.5)
            scanPlot(plot)
        end
    end)
    
    task.spawn(function()
        while task.wait(5) do
            animalCache = {}
            for _, plot in ipairs(plots:GetChildren()) do
                if plot:IsA("Model") then
                    scanPlot(plot)
                end
            end
        end
    end)
end)

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TicGrab"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 200)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
MainFrame.BackgroundColor3 = BG
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 20)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 2
MainStroke.Color = ACCENT
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1, 0, 0, 52)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 20)

local TitleLbl = Instance.new("TextLabel", TitleBar)
TitleLbl.Size = UDim2.new(1, 0, 1, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "TicGrab"
TitleLbl.Font = Enum.Font.GothamBlack
TitleLbl.TextSize = 22
TitleLbl.TextColor3 = ACCENT
TitleLbl.TextStrokeColor3 = WHITE
TitleLbl.TextStrokeTransparency = 0.7

local ScrollFrame = Instance.new("ScrollingFrame", MainFrame)
ScrollFrame.Size = UDim2.new(1, -20, 1, -100)
ScrollFrame.Position = UDim2.new(0, 10, 0, 60)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = ACCENT
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local UIListLayout = Instance.new("UIListLayout", ScrollFrame)
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Toggle function
local function makeToggle(parent, name, order, callback)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = CARD
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)
    
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = WHITE
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local pW, pH, dSz = 46, 24, 18
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0, pW, 0, pH)
    track.Position = UDim2.new(1, -(pW + 12), 0.5, -pH / 2)
    track.BackgroundColor3 = OFF_CLR
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    
    local dot = Instance.new("Frame", track)
    dot.Size = UDim2.new(0, dSz, 0, dSz)
    dot.Position = UDim2.new(0, 3, 0.5, -dSz / 2)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    
    local state = false
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    
    btn.MouseButton1Click:Connect(function()
        state = not state
        track.BackgroundColor3 = state and ACCENT or OFF_CLR
        dot.Position = state and UDim2.new(1, -dSz - 3, 0.5, -dSz / 2) or UDim2.new(0, 3, 0.5, -dSz / 2)
        if callback then callback(state) end
    end)
    
    return row
end

-- Grab Radius input
local function makeNumInput(parent, labelText, defaultVal, order, onChanged)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = CARD
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)
    
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -90, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = WHITE
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local box = Instance.new("TextBox", row)
    box.Size = UDim2.new(0, 68, 0, 28)
    box.Position = UDim2.new(1, -78, 0.5, -14)
    box.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    box.Text = tostring(defaultVal)
    box.TextColor3 = ACCENT
    box.Font = Enum.Font.GothamBold
    box.TextSize = 13
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            if onChanged then onChanged(n) end
        else
            box.Text = tostring(defaultVal)
        end
    end)
    
    return row, box
end

makeToggle(ScrollFrame, "Auto Grab", 1, function(v)
    autoGrabEnabled = v
    if v then
        startAutoGrab()
    else
        stopAutoGrab()
    end
end)

makeNumInput(ScrollFrame, "Grab Radius", GRAB_RADIUS, 2, function(v)
    GRAB_RADIUS = math.clamp(v, 5, 200)
end)

makeNumInput(ScrollFrame, "Grab Duration", GRAB_DURATION, 3, function(v)
    GRAB_DURATION = math.max(0.05, v)
end)

-- Discord label
local DiscordLbl = Instance.new("TextLabel", MainFrame)
DiscordLbl.Size = UDim2.new(1, 0, 0, 18)
DiscordLbl.Position = UDim2.new(0, 0, 1, -22)
DiscordLbl.BackgroundTransparency = 1
DiscordLbl.Text = "made by lumio with <3"
DiscordLbl.Font = Enum.Font.GothamBold
DiscordLbl.TextSize = 11
DiscordLbl.TextColor3 = ACCENT


local dragging, dragStart, startPos = false, nil, nil
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)


UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == Enum.KeyCode.V then
        autoGrabEnabled = not autoGrabEnabled
        if autoGrabEnabled then
            startAutoGrab()
        else
            stopAutoGrab()
        end
    end
end)

print("TicGrab loaded 💛")
