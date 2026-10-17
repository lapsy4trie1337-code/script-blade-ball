-- Blade Ball Auto Parry v2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ═══════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════
local Config = {
    Enabled = true,
    ParryDistance = 14,
    MinDistance = 5,
    KeyToggle = Enum.KeyCode.RightShift,
    KeyGui = Enum.KeyCode.RightControl,
}

-- ═══════════════════════════════════════
--  CACHE (pas de scan chaque frame)
-- ═══════════════════════════════════════
local cachedBall = nil
local cachedRemote = nil
local lastParry = 0
local parryCount = 0

local function grabRemote()
    if cachedRemote then return cachedRemote end
    for _, v in pairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("parry") or n:find("block") or n:find("deflect") or n:find("ability") then
                cachedRemote = v
                return v
            end
        end
    end
    return nil
end

-- Observer la balle au lieu de scanner chaque frame
local function onAdded(obj)
    if obj:IsA("BasePart") and (obj.Name == "Ball" or obj.Name == "ball") then
        cachedBall = obj
    end
end

local function onRemoved(obj)
    if obj == cachedBall then
        cachedBall = nil
    end
end

workspace.DescendantAdded:Connect(onAdded)
workspace.DescendantRemoving:Connect(onRemoved)

for _, v in pairs(workspace:GetDescendants()) do
    if v:IsA("BasePart") and (v.Name == "Ball" or v.Name == "ball") then
        cachedBall = v
        break
    end
end

grabRemote()

-- ═══════════════════════════════════════
--  DETECTION
-- ═══════════════════════════════════════
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isBallComingAtMe(ball)
    local hrp = getHRP()
    if not hrp then return false, math.huge end

    local dist = (ball.Position - hrp.Position).Magnitude

    local target = ball:GetAttribute("Target")
        or ball:GetAttribute("target")
        or ball:GetAttribute("CurrentTarget")

    if target then
        local isMe = false
        if typeof(target) == "Instance" then
            isMe = target == LP.Character
        elseif typeof(target) == "string" then
            isMe = target == LP.Name
        elseif typeof(target) == "number" then
            isMe = target == LP.UserId
        end
        return isMe, dist
    end

    local vel = ball.AssemblyLinearVelocity
    if vel.Magnitude < 5 then return false, dist end

    local dir = (hrp.Position - ball.Position).Unit
    return vel.Unit:Dot(dir) > 0.7, dist
end

local function doParry()
    local now = tick()
    if now - lastParry < 0.35 then return end
    lastParry = now
    parryCount += 1

    local remote = grabRemote()
    if remote then
        remote:FireServer()
    end
end

-- ═══════════════════════════════════════
--  GUI PANEL
-- ═══════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "AP_" .. tostring(math.random(1000, 9999))
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function create(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then obj[k] = v end
    end
    if props.Parent then obj.Parent = props.Parent end
    return obj
end

local function addCorner(parent, r)
    create("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = parent })
end

-- Panel principal
local panel = create("Frame", {
    Size = UDim2.new(0, 260, 0, 310),
    Position = UDim2.new(0, 16, 0.5, -155),
    BackgroundColor3 = Color3.fromRGB(18, 18, 22),
    BackgroundTransparency = 0.05,
    Parent = gui,
})
addCorner(panel, 10)
create("UIStroke", { Color = Color3.fromRGB(60, 60, 70), Thickness = 1, Parent = panel })

-- Titre
local titleBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Color3.fromRGB(25, 25, 32),
    Parent = panel,
})
addCorner(titleBar, 10)

create("TextLabel", {
    Size = UDim2.new(1, -16, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "AUTO PARRY",
    TextColor3 = Color3.fromRGB(220, 220, 230),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = titleBar,
})

-- Status
local statusLabel = create("TextLabel", {
    Size = UDim2.new(1, -24, 0, 18),
    Position = UDim2.new(0, 12, 0, 44),
    BackgroundTransparency = 1,
    Text = "ON",
    TextColor3 = Color3.fromRGB(0, 200, 80),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = panel,
})

-- Stats
local statsLabel = create("TextLabel", {
    Size = UDim2.new(1, -24, 0, 16),
    Position = UDim2.new(0, 12, 0, 64),
    BackgroundTransparency = 1,
    Text = "Parrys: 0",
    TextColor3 = Color3.fromRGB(140, 140, 155),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = panel,
})

-- Separateur
create("Frame", {
    Size = UDim2.new(1, -24, 0, 1),
    Position = UDim2.new(0, 12, 0, 88),
    BackgroundColor3 = Color3.fromRGB(45, 45, 55),
    BorderSizePixel = 0,
    Parent = panel,
})

-- Slider
local function makeSlider(parent, label, min, max, default, yPos, callback)
    create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 12, 0, yPos),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(170, 170, 185),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })

    local valLabel = create("TextLabel", {
        Size = UDim2.new(0, 40, 0, 16),
        Position = UDim2.new(1, -52, 0, yPos),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = Color3.fromRGB(200, 200, 210),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = parent,
    })

    local track = create("Frame", {
        Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.new(0, 12, 0, yPos + 22),
        BackgroundColor3 = Color3.fromRGB(40, 40, 50),
        Parent = parent,
    })
    addCorner(track, 3)

    local fill = create("Frame", {
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(90, 130, 255),
        Parent = track,
    })
    addCorner(fill, 3)

    local knob = create("TextButton", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(220, 220, 230),
        Text = "",
        Parent = track,
    })
    addCorner(knob, 7)

    local dragging = false

    knob.MouseButton1Down:Connect(function()
        dragging = true
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local absPos = track.AbsolutePosition.X
            local absSize = track.AbsoluteSize.X
            local rel = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
            local val = math.floor(min + rel * (max - min))

            fill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, -7, 0.5, -7)
            valLabel.Text = tostring(val)
            callback(val)
        end
    end)
end

-- Toggle
local function makeToggle(parent, label, default, yPos, callback)
    create("TextLabel", {
        Size = UDim2.new(1, -60, 0, 20),
        Position = UDim2.new(0, 12, 0, yPos),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(170, 170, 185),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })

    local bg = create("Frame", {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(1, -48, 0, yPos + 1),
        BackgroundColor3 = default and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(50, 50, 60),
        Parent = parent,
    })
    addCorner(bg, 9)

    local dot = create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = default and UDim2.new(1, -16, 0, 2) or UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Color3.fromRGB(230, 230, 240),
        Parent = bg,
    })
    addCorner(dot, 7)

    local state = default
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = bg,
    })

    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(bg, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(50, 50, 60),
        }):Play()
        TweenService:Create(dot, TweenInfo.new(0.2), {
            Position = state and UDim2.new(1, -16, 0, 2) or UDim2.new(0, 2, 0, 2),
        }):Play()
        callback(state)
    end)
end

makeSlider(panel, "Distance Parry", 5, 30, Config.ParryDistance, 98, function(v)
    Config.ParryDistance = v
end)

makeSlider(panel, "Distance Min", 1, 15, Config.MinDistance, 140, function(v)
    Config.MinDistance = v
end)

makeToggle(panel, "Auto Parry", Config.Enabled, 185, function(v)
    Config.Enabled = v
    statusLabel.Text = v and "ON" or "OFF"
    statusLabel.TextColor3 = v and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 60, 60)
end)

-- Keybinds
create("Frame", {
    Size = UDim2.new(1, -24, 0, 1),
    Position = UDim2.new(0, 12, 0, 220),
    BackgroundColor3 = Color3.fromRGB(45, 45, 55),
    BorderSizePixel = 0,
    Parent = panel,
})

create("TextLabel", {
    Size = UDim2.new(1, -24, 0, 50),
    Position = UDim2.new(0, 12, 0, 230),
    BackgroundTransparency = 1,
    Text = "RShift  -  Toggle ON/OFF\nRCtrl   -  Cacher/Montrer",
    TextColor3 = Color3.fromRGB(100, 100, 115),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    LineHeight = 1.5,
    Parent = panel,
})

-- Drag
local dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = input.Position
        startPos = panel.Position
    end
end)

titleBar.InputChanged:Connect(function(input)
    if dragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = nil
    end
end)

-- Raccourcis
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.KeyToggle then
        Config.Enabled = not Config.Enabled
        statusLabel.Text = Config.Enabled and "ON" or "OFF"
        statusLabel.TextColor3 = Config.Enabled and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 60, 60)
    elseif input.KeyCode == Config.KeyGui then
        panel.Visible = not panel.Visible
    end
end)

gui.Parent = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════
--  BOUCLE PRINCIPALE
-- ═══════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not Config.Enabled then return end
    if not cachedBall or not cachedBall.Parent then return end

    local targeting, dist = isBallComingAtMe(cachedBall)
    if not targeting then return end

    if dist <= Config.ParryDistance and dist >= Config.MinDistance then
        doParry()
        statsLabel.Text = "Parrys: " .. parryCount
    end
end)

print("[Auto Parry v2] OK")
