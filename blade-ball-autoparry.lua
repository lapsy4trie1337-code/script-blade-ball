-- Auto Parry v23
-- Base sur un script qui marche : workspace.Balls + distance = parry
-- Mode Normal (rouge + dist) / Entrainement (dist seul)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local function rkey()
    local s = ""
    for _ = 1, 16 do s = s .. string.char(math.random(97, 122)) end
    return s
end
local RK = rkey()

local actif = true
local modeEntrainement = false
local dernierP = 0
local compteur = 0
local streak = 0
local best = 0
local ouvert = true
local charRouge = false

-- Personnage
local cachedChar = LP.Character
local cachedHRP = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")

local function onChar(c)
    cachedChar = c
    c:WaitForChild("HumanoidRootPart", 5)
    cachedHRP = c:FindFirstChild("HumanoidRootPart")
end
if cachedChar then task.spawn(function() onChar(cachedChar) end) end
LP.CharacterAdded:Connect(onChar)
LP.CharacterRemoving:Connect(function() cachedChar = nil; cachedHRP = nil; charRouge = false end)

-- Rouge: Highlight sur le personnage
local function checkRouge()
    charRouge = false
    if not cachedChar then return end
    local ok, desc = pcall(cachedChar.GetDescendants, cachedChar)
    if not ok then return end
    for _, ch in pairs(desc) do
        if ch:IsA("Highlight") then
            charRouge = true; return
        end
    end
end

-- Balls folder
local ballsFolder = nil
task.spawn(function()
    local ok, f = pcall(workspace.WaitForChild, workspace, "Balls", 60)
    if ok and f then ballsFolder = f end
end)

-- Parry
local function doParry()
    local now = tick()
    if now - dernierP < 0.3 then return false end
    dernierP = now
    compteur = compteur + 1
    streak = streak + 1
    if streak > best then best = streak end
    pcall(mouse1click)
    return true
end

-- Anti AFK
task.spawn(function()
    while true do
        task.wait(180)
        if cachedHRP then pcall(function() cachedHRP.CFrame = cachedHRP.CFrame end) end
    end
end)

-- ═══════════════════════════════════════
--  GUI
-- ═══════════════════════════════════════
local ACCENT = Color3.fromRGB(90, 120, 255)
local GREEN  = Color3.fromRGB(45, 210, 90)
local RED    = Color3.fromRGB(230, 55, 55)
local ORANGE = Color3.fromRGB(255, 165, 40)
local YELLOW = Color3.fromRGB(255, 220, 50)
local CYAN   = Color3.fromRGB(50, 200, 220)
local BG1    = Color3.fromRGB(10, 10, 18)
local BG2    = Color3.fromRGB(18, 18, 28)
local BG3    = Color3.fromRGB(28, 28, 40)
local BG4    = Color3.fromRGB(38, 38, 54)
local BORD   = Color3.fromRGB(42, 42, 62)
local TXT1   = Color3.fromRGB(235, 235, 248)
local TXT2   = Color3.fromRGB(155, 155, 180)
local TXT3   = Color3.fromRGB(95, 95, 125)

local gui = Instance.new("ScreenGui")
gui.Name = rkey()
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function mk(c, p)
    local o = Instance.new(c)
    for k, v in pairs(p) do
        if k ~= "Parent" then pcall(function() o[k] = v end) end
    end
    if p.Parent then o.Parent = p.Parent end
    return o
end
local function rnd(p, r)
    mk("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = p})
end

local W = 300
local H_OPEN = 320
local H_CLOSED = 42

local panel = mk("Frame", {
    Size = UDim2.new(0, W, 0, H_OPEN),
    Position = UDim2.new(0, 14, 0.5, -H_OPEN / 2),
    BackgroundColor3 = BG1, BackgroundTransparency = 0.02,
    ClipsDescendants = true, Parent = gui,
})
rnd(panel, 12)
mk("UIStroke", {Color = BORD, Thickness = 1, Parent = panel})

local hdr = mk("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = BG2, Parent = panel})
rnd(hdr, 12)
mk("Frame", {Size = UDim2.new(1, -20, 0, 2), Position = UDim2.new(0, 10, 0, 0), BackgroundColor3 = ACCENT, Parent = hdr})
local statusDot = mk("Frame", {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, 12, 0, 16), BackgroundColor3 = GREEN, Parent = hdr})
rnd(statusDot, 5)
local statusLbl = mk("TextLabel", {Size = UDim2.new(0, 50, 0, 14), Position = UDim2.new(0, 28, 0, 14), BackgroundTransparency = 1, Text = "ACTIF", TextColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
mk("TextLabel", {Size = UDim2.new(0, 130, 0, 14), Position = UDim2.new(0, 80, 0, 14), BackgroundTransparency = 1, Text = "AUTO PARRY v23", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
local btnMin = mk("TextButton", {Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -34, 0, 8), BackgroundColor3 = BG4, Text = "-", TextColor3 = TXT2, Font = Enum.Font.GothamBold, TextSize = 14, Parent = hdr})
rnd(btnMin, 7)
btnMin.MouseButton1Click:Connect(function()
    ouvert = not ouvert
    btnMin.Text = ouvert and "-" or "+"
    TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {
        Size = UDim2.new(0, W, 0, ouvert and H_OPEN or H_CLOSED)
    }):Play()
end)

local function sect(y, titre, h)
    local c = mk("Frame", {Size = UDim2.new(1, -20, 0, h), Position = UDim2.new(0, 10, 0, y), BackgroundColor3 = BG2, Parent = panel})
    rnd(c, 9)
    mk("TextLabel", {Size = UDim2.new(1, -14, 0, 10), Position = UDim2.new(0, 7, 0, 5), BackgroundTransparency = 1, Text = string.upper(titre), TextColor3 = ACCENT, Font = Enum.Font.GothamBold, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left, Parent = c})
    return c
end

-- MODE
local mc = sect(48, "Mode", 32)
local btnNormal = mk("TextButton", {Size = UDim2.new(0.45, 0, 0, 18), Position = UDim2.new(0, 7, 0, 14), BackgroundColor3 = ACCENT, Text = "Normal", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 10, Parent = mc})
rnd(btnNormal, 6)
local btnTrain = mk("TextButton", {Size = UDim2.new(0.45, 0, 0, 18), Position = UDim2.new(0.5, 7, 0, 14), BackgroundColor3 = BG4, Text = "Entrainement", TextColor3 = TXT2, Font = Enum.Font.GothamBold, TextSize = 10, Parent = mc})
rnd(btnTrain, 6)
local function majMode()
    if modeEntrainement then
        btnNormal.BackgroundColor3 = BG4; btnNormal.TextColor3 = TXT2
        btnTrain.BackgroundColor3 = CYAN; btnTrain.TextColor3 = TXT1
    else
        btnNormal.BackgroundColor3 = ACCENT; btnNormal.TextColor3 = TXT1
        btnTrain.BackgroundColor3 = BG4; btnTrain.TextColor3 = TXT2
    end
end
btnNormal.MouseButton1Click:Connect(function() modeEntrainement = false; majMode() end)
btnTrain.MouseButton1Click:Connect(function() modeEntrainement = true; majMode() end)

-- STATS
local sc = sect(86, "Stats", 46)
local bw = math.floor((W - 20 - 16) / 3)
local function sbox(parent, x, lbl, col)
    mk("TextLabel", {Size = UDim2.new(0, bw, 0, 8), Position = UDim2.new(0, x, 0, 17), BackgroundTransparency = 1, Text = string.upper(lbl), TextColor3 = col, Font = Enum.Font.GothamBold, TextSize = 7, Parent = parent})
    return mk("TextLabel", {Size = UDim2.new(0, bw, 0, 16), Position = UDim2.new(0, x, 0, 26), BackgroundTransparency = 1, Text = "0", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 15, Parent = parent})
end
local lP = sbox(sc, 7, "Parrys", ACCENT)
local lS = sbox(sc, 7 + bw + 8, "Streak", ORANGE)
local lB = sbox(sc, 7 + bw * 2 + 16, "Record", YELLOW)

-- BALLE
local bc = sect(138, "Balle", 52)
local lBalle = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 18), BackgroundTransparency = 1, Text = "Recherche...", TextColor3 = ORANGE, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lInfo = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 32), BackgroundTransparency = 1, Text = "", TextColor3 = TXT2, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})

-- TOGGLE
local tBg = mk("Frame", {Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 196), BackgroundColor3 = GREEN, Parent = panel})
rnd(tBg, 9)
local tBtn = mk("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "ACTIF — Cliquer pour desactiver", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 11, Parent = tBg})
local function majToggle()
    tBg.BackgroundColor3 = actif and GREEN or RED
    tBtn.Text = actif and "ACTIF — Cliquer pour desactiver" or "INACTIF — Cliquer pour activer"
    statusLbl.Text = actif and "ACTIF" or "INACTIF"
    statusLbl.TextColor3 = actif and GREEN or RED
    statusDot.BackgroundColor3 = actif and GREEN or RED
end
tBtn.MouseButton1Click:Connect(function() actif = not actif; majToggle() end)

-- INFO
local ic = sect(230, "Info", 38)
mk("TextLabel", {
    Size = UDim2.new(1, -14, 0, 22), Position = UDim2.new(0, 7, 0, 12),
    BackgroundTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Normal: rouge + dist | Train: dist seule\nRShift = On/Off  |  RCtrl = Masquer",
    TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 8, Parent = ic,
})

-- BOUTONS
local btnRst = mk("TextButton", {Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 0, 274), BackgroundColor3 = BG3, Text = "Reset stats", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnRst, 6)
btnRst.MouseButton1Click:Connect(function() compteur = 0; streak = 0; best = 0 end)

mk("TextLabel", {Size = UDim2.new(1, -20, 0, 12), Position = UDim2.new(0, 10, 0, 302), BackgroundTransparency = 1, Text = "v23 | Normal + Entrainement", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 7, Parent = panel})

local flash = mk("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = GREEN, BackgroundTransparency = 1, ZIndex = 100, Parent = gui})

-- DRAG
local dd, sp
hdr.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = i.Position; sp = panel.Position end
end)
hdr.InputChanged:Connect(function(i)
    if dd and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d2 = i.Position - dd
        panel.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d2.X, sp.Y.Scale, sp.Y.Offset + d2.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = nil end
end)
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        actif = not actif; majToggle()
    elseif input.KeyCode == Enum.KeyCode.RightControl then
        panel.Visible = not panel.Visible
    end
end)

gui.Parent = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════
--  CORE — simple comme le script de reference
--
--  Chaque frame:
--  1. Cherche balles dans workspace.Balls
--  2. Normal: realBall + (rouge OU dist < 8) + dist < 13 → parry
--  3. Entrainement: toute balle + dist < 13 → parry
-- ═══════════════════════════════════════
local uiDist = 9999
local uiBalle = false
local frameN = 0

RunService.Heartbeat:Connect(function()
    frameN = frameN + 1
    if not actif then return end
    if not cachedChar or not cachedChar.Parent then return end
    if not cachedHRP then return end

    -- Rouge check toutes les 2 frames
    if frameN % 2 == 0 then checkRouge() end

    -- Chercher le folder
    if not ballsFolder then
        local ok, f = pcall(workspace.FindFirstChild, workspace, "Balls")
        if ok and f then ballsFolder = f end
    end
    if not ballsFolder then return end

    local hPos = cachedHRP.Position
    local closestDist = 9999
    local didParry = false

    local ok, children = pcall(ballsFolder.GetChildren, ballsFolder)
    if not ok then return end

    for _, ball in pairs(children) do
        if not ball:IsA("BasePart") then continue end

        local okPos, bPos = pcall(function() return ball.Position end)
        if not okPos then continue end

        local dist = (bPos - hPos).Magnitude
        if dist < closestDist then closestDist = dist end

        if didParry then continue end

        if modeEntrainement then
            -- Entrainement: toute balle non-anchored + distance
            if not ball.Anchored and dist <= 13 then
                if doParry() then
                    didParry = true
                    pcall(function()
                        flash.BackgroundTransparency = 0.8
                        TweenService:Create(flash, TweenInfo.new(0.06), {BackgroundTransparency = 1}):Play()
                    end)
                end
            end
        else
            -- Normal: realBall + (rouge OU tres proche) + distance
            local okAttr, isReal = pcall(ball.GetAttribute, ball, "realBall")
            if okAttr and isReal == true then
                if dist <= 13 and (charRouge or dist <= 8) then
                    if doParry() then
                        didParry = true
                        pcall(function()
                            flash.BackgroundTransparency = 0.8
                            TweenService:Create(flash, TweenInfo.new(0.06), {BackgroundTransparency = 1}):Play()
                        end)
                    end
                end
            end
        end
    end

    uiDist = closestDist
    uiBalle = closestDist < 9999

    if not didParry and closestDist > 50 then streak = 0 end

    -- UI
    if frameN % 20 ~= 0 then return end
    lP.Text = tostring(compteur)
    lS.Text = tostring(streak)
    lB.Text = tostring(best)

    if not uiBalle then
        lBalle.Text = "Recherche..."
        lBalle.TextColor3 = ORANGE
        lInfo.Text = ""
    else
        lBalle.Text = "Balle detectee"
        lBalle.TextColor3 = GREEN
        lInfo.Text = "Dist " .. math.floor(uiDist) .. (charRouge and " | ROUGE" or " | Surveillance")
    end
end)

print("[AutoParry] v23 | Simple + Fiable")
