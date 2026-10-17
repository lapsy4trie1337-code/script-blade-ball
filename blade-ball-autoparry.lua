-- Auto Parry v13 — Intelligent

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
local RK = rkey()

-- ═══════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════
local C = {
    Active = true,
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
local ouvert = true
local onglet = 1
local cachedHRP = nil
local cachedChar = nil

-- Etat intelligent
local targetConfirme = false  -- true = attribut confirme, false = velocite seulement
local balleApproche = false   -- true = la distance diminue
local prevDist = 999
local prevDistTime = 0
local nbParrysCeTour = 0      -- parrys depuis que la balle nous cible

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
        prevDist = 999
        nbParrysCeTour = 0
        log("Balle detectee: " .. o.Name)
    end
end)
workspace.DescendantRemoving:Connect(function(o) if o == balle then balle = nil; prevDist = 999; nbParrysCeTour = 0 end end)

balle = chercheBalle()
if balle then log("Balle trouvee: " .. balle.Name) end

task.spawn(function()
    while true do
        task.wait(0.15)
        if not balle or not balle.Parent then balle = chercheBalle() end
    end
end)

-- ═══════════════════════════════════════════════
--  DETECTION CIBLE — intelligente
--  Retourne: cible, distance, vitesse, confirme
--  confirme = true si attribut match (100% sur)
--  confirme = false si velocite seulement (estimation)
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
    if not hrp then return false, 999, 0, false end

    local bPos = b.Position
    local hPos = hrp.Position
    local dx = bPos.X - hPos.X
    local dy = bPos.Y - hPos.Y
    local dz = bPos.Z - hPos.Z
    local d = math.sqrt(dx*dx + dy*dy + dz*dz)

    local velOk, vel = pcall(function() return b.AssemblyLinearVelocity end)
    if not velOk then velOk, vel = pcall(function() return b.Velocity end) end
    local spd = (velOk and vel) and vel.Magnitude or 0

    -- 1) Attributs directs → CONFIRME (100% sur)
    if matchTarget(b:GetAttribute("Target")) or matchTarget(b:GetAttribute("target"))
        or matchTarget(b:GetAttribute("realTarget")) or matchTarget(b:GetAttribute("CurrentTarget"))
        or matchTarget(b:GetAttribute("currentTarget")) or matchTarget(b:GetAttribute("TargetPlayer")) then
        return true, d, spd, true
    end

    -- 2) Attributs parent → CONFIRME
    local par = b.Parent
    if par and par ~= workspace then
        if matchTarget(par:GetAttribute("Target")) or matchTarget(par:GetAttribute("target"))
            or matchTarget(par:GetAttribute("realTarget")) or matchTarget(par:GetAttribute("CurrentTarget")) then
            return true, d, spd, true
        end
    end

    -- 3) ObjectValue → CONFIRME
    for _, ch in pairs(b:GetChildren()) do
        if ch:IsA("ObjectValue") and ch.Value then
            if ch.Value == cachedChar or ch.Value == LP then return true, d, spd, true end
        end
    end

    -- 4) Velocite → NON CONFIRME (estimation)
    -- Seuil plus haut : 0.35 (doit vraiment viser vers nous)
    if velOk and vel and spd > 8 then
        local dm = d
        if dm > 0.01 then
            local invDm = 1 / dm
            local invSpd = 1 / spd
            local dot = (vel.X*invSpd)*((-dx)*invDm) + (vel.Y*invSpd)*((-dy)*invDm) + (vel.Z*invSpd)*((-dz)*invDm)
            if dot > 0.35 then return true, d, spd, false end
        end
    end

    return false, d, spd, false
end

-- ═══════════════════════════════════════════════
--  PARRY — intelligent
-- ═══════════════════════════════════════════════
local flashFrame = nil

local function parry(spd)
    local now = tick()
    -- Cooldown intelligent : 0.15s minimum (le jeu a besoin de temps pour register)
    if now - dernierP < 0.15 then return end
    dernierP = now
    compteur = compteur + 1
    streak = streak + 1
    if streak > best then best = streak end
    nbParrysCeTour = nbParrysCeTour + 1

    -- Multi-click intelligent : juste assez pour que ca passe
    local nb = 1
    if spd > 250 then nb = 3
    elseif spd > 120 then nb = 2 end

    for _ = 1, nb do pcall(mouse1click) end

    if C.FlashParry and flashFrame then
        pcall(function()
            flashFrame.BackgroundTransparency = 0.82
            TweenService:Create(flashFrame, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
        end)
    end

    log("PARRY #" .. compteur .. " x" .. nb .. " | d=" .. math.floor(dBalle) .. " v=" .. math.floor(vBalle))
end

local function doitParry(d, spd, confirme, approche)
    -- Si on a deja parry 3+ fois ce tour et la balle est toujours la → arreter de spam
    if nbParrysCeTour >= 3 then return false end

    if confirme then
        -- CONFIRME par attribut → on sait que c'est nous
        -- Distance adaptee a la vitesse, mais raisonnable
        -- Balle lente (0-80):    parry a 8-16 studs
        -- Balle moyenne (80-200): parry a 16-28 studs
        -- Balle rapide (200-400): parry a 28-44 studs
        -- Balle extreme (400+):   parry a 44-55 studs
        local seuil = math.clamp(8 + spd * 0.1, 8, 55)
        return d <= seuil
    else
        -- NON CONFIRME (velocite seulement) → etre prudent
        -- Parry seulement si :
        -- 1) La balle APPROCHE (distance diminue)
        -- 2) Distance < 20 studs (assez proche pour etre sur)
        -- 3) Vitesse > 15 (pas un truc random qui flotte)
        if not approche then return false end
        if spd < 15 then return false end
        local seuil = math.clamp(8 + spd * 0.06, 8, 25)
        return d <= seuil
    end
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

-- ═══════ PANEL ═══════
local W, H_OPEN, H_CLOSED = 380, 640, 52

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
mk("TextLabel", {Size = UDim2.new(1,-140,0,20), Position = UDim2.new(0,56,0,8), BackgroundTransparency = 1, Text = "AUTO PARRY", TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
mk("TextLabel", {Size = UDim2.new(1,-140,0,14), Position = UDim2.new(0,56,0,29), BackgroundTransparency = 1, Text = "v13 | Intelligent | Zero faux clic", TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})

local btnMin = mk("TextButton", {Size = UDim2.new(0,36,0,36), Position = UDim2.new(1,-50,0,8), BackgroundColor3 = BG4, Text = "-", TextColor3 = TEXT2, Font = Enum.Font.GothamBold, TextSize = 18, Parent = hdr})
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
local tabNames = {"Statut", "Options", "Info"}
local tabBtns = {}
local pagesList = {}

for i, name in ipairs(tabNames) do
    local btn = mk("TextButton", {
        Size = UDim2.new(1/3,-4,1,-6), Position = UDim2.new((i-1)/3,2,0,3),
        BackgroundColor3 = i==1 and ACCENT or BG3, BackgroundTransparency = i==1 and 0 or 1,
        Text = name, TextColor3 = i==1 and TEXT1 or TEXT3,
        Font = Enum.Font.GothamBold, TextSize = 12, Parent = tabBar,
    })
    rnd(btn, 8); tabBtns[i] = btn
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
            TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = j==i and ACCENT or BG3, BackgroundTransparency = j==i and 0 or 1, TextColor3 = j==i and TEXT1 or TEXT3}):Play()
            pagesList[j].Visible = (j==i)
        end
    end)
end

-- ═══════ COMPOSANTS ═══════
local function card(parent, y, h)
    local c = mk("Frame", {Size = UDim2.new(1,-28,0,h), Position = UDim2.new(0,14,0,y), BackgroundColor3 = BG2, Parent = parent})
    rnd(c, 12); str(c, BORDER, 0.5); return c
end
local function section(parent, y, t)
    mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,y), BackgroundTransparency = 1, Text = string.upper(t), TextColor3 = ACCENT, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
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
local statusLbl = mk("TextLabel", {Size = UDim2.new(0,200,0,16), Position = UDim2.new(0,34,0,17), BackgroundTransparency = 1, Text = "ACTIF", TextColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = statusCard})

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

local balleCard = card(p1, 140, 112)
section(balleCard, 10, "Analyse balle")
local lblBS = mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,28), BackgroundTransparency = 1, Text = "Recherche...", TextColor3 = TEXT2, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})
local lblBI = mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,46), BackgroundTransparency = 1, Text = "", TextColor3 = TEXT3, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})
local lblTI = mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,64), BackgroundTransparency = 1, Text = "", TextColor3 = CYAN, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})
local lblST = mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,82), BackgroundTransparency = 1, Text = "", TextColor3 = GREEN, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard})

local logCard = card(p1, 262, 50)
section(logCard, 8, "Dernier evenement")
local logLbl = mk("TextLabel", {Size = UDim2.new(1,-28,0,14), Position = UDim2.new(0,14,0,28), BackgroundTransparency = 1, Text = derLog, TextColor3 = ORANGE, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = logCard})

makeButton(p1, 322, "Forcer recherche balle", BG4, function() balle = chercheBalle(); prevDist = 999; log(balle and "Balle: "..balle.Name or "Aucune balle") end)
makeButton(p1, 362, "Reset statistiques", BG4, function() compteur=0; streak=0; best=0; log("Stats reset") end)

local kCard = card(p1, 406, 58)
section(kCard, 8, "Raccourcis")
mk("TextLabel", {Size = UDim2.new(1,-28,0,30), Position = UDim2.new(0,14,0,24), BackgroundTransparency = 1, Text = "RShift    Activer / Desactiver\nRCtrl     Afficher / Masquer", TextColor3 = TEXT3, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = kCard})
p1.CanvasSize = UDim2.new(0,0,0,474)

-- ═══════════════════════════════════════════════
--  PAGE 2 : OPTIONS
-- ═══════════════════════════════════════════════
local p2 = pagesList[2]

local mainCard = card(p2, 8, 48)
local majToggle = makeToggle(mainCard, 14, "Auto Parry", nil, C.Active, function(v)
    C.Active = v; statusLbl.Text = v and "ACTIF" or "INACTIF"; statusLbl.TextColor3 = v and GREEN or RED; statusDot.BackgroundColor3 = v and GREEN or RED
end)

local optCard = card(p2, 64, 80)
section(optCard, 10, "Options")
makeToggle(optCard, 30, "Anti-AFK", "Empeche le kick inactivite", C.AntiAFK, function(v) C.AntiAFK = v end)
makeToggle(optCard, 56, "Flash Parry", "Flash bleu a chaque parry", C.FlashParry, function(v) C.FlashParry = v end)
p2.CanvasSize = UDim2.new(0,0,0,154)

-- ═══════════════════════════════════════════════
--  PAGE 3 : INFO
-- ═══════════════════════════════════════════════
local p3 = pagesList[3]

local howCard = card(p3, 8, 240)
section(howCard, 10, "Intelligence du parry")
mk("TextLabel", {
    Size = UDim2.new(1,-28,0,210), Position = UDim2.new(0,14,0,28), BackgroundTransparency = 1,
    Text = "DETECTION A 2 NIVEAUX:\n\n"
        .. "  CONFIRME (attribut du jeu = 100% sur)\n"
        .. "    Le jeu dit que la balle te vise\n"
        .. "    Parry agressif, distance adaptee a la vitesse\n"
        .. "    Zone: 8 + vitesse*0.1 studs (max 55)\n\n"
        .. "  ESTIME (velocite = estimation)\n"
        .. "    La balle semble aller vers toi\n"
        .. "    Parry prudent: seulement si elle approche\n"
        .. "    ET distance < 25 studs ET dot > 0.35\n\n"
        .. "MULTI-CLICK ADAPTATIF:\n"
        .. "  Lente: 1 clic | >120: 2 clics | >250: 3 clics\n\n"
        .. "ANTI-SPAM:\n"
        .. "  Max 3 parrys par tour de balle\n"
        .. "  Cooldown 0.15s (temps de register du jeu)\n"
        .. "  Stop si la balle s'eloigne",
    TextColor3 = TEXT2, Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = howCard,
})

local secCard = card(p3, 256, 120)
section(secCard, 10, "Anti-detection")
mk("TextLabel", {
    Size = UDim2.new(1,-28,0,90), Position = UDim2.new(0,14,0,28), BackgroundTransparency = 1,
    Text = "mouse1click() uniquement\nAucun RemoteEvent:FireServer()\nAucun Highlight / Sound / BillboardGui\nAucun VirtualUser / VirtualInputManager\nNom RenderStep aleatoire\nNom ScreenGui aleatoire\nAnti-AFK par CFrame (invisible)",
    TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = secCard,
})
p3.CanvasSize = UDim2.new(0,0,0,386)

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
--  BOUCLE PRINCIPALE — intelligente
-- ═══════════════════════════════════════════════
local frameCount = 0
local lastCible = false

RunService:BindToRenderStep(RK, Enum.RenderPriority.First.Value, function()
    local b = balle
    local ok = b and b.Parent and true or false
    local isCible, dist, spd, confirme = false, 0, 0, false

    if ok then
        local s2, r1, r2, r3, r4 = pcall(checkCible, b)
        if s2 then isCible, dist, spd, confirme = r1, r2, r3, r4 end
    end

    dBalle = dist
    vBalle = spd
    targetConfirme = confirme

    -- Tracking approche (la distance diminue-t-elle ?)
    local now = tick()
    if now - prevDistTime > 0.03 then
        balleApproche = dist < prevDist - 0.5
        prevDist = dist
        prevDistTime = now
    end

    -- Reset compteur quand la balle change de cible
    if isCible and not lastCible then
        nbParrysCeTour = 0
    end
    lastCible = isCible

    if not isCible then streak = 0 end

    -- PARRY intelligent
    if C.Active and ok and isCible then
        if doitParry(dist, spd, confirme, balleApproche) then
            parry(spd)
        end
    end

    -- UI throttle
    frameCount = frameCount + 1
    if frameCount < 8 then return end
    frameCount = 0
    if onglet ~= 1 then return end

    lblParrys.Text = tostring(compteur)
    lblStreak.Text = tostring(streak)
    lblBest.Text = tostring(best)

    if ok then
        lblBS.Text = "Balle: " .. b.Name
        lblBS.TextColor3 = GREEN
    else
        lblBS.Text = "Recherche..."
        lblBS.TextColor3 = ORANGE
    end

    if isCible then
        lblBI.Text = "Vit: " .. math.floor(spd) .. " | Dist: " .. math.floor(dist)
        lblBI.TextColor3 = YELLOW
        local seuil
        if confirme then seuil = math.clamp(8 + spd * 0.1, 8, 55)
        else seuil = math.clamp(8 + spd * 0.06, 8, 25) end
        lblTI.Text = "Zone parry: " .. math.floor(seuil) .. " studs | Impact: " .. string.format("%.2f", dist / math.max(spd, 1)) .. "s"
        lblST.Text = (confirme and "CONFIRME" or "ESTIME") .. " | " .. (balleApproche and "APPROCHE" or "ELOIGNE") .. " | Parrys: " .. nbParrysCeTour .. "/3"
        lblST.TextColor3 = confirme and GREEN or ORANGE
    else
        lblBI.Text = "Pas de cible"
        lblBI.TextColor3 = TEXT3
        lblTI.Text = ""
        lblST.Text = ""
    end

    logLbl.Text = derLog
end)

print("[AutoParry] v13 charge | Intelligent | Zero faux clic")
