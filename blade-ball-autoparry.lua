-- Auto Parry v9.5 — Interface Premium

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════
local C = {
    Active = true,
    Mode = 1,
    DistanceMax = 35,
    DistanceMin = 0,
    Delai = 0,
    CPS = 60,
    MultiClick = 3,
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

local function log(m) derLog = os.date("%H:%M:%S") .. " " .. m end

-- ═══════════════════════════════════════════════
--  COULEURS
-- ═══════════════════════════════════════════════
local ACCENT   = Color3.fromRGB(90, 120, 255)
local ACCENT2  = Color3.fromRGB(130, 90, 255)
local GREEN    = Color3.fromRGB(45, 210, 90)
local RED      = Color3.fromRGB(230, 55, 55)
local ORANGE   = Color3.fromRGB(255, 165, 40)
local YELLOW   = Color3.fromRGB(255, 220, 50)
local BG1      = Color3.fromRGB(10, 10, 16)
local BG2      = Color3.fromRGB(16, 16, 24)
local BG3      = Color3.fromRGB(22, 22, 32)
local BG4      = Color3.fromRGB(30, 30, 42)
local BORDER   = Color3.fromRGB(38, 38, 55)
local TEXT1    = Color3.fromRGB(225, 225, 240)
local TEXT2    = Color3.fromRGB(150, 150, 175)
local TEXT3    = Color3.fromRGB(90, 90, 115)

-- ═══════════════════════════════════════════════
--  BALLE
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
    end
end)
workspace.DescendantRemoving:Connect(function(o) if o == balle then balle = nil end end)

balle = chercheBalle()
task.spawn(function()
    while true do
        task.wait(0.5)
        if not balle or not balle.Parent then balle = chercheBalle() end
    end
end)

-- ═══════════════════════════════════════════════
--  CIBLE
-- ═══════════════════════════════════════════════
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local noms = {"Target","target","realTarget","RealTarget","CurrentTarget","currentTarget","TargetPlayer","targetPlayer","PlayerTarget"}

local function checkCible(b)
    local hrp = getHRP()
    if not hrp then return false, math.huge, 0 end
    local d = (b.Position - hrp.Position).Magnitude
    local ok, vel = pcall(function() return b.AssemblyLinearVelocity end)
    if not ok then ok, vel = pcall(function() return b.Velocity end) end
    local spd = (ok and vel) and vel.Magnitude or 0

    local objs = {b}
    if b.Parent and b.Parent ~= workspace then objs[2] = b.Parent end

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
        if vel.Unit:Dot(dir) > 0.45 then return true, d, spd end
    end
    return false, d, spd
end

-- ═══════════════════════════════════════════════
--  PARRY
-- ═══════════════════════════════════════════════
local flashFrame

local function parry()
    local now = tick()
    local cd = 1 / math.max(C.CPS, 1)
    if now - dernierP < cd then return end
    dernierP = now
    compteur += 1
    streak += 1
    if streak > best then best = streak end

    local nb = math.clamp(C.MultiClick, 1, 50)
    for _ = 1, nb do pcall(mouse1click) end

    if C.FlashParry and flashFrame then
        flashFrame.BackgroundTransparency = 0.85
        TweenService:Create(flashFrame, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
    end

    log("PARRY #" .. compteur .. " | d=" .. math.floor(dBalle) .. " v=" .. math.floor(vBalle))
end

local function doitParry(d, spd)
    if d > C.DistanceMax or d < C.DistanceMin then return false end
    if C.Mode == 1 then
        if spd > 200 then return true end
        if spd > 100 then return d <= C.DistanceMax end
        return d <= C.DistanceMax * 0.8
    elseif C.Mode == 2 then
        if spd < 5 then return d <= 15 end
        local t = d / spd
        local seuil = math.clamp(0.1 + (spd / 400), 0.1, 1.0)
        return t <= seuil
    elseif C.Mode == 3 then
        if spd < 5 then return d <= 10 end
        local t = d / spd
        local seuil = math.clamp(0.05 + (spd / 800), 0.05, 0.3)
        return t <= seuil
    end
    return false
end

-- ═══════════════════════════════════════════════
--  ANTI AFK
-- ═══════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(120)
        if C.AntiAFK then
            local hrp = getHRP()
            if hrp then pcall(function() hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, 0) end) end
        end
    end
end)

-- ═══════════════════════════════════════════════
--  GUI — CREATION
-- ═══════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = HttpService:GenerateGUID(false):sub(1, 8)
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function mk(c, p)
    local o = Instance.new(c)
    for k, v in pairs(p) do if k ~= "Parent" then o[k] = v end end
    if p.Parent then o.Parent = p.Parent end
    return o
end
local function rnd(p, r) mk("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = p}) end
local function str(p, c, t) mk("UIStroke", {Color = c or BORDER, Thickness = t or 1, Parent = p}) end

-- Flash overlay
flashFrame = mk("Frame", {
    Size = UDim2.new(1,0,1,0), BackgroundColor3 = ACCENT,
    BackgroundTransparency = 1, ZIndex = 100, Parent = gui,
})

-- ═══════════════════════════════════════════════
--  PANEL PRINCIPAL
-- ═══════════════════════════════════════════════
local W, H_OPEN, H_CLOSED = 320, 560, 48

local panel = mk("Frame", {
    Size = UDim2.new(0, W, 0, H_OPEN),
    Position = UDim2.new(0, 16, 0.5, -H_OPEN/2),
    BackgroundColor3 = BG1, BackgroundTransparency = 0.03,
    ClipsDescendants = true, Parent = gui,
})
rnd(panel, 16)
str(panel, BORDER, 1.5)

-- Ombre
mk("ImageLabel", {
    Size = UDim2.new(1,40,1,40), Position = UDim2.new(0,-20,0,-20),
    BackgroundTransparency = 1, ImageTransparency = 0.6,
    Image = "rbxassetid://6014261993", ImageColor3 = Color3.fromRGB(0,0,0),
    ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49,49,450,450),
    ZIndex = -1, Parent = panel,
})

-- ═══════════════════════════════════════════════
--  HEADER
-- ═══════════════════════════════════════════════
local hdr = mk("Frame", {Size = UDim2.new(1,0,0,48), BackgroundColor3 = BG2, Parent = panel})
rnd(hdr, 16)

mk("Frame", {Size = UDim2.new(1,-32,0,3), Position = UDim2.new(0,16,0,0), BackgroundColor3 = ACCENT, Parent = hdr})

local iconBg = mk("Frame", {Size = UDim2.new(0,28,0,28), Position = UDim2.new(0,14,0,12), BackgroundColor3 = ACCENT, Parent = hdr})
rnd(iconBg, 14)
mk("TextLabel", {
    Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
    Text = "AP", TextColor3 = TEXT1, Font = Enum.Font.GothamBlack, TextSize = 11, Parent = iconBg,
})

mk("TextLabel", {
    Size = UDim2.new(1,-120,0,16), Position = UDim2.new(0,50,0,10),
    BackgroundTransparency = 1, Text = "AUTO PARRY",
    TextColor3 = TEXT1, Font = Enum.Font.GothamBlack, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr,
})
mk("TextLabel", {
    Size = UDim2.new(1,-120,0,12), Position = UDim2.new(0,50,0,27),
    BackgroundTransparency = 1, Text = "v9.5 · Indetectable",
    TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr,
})

local btnMin = mk("TextButton", {
    Size = UDim2.new(0,32,0,32), Position = UDim2.new(1,-46,0,8),
    BackgroundColor3 = BG4, Text = "—",
    TextColor3 = TEXT2, Font = Enum.Font.GothamBold, TextSize = 16, Parent = hdr,
})
rnd(btnMin, 10)

btnMin.MouseButton1Click:Connect(function()
    ouvert = not ouvert
    btnMin.Text = ouvert and "—" or "+"
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, W, 0, ouvert and H_OPEN or H_CLOSED)
    }):Play()
end)

-- ═══════════════════════════════════════════════
--  ONGLETS
-- ═══════════════════════════════════════════════
local tabBar = mk("Frame", {Size = UDim2.new(1,-24,0,32), Position = UDim2.new(0,12,0,52), BackgroundColor3 = BG3, Parent = panel})
rnd(tabBar, 10)

local tabNames = {"Statut", "Config", "Extra"}
local tabBtns = {}
local pages = {}

for i, name in ipairs(tabNames) do
    local btn = mk("TextButton", {
        Size = UDim2.new(1/#tabNames, -4, 1, -4),
        Position = UDim2.new((i-1)/#tabNames, 2, 0, 2),
        BackgroundColor3 = i == 1 and ACCENT or BG3,
        BackgroundTransparency = i == 1 and 0 or 1,
        Text = name, TextColor3 = i == 1 and TEXT1 or TEXT3,
        Font = Enum.Font.GothamBold, TextSize = 11, Parent = tabBar,
    })
    rnd(btn, 8)
    tabBtns[i] = btn

    local page = mk("ScrollingFrame", {
        Size = UDim2.new(1,0,1,-88), Position = UDim2.new(0,0,0,88),
        BackgroundTransparency = 1, ScrollBarThickness = 2,
        ScrollBarImageColor3 = ACCENT, CanvasSize = UDim2.new(0,0,0,0),
        Visible = i == 1, Parent = panel,
    })
    pages[i] = page

    btn.MouseButton1Click:Connect(function()
        onglet = i
        for j, b in ipairs(tabBtns) do
            TweenService:Create(b, TweenInfo.new(0.12), {
                BackgroundColor3 = j == i and ACCENT or BG3,
                BackgroundTransparency = j == i and 0 or 1,
                TextColor3 = j == i and TEXT1 or TEXT3,
            }):Play()
            pages[j].Visible = (j == i)
        end
    end)
end

-- ═══════════════════════════════════════════════
--  COMPOSANTS UI
-- ═══════════════════════════════════════════════
local function card(parent, y, h)
    local c = mk("Frame", {
        Size = UDim2.new(1,-24,0,h), Position = UDim2.new(0,12,0,y),
        BackgroundColor3 = BG2, Parent = parent,
    })
    rnd(c, 10)
    str(c, BORDER, 0.5)
    return c
end

local function sectionTitle(parent, y, title)
    mk("TextLabel", {
        Size = UDim2.new(1,-28,0,12), Position = UDim2.new(0,14,0,y),
        BackgroundTransparency = 1, Text = title:upper(),
        TextColor3 = ACCENT, Font = Enum.Font.GothamBlack, TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
end

local function makeSlider(parent, y, label, desc, min, max, def, unit, cb)
    mk("TextLabel", {
        Size = UDim2.new(1,-60,0,13), Position = UDim2.new(0,12,0,y),
        BackgroundTransparency = 1, Text = label, TextColor3 = TEXT1,
        Font = Enum.Font.GothamSemibold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    local valLbl = mk("TextLabel", {
        Size = UDim2.new(0,48,0,13), Position = UDim2.new(1,-58,0,y),
        BackgroundTransparency = 1, Text = tostring(def) .. (unit or ""),
        TextColor3 = ACCENT, Font = Enum.Font.GothamBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = parent,
    })
    local dy = y + 15
    if desc then
        mk("TextLabel", {
            Size = UDim2.new(1,-24,0,11), Position = UDim2.new(0,12,0,dy),
            BackgroundTransparency = 1, Text = desc, TextColor3 = TEXT3,
            Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
        })
        dy = dy + 13
    end
    local track = mk("Frame", {
        Size = UDim2.new(1,-24,0,6), Position = UDim2.new(0,12,0,dy+2),
        BackgroundColor3 = BG4, Parent = parent,
    })
    rnd(track, 3)
    local fill = mk("Frame", {
        Size = UDim2.new((def-min)/(max-min),0,1,0),
        BackgroundColor3 = ACCENT, Parent = track,
    })
    rnd(fill, 3)
    local fillGlow = mk("Frame", {
        Size = UDim2.new(1,0,1,4), Position = UDim2.new(0,0,0,-2),
        BackgroundColor3 = ACCENT, BackgroundTransparency = 0.7, Parent = fill,
    })
    rnd(fillGlow, 3)

    local knob = mk("TextButton", {
        Size = UDim2.new(0,16,0,16), Position = UDim2.new((def-min)/(max-min),-8,0.5,-8),
        BackgroundColor3 = Color3.fromRGB(240,240,252), Text = "", Parent = track,
    })
    rnd(knob, 8)
    mk("UIStroke", {Color = ACCENT, Thickness = 2, Parent = knob})

    local drag = false
    local function up(px)
        local r = math.clamp((px - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + r*(max-min) + 0.5)
        fill.Size = UDim2.new(r,0,1,0)
        knob.Position = UDim2.new(r,-8,0.5,-8)
        valLbl.Text = tostring(v) .. (unit or "")
        cb(v)
    end
    knob.MouseButton1Down:Connect(function() drag = true end)
    track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; up(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then up(i.Position.X) end end)
end

local function makeToggle(parent, y, label, desc, def, cb)
    mk("TextLabel", {
        Size = UDim2.new(1,-64,0,13), Position = UDim2.new(0,12,0,y),
        BackgroundTransparency = 1, Text = label, TextColor3 = TEXT1,
        Font = Enum.Font.GothamSemibold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    if desc then
        mk("TextLabel", {
            Size = UDim2.new(1,-64,0,10), Position = UDim2.new(0,12,0,y+14),
            BackgroundTransparency = 1, Text = desc, TextColor3 = TEXT3,
            Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
        })
    end
    local bg = mk("Frame", {
        Size = UDim2.new(0,40,0,22), Position = UDim2.new(1,-54,0,y),
        BackgroundColor3 = def and ACCENT or BG4, Parent = parent,
    })
    rnd(bg, 11)
    local dot = mk("Frame", {
        Size = UDim2.new(0,16,0,16), Position = def and UDim2.new(1,-19,0,3) or UDim2.new(0,3,0,3),
        BackgroundColor3 = Color3.fromRGB(245,245,255), Parent = bg,
    })
    rnd(dot, 8)

    local state = def
    local hitArea = mk("TextButton", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = bg})
    hitArea.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(bg, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {BackgroundColor3 = state and ACCENT or BG4}):Play()
        TweenService:Create(dot, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {Position = state and UDim2.new(1,-19,0,3) or UDim2.new(0,3,0,3)}):Play()
        cb(state)
    end)

    return function(v)
        state = v
        bg.BackgroundColor3 = v and ACCENT or BG4
        dot.Position = v and UDim2.new(1,-19,0,3) or UDim2.new(0,3,0,3)
    end
end

local function makeButton(parent, y, label, color, cb)
    local btn = mk("TextButton", {
        Size = UDim2.new(1,-24,0,30), Position = UDim2.new(0,12,0,y),
        BackgroundColor3 = color or BG4, Text = label,
        TextColor3 = TEXT1, Font = Enum.Font.GothamBold, TextSize = 11, Parent = parent,
    })
    rnd(btn, 8)
    btn.MouseButton1Click:Connect(cb)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.15}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
    end)
    return btn
end

-- ═══════════════════════════════════════════════
--  PAGE 1 : STATUT
-- ═══════════════════════════════════════════════
local p1 = pages[1]

-- Statut ON/OFF
local statusCard = card(p1, 6, 44)
local statusDot = mk("Frame", {
    Size = UDim2.new(0,10,0,10), Position = UDim2.new(0,14,0,17),
    BackgroundColor3 = GREEN, Parent = statusCard,
})
rnd(statusDot, 5)
local statusLbl = mk("TextLabel", {
    Size = UDim2.new(0,80,0,14), Position = UDim2.new(0,30,0,15),
    BackgroundTransparency = 1, Text = "ACTIF",
    TextColor3 = GREEN, Font = Enum.Font.GothamBlack, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = statusCard,
})
task.spawn(function()
    while true do
        if C.Active then
            TweenService:Create(statusDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.4}):Play()
            task.wait(0.8)
            TweenService:Create(statusDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0}):Play()
            task.wait(0.8)
        else
            statusDot.BackgroundTransparency = 0
            task.wait(0.5)
        end
    end
end)

-- Stats cards
local function statBox(parent, x, y, w, title)
    local box = mk("Frame", {
        Size = UDim2.new(0,w,0,52), Position = UDim2.new(0,x,0,y),
        BackgroundColor3 = BG2, Parent = parent,
    })
    rnd(box, 8)
    str(box, BORDER, 0.5)
    mk("TextLabel", {
        Size = UDim2.new(1,0,0,10), Position = UDim2.new(0,0,0,6),
        BackgroundTransparency = 1, Text = title:upper(),
        TextColor3 = TEXT3, Font = Enum.Font.GothamBold, TextSize = 8,
        Parent = box,
    })
    local val = mk("TextLabel", {
        Size = UDim2.new(1,0,0,22), Position = UDim2.new(0,0,0,20),
        BackgroundTransparency = 1, Text = "0",
        TextColor3 = TEXT1, Font = Enum.Font.GothamBlack, TextSize = 20,
        Parent = box,
    })
    return val
end

local lblParrys = statBox(p1, 12, 58, 90, "Parrys")
local lblStreak = statBox(p1, 108, 58, 90, "Streak")
local lblBest   = statBox(p1, 204, 58, 90, "Record")

-- Balle info card
local balleCard = card(p1, 118, 68)
sectionTitle(balleCard, 8, "Detection balle")
local lblBalleStatus = mk("TextLabel", {
    Size = UDim2.new(1,-24,0,12), Position = UDim2.new(0,12,0,24),
    BackgroundTransparency = 1, Text = "Recherche...",
    TextColor3 = TEXT2, Font = Enum.Font.Gotham, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard,
})
local lblBalleInfo = mk("TextLabel", {
    Size = UDim2.new(1,-24,0,12), Position = UDim2.new(0,12,0,40),
    BackgroundTransparency = 1, Text = "Vitesse: 0 | Distance: 0 | Cible: non",
    TextColor3 = TEXT3, Font = Enum.Font.Code, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = balleCard,
})

-- Mode actif
local modeCard = card(p1, 194, 70)
sectionTitle(modeCard, 8, "Mode actif")

local mNoms = {"AGRESSIF", "PREDICTIF", "SAFE"}
local mDesc = {
    "Parry des la detection. Zone elargie pour balles rapides.",
    "Timing calcule selon vitesse/distance. Equilibre.",
    "Timing conservateur. Moins reactif mais plus sur.",
}
local mColors = {RED, ACCENT, GREEN}

local modeLbl = mk("TextLabel", {
    Size = UDim2.new(1,-24,0,18), Position = UDim2.new(0,12,0,24),
    BackgroundTransparency = 1, Text = mNoms[C.Mode],
    TextColor3 = mColors[C.Mode], Font = Enum.Font.GothamBlack, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = modeCard,
})
local modeDescLbl = mk("TextLabel", {
    Size = UDim2.new(1,-24,0,12), Position = UDim2.new(0,12,0,46),
    BackgroundTransparency = 1, Text = mDesc[C.Mode],
    TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 9,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = modeCard,
})

-- Log
local logCard = card(p1, 272, 44)
sectionTitle(logCard, 6, "Dernier evenement")
local logLbl = mk("TextLabel", {
    Size = UDim2.new(1,-24,0,12), Position = UDim2.new(0,12,0,24),
    BackgroundTransparency = 1, Text = "...",
    TextColor3 = ORANGE, Font = Enum.Font.Code, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = logCard,
})

-- Boutons
makeButton(p1, 326, "Forcer recherche balle", BG4, function()
    balle = chercheBalle()
    log(balle and "Balle trouvee: " .. balle.Name or "Aucune balle trouvee")
end)

makeButton(p1, 362, "Reset statistiques", BG4, function()
    compteur = 0; streak = 0; best = 0; log("Stats reinit.")
end)

-- Raccourcis
local kCard = card(p1, 400, 50)
sectionTitle(kCard, 6, "Raccourcis clavier")
mk("TextLabel", {
    Size = UDim2.new(1,-24,0,28), Position = UDim2.new(0,12,0,20),
    BackgroundTransparency = 1,
    Text = "RShift  Activer / Desactiver\nRCtrl   Afficher / Masquer",
    TextColor3 = TEXT3, Font = Enum.Font.Code, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left, LineHeight = 1.4, Parent = kCard,
})
p1.CanvasSize = UDim2.new(0,0,0,458)

-- ═══════════════════════════════════════════════
--  PAGE 2 : CONFIG
-- ═══════════════════════════════════════════════
local p2 = pages[2]

-- Toggle ON/OFF
local mainCard = card(p2, 6, 42)
local majToggle = makeToggle(mainCard, 12, "Auto Parry", nil, C.Active, function(v)
    C.Active = v
    statusLbl.Text = v and "ACTIF" or "INACTIF"
    statusLbl.TextColor3 = v and GREEN or RED
    statusDot.BackgroundColor3 = v and GREEN or RED
end)

-- Mode selector
local modeSelCard = card(p2, 56, 50)
sectionTitle(modeSelCard, 8, "Mode de parry")
local modeBtns = {}
for i = 1, 3 do
    local mb = mk("TextButton", {
        Size = UDim2.new(1/3,-6,0,24), Position = UDim2.new((i-1)/3,2,0,22),
        BackgroundColor3 = i == C.Mode and mColors[i] or BG4,
        Text = mNoms[i], TextColor3 = i == C.Mode and TEXT1 or TEXT3,
        Font = Enum.Font.GothamBold, TextSize = 9, Parent = modeSelCard,
    })
    rnd(mb, 6)
    modeBtns[i] = mb
    mb.MouseButton1Click:Connect(function()
        C.Mode = i
        modeLbl.Text = mNoms[i]; modeLbl.TextColor3 = mColors[i]
        modeDescLbl.Text = mDesc[i]
        for j, b in ipairs(modeBtns) do
            TweenService:Create(b, TweenInfo.new(0.12), {
                BackgroundColor3 = j == i and mColors[j] or BG4,
                TextColor3 = j == i and TEXT1 or TEXT3,
            }):Play()
        end
    end)
end

-- Distances
local distCard = card(p2, 114, 100)
sectionTitle(distCard, 8, "Distances (studs)")
makeSlider(distCard, 24, "Distance Max", "Zone de detection du parry", 1, 100, C.DistanceMax, "", function(v) C.DistanceMax = v end)
makeSlider(distCard, 64, "Distance Min", "Ignore si trop proche", 0, 50, C.DistanceMin, "", function(v) C.DistanceMin = v end)

-- Performance
local perfCard = card(p2, 222, 140)
sectionTitle(perfCard, 8, "Performance")
makeSlider(perfCard, 24, "CPS", "Clics par seconde", 1, 330, C.CPS, " c/s", function(v) C.CPS = v end)
makeSlider(perfCard, 64, "Multi-Click", "Clics par parry", 1, 50, C.MultiClick, "x", function(v) C.MultiClick = v end)
makeSlider(perfCard, 104, "Delai", "Attente avant parry (ms)", 0, 500, C.Delai, "ms", function(v) C.Delai = v end)

-- Config recommandee
local recCard = card(p2, 370, 100)
sectionTitle(recCard, 8, "Configs recommandees")
makeButton(recCard, 24, "Rapide (Agressif, 120 CPS)", Color3.fromRGB(40, 25, 55), function()
    C.Mode = 1; C.CPS = 120; C.MultiClick = 4; C.DistanceMax = 45; C.Delai = 0
    for j, b in ipairs(modeBtns) do b.BackgroundColor3 = j==1 and mColors[1] or BG4; b.TextColor3 = j==1 and TEXT1 or TEXT3 end
    modeLbl.Text = mNoms[1]; modeLbl.TextColor3 = mColors[1]; modeDescLbl.Text = mDesc[1]
    log("Config: Rapide appliquee")
end)
makeButton(recCard, 60, "Equilibre (Predictif, 60 CPS)", Color3.fromRGB(20, 25, 55), function()
    C.Mode = 2; C.CPS = 60; C.MultiClick = 3; C.DistanceMax = 35; C.Delai = 0
    for j, b in ipairs(modeBtns) do b.BackgroundColor3 = j==2 and mColors[2] or BG4; b.TextColor3 = j==2 and TEXT1 or TEXT3 end
    modeLbl.Text = mNoms[2]; modeLbl.TextColor3 = mColors[2]; modeDescLbl.Text = mDesc[2]
    log("Config: Equilibre appliquee")
end)

p2.CanvasSize = UDim2.new(0,0,0,478)

-- ═══════════════════════════════════════════════
--  PAGE 3 : EXTRA
-- ═══════════════════════════════════════════════
local p3 = pages[3]

local extraCard = card(p3, 6, 110)
sectionTitle(extraCard, 8, "Options supplementaires")
makeToggle(extraCard, 26, "Anti-AFK", "Empeche le kick pour inactivite", C.AntiAFK, function(v) C.AntiAFK = v end)
makeToggle(extraCard, 58, "Flash Parry", "Flash bleu quand on parry", C.FlashParry, function(v) C.FlashParry = v end)

-- Info card
local infoCard = card(p3, 124, 110)
sectionTitle(infoCard, 8, "Informations")
mk("TextLabel", {
    Size = UDim2.new(1,-24,0,80), Position = UDim2.new(0,12,0,24),
    BackgroundTransparency = 1,
    Text = "Version 9.5 · Indetectable\n\nMethode: mouse1click() uniquement\nAucun remote fire, aucun Highlight,\naucun Sound, aucun VirtualUser.\n\nZero element detectable par le BAC.",
    TextColor3 = TEXT3, Font = Enum.Font.Gotham, TextSize = 9,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    LineHeight = 1.35, Parent = infoCard,
})

p3.CanvasSize = UDim2.new(0,0,0,242)

-- ═══════════════════════════════════════════════
--  DRAG
-- ═══════════════════════════════════════════════
local dd, sp
hdr.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = i.Position; sp = panel.Position end
end)
hdr.InputChanged:Connect(function(i)
    if dd and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dd
        panel.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = nil end end)

-- ═══════════════════════════════════════════════
--  RACCOURCIS
-- ═══════════════════════════════════════════════
UIS.InputBegan:Connect(function(input, g)
    if g then return end
    if input.KeyCode == C.KToggle then
        C.Active = not C.Active; majToggle(C.Active)
        statusLbl.Text = C.Active and "ACTIF" or "INACTIF"
        statusLbl.TextColor3 = C.Active and GREEN or RED
        statusDot.BackgroundColor3 = C.Active and GREEN or RED
    elseif input.KeyCode == C.KPanel then
        panel.Visible = not panel.Visible
    end
end)

gui.Parent = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════
--  BOUCLE PRINCIPALE — BindToRenderStep
-- ═══════════════════════════════════════════════
RunService:BindToRenderStep("AutoParry", Enum.RenderPriority.First.Value, function()
    local ok = balle and balle.Parent and true or false

    if ok then
        cible, dBalle, vBalle = checkCible(balle)
    else
        cible = false; dBalle = 0; vBalle = 0
    end

    if not cible then streak = 0 end

    if onglet == 1 then
        lblParrys.Text = tostring(compteur)
        lblStreak.Text = tostring(streak)
        lblBest.Text = tostring(best)

        if ok then
            lblBalleStatus.Text = "Balle detectee: " .. balle.Name
            lblBalleStatus.TextColor3 = GREEN
        else
            lblBalleStatus.Text = "Recherche en cours..."
            lblBalleStatus.TextColor3 = ORANGE
        end

        lblBalleInfo.Text = string.format("Vitesse: %d | Distance: %d | Cible: %s",
            math.floor(vBalle), math.floor(dBalle), cible and "OUI" or "non")
        lblBalleInfo.TextColor3 = cible and YELLOW or TEXT3

        logLbl.Text = derLog
    end

    if not C.Active or not ok or not cible then return end

    if doitParry(dBalle, vBalle) then
        if C.Delai > 0 then
            task.delay(C.Delai / 1000, parry)
        else
            parry()
        end
    end
end)
