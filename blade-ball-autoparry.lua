-- Auto Parry v14 — Final | ETA Timing | Zero Lag | Zero Faux Clic

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
    for _ = 1, 16 do s = s .. string.char(math.random(97, 122)) end
    return s
end
local RK = rkey()

-- ═══════════════════════════════════════
--  ETAT
-- ═══════════════════════════════════════
local actif = true
local balle = nil
local cachedHRP = nil
local cachedChar = nil
local dernierP = 0
local compteur = 0
local streak = 0
local best = 0
local ouvert = true
local curDist = 999
local prevDist = 999
local prevTime = 0
local closingSpd = 0
local approcheSuite = 0
local eta = 999
local cachedCible = false
local cachedConfirme = false
local frameN = 0

-- ═══════════════════════════════════════
--  CONSTANTES — bases sur les vraies mecaniques du jeu
--  Le parry leve un bouclier ~500ms
--  La balle est "homing" (pourchasse sa cible)
--  Timing = tout : cliquer quand ETA est dans la fenetre du bouclier
-- ═══════════════════════════════════════
local ETA_CONFIRME = 0.43
local ETA_ESTIME   = 0.28
local ETA_MIN      = 0.04
local COOLDOWN     = 0.6
local APPROACH_MIN = 6
local DOT_MIN      = 0.25
local SMOOTH       = 0.35

-- ═══════════════════════════════════════
--  COULEURS
-- ═══════════════════════════════════════
local ACCENT = Color3.fromRGB(90, 120, 255)
local GREEN  = Color3.fromRGB(45, 210, 90)
local RED    = Color3.fromRGB(230, 55, 55)
local ORANGE = Color3.fromRGB(255, 165, 40)
local YELLOW = Color3.fromRGB(255, 220, 50)
local BG1    = Color3.fromRGB(10, 10, 18)
local BG2    = Color3.fromRGB(18, 18, 28)
local BG3    = Color3.fromRGB(28, 28, 40)
local BG4    = Color3.fromRGB(38, 38, 54)
local BORD   = Color3.fromRGB(42, 42, 62)
local TXT1   = Color3.fromRGB(235, 235, 248)
local TXT2   = Color3.fromRGB(155, 155, 180)
local TXT3   = Color3.fromRGB(95, 95, 125)

-- ═══════════════════════════════════════
--  CACHE PERSONNAGE
-- ═══════════════════════════════════════
local function majChar()
    cachedChar = LP.Character
    cachedHRP = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")
end
majChar()
LP.CharacterAdded:Connect(function(c)
    cachedChar = c
    c:WaitForChild("HumanoidRootPart", 5)
    cachedHRP = c:FindFirstChild("HumanoidRootPart")
end)
LP.CharacterRemoving:Connect(function()
    cachedChar = nil
    cachedHRP = nil
end)

-- ═══════════════════════════════════════
--  DETECTION BALLE — event-based, zero lag
-- ═══════════════════════════════════════
local function estJoueur(o)
    local p = o.Parent
    while p and p ~= workspace do
        if Players:GetPlayerFromCharacter(p) then return true end
        p = p.Parent
    end
    return false
end

local function estBalle(o)
    if not (o:IsA("BasePart") or o:IsA("MeshPart")) then return false end
    if estJoueur(o) then return false end
    local n = o.Name:lower()
    if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb") then return true end
    local ok1, a1 = pcall(o.GetAttribute, o, "Target")
    if ok1 and a1 ~= nil then return true end
    local ok2, a2 = pcall(o.GetAttribute, o, "target")
    if ok2 and a2 ~= nil then return true end
    return false
end

local function resetTracking()
    prevDist = 999
    closingSpd = 0
    approcheSuite = 0
    eta = 999
    cachedCible = false
    cachedConfirme = false
end

local function scanBalleLeger()
    for _, name in pairs({"Ball", "ball", "Balle", "Projectile", "projectile", "Orb", "orb"}) do
        local ok, b = pcall(workspace.FindFirstChild, workspace, name, true)
        if ok and b and (b:IsA("BasePart") or b:IsA("MeshPart")) and not estJoueur(b) then
            return b
        end
    end
    local ok, folder = pcall(workspace.FindFirstChild, workspace, "Balls")
    if ok and folder then
        for _, v in pairs(folder:GetChildren()) do
            if (v:IsA("BasePart") or v:IsA("MeshPart")) and not v.Anchored then return v end
            if v:IsA("Model") then
                local p = v:FindFirstChildWhichIsA("BasePart")
                if p then return p end
            end
        end
    end
    return nil
end

local function scanBalleComplet()
    local r = scanBalleLeger()
    if r then return r end
    for _, v in pairs(workspace:GetDescendants()) do
        if estBalle(v) then return v end
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not v.Anchored and not estJoueur(v) then
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
    if estBalle(o) then
        balle = o
        resetTracking()
    end
end)
workspace.DescendantRemoving:Connect(function(o)
    if o == balle then
        balle = nil
        resetTracking()
    end
end)

balle = scanBalleComplet()

task.spawn(function()
    while true do
        task.wait(3)
        if not balle or not balle.Parent then
            local b = scanBalleLeger()
            if b then balle = b; resetTracking() end
        end
    end
end)

-- ═══════════════════════════════════════
--  TARGET CHECK
-- ═══════════════════════════════════════
local function matchT(t)
    if t == nil then return false end
    if typeof(t) == "Instance" then return t == cachedChar or t == LP end
    if typeof(t) == "string" then return t == lpName or t == lpIdStr end
    if typeof(t) == "number" then return t == lpId end
    return false
end

local function checkTarget(b)
    local ok, t
    ok, t = pcall(b.GetAttribute, b, "Target")
    if ok and matchT(t) then return true end
    ok, t = pcall(b.GetAttribute, b, "target")
    if ok and matchT(t) then return true end
    ok, t = pcall(b.GetAttribute, b, "realTarget")
    if ok and matchT(t) then return true end
    ok, t = pcall(b.GetAttribute, b, "CurrentTarget")
    if ok and matchT(t) then return true end
    ok, t = pcall(b.GetAttribute, b, "currentTarget")
    if ok and matchT(t) then return true end
    ok, t = pcall(b.GetAttribute, b, "TargetPlayer")
    if ok and matchT(t) then return true end
    local p = b.Parent
    if p and p ~= workspace then
        ok, t = pcall(p.GetAttribute, p, "Target")
        if ok and matchT(t) then return true end
        ok, t = pcall(p.GetAttribute, p, "target")
        if ok and matchT(t) then return true end
    end
    return false
end

-- ═══════════════════════════════════════
--  PARRY — 1 seul clic, timing parfait
-- ═══════════════════════════════════════
local function doParry()
    local now = tick()
    if now - dernierP < COOLDOWN then return end
    dernierP = now
    compteur = compteur + 1
    streak = streak + 1
    if streak > best then best = streak end
    pcall(mouse1click)
    prevDist = curDist
    closingSpd = 0
    approcheSuite = 0
    eta = 999
    cachedCible = false
end

-- ═══════════════════════════════════════
--  ANTI AFK
-- ═══════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(180)
        if cachedHRP then
            pcall(function() cachedHRP.CFrame = cachedHRP.CFrame end)
        end
    end
end)

-- ═══════════════════════════════════════
--  GUI — compact, 1 mode, propre
-- ═══════════════════════════════════════
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

local W = 340
local H_OPEN = 400
local H_CLOSED = 46

local panel = mk("Frame", {
    Size = UDim2.new(0, W, 0, H_OPEN),
    Position = UDim2.new(0, 14, 0.5, -H_OPEN / 2),
    BackgroundColor3 = BG1, BackgroundTransparency = 0.02,
    ClipsDescendants = true, Parent = gui,
})
rnd(panel, 12)
mk("UIStroke", {Color = BORD, Thickness = 1, Parent = panel})

-- HEADER
local hdr = mk("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = BG2, Parent = panel})
rnd(hdr, 12)
mk("Frame", {Size = UDim2.new(1, -24, 0, 2), Position = UDim2.new(0, 12, 0, 0), BackgroundColor3 = ACCENT, Parent = hdr})
local statusDot = mk("Frame", {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, 14, 0, 18), BackgroundColor3 = GREEN, Parent = hdr})
rnd(statusDot, 5)
local statusLbl = mk("TextLabel", {Size = UDim2.new(0, 56, 0, 14), Position = UDim2.new(0, 30, 0, 16), BackgroundTransparency = 1, Text = "ACTIF", TextColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
mk("TextLabel", {Size = UDim2.new(0, 180, 0, 14), Position = UDim2.new(0, 90, 0, 16), BackgroundTransparency = 1, Text = "AUTO PARRY v14", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
local btnMin = mk("TextButton", {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -40, 0, 8), BackgroundColor3 = BG4, Text = "-", TextColor3 = TXT2, Font = Enum.Font.GothamBold, TextSize = 16, Parent = hdr})
rnd(btnMin, 8)
btnMin.MouseButton1Click:Connect(function()
    ouvert = not ouvert
    btnMin.Text = ouvert and "-" or "+"
    TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {
        Size = UDim2.new(0, W, 0, ouvert and H_OPEN or H_CLOSED)
    }):Play()
end)

-- SECTION BUILDER
local function sect(y, titre, h)
    local c = mk("Frame", {Size = UDim2.new(1, -24, 0, h), Position = UDim2.new(0, 12, 0, y), BackgroundColor3 = BG2, Parent = panel})
    rnd(c, 10)
    mk("TextLabel", {Size = UDim2.new(1, -16, 0, 11), Position = UDim2.new(0, 8, 0, 6), BackgroundTransparency = 1, Text = string.upper(titre), TextColor3 = ACCENT, Font = Enum.Font.GothamBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = c})
    return c
end

-- STATS
local sc = sect(52, "Stats", 52)
local bw = math.floor((W - 24 - 20) / 3)
local function sbox(parent, x, lbl, col)
    mk("TextLabel", {Size = UDim2.new(0, bw, 0, 9), Position = UDim2.new(0, x, 0, 20), BackgroundTransparency = 1, Text = string.upper(lbl), TextColor3 = col, Font = Enum.Font.GothamBold, TextSize = 8, Parent = parent})
    return mk("TextLabel", {Size = UDim2.new(0, bw, 0, 18), Position = UDim2.new(0, x, 0, 30), BackgroundTransparency = 1, Text = "0", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 17, Parent = parent})
end
local lP = sbox(sc, 8, "Parrys", ACCENT)
local lS = sbox(sc, 8 + bw + 10, "Streak", ORANGE)
local lB = sbox(sc, 8 + bw * 2 + 20, "Record", YELLOW)

-- BALLE
local bc = sect(110, "Balle", 90)
local lBalle = mk("TextLabel", {Size = UDim2.new(1, -16, 0, 12), Position = UDim2.new(0, 8, 0, 20), BackgroundTransparency = 1, Text = "Recherche...", TextColor3 = ORANGE, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lInfo = mk("TextLabel", {Size = UDim2.new(1, -16, 0, 11), Position = UDim2.new(0, 8, 0, 36), BackgroundTransparency = 1, Text = "", TextColor3 = TXT2, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lEta = mk("TextLabel", {Size = UDim2.new(1, -16, 0, 11), Position = UDim2.new(0, 8, 0, 50), BackgroundTransparency = 1, Text = "", TextColor3 = YELLOW, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lMode = mk("TextLabel", {Size = UDim2.new(1, -16, 0, 11), Position = UDim2.new(0, 8, 0, 66), BackgroundTransparency = 1, Text = "", TextColor3 = GREEN, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})

-- TOGGLE
local tBg = mk("Frame", {Size = UDim2.new(1, -24, 0, 36), Position = UDim2.new(0, 12, 0, 206), BackgroundColor3 = GREEN, Parent = panel})
rnd(tBg, 10)
local tBtn = mk("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "ACTIF — Cliquer pour desactiver", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 12, Parent = tBg})

local function majToggle()
    tBg.BackgroundColor3 = actif and GREEN or RED
    tBtn.Text = actif and "ACTIF — Cliquer pour desactiver" or "INACTIF — Cliquer pour activer"
    statusLbl.Text = actif and "ACTIF" or "INACTIF"
    statusLbl.TextColor3 = actif and GREEN or RED
    statusDot.BackgroundColor3 = actif and GREEN or RED
end
tBtn.MouseButton1Click:Connect(function() actif = not actif; majToggle() end)

-- INFO
local ic = sect(248, "Comment ca marche", 90)
mk("TextLabel", {
    Size = UDim2.new(1, -16, 0, 72), Position = UDim2.new(0, 8, 0, 20),
    BackgroundTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Calcule le temps d'impact (ETA) de la balle\n1 clic au moment parfait (bouclier = 500ms)\nConfirme par attributs du jeu + velocite\nZero faux clic | Anti-detection total\n\nRShift = On/Off  |  RCtrl = Masquer",
    TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 9, Parent = ic,
})

-- BOUTONS
local btnScan = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 26), Position = UDim2.new(0, 12, 0, 344), BackgroundColor3 = BG3, Text = "Chercher balle", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 10, Parent = panel})
rnd(btnScan, 6)
btnScan.MouseButton1Click:Connect(function()
    balle = scanBalleComplet()
    resetTracking()
end)
local btnRst = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 26), Position = UDim2.new(0.53, 0, 0, 344), BackgroundColor3 = BG3, Text = "Reset stats", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 10, Parent = panel})
rnd(btnRst, 6)
btnRst.MouseButton1Click:Connect(function() compteur = 0; streak = 0; best = 0 end)

mk("TextLabel", {Size = UDim2.new(1, -24, 0, 20), Position = UDim2.new(0, 12, 0, 374), BackgroundTransparency = 1, Text = "v14 | ETA Timing | github.com/lapsy4trie1337-code", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 8, Parent = panel})

-- FLASH (feedback parry)
local flash = mk("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 100, Parent = gui})

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

-- RACCOURCIS
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
--  BOUCLE PRINCIPALE — ultra optimisee
--
--  Chaque frame : distance + closing speed + ETA (ultra leger)
--  Toutes les 4 frames : check attributs cible
--  Toutes les 15 frames : mise a jour UI
-- ═══════════════════════════════════════
RunService:BindToRenderStep(RK, Enum.RenderPriority.First.Value, function()
    frameN = frameN + 1

    local b = balle
    if not b or not b.Parent then
        streak = 0
        if frameN % 15 == 0 then
            lBalle.Text = "Recherche..."
            lBalle.TextColor3 = ORANGE
            lInfo.Text = ""; lEta.Text = ""; lMode.Text = ""
        end
        return
    end

    local hrp = cachedHRP
    if not hrp then majChar(); hrp = cachedHRP end
    if not hrp then return end

    -- ── Position + distance (chaque frame) ──
    local okP, bPos = pcall(function() return b.Position end)
    if not okP then balle = nil; return end
    local hPos = hrp.Position
    local dx = bPos.X - hPos.X
    local dy = bPos.Y - hPos.Y
    local dz = bPos.Z - hPos.Z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    curDist = dist

    -- ── Closing speed + tracking approche (chaque frame) ──
    local now = tick()
    local dt = now - prevTime
    if dt > 0.005 then
        local raw = (prevDist - dist) / dt
        closingSpd = closingSpd * (1 - SMOOTH) + raw * SMOOTH
        if dist < prevDist - 0.3 then
            approcheSuite = approcheSuite + 1
        else
            approcheSuite = 0
        end
        prevDist = dist
        prevTime = now
    end

    if closingSpd > 3 then
        eta = dist / closingSpd
    else
        eta = 999
    end

    -- ── Target check (toutes les 4 frames) ──
    if frameN % 4 == 0 then
        cachedConfirme = checkTarget(b)
        if cachedConfirme then
            cachedCible = true
        else
            local velOk, vel = pcall(function() return b.AssemblyLinearVelocity end)
            if not velOk then velOk, vel = pcall(function() return b.Velocity end) end
            if velOk and vel then
                local spd = vel.Magnitude
                if spd > 10 and dist > 0.5 then
                    local invD = 1 / dist
                    local invS = 1 / spd
                    local dotP = (vel.X * invS) * ((-dx) * invD) + (vel.Y * invS) * ((-dy) * invD) + (vel.Z * invS) * ((-dz) * invD)
                    cachedCible = dotP > DOT_MIN and approcheSuite >= APPROACH_MIN and closingSpd > 15
                else
                    cachedCible = false
                end
            else
                cachedCible = false
            end
        end
    end

    if not cachedCible then streak = 0 end

    -- ── PARRY — timing base sur ETA ──
    if actif and cachedCible then
        local seuil = cachedConfirme and ETA_CONFIRME or ETA_ESTIME
        if eta > ETA_MIN and eta < seuil then
            doParry()
            pcall(function()
                flash.BackgroundTransparency = 0.85
                TweenService:Create(flash, TweenInfo.new(0.08), {BackgroundTransparency = 1}):Play()
            end)
        end
    end

    -- ── UI (toutes les 15 frames ~4fps) ──
    if frameN % 15 ~= 0 then return end

    lP.Text = tostring(compteur)
    lS.Text = tostring(streak)
    lB.Text = tostring(best)
    lBalle.Text = b.Name
    lBalle.TextColor3 = GREEN

    if cachedCible then
        local cs = closingSpd
        if cs < 0 then cs = 0 end
        lInfo.Text = "Dist " .. math.floor(dist) .. " | Approche " .. math.floor(cs) .. "/s"
        lInfo.TextColor3 = YELLOW
        if eta < 30 then
            lEta.Text = "ETA " .. string.format("%.2f", eta) .. "s"
        else
            lEta.Text = "ETA ---"
        end
        lEta.TextColor3 = eta < 0.5 and RED or YELLOW
        lMode.Text = cachedConfirme and "CONFIRME" or "ESTIME"
        lMode.TextColor3 = cachedConfirme and GREEN or ORANGE
    else
        lInfo.Text = "Pas cible"
        lInfo.TextColor3 = TXT3
        lEta.Text = ""
        lMode.Text = ""
    end
end)

-- Pulsation status
task.spawn(function()
    while true do
        if actif then
            pcall(function() TweenService:Create(statusDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.5}):Play() end)
            task.wait(0.8)
            pcall(function() TweenService:Create(statusDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0}):Play() end)
            task.wait(0.8)
        else
            statusDot.BackgroundTransparency = 0
            task.wait(0.5)
        end
    end
end)

print("[AutoParry] v14 charge | ETA timing | Zero lag")
