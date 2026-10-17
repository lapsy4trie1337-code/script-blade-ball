-- ╔════════════════════════════════════════════════╗
-- ║       BLADE BALL AUTO PARRY v8 — ULTRA        ║
-- ║  Parry predictif  ·  330 CPS  ·  Full Panel   ║
-- ╚════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════
local C = {
    Active = true,

    -- MODE : 1=Instantane, 2=Predictif, 3=Proche
    Mode = 2,

    -- DISTANCES
    DistanceMax = 25,
    DistanceMin = 0,

    -- TIMING
    Delai = 0,
    CPS = 30,

    -- VISUEL
    FlashEcran = true,
    ESPBalle = true,
    NotifSon = true,

    -- EXTRA
    AntiAFK = true,

    -- TOUCHES
    KToggle = Enum.KeyCode.RightShift,
    KPanel = Enum.KeyCode.RightControl,
}

-- ═══════════════════════════════════════════════
--  VARIABLES
-- ═══════════════════════════════════════════════
local balle = nil
local remote = nil
local dernierP = 0
local compteur = 0
local streak = 0
local bestStreak = 0
local derLog = "Demarrage..."
local vBalle = 0
local dBalle = 0
local cible = false
local panelOuvert = true

local function log(m) derLog = m end

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
        if (v:IsA("BasePart") or v:IsA("MeshPart")) then
            local n = v.Name:lower()
            if (n == "ball" or n == "balle" or n:find("projectile") or n:find("orb")) and not estJoueur(v) then
                return v
            end
        end
    end
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not estJoueur(v) then
            if v:GetAttribute("Target") or v:GetAttribute("target") or v:GetAttribute("realTarget") then
                return v
            end
        end
    end
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not estJoueur(v) and not v.Anchored then
            if v.Name ~= "Baseplate" and v.Name ~= "Terrain" then
                local ok, vel = pcall(function() return v.AssemblyLinearVelocity end)
                if ok and vel and vel.Magnitude > 30 and v.Size.Magnitude < 15 then return v end
            end
        end
    end
end

workspace.DescendantAdded:Connect(function(o)
    if balle and balle.Parent then return end
    if not (o:IsA("BasePart") or o:IsA("MeshPart")) or estJoueur(o) then return end
    local n = o.Name:lower()
    if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb")
        or o:GetAttribute("Target") or o:GetAttribute("target") or o:GetAttribute("realTarget") then
        balle = o
        log("Balle: " .. o.Name)
    end
end)
workspace.DescendantRemoving:Connect(function(o) if o == balle then balle = nil end end)

balle = chercheBalle()
if balle then log("Balle: " .. balle.Name) end

task.spawn(function()
    while true do
        task.wait(0.5)
        if not balle or not balle.Parent then
            balle = chercheBalle()
            if balle then log("Balle: " .. balle.Name) end
        end
    end
end)

-- Remote
pcall(function()
    for _, v in pairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == "ParrySlashAll" then remote = v end
    end
end)

-- ═══════════════════════════════════════════════
--  CIBLE
-- ═══════════════════════════════════════════════
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function checkCible(b)
    local hrp = getHRP()
    if not hrp then return false, math.huge, 0 end
    local d = (b.Position - hrp.Position).Magnitude
    local ok, vel = pcall(function() return b.AssemblyLinearVelocity end)
    if not ok then ok, vel = pcall(function() return b.Velocity end) end
    local spd = (ok and vel) and vel.Magnitude or 0

    local objs = {b}
    if b.Parent and b.Parent ~= workspace then table.insert(objs, b.Parent) end
    local noms = {"Target","target","realTarget","RealTarget","CurrentTarget","currentTarget","TargetPlayer","targetPlayer","PlayerTarget"}

    for _, obj in pairs(objs) do
        for _, nom in pairs(noms) do
            local t = obj:GetAttribute(nom)
            if t ~= nil then
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
    if ok and vel and spd > 10 then
        local dir = (hrp.Position - b.Position).Unit
        if vel.Unit:Dot(dir) > 0.5 then return true, d, spd end
    end
    return false, d, spd
end

-- ═══════════════════════════════════════════════
--  PARRY
-- ═══════════════════════════════════════════════
local function parry()
    local now = tick()
    local cd = 1 / math.max(C.CPS, 1)
    if now - dernierP < cd then return end
    dernierP = now
    compteur += 1
    streak += 1
    if streak > bestStreak then bestStreak = streak end

    local nb = math.clamp(math.ceil(C.CPS / 60), 1, 50)
    for _ = 1, nb do pcall(mouse1click) end
    if remote then pcall(function() remote:FireServer() end) end

    if C.NotifSon then
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = "rbxassetid://12221976"
            s.Volume = 0.3
            s.PlayOnRemove = true
            s.Parent = workspace
            game:GetService("Debris"):AddItem(s, 0.1)
        end)
    end

    log("PARRY #" .. compteur .. " | streak " .. streak)
end

local function doitParry(d, spd)
    if d > C.DistanceMax or d < C.DistanceMin then return false end
    if C.Mode == 1 then return true end
    if C.Mode == 3 then return d <= math.min(C.DistanceMax, 10) end
    -- Mode 2 : predictif
    if spd < 5 then return d <= 12 end
    local t = d / spd
    local seuil = math.clamp(0.04 + (spd / 1200), 0.04, 0.5)
    return t <= seuil
end

-- ═══════════════════════════════════════════════
--  ANTI AFK
-- ═══════════════════════════════════════════════
if C.AntiAFK then
    task.spawn(function()
        while true do
            task.wait(60)
            if C.AntiAFK then
                pcall(function()
                    local ve = game:GetService("VirtualUser")
                    ve:ClickButton2(Vector2.new())
                end)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════
--  GUI — HELPERS
-- ═══════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "AP" .. math.random(10000, 99999)
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local BLEU = Color3.fromRGB(80, 120, 255)
local VERT = Color3.fromRGB(0, 210, 70)
local ROUGE = Color3.fromRGB(220, 50, 50)
local ORANGE = Color3.fromRGB(255, 170, 40)
local FOND = Color3.fromRGB(12, 12, 18)
local FOND2 = Color3.fromRGB(18, 18, 26)
local FOND3 = Color3.fromRGB(25, 25, 35)
local TEXTE = Color3.fromRGB(180, 180, 200)
local TEXTE2 = Color3.fromRGB(110, 110, 130)
local BORD = Color3.fromRGB(45, 45, 60)

local function mk(c, p)
    local o = Instance.new(c)
    for k, v in pairs(p) do if k ~= "Parent" then o[k] = v end end
    if p.Parent then o.Parent = p.Parent end
    return o
end
local function rnd(p, r) mk("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = p}) end

-- Flash ecran
local flash = mk("Frame", {
    Size = UDim2.new(1,0,1,0), BackgroundColor3 = ROUGE,
    BackgroundTransparency = 1, ZIndex = 0, Parent = gui,
})

-- ESP Balle (highlight)
local espHighlight = nil

-- ═══════════════════════════════════════════════
--  GUI — PANEL PRINCIPAL
-- ═══════════════════════════════════════════════
local panel = mk("Frame", {
    Size = UDim2.new(0, 300, 0, 560),
    Position = UDim2.new(0, 14, 0.5, -280),
    BackgroundColor3 = FOND,
    BackgroundTransparency = 0.02,
    ClipsDescendants = true,
    Parent = gui,
})
rnd(panel, 14)
mk("UIStroke", {Color = BORD, Thickness = 1.5, Parent = panel})

-- Taille ouverte / fermee
local tailleOuverte = UDim2.new(0, 300, 0, 560)
local tailleFermee = UDim2.new(0, 300, 0, 44)

-- HEADER
local header = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = FOND2, Parent = panel,
})
rnd(header, 14)

mk("TextLabel", {
    Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1, Text = "AUTO PARRY v8",
    TextColor3 = BLEU, Font = Enum.Font.GothamBold, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})

-- Bouton minimiser
local btnMin = mk("TextButton", {
    Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -40, 0, 7),
    BackgroundColor3 = FOND3, Text = "—",
    TextColor3 = TEXTE, Font = Enum.Font.GothamBold, TextSize = 16, Parent = header,
})
rnd(btnMin, 8)

btnMin.MouseButton1Click:Connect(function()
    panelOuvert = not panelOuvert
    btnMin.Text = panelOuvert and "—" or "+"
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = panelOuvert and tailleOuverte or tailleFermee,
    }):Play()
end)

-- CONTENU (scrollable)
local contenu = mk("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -46),
    Position = UDim2.new(0, 0, 0, 46),
    BackgroundTransparency = 1,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = BLEU,
    CanvasSize = UDim2.new(0, 0, 0, 830),
    Parent = panel,
})

-- ═══════════════════════════════════════════════
--  GUI — COMPOSANTS
-- ═══════════════════════════════════════════════
local function section(parent, titre, yPos)
    mk("TextLabel", {
        Size = UDim2.new(1, -28, 0, 14), Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1, Text = titre:upper(),
        TextColor3 = BLEU, Font = Enum.Font.GothamBold, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    mk("Frame", {
        Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0, yPos + 16),
        BackgroundColor3 = BORD, BorderSizePixel = 0, Parent = parent,
    })
end

local function slider(parent, texte, desc, min, max, defaut, yPos, callback)
    mk("TextLabel", {
        Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1, Text = texte, TextColor3 = TEXTE,
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    local lv = mk("TextLabel", {
        Size = UDim2.new(0, 44, 0, 14), Position = UDim2.new(1, -56, 0, yPos),
        BackgroundTransparency = 1, Text = tostring(defaut), TextColor3 = Color3.fromRGB(220, 220, 230),
        Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = parent,
    })
    if desc then
        mk("TextLabel", {
            Size = UDim2.new(1, -28, 0, 12), Position = UDim2.new(0, 14, 0, yPos + 14),
            BackgroundTransparency = 1, Text = desc, TextColor3 = TEXTE2,
            Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
        })
    end
    local yTrack = desc and yPos + 28 or yPos + 18
    local piste = mk("Frame", {
        Size = UDim2.new(1, -28, 0, 8), Position = UDim2.new(0, 14, 0, yTrack),
        BackgroundColor3 = Color3.fromRGB(28, 28, 40), Parent = parent,
    })
    rnd(piste, 4)
    local fill = mk("Frame", {
        Size = UDim2.new((defaut - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = BLEU, Parent = piste,
    })
    rnd(fill, 4)
    local knob = mk("TextButton", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new((defaut - min) / (max - min), -9, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(235, 235, 245), Text = "", Parent = piste,
    })
    rnd(knob, 9)
    local drag = false
    local function upd(px)
        local r = math.clamp((px - piste.AbsolutePosition.X) / piste.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + r * (max - min) + 0.5)
        fill.Size = UDim2.new(r, 0, 1, 0)
        knob.Position = UDim2.new(r, -9, 0.5, -9)
        lv.Text = tostring(v)
        callback(v)
    end
    knob.MouseButton1Down:Connect(function() drag = true end)
    piste.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; upd(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then upd(i.Position.X) end end)
end

local function toggle(parent, texte, desc, defaut, yPos, callback)
    mk("TextLabel", {
        Size = UDim2.new(1, -64, 0, 14), Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1, Text = texte, TextColor3 = TEXTE,
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    if desc then
        mk("TextLabel", {
            Size = UDim2.new(1, -64, 0, 12), Position = UDim2.new(0, 14, 0, yPos + 14),
            BackgroundTransparency = 1, Text = desc, TextColor3 = TEXTE2,
            Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
        })
    end
    local bg = mk("Frame", {
        Size = UDim2.new(0, 38, 0, 20), Position = UDim2.new(1, -52, 0, yPos),
        BackgroundColor3 = defaut and BLEU or Color3.fromRGB(38, 38, 52), Parent = parent,
    })
    rnd(bg, 10)
    local dot = mk("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = defaut and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Color3.fromRGB(240, 240, 248), Parent = bg,
    })
    rnd(dot, 8)
    local st = defaut
    mk("TextButton", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = bg})
    .MouseButton1Click:Connect(function()
        st = not st
        TweenService:Create(bg, TweenInfo.new(0.12), {BackgroundColor3 = st and BLEU or Color3.fromRGB(38, 38, 52)}):Play()
        TweenService:Create(dot, TweenInfo.new(0.12), {Position = st and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)}):Play()
        callback(st)
    end)
    return function(v)
        st = v
        bg.BackgroundColor3 = st and BLEU or Color3.fromRGB(38, 38, 52)
        dot.Position = st and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    end
end

-- ═══════════════════════════════════════════════
--  GUI — STATUT
-- ═══════════════════════════════════════════════
local lblStatut = mk("TextLabel", {
    Size = UDim2.new(0, 80, 0, 24), Position = UDim2.new(0, 14, 0, 6),
    BackgroundColor3 = VERT, BackgroundTransparency = 0.8,
    Text = " ACTIF", TextColor3 = VERT,
    Font = Enum.Font.GothamBold, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Center, Parent = contenu,
})
rnd(lblStatut, 6)

local lblStats = mk("TextLabel", {
    Size = UDim2.new(1, -24, 0, 70), Position = UDim2.new(0, 14, 0, 36),
    BackgroundTransparency = 1, Text = "...",
    TextColor3 = TEXTE2, Font = Enum.Font.Code, TextSize = 11,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    LineHeight = 1.4, Parent = contenu,
})

local lblLog = mk("TextLabel", {
    Size = UDim2.new(1, -24, 0, 12), Position = UDim2.new(0, 14, 0, 108),
    BackgroundTransparency = 1, Text = "",
    TextColor3 = ORANGE, Font = Enum.Font.Code, TextSize = 9,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = contenu,
})

-- ═══════════════════════════════════════════════
--  GUI — SECTIONS
-- ═══════════════════════════════════════════════

-- ── MODE ──
section(contenu, "Mode de Parry", 128)

local modeNoms = {"INSTANTANE", "PREDICTIF", "PROCHE"}
local modeDesc = {
    "Parry immediatement quand la balle entre dans la zone de distance. Le plus reactif, mais peut parry trop tot.",
    "Calcule le timing parfait selon la vitesse et la distance de la balle. S'adapte aux balles rapides. Recommande.",
    "Attend que la balle soit tres proche (< 10 studs). Plus risque mais plus naturel.",
}
local modeC = {ROUGE, BLEU, ORANGE}

local lblMode = mk("TextButton", {
    Size = UDim2.new(1, -28, 0, 28), Position = UDim2.new(0, 14, 0, 150),
    BackgroundColor3 = modeC[C.Mode], Text = modeNoms[C.Mode],
    TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold,
    TextSize = 13, Parent = contenu,
})
rnd(lblMode, 7)

local lblModeDesc = mk("TextLabel", {
    Size = UDim2.new(1, -28, 0, 30), Position = UDim2.new(0, 14, 0, 182),
    BackgroundTransparency = 1, Text = modeDesc[C.Mode],
    TextColor3 = TEXTE2, Font = Enum.Font.Gotham, TextSize = 9,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = contenu,
})

lblMode.MouseButton1Click:Connect(function()
    C.Mode = (C.Mode % 3) + 1
    TweenService:Create(lblMode, TweenInfo.new(0.15), {BackgroundColor3 = modeC[C.Mode]}):Play()
    lblMode.Text = modeNoms[C.Mode]
    lblModeDesc.Text = modeDesc[C.Mode]
end)

-- ── DISTANCES ──
section(contenu, "Distances", 220)
slider(contenu, "Distance Max", "Zone dans laquelle le parry peut se declencher (en studs)", 1, 100, C.DistanceMax, 242, function(v) C.DistanceMax = v end)
slider(contenu, "Distance Min", "Ignore la balle si elle est plus proche que ca", 0, 50, C.DistanceMin, 288, function(v) C.DistanceMin = v end)

-- ── PERFORMANCE ──
section(contenu, "Performance", 326)
slider(contenu, "CPS (Clics/sec)", "Nombre de clics par seconde. Plus haut = plus reactif. Max 330", 1, 330, C.CPS, 348, function(v) C.CPS = v end)
slider(contenu, "Delai (ms)", "Ajoute un delai avant le parry. 0 = instantane", 0, 500, C.Delai, 394, function(v) C.Delai = v end)

-- ── PRINCIPAL ──
section(contenu, "Principal", 440)
local majToggle = toggle(contenu, "Auto Parry", "Active/desactive le parry automatique", C.Active, 462, function(v)
    C.Active = v
    lblStatut.Text = v and " ACTIF" or " OFF"
    lblStatut.TextColor3 = v and VERT or ROUGE
    lblStatut.BackgroundColor3 = v and VERT or ROUGE
end)

-- ── VISUEL ──
section(contenu, "Visuel", 502)
toggle(contenu, "Flash Ecran", "L'ecran flashe en rouge quand tu es cible", C.FlashEcran, 524, function(v) C.FlashEcran = v end)

toggle(contenu, "ESP Balle", "Met un highlight visible sur la balle", C.ESPBalle, 556, function(v)
    C.ESPBalle = v
    if not v and espHighlight then espHighlight:Destroy(); espHighlight = nil end
end)

toggle(contenu, "Son de Parry", "Joue un son quand tu parry", C.NotifSon, 588, function(v) C.NotifSon = v end)

-- ── EXTRA ──
section(contenu, "Extra", 622)
toggle(contenu, "Anti-AFK", "Empeche d'etre kick pour inactivite", C.AntiAFK, 644, function(v) C.AntiAFK = v end)

-- Bouton recherche
mk("Frame", {
    Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0, 686),
    BackgroundColor3 = BORD, BorderSizePixel = 0, Parent = contenu,
})

local btnR = mk("TextButton", {
    Size = UDim2.new(1, -28, 0, 28), Position = UDim2.new(0, 14, 0, 696),
    BackgroundColor3 = FOND3, Text = "Forcer recherche balle",
    TextColor3 = TEXTE, Font = Enum.Font.GothamBold, TextSize = 11, Parent = contenu,
})
rnd(btnR, 6)
btnR.MouseButton1Click:Connect(function()
    balle = chercheBalle()
    log(balle and "Balle: " .. balle:GetFullName() or "Aucune balle !")
end)

local btnReset = mk("TextButton", {
    Size = UDim2.new(1, -28, 0, 28), Position = UDim2.new(0, 14, 0, 732),
    BackgroundColor3 = FOND3, Text = "Reset compteur / streak",
    TextColor3 = TEXTE, Font = Enum.Font.GothamBold, TextSize = 11, Parent = contenu,
})
rnd(btnReset, 6)
btnReset.MouseButton1Click:Connect(function()
    compteur = 0; streak = 0; bestStreak = 0
    log("Stats reset")
end)

-- ── RACCOURCIS ──
section(contenu, "Raccourcis", 772)
mk("TextLabel", {
    Size = UDim2.new(1, -28, 0, 40), Position = UDim2.new(0, 14, 0, 792),
    BackgroundTransparency = 1,
    Text = "RShift = Activer / Desactiver\nRCtrl  = Ouvrir / Fermer le panel",
    TextColor3 = TEXTE2, Font = Enum.Font.Gotham, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, LineHeight = 1.6, Parent = contenu,
})

-- ═══════════════════════════════════════════════
--  DRAG
-- ═══════════════════════════════════════════════
local dd, sp
header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = i.Position; sp = panel.Position end end)
header.InputChanged:Connect(function(i) if dd and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - dd; panel.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = nil end end)

-- ═══════════════════════════════════════════════
--  RACCOURCIS
-- ═══════════════════════════════════════════════
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == C.KToggle then
        C.Active = not C.Active
        majToggle(C.Active)
        lblStatut.Text = C.Active and " ACTIF" or " OFF"
        lblStatut.TextColor3 = C.Active and VERT or ROUGE
        lblStatut.BackgroundColor3 = C.Active and VERT or ROUGE
    elseif input.KeyCode == C.KPanel then
        panel.Visible = not panel.Visible
    end
end)

gui.Parent = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════
--  ESP BALLE
-- ═══════════════════════════════════════════════
local function majESP()
    if not C.ESPBalle then
        if espHighlight then espHighlight:Destroy(); espHighlight = nil end
        return
    end
    if balle and balle.Parent then
        if not espHighlight or espHighlight.Parent ~= balle then
            if espHighlight then espHighlight:Destroy() end
            espHighlight = Instance.new("Highlight")
            espHighlight.FillColor = BLEU
            espHighlight.FillTransparency = 0.6
            espHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            espHighlight.OutlineTransparency = 0.3
            espHighlight.Adornee = balle
            espHighlight.Parent = balle
        end
        if cible then
            espHighlight.FillColor = ROUGE
            espHighlight.OutlineColor = ROUGE
        else
            espHighlight.FillColor = BLEU
            espHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        end
    else
        if espHighlight then espHighlight:Destroy(); espHighlight = nil end
    end
end

-- ═══════════════════════════════════════════════
--  BOUCLE PRINCIPALE — RenderStepped
-- ═══════════════════════════════════════════════
local mN = {"INSTANT", "PREDICT", "PROCHE"}

RunService.RenderStepped:Connect(function()
    local ok = balle and balle.Parent and true or false

    if ok then
        cible, dBalle, vBalle = checkCible(balle)
    else
        cible, dBalle, vBalle = false, 0, 0
    end

    -- Reset streak si plus cible
    if not cible then streak = 0 end

    -- Flash
    if C.FlashEcran and cible and dBalle < C.DistanceMax then
        flash.BackgroundTransparency = 1 - math.clamp(1 - (dBalle / C.DistanceMax), 0, 0.25)
    else
        flash.BackgroundTransparency = 1
    end

    -- ESP
    majESP()

    -- Stats
    lblStats.Text = string.format(
        "Parrys: %d  |  Streak: %d  |  Best: %d\nBalle: %s  |  Mode: %s\nVitesse: %d  |  Distance: %d  |  CPS: %d\nCible: %s",
        compteur, streak, bestStreak,
        ok and "OUI" or "NON", mN[C.Mode],
        math.floor(vBalle), math.floor(dBalle), C.CPS,
        cible and "OUI" or "non"
    )
    lblLog.Text = derLog

    -- Parry
    if not C.Active or not ok or not cible then return end

    if doitParry(dBalle, vBalle) then
        if C.Delai > 0 then
            task.delay(C.Delai / 1000, parry)
        else
            parry()
        end
    end
end)

log("v8 ULTRA charge")
