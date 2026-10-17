-- Auto Parry v10.1

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local function rkey()
    local s = ""
    for _ = 1, 12 do s = s .. string.char(math.random(97,122)) end
    return s
end
local RENDER_KEY = rkey()

-- ═══════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════
local C = {
    Active = true,
    Mode = 1,
    DistanceParry = 18,
    Sensibilite = 0.2,
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
local derLog = ""
local vBalle = 0
local dBalle = 0
local cible = false
local ouvert = true
local onglet = 1
local COOLDOWN = 0.25

local function log(m) derLog = m end

-- ═══════════════════════════════════════════════
--  COULEURS
-- ═══════════════════════════════════════════════
local ACCENT = Color3.fromRGB(90, 120, 255)
local GREEN  = Color3.fromRGB(45, 210, 90)
local RED    = Color3.fromRGB(230, 55, 55)
local ORANGE = Color3.fromRGB(255, 165, 40)
local YELLOW = Color3.fromRGB(255, 220, 50)
local BG1    = Color3.fromRGB(10, 10, 16)
local BG2    = Color3.fromRGB(16, 16, 24)
local BG3    = Color3.fromRGB(22, 22, 32)
local BG4    = Color3.fromRGB(30, 30, 42)
local BORDER = Color3.fromRGB(38, 38, 55)
local TEXT1  = Color3.fromRGB(225, 225, 240)
local TEXT2  = Color3.fromRGB(150, 150, 175)
local TEXT3  = Color3.fromRGB(90, 90, 115)

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
                if s and vel and vel.Magnitude > 30 and v.Size.Magnitude < 15 then return v end
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
        log("Balle detectee: " .. o.Name)
    end
end)
workspace.DescendantRemoving:Connect(function(o) if o == balle then balle = nil end end)

balle = chercheBalle()
if balle then log("Balle trouvee: " .. balle.Name) end

task.spawn(function()
    while true do
        task.wait(0.3)
        if not balle or not balle.Parent then balle = chercheBalle() end
    end
end)

-- ═══════════════════════════════════════════════
--  DETECTION CIBLE
-- ═══════════════════════════════════════════════
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local attrNoms = {"Target","target","realTarget","RealTarget","CurrentTarget","currentTarget","TargetPlayer","targetPlayer","PlayerTarget"}

local function checkCible(b)
    local hrp = getHRP()
    if not hrp then return false, 999, 0 end

    local pos = b.Position
    local d = (pos - hrp.Position).Magnitude
    local s1, vel = pcall(function() return b.AssemblyLinearVelocity end)
    if not s1 then s1, vel = pcall(function() return b.Velocity end) end
    local spd = (s1 and vel) and vel.Magnitude or 0

    local sources = {b}
    if b.Parent and b.Parent ~= workspace then sources[2] = b.Parent end

    for _, src in pairs(sources) do
        for _, nom in pairs(attrNoms) do
            local ok2, t = pcall(function() return src:GetAttribute(nom) end)
            if ok2 and t ~= nil then
                local m = false
                if typeof(t) == "Instance" then m = (t == LP.Character or t == LP)
                elseif typeof(t) == "string" then m = (t == LP.Name or t == tostring(LP.UserId))
                elseif typeof(t) == "number" then m = (t == LP.UserId) end
                return m, d, spd
            end
        end
    end

    for _, ch in pairs(b:GetChildren()) do
        if ch:IsA("ObjectValue") and ch.Value then
            return (ch.Value == LP.Character or ch.Value == LP), d, spd
        end
    end

    if s1 and vel and spd > 8 then
        local dir = (hrp.Position - pos).Unit
        local dot = vel.Unit:Dot(dir)
        if dot > C.Sensibilite then return true, d, spd end
    end

    return false, d, spd
end

-- ═══════════════════════════════════════════════
--  PARRY
-- ═══════════════════════════════════════════════
local flashFrame = nil

local function parry()
    local now = tick()
    if now - dernierP < COOLDOWN then return end
    dernierP = now
    compteur = compteur + 1
    streak = streak + 1
    if streak > best then best = streak end

    pcall(mouse1click)

    if C.FlashParry and flashFrame then
        pcall(function()
            flashFrame.BackgroundTransparency = 0.85
            TweenService:Create(flashFrame, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
        end)
    end

    log("PARRY #" .. compteur .. " d=" .. math.floor(dBalle) .. " v=" .. math.floor(vBalle))
end

local function doitParry(d, spd)
    if C.Mode == 1 then
        local seuil = math.clamp(8 + spd * 0.1, 8, 50)
        return d <= seuil
    elseif C.Mode == 2 then
        if spd < 3 then return false end
        local tempsImpact = d / spd
        local seuil = math.clamp(0.15 + (spd / 300), 0.15, 1.5)
        return tempsImpact <= seuil
    elseif C.Mode == 3 then
        return d <= C.DistanceParry
    end
    return false
end

-- ═══════════════════════════════════════════════
--  ANTI AFK
-- ═══════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(180)
        if C.AntiAFK then
            local hrp = getHRP()
            if hrp then pcall(function() hrp.CFrame = hrp.CFrame end) end
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
        if k ~= "Parent" then
            pcall(function() o[k] = v end)
        end
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

-- ═══════ PANEL ═══════
local W, H_OPEN, H_CLOSED = 320, 560, 48

local panel = mk("Frame", {
    Size = UDim2.new(0, W, 0, H_OPEN),
    Position = UDim2.new(0, 16, 0.5, -H_OPEN/2),
    BackgroundColor3 = BG1, BackgroundTransparency = 0.03,
    ClipsDescendants = true, Parent = gui,
})
rnd(panel, 16)
str(panel, BORDER, 1.5)

-- ═══════ HEADER ═══════
local hdr = mk("Frame", {Size = UDim2.new(1,0,0,48), BackgroundColor3 = BG2, Parent = panel})
rnd(hdr, 16)
mk("Frame", {Size = UDim2.new(1,-32,0,3), Position = UDim2.new(0,16,0,0), BackgroundColor3 = ACCENT, Parent = hdr})

local iconBg = mk("Frame", {Size = UDim2.new(0,28,0,28), Position = UDim2.new(0,14,0,12), BackgroundColor3 = ACCENT, Parent = hdr})
rnd(iconBg, 14)
mk("TextLabel", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "AP", TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 11, Parent = iconBg})

mk("TextLabel", {
    Size = UDim2.new(1,-120,0,16), Position = UDim2.new(0,50,0,10),
    BackgroundTransparency = 1, Text = "AUTO PARRY",
    TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr,
})
mk("TextLabel", {
    Size = UDim2.new(1,-120,0,12), Position = UDim2.new(0,50,0,27),
    BackgroundTransparency = 1, Text = "v10.1",
    TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr,
})

local btnMin = mk("TextButton", {
    Size = UDim2.new(0,32,0,32), Position = UDim2.new(1,-46,0,8),
    BackgroundColor3 = BG4, Text = "-",
    TextColor3 = TEXT2, Font = Enum.Font.GothamBold, TextSize = 16, Parent = hdr,
})
rnd(btnMin, 10)
btnMin.MouseButton1Click:Connect(function()
    ouvert = not ouvert
    btnMin.Text = ouvert and "-" or "+"
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, W, 0, ouvert and H_OPEN or H_CLOSED)
    }):Play()
end)

-- ═══════ ONGLETS ═══════
local tabBar = mk("Frame", {Size = UDim2.new(1,-24,0,32), Position = UDim2.new(0,12,0,52), BackgroundColor3 = BG3, Parent = panel})
rnd(tabBar, 10)

local tabNames = {"Statut", "Config", "Extra"}
local tabBtns = {}
local pagesList = {}

for i, name in ipairs(tabNames) do
    local btn = mk("TextButton", {
        Size = UDim2.new(1/3,-4,1,-4), Position = UDim2.new((i-1)/3,2,0,2),
        BackgroundColor3 = i==1 and ACCENT or BG3, BackgroundTransparency = i==1 and 0 or 1,
        Text = name, TextColor3 = i==1 and TEXT1 or TEXT3,
        Font = Enum.Font.GothamBold, TextSize = 11, Parent = tabBar,
    })
    rnd(btn, 8)
    tabBtns[i] = btn

    local page = mk("ScrollingFrame", {
        Size = UDim2.new(1,0,1,-88), Position = UDim2.new(0,0,0,88),
        BackgroundTransparency = 1, ScrollBarThickness = 2,
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
    local c = mk("Frame", {Size = UDim2.new(1,-24,0,h), Position = UDim2.new(0,12,0,y), BackgroundColor3 = BG2, Parent = parent})
    rnd(c, 10)
    str(c, BORDER, 0.5)
    return c
end

local function sectionTitle(parent, y, t)
    mk("TextLabel", {Size = UDim2.new(1,-28,0,12), Position = UDim2.new(0,14,0,y), BackgroundTransparency = 1, Text = string.upper(t), TextColor3 = ACCENT, Font = Enum.Font.GothamBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
end

local function makeSlider(parent, y, label, desc, min, max, def, unit, cb)
    mk("TextLabel", {Size = UDim2.new(1,-60,0,13), Position = UDim2.new(0,12,0,y), BackgroundTransparency = 1, Text = label, TextColor3 = TEXT1, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
    local vl = mk("TextLabel", {Size = UDim2.new(0,48,0,13), Position = UDim2.new(1,-58,0,y), BackgroundTransparency = 1, Text = tostring(def)..(unit or ""), TextColor3 = ACCENT, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = parent})
    local dy = y + 15
    if desc then
        mk("TextLabel", {Size = UDim2.new(1,-24,0,11), Position = UDim2.new(0,12,0,dy), BackgroundTransparency = 1, Text = desc, TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
        dy = dy + 13
    end
    local tr = mk("Frame", {Size = UDim2.new(1,-24,0,6), Position = UDim2.new(0,12,0,dy+2), BackgroundColor3 = BG4, Parent = parent})
    rnd(tr, 3)
    local fl = mk("Frame", {Size = UDim2.new((def-min)/(max-min),0,1,0), BackgroundColor3 = ACCENT, Parent = tr})
    rnd(fl, 3)
    local kn = mk("TextButton", {Size = UDim2.new(0,16,0,16), Position = UDim2.new((def-min)/(max-min),-8,0.5,-8), BackgroundColor3 = Color3.fromRGB(240,240,252), Text = "", Parent = tr})
    rnd(kn, 8)
    mk("UIStroke", {Color = ACCENT, Thickness = 2, Parent = kn})
    local drag = false
    local function up(px)
        local r = math.clamp((px - tr.AbsolutePosition.X) / tr.AbsoluteSize.X, 0, 1)
        local v
        if max >= 10 then v = math.floor(min + r*(max-min) + 0.5) else v = math.floor((min + r*(max-min)) * 100 + 0.5) / 100 end
        fl.Size = UDim2.new(r,0,1,0)
        kn.Position = UDim2.new(r,-8,0.5,-8)
        vl.Text = tostring(v)..(unit or "")
        cb(v)
    end
    kn.MouseButton1Down:Connect(function() drag = true end)
    tr.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; up(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then up(i.Position.X) end end)
end

local function makeToggle(parent, y, label, desc, def, cb)
    mk("TextLabel", {Size = UDim2.new(1,-64,0,13), Position = UDim2.new(0,12,0,y), BackgroundTransparency = 1, Text = label, TextColor3 = TEXT1, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
    if desc then mk("TextLabel", {Size = UDim2.new(1,-64,0,10), Position = UDim2.new(0,12,0,y+14), BackgroundTransparency = 1, Text = desc, TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent}) end
    local bg = mk("Frame", {Size = UDim2.new(0,40,0,22), Position = UDim2.new(1,-54,0,y), BackgroundColor3 = def and ACCENT or BG4, Parent = parent})
    rnd(bg, 11)
    local dot = mk("Frame", {Size = UDim2.new(0,16,0,16), Position = def and UDim2.new(1,-19,0,3) or UDim2.new(0,3,0,3), BackgroundColor3 = Color3.fromRGB(245,245,255), Parent = bg})
    rnd(dot, 8)
    local state = def
    mk("TextButton", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = bg}).MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(bg, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {BackgroundColor3 = state and ACCENT or BG4}):Play()
        TweenService:Create(dot, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {Position = state and UDim2.new(1,-19,0,3) or UDim2.new(0,3,0,3)}):Play()
        cb(state)
    end)
    return function(v) state=v; bg.BackgroundColor3=v and ACCENT or BG4; dot.Position=v and UDim2.new(1,-19,0,3) or UDim2.new(0,3,0,3) end
end

local function makeButton(parent, y, label, color, cb)
    local b = mk("TextButton", {Size = UDim2.new(1,-24,0,30), Position = UDim2.new(0,12,0,y), BackgroundColor3 = color or BG4, Text = label, TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 11, Parent = parent})
    rnd(b, 8)
    b.MouseButton1Click:Connect(cb)
end

-- ═══════ PAGE 1 : STATUT ═══════
local p1 = pagesList[1]

local statusCard = card(p1, 6, 44)
local statusDot = mk("Frame", {Size = UDim2.new(0,10,0,10), Position = UDim2.new(0,14,0,17), BackgroundColor3 = GREEN, Parent = statusCard})
rnd(statusDot, 5)
local statusLbl = mk("TextLabel", {Size = UDim2.new(0,120,0,14), Position = UDim2.new(0,30,0,15), BackgroundTransparency = 1, Text = "ACTIF", TextColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = statusCard})

task.spawn(function()
    while true do
        if C.Active then
            pcall(function() TweenService:Create(statusDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.4}):Play() end)
            task.wait(0.8)
            pcall(function() TweenService:Create(statusDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0}):Play() end)
            task.wait(0.8)
        else
            statusDot.BackgroundTransparency = 0
            task.wait(0.5)
        end
    end
end)

local function statBox(parent, x, y, w, title)
    local box = mk("Frame", {Size = UDim2.new(0,w,0,52), Position = UDim2.new(0,x,0,y), BackgroundColor3 = BG2, Parent = parent})
    rnd(box, 8)
    str(box, BORDER, 0.5)
    mk("TextLabel", {Size = UDim2.new(1,0,0,10), Position = UDim2.new(0,0,0,6), BackgroundTransparency = 1, Text = string.upper(title), TextColor3 = TEXT3, Font = Enum.Font.GothamBold, TextSize = 8, Parent = box})
    return mk("TextLabel", {Size = UDim2.new(1,0,0,22), Position = UDim2.new(0,0,0,20), BackgroundTransparency = 1, Text = "0", TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 20, Parent = box})
end

local lblParrys = statBox(p1, 12, 58, 90, "Parrys")
local lblStreak = statBox(p1, 108, 58, 90, "Streak")
local lblBest   = statBox(p1, 204, 58, 90, "Record")

local balleCard = card(p1, 118, 68)
sectionTitle(balleCard, 8, "Detection balle")
local lblBS = mk("TextLabel", {Size = UDim2.new(1,-24,0,12), Position = UDim2.new(0,12,0,24), BackgroundTransparency = 1, Text = "Recherche...", TextColor3 = TEXT2, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})
local lblBI = mk("TextLabel", {Size = UDim2.new(1,-24,0,12), Position = UDim2.new(0,12,0,40), BackgroundTransparency = 1, Text = "Vitesse: 0 | Distance: 0 | Cible: non", TextColor3 = TEXT3, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})

local modeCard = card(p1, 194, 70)
sectionTitle(modeCard, 8, "Mode actif")
local mNoms = {"AGRESSIF", "PREDICTIF", "SAFE"}
local mDesc = {"Parry instantane. Distance ajustee a la vitesse.", "Timing par temps d'impact. Anticipe quand rapide.", "Distance fixe configurable. Plus prudent."}
local mColors = {RED, ACCENT, GREEN}
local modeLbl = mk("TextLabel", {Size = UDim2.new(1,-24,0,18), Position = UDim2.new(0,12,0,24), BackgroundTransparency = 1, Text = mNoms[C.Mode], TextColor3 = mColors[C.Mode], Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = modeCard})
local modeDescLbl = mk("TextLabel", {Size = UDim2.new(1,-24,0,12), Position = UDim2.new(0,12,0,46), BackgroundTransparency = 1, Text = mDesc[C.Mode], TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 9, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = modeCard})

local logCard = card(p1, 272, 44)
sectionTitle(logCard, 6, "Dernier evenement")
local logLbl = mk("TextLabel", {Size = UDim2.new(1,-24,0,12), Position = UDim2.new(0,12,0,24), BackgroundTransparency = 1, Text = "...", TextColor3 = ORANGE, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = logCard})

makeButton(p1, 326, "Forcer recherche balle", BG4, function() balle = chercheBalle(); log(balle and "Balle: "..balle.Name or "Aucune balle") end)
makeButton(p1, 362, "Reset statistiques", BG4, function() compteur=0; streak=0; best=0; log("Reset") end)

local kCard = card(p1, 400, 50)
sectionTitle(kCard, 6, "Raccourcis")
mk("TextLabel", {Size = UDim2.new(1,-24,0,28), Position = UDim2.new(0,12,0,20), BackgroundTransparency = 1, Text = "RShift  ON / OFF\nRCtrl   Afficher / Masquer", TextColor3 = TEXT3, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = kCard})
p1.CanvasSize = UDim2.new(0,0,0,458)

-- ═══════ PAGE 2 : CONFIG ═══════
local p2 = pagesList[2]

local mainCard = card(p2, 6, 42)
local majToggle = makeToggle(mainCard, 12, "Auto Parry", nil, C.Active, function(v)
    C.Active = v; statusLbl.Text = v and "ACTIF" or "INACTIF"; statusLbl.TextColor3 = v and GREEN or RED; statusDot.BackgroundColor3 = v and GREEN or RED
end)

local modeSelCard = card(p2, 56, 50)
sectionTitle(modeSelCard, 8, "Mode de parry")
local modeBtns = {}
for i = 1, 3 do
    local mb = mk("TextButton", {Size = UDim2.new(1/3,-6,0,24), Position = UDim2.new((i-1)/3,2,0,22), BackgroundColor3 = i==C.Mode and mColors[i] or BG4, Text = mNoms[i], TextColor3 = i==C.Mode and TEXT1 or TEXT3, Font = Enum.Font.GothamBold, TextSize = 9, Parent = modeSelCard})
    rnd(mb, 6)
    modeBtns[i] = mb
    mb.MouseButton1Click:Connect(function()
        C.Mode = i; modeLbl.Text = mNoms[i]; modeLbl.TextColor3 = mColors[i]; modeDescLbl.Text = mDesc[i]
        for j, b2 in ipairs(modeBtns) do
            TweenService:Create(b2, TweenInfo.new(0.12), {BackgroundColor3 = j==i and mColors[j] or BG4, TextColor3 = j==i and TEXT1 or TEXT3}):Play()
        end
    end)
end

local sensCard = card(p2, 114, 80)
sectionTitle(sensCard, 8, "Detection")
makeSlider(sensCard, 24, "Sensibilite", "Plus bas = detecte plus vite (0.1-0.5)", 0.1, 0.5, C.Sensibilite, "", function(v) C.Sensibilite = v end)
makeSlider(sensCard, 54, "Distance (Safe)", "Distance fixe pour le mode Safe", 5, 50, C.DistanceParry, "", function(v) C.DistanceParry = v end)

local perfCard = card(p2, 202, 50)
sectionTitle(perfCard, 8, "Performance")
makeSlider(perfCard, 24, "Cooldown", "Delai entre parrys (sec)", 0.1, 1.0, COOLDOWN, "s", function(v) COOLDOWN = v end)

local recCard = card(p2, 260, 100)
sectionTitle(recCard, 8, "Configs recommandees")
makeButton(recCard, 24, "Ultra Reactif (Agressif, Sens 0.15)", Color3.fromRGB(40, 25, 25), function()
    C.Mode = 1; C.Sensibilite = 0.15; COOLDOWN = 0.2
    for j, b2 in ipairs(modeBtns) do b2.BackgroundColor3 = j==1 and mColors[1] or BG4; b2.TextColor3 = j==1 and TEXT1 or TEXT3 end
    modeLbl.Text = mNoms[1]; modeLbl.TextColor3 = mColors[1]; modeDescLbl.Text = mDesc[1]; log("Config: Ultra Reactif")
end)
makeButton(recCard, 60, "Equilibre (Predictif, Sens 0.25)", Color3.fromRGB(25, 25, 40), function()
    C.Mode = 2; C.Sensibilite = 0.25; COOLDOWN = 0.25
    for j, b2 in ipairs(modeBtns) do b2.BackgroundColor3 = j==2 and mColors[2] or BG4; b2.TextColor3 = j==2 and TEXT1 or TEXT3 end
    modeLbl.Text = mNoms[2]; modeLbl.TextColor3 = mColors[2]; modeDescLbl.Text = mDesc[2]; log("Config: Equilibre")
end)
p2.CanvasSize = UDim2.new(0,0,0,368)

-- ═══════ PAGE 3 : EXTRA ═══════
local p3 = pagesList[3]

local extraCard = card(p3, 6, 80)
sectionTitle(extraCard, 8, "Options")
makeToggle(extraCard, 26, "Anti-AFK", "Empeche le kick inactivite", C.AntiAFK, function(v) C.AntiAFK = v end)
makeToggle(extraCard, 56, "Flash Parry", "Flash bleu a chaque parry", C.FlashParry, function(v) C.FlashParry = v end)

local infoCard = card(p3, 94, 130)
sectionTitle(infoCard, 8, "Securite")
mk("TextLabel", {
    Size = UDim2.new(1,-24,0,100), Position = UDim2.new(0,12,0,24), BackgroundTransparency = 1,
    Text = "1 seul mouse1click() par parry\nAucun RemoteEvent fire\nAucun Highlight / Sound / ESP\nAucun VirtualUser / VIM\nNom RenderStep aleatoire\nNom ScreenGui aleatoire\nAnti-AFK par CFrame",
    TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 9, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = infoCard,
})
p3.CanvasSize = UDim2.new(0,0,0,232)

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
        statusLbl.Text = C.Active and "ACTIF" or "INACTIF"; statusLbl.TextColor3 = C.Active and GREEN or RED; statusDot.BackgroundColor3 = C.Active and GREEN or RED
    elseif input.KeyCode == C.KPanel then
        panel.Visible = not panel.Visible
    end
end)

gui.Parent = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════
--  BOUCLE — nom aleatoire
-- ═══════════════════════════════════════════════
RunService:BindToRenderStep(RENDER_KEY, Enum.RenderPriority.First.Value, function()
    local ok = balle and balle.Parent and true or false
    if ok then
        local s2, r1, r2, r3 = pcall(checkCible, balle)
        if s2 then cible, dBalle, vBalle = r1, r2, r3 else cible = false; dBalle = 0; vBalle = 0 end
    else
        cible = false; dBalle = 0; vBalle = 0
    end
    if not cible then streak = 0 end

    if onglet == 1 then
        lblParrys.Text = tostring(compteur)
        lblStreak.Text = tostring(streak)
        lblBest.Text = tostring(best)
        if ok then lblBS.Text = "Balle: "..balle.Name; lblBS.TextColor3 = GREEN
        else lblBS.Text = "Recherche..."; lblBS.TextColor3 = ORANGE end
        lblBI.Text = "Vit: "..math.floor(vBalle).." | Dist: "..math.floor(dBalle).." | Cible: "..(cible and "OUI" or "non")
        lblBI.TextColor3 = cible and YELLOW or TEXT3
        logLbl.Text = derLog
    end

    if not C.Active or not ok or not cible then return end
    if doitParry(dBalle, vBalle) then parry() end
end)

print("[AutoParry] v10.1 charge avec succes!")
