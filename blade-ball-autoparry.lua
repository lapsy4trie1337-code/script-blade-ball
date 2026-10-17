-- Blade Ball Auto Parry
-- Renvoie la balle automatiquement quand elle se dirige vers toi

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Config
local PARRY_DISTANCE = 15
local ENABLED = true

-- UI toggle
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoParryGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Toggle = Instance.new("TextButton")
Toggle.Size = UDim2.new(0, 160, 0, 36)
Toggle.Position = UDim2.new(0, 10, 0, 10)
Toggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
Toggle.Font = Enum.Font.GothamBold
Toggle.TextSize = 14
Toggle.Text = "Auto Parry: ON"
Toggle.Parent = ScreenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = Toggle

Toggle.MouseButton1Click:Connect(function()
    ENABLED = not ENABLED
    Toggle.Text = ENABLED and "Auto Parry: ON" or "Auto Parry: OFF"
    Toggle.BackgroundColor3 = ENABLED and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
end)

-- Trouver la balle dans le workspace
local function findBall()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name == "Ball" or v.Name == "ball") then
            return v
        end
    end
    local ballsFolder = workspace:FindFirstChild("Balls")
    if ballsFolder then
        for _, v in pairs(ballsFolder:GetChildren()) do
            if v:IsA("BasePart") or v:IsA("Model") then
                if v:IsA("Model") then
                    return v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                end
                return v
            end
        end
    end
    return nil
end

-- Trouver le remote pour parry
local function findParryRemote()
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local name = v.Name:lower()
            if name == "parry" or name == "block" or name == "deflect" then
                return v
            end
        end
    end
    return nil
end

-- Verifier si la balle cible le joueur local
local function isBallTargetingMe(ball)
    local target = ball:GetAttribute("Target")
        or ball:GetAttribute("target")
        or ball:GetAttribute("CurrentTarget")

    if target then
        if typeof(target) == "Instance" then
            return target == LocalPlayer.Character
        end
        return tostring(target) == LocalPlayer.Name
            or tostring(target) == tostring(LocalPlayer.UserId)
    end

    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local vel = ball.AssemblyLinearVelocity or ball.Velocity
    if vel.Magnitude < 1 then return false end

    local toPlayer = (hrp.Position - ball.Position).Unit
    return vel.Unit:Dot(toPlayer) > 0.6
end

-- Parry
local parryRemote = findParryRemote()
local lastParry = 0

local function doParry()
    local now = tick()
    if now - lastParry < 0.4 then return end
    lastParry = now

    if parryRemote then
        parryRemote:FireServer()
        return
    end

    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.05)
        vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- Boucle principale
RunService.Heartbeat:Connect(function()
    if not ENABLED then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ball = findBall()
    if not ball then return end

    if not parryRemote then
        parryRemote = findParryRemote()
    end

    local distance = (ball.Position - hrp.Position).Magnitude

    if isBallTargetingMe(ball) and distance <= PARRY_DISTANCE then
        doParry()
    end
end)

print("[Auto Parry] Script charge avec succes!")
