-- Auto Parry v12 — Ultra Reactif + Prediction

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local lpName = LP.Name
local lpId = LP.UserId
local lpIdStr = tostring(lpId)

local function rkey()
    local s = ""
    for _ = 1, 16 do s = s .. string.char(math.random(97,122)) end
    return s
end
local RK1 = rkey()
local RK2 = rkey()

-- ═══════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════
local C = {
    Active = true,
    Sensibilite = 0.05,
    AntiAFK = true,
    FlashParry = true,
    KToggle = Enum.KeyCode.RightShift,
    KPanel = Enum.KeyCode.RightControl,
}

local balle = nil
local dernierP = 0
local compteur = 0
local streak = 0
local best = 0
local derLog = "En attente..."
local vBalle = 0
local dBalle = 0
local cible = false
local ouvert = true
local onglet = 1
local COOLDOWN = 0.04
local cachedHRP = nil
local cachedChar = nil
local prevBPos = nil
local prevBTime = 0

local function log(m) derLog = m end

-- ═══════════════════════════════════════════════
--  COULEURS
-- ═══════════════════════════════════════════════
local ACCENT = Color3.fromRGB(100, 130, 255)
local GREEN  = Color3.fromRGB(50, 215, 95)
local RED    = Color3.fromRGB(235, 60, 60)
local ORANGE = Color3.fromRGB(255, 170, 45)
local YELLOW = Color3.fromRGB(255, 225, 55)
local CYAN   = Color3.fromRGB(80, 220, 255)
local BG1    = Color3.fromRGB(12, 12, 20)
local BG2    = Color3.fromRGB(18, 18, 28)
local BG3    = Color3.fromRGB(24, 24, 36)
local BG4    = Color3.fromRGB(32, 32, 46)
local BG5    = Color3.fromRGB(40, 40, 56)
local BORDER = Color3.fromRGB(45, 45, 65)
local TEXT1  = Color3.fromRGB(235, 235, 250)
local TEXT2  = Color3.fromRGB(160, 160, 185)
local TEXT3  = Color3.fromRGB(100, 100, 130)

-- ═══════════════════════════════════════════════
--  CACHE PERSONNAGE
-- ═══════════════════════════════════════════════
local function updateCharCache()
    cachedChar = LP.Character
    cachedHRP = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")
end
updateCharCache()
LP.CharacterAdded:Connect(function(c)
    cachedChar = c
    c:WaitForChild("HumanoidRootPart", 5)
    cachedHRP = c:FindFirstChild("HumanoidRootPart")
end)
LP.CharacterRemoving:Connect(function() cachedChar = nil; cachedHRP = nil end)

-- ═══════════════════════════════════════════════
--  DETECTION BALLE
-- ═══════════════════════════════════════════════
local function estJoueur(o)
    local p = o.Parent
    while p and p ~= workspace do
        if Players:GetPlayerFromCharacter(p) then return true end
        p = p.Parent
    end
    return false
end

local function chercheBalle()
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not estJoueur(v) then
            local n = v.Name:lower()
            if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb") then return v end
        end
    end
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not estJoueur(v) then
            if v:GetAttribute("Target") or v:GetAttribute("target") or v:GetAttribute("realTarget") then return v end
        end
    end
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not estJoueur(v) and not v.Anchored then
            if v.Name ~= "Baseplate" and v.Name ~= "Terrain" then
                local s, vel = pcall(function() return v.AssemblyLinearVelocity end)
                if s and vel and vel.Magnitude > 20 and v.Size.Magnitude < 15 then return v end
            end
        end
    end
    return nil
end

workspace.DescendantAdded:Connect(function(o)
    if balle and balle.Parent then return end
    if not (o:IsA("BasePart") or o:IsA("MeshPart")) or estJoueur(o) then return end
    local n = o.Name:lower()
    if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb")
        or o:GetAttribute("Target") or o:GetAttribute("target") or o:GetAttribute("realTarget") then
        balle = o
        prevBPos = nil
        log("Balle detectee: " .. o.Name)
    end
end)
workspace.DescendantRemoving:Connect(function(o) if o == balle then balle = nil; prevBPos = nil end end)

balle = chercheBalle()
if balle then log("Balle trouvee: " .. balle.Name) end

task.spawn(function()
    while true do
        task.wait(0.15)
        if not balle or not balle.Parent then balle = chercheBalle() end
    end
end)

-- ═══════════════════════════════════════════════
--  DETECTION CIBLE — ultra rapide
-- ═══════════════════════════════════════════════
local function matchTarget(t)
    if t == nil then return false end
    if typeof(t) == "Instance" then return t == cachedChar or t == LP end
    if typeof(t) == "string" then return t == lpName or t == lpIdStr end
    if typeof(t) == "number" then return t == lpId end
    return false
end

local function checkCible(b)
    local hrp = cachedHRP
    if not hrp then updateCharCache(); hrp = cachedHRP end
    if not hrp then return false, 999, 0 end

    local bPos = b.Position
    local hPos = hrp.Position
    local dx = bPos.X - hPos.X
    local dy = bPos.Y - hPos.Y
    local dz = bPos.Z - hPos.Z
    local d = math.sqrt(dx*dx + dy*dy + dz*dz)

    local velOk, vel = pcall(function() return b.AssemblyLinearVelocity end)
    if not velOk then velOk, vel = pcall(function() return b.Velocity end) end
    local spd = (velOk and vel) and vel.Magnitude or 0

    -- 1) Attributs directs
    if matchTarget(b:GetAttribute("Target")) or matchTarget(b:GetAttribute("target"))
        or matchTarget(b:GetAttribute("realTarget")) or matchTarget(b:GetAttribute("CurrentTarget"))
        or matchTarget(b:GetAttribute("currentTarget")) or matchTarget(b:GetAttribute("TargetPlayer")) then
        return true, d, spd
    end

    -- 2) Attributs parent
    local par = b.Parent
    if par and par ~= workspace then
        if matchTarget(par:GetAttribute("Target")) or matchTarget(par:GetAttribute("target"))
            or matchTarget(par:GetAttribute("realTarget")) or matchTarget(par:GetAttribute("CurrentTarget")) then
            return true, d, spd
        end
    end

    -- 3) ObjectValue
    for _, ch in pairs(b:GetChildren()) do
        if ch:IsA("ObjectValue") and ch.Value then
            if ch.Value == cachedChar or ch.Value == LP then return true, d, spd end
        end
    end

    -- 4) Velocite direction (seuil ULTRA bas)
    if velOk and vel and spd > 3 then
        local dm = d
        if dm > 0.01 then
            local invDm = 1 / dm
            local invSpd = 1 / spd
            local dot = (vel.X*invSpd)*((-dx)*invDm) + (vel.Y*invSpd)*((-dy)*invDm) + (vel.Z*invSpd)*((-dz)*invDm)
            if dot > C.Sensibilite then return true, d, spd end
        end
    end

    return false, d, spd
end

-- ═══════════════════════════════════════════════
--  PARRY — multi-click adaptatif + prediction
-- ═══════════════════════════════════════════════
local flashFrame = nil

local function parry(spd)
    local now = tick()
    if now - dernierP < COOLDOWN then return end
    dernierP = now
    compteur = compteur + 1
    streak = streak + 1
    if streak > best then best = streak end

    -- Multi-click selon vitesse balle
    local nb = 1
    if spd > 300 then nb = 5
    elseif spd > 200 then nb = 4
    elseif spd > 100 then nb = 3
    elseif spd > 50 then nb = 2 end

    for _ = 1, nb do pcall(mouse1click) end

    if C.FlashParry and flashFrame then
        pcall(function()
            flashFrame.BackgroundTransparency = 0.8
            TweenService:Create(flashFrame, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
        end)
    end

    log("PARRY #" .. compteur .. " x" .. nb .. " | d=" .. math.floor(dBalle) .. " v=" .. math.floor(vBalle))
end

local function doitParry(d, spd)
    -- Distance DYNAMIQUE selon vitesse
    -- Balle lente (0-50):     parry a 10-14 studs
    -- Balle moyenne (50-150): parry a 14-23 studs
    -- Balle rapide (150-300): parry a 23-37 studs
    -- Balle ultra (300-500):  parry a 37-55 studs
    -- Balle extreme (500+):   parry a 55-70 studs
    local seuil = math.clamp(10 + spd * 0.12, 10, 70)
    return d <= seuil
end

-- PREDICTION : estime la distance dans N frames
local function predictDistance(b, hrp, frames)
    local velOk, vel = pcall(function() return b.AssemblyLinearVelocity end)
    if not velOk or not vel then return nil end
    local dt = frames / 60
    local futurePos = b.Position + vel * dt
    return (futurePos - hrp.Position).Magnitude
end

-- ═══════════════════════════════════════════════
--  ANTI AFK
-- ═══════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(180)
        if C.AntiAFK and cachedHRP then
            pcall(function() cachedHRP.CFrame = cachedHRP.CFrame end)
        end
    end
end)

-- ═══════════════════════════════════════════════
--  GUI
-- ═══════════════════════════════════════════════
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
local function rnd(p, r) mk("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = p}) end
local function str(p, c, t) mk("UIStroke", {Color = c or BORDER, Thickness = t or 1, Parent = p}) end

flashFrame = mk("Frame", {
    Size = UDim2.new(1,0,1,0), BackgroundColor3 = ACCENT,
    BackgroundTransparency = 1, ZIndex = 100, Parent = gui,
})

-- ═══════ PANEL 380x660 ═══════
local W, H_OPEN, H_CLOSED = 380, 660, 52

local panel = mk("Frame", {
    Size = UDim2.new(0, W, 0, H_OPEN),
    Position = UDim2.new(0, 16, 0.5, -H_OPEN/2),
    BackgroundColor3 = BG1, BackgroundTransparency = 0.02,
    ClipsDescendants = true, Parent = gui,
})
rnd(panel, 14)
str(panel, BORDER, 1)

-- ═══════ HEADER ═══════
local hdr = mk("Frame", {Size = UDim2.new(1,0,0,52), BackgroundColor3 = BG2, Parent = panel})
rnd(hdr, 14)
mk("Frame", {Size = UDim2.new(1,-30,0,3), Position = UDim2.new(0,15,0,0), BackgroundColor3 = ACCENT, Parent = hdr})

local iconBg = mk("Frame", {Size = UDim2.new(0,34,0,34), Position = UDim2.new(0,14,0,10), BackgroundColor3 = ACCENT, Parent = hdr})
rnd(iconBg, 17)
mk("TextLabel", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "AP", TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 13, Parent = iconBg})

mk("TextLabel", {
    Size = UDim2.new(1,-140,0,20), Position = UDim2.new(0,56,0,8),
    BackgroundTransparency = 1, Text = "AUTO PARRY",
    TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr,
})
mk("TextLabel", {
    Size = UDim2.new(1,-140,0,14), Position = UDim2.new(0,56,0,29),
    BackgroundTransparency = 1, Text = "v12 | Predictif | 120 checks/s",
    TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr,
})

local btnMin = mk("TextButton", {
    Size = UDim2.new(0,36,0,36), Position = UDim2.new(1,-50,0,8),
    BackgroundColor3 = BG4, Text = "-",
    TextColor3 = TEXT2, Font = Enum.Font.GothamBold, TextSize = 18, Parent = hdr,
})
rnd(btnMin, 10)
btnMin.MouseButton1Click:Connect(function()
    ouvert = not ouvert
    btnMin.Text = ouvert and "-" or "+"
    TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, W, 0, ouvert and H_OPEN or H_CLOSED)
    }):Play()
end)

-- ═══════ ONGLETS ═══════
local tabBar = mk("Frame", {Size = UDim2.new(1,-28,0,36), Position = UDim2.new(0,14,0,56), BackgroundColor3 = BG3, Parent = panel})
rnd(tabBar, 10)

local tabNames = {"Statut", "Reglages", "Info"}
local tabBtns = {}
local pagesList = {}

for i, name in ipairs(tabNames) do
    local btn = mk("TextButton", {
        Size = UDim2.new(1/3,-4,1,-6), Position = UDim2.new((i-1)/3,2,0,3),
        BackgroundColor3 = i==1 and ACCENT or BG3, BackgroundTransparency = i==1 and 0 or 1,
        Text = name, TextColor3 = i==1 and TEXT1 or TEXT3,
        Font = Enum.Font.GothamBold, TextSize = 12, Parent = tabBar,
    })
    rnd(btn, 8)
    tabBtns[i] = btn

    local page = mk("ScrollingFrame", {
        Size = UDim2.new(1,0,1,-96), Position = UDim2.new(0,0,0,96),
        BackgroundTransparency = 1, ScrollBarThickness = 3,
        ScrollBarImageColor3 = ACCENT, CanvasSize = UDim2.new(0,0,0,0),
        Visible = i==1, Parent = panel,
    })
    pagesList[i] = page

    btn.MouseButton1Click:Connect(function()
        onglet = i
        for j, b in ipairs(tabBtns) do
            TweenService:Create(b, TweenInfo.new(0.12), {
                BackgroundColor3 = j==i and ACCENT or BG3,
                BackgroundTransparency = j==i and 0 or 1,
                TextColor3 = j==i and TEXT1 or TEXT3,
            }):Play()
            pagesList[j].Visible = (j==i)
        end
    end)
end

-- ═══════ COMPOSANTS ═══════
local function card(parent, y, h)
    local c = mk("Frame", {Size = UDim2.new(1,-28,0,h), Position = UDim2.new(0,14,0,y), BackgroundColor3 = BG2, Parent = parent})
    rnd(c, 12); str(c, BORDER, 0.5)
    return c
end

local function section(parent, y, t)
    mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,y), BackgroundTransparency = 1, Text = string.upper(t), TextColor3 = ACCENT, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
end

local function makeSlider(parent, y, label, desc, min, max, def, unit, cb)
    mk("TextLabel", {Size = UDim2.new(1,-70,0,15), Position = UDim2.new(0,14,0,y), BackgroundTransparency = 1, Text = label, TextColor3 = TEXT1, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
    local vl = mk("TextLabel", {Size = UDim2.new(0,54,0,15), Position = UDim2.new(1,-66,0,y), BackgroundTransparency = 1, Text = tostring(def)..(unit or ""), TextColor3 = ACCENT, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = parent})
    local dy = y + 17
    if desc then
        mk("TextLabel", {Size = UDim2.new(1,-28,0,12), Position = UDim2.new(0,14,0,dy), BackgroundTransparency = 1, Text = desc, TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
        dy = dy + 14
    end
    local tr = mk("Frame", {Size = UDim2.new(1,-28,0,8), Position = UDim2.new(0,14,0,dy+3), BackgroundColor3 = BG4, Parent = parent})
    rnd(tr, 4)
    local fl = mk("Frame", {Size = UDim2.new((def-min)/(max-min),0,1,0), BackgroundColor3 = ACCENT, Parent = tr})
    rnd(fl, 4)
    local kn = mk("TextButton", {Size = UDim2.new(0,18,0,18), Position = UDim2.new((def-min)/(max-min),-9,0.5,-9), BackgroundColor3 = Color3.fromRGB(242,242,255), Text = "", Parent = tr})
    rnd(kn, 9)
    mk("UIStroke", {Color = ACCENT, Thickness = 2, Parent = kn})
    local drag = false
    local function up(px)
        local r = math.clamp((px - tr.AbsolutePosition.X) / tr.AbsoluteSize.X, 0, 1)
        local v
        if max >= 10 then v = math.floor(min + r*(max-min) + 0.5) else v = math.floor((min + r*(max-min)) * 100 + 0.5) / 100 end
        fl.Size = UDim2.new(r,0,1,0); kn.Position = UDim2.new(r,-9,0.5,-9); vl.Text = tostring(v)..(unit or ""); cb(v)
    end
    kn.MouseButton1Down:Connect(function() drag = true end)
    tr.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; up(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then up(i.Position.X) end end)
end

local function makeToggle(parent, y, label, desc, def, cb)
    mk("TextLabel", {Size = UDim2.new(1,-70,0,15), Position = UDim2.new(0,14,0,y), BackgroundTransparency = 1, Text = label, TextColor3 = TEXT1, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
    if desc then mk("TextLabel", {Size = UDim2.new(1,-70,0,12), Position = UDim2.new(0,14,0,y+16), BackgroundTransparency = 1, Text = desc, TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent}) end
    local bg = mk("Frame", {Size = UDim2.new(0,44,0,24), Position = UDim2.new(1,-58,0,y), BackgroundColor3 = def and ACCENT or BG5, Parent = parent})
    rnd(bg, 12)
    local dot = mk("Frame", {Size = UDim2.new(0,18,0,18), Position = def and UDim2.new(1,-21,0,3) or UDim2.new(0,3,0,3), BackgroundColor3 = Color3.fromRGB(248,248,255), Parent = bg})
    rnd(dot, 9)
    local state = def
    mk("TextButton", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = bg}).MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(bg, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {BackgroundColor3 = state and ACCENT or BG5}):Play()
        TweenService:Create(dot, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {Position = state and UDim2.new(1,-21,0,3) or UDim2.new(0,3,0,3)}):Play()
        cb(state)
    end)
    return function(v) state=v; bg.BackgroundColor3=v and ACCENT or BG5; dot.Position=v and UDim2.new(1,-21,0,3) or UDim2.new(0,3,0,3) end
end

local function makeButton(parent, y, label, color, cb)
    local b = mk("TextButton", {Size = UDim2.new(1,-28,0,34), Position = UDim2.new(0,14,0,y), BackgroundColor3 = color or BG4, Text = label, TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 12, Parent = parent})
    rnd(b, 8); b.MouseButton1Click:Connect(cb)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.08), {BackgroundTransparency = 0.12}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.08), {BackgroundTransparency = 0}):Play() end)
end

-- ═══════════════════════════════════════════════
--  PAGE 1 : STATUT
-- ═══════════════════════════════════════════════
local p1 = pagesList[1]

local statusCard = card(p1, 8, 50)
local statusDot = mk("Frame", {Size = UDim2.new(0,12,0,12), Position = UDim2.new(0,16,0,19), BackgroundColor3 = GREEN, Parent = statusCard})
rnd(statusDot, 6)
local statusLbl = mk("TextLabel", {Size = UDim2.new(0,200,0,16), Position = UDim2.new(0,34,0,17), BackgroundTransparency = 1, Text = "ACTIF | 120 checks/s", TextColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = statusCard})

task.spawn(function()
    while true do
        if C.Active then
            pcall(function() TweenService:Create(statusDot, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.5}):Play() end)
            task.wait(0.6)
            pcall(function() TweenService:Create(statusDot, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0}):Play() end)
            task.wait(0.6)
        else statusDot.BackgroundTransparency = 0; task.wait(0.4) end
    end
end)

local function statBox(parent, x, y, w, title, col)
    local box = mk("Frame", {Size = UDim2.new(0,w,0,62), Position = UDim2.new(0,x,0,y), BackgroundColor3 = BG2, Parent = parent})
    rnd(box, 10); str(box, BORDER, 0.5)
    mk("TextLabel", {Size = UDim2.new(1,0,0,12), Position = UDim2.new(0,0,0,8), BackgroundTransparency = 1, Text = string.upper(title), TextColor3 = col or TEXT3, Font = Enum.Font.GothamBold, TextSize = 9, Parent = box})
    return mk("TextLabel", {Size = UDim2.new(1,0,0,26), Position = UDim2.new(0,0,0,24), BackgroundTransparency = 1, Text = "0", TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 24, Parent = box})
end

local bw = math.floor((W - 28 - 20) / 3)
local lblParrys = statBox(p1, 14, 68, bw, "Parrys", ACCENT)
local lblStreak = statBox(p1, 14+bw+10, 68, bw, "Streak", ORANGE)
local lblBest   = statBox(p1, 14+bw*2+20, 68, bw, "Record", YELLOW)

-- Balle info
local balleCard = card(p1, 140, 96)
section(balleCard, 10, "Detection balle")
local lblBS = mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,28), BackgroundTransparency = 1, Text = "Recherche...", TextColor3 = TEXT2, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})
local lblBI = mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,46), BackgroundTransparency = 1, Text = "Vit: 0 | Dist: 0 | Cible: -", TextColor3 = TEXT3, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})
local lblTI = mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,64), BackgroundTransparency = 1, Text = "", TextColor3 = CYAN, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})
local lblPR = mk("TextLabel", {Size = UDim2.new(1,-28,0,12), Position = UDim2.new(0,14,0,80), BackgroundTransparency = 1, Text = "", TextColor3 = GREEN, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})

-- Log
local logCard = card(p1, 244, 50)
section(logCard, 8, "Dernier evenement")
local logLbl = mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,28), BackgroundTransparency = 1, Text = derLog, TextColor3 = ORANGE, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = logCard})

-- Boutons
makeButton(p1, 304, "Forcer recherche balle", BG4, function() balle = chercheBalle(); prevBPos = nil; log(balle and "Balle: "..balle.Name or "Aucune balle") end)
makeButton(p1, 344, "Reset statistiques", BG4, function() compteur=0; streak=0; best=0; log("Stats reset") end)

local kCard = card(p1, 388, 58)
section(kCard, 8, "Raccourcis clavier")
mk("TextLabel", {Size = UDim2.new(1,-28,0,30), Position = UDim2.new(0,14,0,24), BackgroundTransparency = 1, Text = "RShift    Activer / Desactiver\nRCtrl     Afficher / Masquer", TextColor3 = TEXT3, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = kCard})
p1.CanvasSize = UDim2.new(0,0,0,456)

-- ═══════════════════════════════════════════════
--  PAGE 2 : REGLAGES
-- ═══════════════════════════════════════════════
local p2 = pagesList[2]

local mainCard = card(p2, 8, 48)
local majToggle = makeToggle(mainCard, 14, "Auto Parry", nil, C.Active, function(v)
    C.Active = v; statusLbl.Text = v and "ACTIF | 120 checks/s" or "INACTIF"; statusLbl.TextColor3 = v and GREEN or RED; statusDot.BackgroundColor3 = v and GREEN or RED
end)

local sensCard = card(p2, 64, 100)
section(sensCard, 10, "Reactivite")
makeSlider(sensCard, 28, "Sensibilite", "Plus bas = detecte plus vite (0.01 = max)", 0.01, 0.5, C.Sensibilite, "", function(v) C.Sensibilite = v end)
makeSlider(sensCard, 68, "Cooldown", "Delai min entre parrys (sec)", 0.01, 0.5, COOLDOWN, "s", function(v) COOLDOWN = v end)

local extraCard = card(p2, 172, 80)
section(extraCard, 10, "Options")
makeToggle(extraCard, 30, "Anti-AFK", "Empeche le kick inactivite", C.AntiAFK, function(v) C.AntiAFK = v end)
makeToggle(extraCard, 56, "Flash Parry", "Flash bleu a chaque parry", C.FlashParry, function(v) C.FlashParry = v end)

section(p2, 262, "Configs recommandees")
makeButton(p2, 280, "ULTRA REACTIF | Sens 0.03, CD 0.03s", Color3.fromRGB(50, 22, 22), function()
    C.Sensibilite = 0.03; COOLDOWN = 0.03; log("Config: Ultra Reactif")
end)
makeButton(p2, 320, "EQUILIBRE | Sens 0.1, CD 0.1s", Color3.fromRGB(22, 22, 50), function()
    C.Sensibilite = 0.1; COOLDOWN = 0.1; log("Config: Equilibre")
end)
makeButton(p2, 360, "PRUDENT | Sens 0.2, CD 0.2s", Color3.fromRGB(22, 40, 22), function()
    C.Sensibilite = 0.2; COOLDOWN = 0.2; log("Config: Prudent")
end)
p2.CanvasSize = UDim2.new(0,0,0,404)

-- ═══════════════════════════════════════════════
--  PAGE 3 : INFO
-- ═══════════════════════════════════════════════
local p3 = pagesList[3]

local infoCard = card(p3, 8, 200)
section(infoCard, 10, "Comment ca marche")
mk("TextLabel", {
    Size = UDim2.new(1,-28,0,170), Position = UDim2.new(0,14,0,28), BackgroundTransparency = 1,
    Text = "DOUBLE BOUCLE (120 checks/sec):\n  RenderStepped = check avant le rendu (60fps)\n  Heartbeat = check apres la physique (60fps)\n\nPREDICTION:\n  Calcule ou la balle SERA dans 2-3 frames\n  Parry avant qu'elle arrive = zero retard\n\nMULTI-CLICK ADAPTATIF:\n  Balle lente: 1 clic\n  Balle moyenne (>50): 2 clics\n  Balle rapide (>100): 3 clics\n  Balle ultra (>200): 4 clics\n  Balle extreme (>300): 5 clics\n\nDISTANCE DYNAMIQUE:\n  Zone = 10 + (vitesse x 0.12) studs\n  Max 70 studs pour les balles extremes",
    TextColor3 = TEXT2, Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = infoCard,
})

local secCard = card(p3, 216, 140)
section(secCard, 10, "Anti-detection")
mk("TextLabel", {
    Size = UDim2.new(1,-28,0,110), Position = UDim2.new(0,14,0,28), BackgroundTransparency = 1,
    Text = "mouse1click() uniquement\nAucun RemoteEvent:FireServer()\nAucun Highlight / Sound / BillboardGui\nAucun VirtualUser / VirtualInputManager\nNoms RenderStep = GUID aleatoires\nNom ScreenGui = aleatoire\nAnti-AFK par CFrame (invisible)\nZero interaction avec les remotes du jeu",
    TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = secCard,
})
p3.CanvasSize = UDim2.new(0,0,0,366)

-- ═══════ DRAG ═══════
local dd, sp
hdr.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = i.Position; sp = panel.Position end end)
hdr.InputChanged:Connect(function(i) if dd and i.UserInputType == Enum.UserInputType.MouseMovement then local d2 = i.Position - dd; panel.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d2.X, sp.Y.Scale, sp.Y.Offset+d2.Y) end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = nil end end)

-- ═══════ RACCOURCIS ═══════
UIS.InputBegan:Connect(function(input, g)
    if g then return end
    if input.KeyCode == C.KToggle then
        C.Active = not C.Active; majToggle(C.Active)
        statusLbl.Text = C.Active and "ACTIF | 120 checks/s" or "INACTIF"; statusLbl.TextColor3 = C.Active and GREEN or RED; statusDot.BackgroundColor3 = C.Active and GREEN or RED
    elseif input.KeyCode == C.KPanel then
        panel.Visible = not panel.Visible
    end
end)

gui.Parent = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════
--  BOUCLE 1 : RenderStepped (avant rendu, 60fps)
-- ═══════════════════════════════════════════════
local frameCount = 0

RunService:BindToRenderStep(RK1, Enum.RenderPriority.First.Value, function()
    local b = balle
    local ok = b and b.Parent and true or false

    if ok then
        local s2, r1, r2, r3 = pcall(checkCible, b)
        if s2 then cible, dBalle, vBalle = r1, r2, r3 else cible = false; dBalle = 0; vBalle = 0 end
    else
        cible = false; dBalle = 0; vBalle = 0
    end
    if not cible then streak = 0 end

    -- PARRY avec prediction
    if C.Active and ok and cible then
        if doitParry(dBalle, vBalle) then
            parry(vBalle)
        else
            -- Prediction : si la balle sera dans la zone dans 2-3 frames, parry maintenant
            local hrp = cachedHRP
            if hrp and vBalle > 30 then
                local pd = predictDistance(b, hrp, 3)
                if pd then
                    local seuil = math.clamp(10 + vBalle * 0.12, 10, 70)
                    if pd <= seuil and dBalle <= seuil * 1.5 then
                        parry(vBalle)
                    end
                end
            end
        end
    end

    -- UI throttle (toutes les 8 frames)
    frameCount = frameCount + 1
    if frameCount < 8 then return end
    frameCount = 0
    if onglet ~= 1 then return end

    lblParrys.Text = tostring(compteur)
    lblStreak.Text = tostring(streak)
    lblBest.Text = tostring(best)
    if ok then lblBS.Text = "Balle: " .. b.Name; lblBS.TextColor3 = GREEN
    else lblBS.Text = "Recherche..."; lblBS.TextColor3 = ORANGE end
    lblBI.Text = "Vit: " .. math.floor(vBalle) .. " | Dist: " .. math.floor(dBalle) .. " | " .. (cible and "CIBLE" or "-")
    lblBI.TextColor3 = cible and YELLOW or TEXT3
    if cible and vBalle > 1 then
        local ti = dBalle / vBalle
        local seuil = math.clamp(10 + vBalle * 0.12, 10, 70)
        lblTI.Text = "Impact: " .. string.format("%.2f", ti) .. "s | Zone: " .. math.floor(seuil) .. " studs"
        local nb = vBalle > 300 and 5 or vBalle > 200 and 4 or vBalle > 100 and 3 or vBalle > 50 and 2 or 1
        lblPR.Text = "Multi-click: x" .. nb .. " | Cooldown: " .. COOLDOWN .. "s"
    else
        lblTI.Text = ""; lblPR.Text = ""
    end
    logLbl.Text = derLog
end)

-- ═══════════════════════════════════════════════
--  BOUCLE 2 : Heartbeat (apres physique, 60fps)
--  = double la frequence de check a ~120/s
-- ═══════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not C.Active then return end
    local b = balle
    if not b or not b.Parent then return end

    local s2, r1, r2, r3 = pcall(checkCible, b)
    if not s2 then return end

    if r1 then
        cible = true; dBalle = r2; vBalle = r3
        if doitParry(r2, r3) then
            parry(r3)
        else
            local hrp = cachedHRP
            if hrp and r3 > 30 then
                local pd = predictDistance(b, hrp, 2)
                if pd then
                    local seuil = math.clamp(10 + r3 * 0.12, 10, 70)
                    if pd <= seuil and r2 <= seuil * 1.5 then
                        parry(r3)
                    end
                end
            end
        end
    end
end)

print("[AutoParry] v12 charge | Sens: " .. C.Sensibilite .. " | CD: " .. COOLDOWN .. " | Double boucle 120 checks/s")
