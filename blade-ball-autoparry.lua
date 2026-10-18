-- Auto Parry v17 — Zero Faux Clic
--
-- REGLE D'OR : cliquer UNIQUEMENT quand on est CONFIRME comme cible
-- Confirme = personnage rouge (Highlight) OU attribut du jeu
-- + la balle doit etre TRES proche
-- Aucun chemin "estime" par velocite = zero clic pour rien

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
local frameN = 0

-- Rouge detection
local charRouge = false

-- Velocite calculee par position
local prevBPos = nil
local prevBTime = 0
local calcSpd = 0

-- Anti-feinte : tracking direction
local prevDot = 0
local feintDetectee = false

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
--  CACHE PERSONNAGE + DETECTION ROUGE
-- ═══════════════════════════════════════
local function checkRouge()
    charRouge = false
    if not cachedChar then return end
    for _, ch in pairs(cachedChar:GetChildren()) do
        if ch:IsA("Highlight") then
            local ok1, fc = pcall(function() return ch.FillColor end)
            if ok1 and fc and fc.R > 0.5 and fc.G < 0.4 then
                charRouge = true
                return
            end
            local ok2, oc = pcall(function() return ch.OutlineColor end)
            if ok2 and oc and oc.R > 0.5 and oc.G < 0.4 then
                charRouge = true
                return
            end
        elseif ch:IsA("SelectionBox") then
            local ok1, c3 = pcall(function() return ch.Color3 end)
            if ok1 and c3 and c3.R > 0.5 and c3.G < 0.4 then
                charRouge = true
                return
            end
        end
    end
end

local function watchChar(char)
    pcall(function()
        char.ChildAdded:Connect(function(ch)
            if ch:IsA("Highlight") or ch:IsA("SelectionBox") then
                task.spawn(function()
                    task.wait(0.02)
                    checkRouge()
                end)
            end
        end)
        char.ChildRemoved:Connect(function(ch)
            if ch:IsA("Highlight") or ch:IsA("SelectionBox") then
                charRouge = false
                checkRouge()
            end
        end)
    end)
    checkRouge()
end

local function majChar()
    cachedChar = LP.Character
    cachedHRP = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")
    if cachedChar then watchChar(cachedChar) end
end
majChar()
LP.CharacterAdded:Connect(function(c)
    cachedChar = c
    c:WaitForChild("HumanoidRootPart", 5)
    cachedHRP = c:FindFirstChild("HumanoidRootPart")
    watchChar(c)
end)
LP.CharacterRemoving:Connect(function()
    cachedChar = nil
    cachedHRP = nil
    charRouge = false
end)

-- ═══════════════════════════════════════
--  DETECTION BALLE
-- ═══════════════════════════════════════
local function scanBalle()
    for _, name in pairs({"Ball", "ball", "Balle", "Projectile", "projectile", "Orb", "orb"}) do
        local ok, b = pcall(workspace.FindFirstChild, workspace, name, true)
        if ok and b and (b:IsA("BasePart") or b:IsA("MeshPart")) then return b end
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

local function estJoueur(o)
    local p = o.Parent
    while p and p ~= workspace do
        if Players:GetPlayerFromCharacter(p) then return true end
        p = p.Parent
    end
    return false
end

local function scanComplet()
    local r = scanBalle()
    if r then return r end
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not v.Anchored then
            local n = v.Name:lower()
            if (n == "ball" or n == "balle" or n:find("projectile") or n:find("orb")) and not estJoueur(v) then
                return v
            end
        end
    end
    return nil
end

workspace.DescendantAdded:Connect(function(o)
    if balle and balle.Parent then return end
    if not (o:IsA("BasePart") or o:IsA("MeshPart")) then return end
    if o.Anchored then return end
    local n = o.Name:lower()
    if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb") then
        balle = o
        prevBPos = nil
        calcSpd = 0
    end
end)
workspace.DescendantRemoving:Connect(function(o)
    if o == balle then
        balle = nil
        prevBPos = nil
        calcSpd = 0
    end
end)

balle = scanComplet()

task.spawn(function()
    while true do
        task.wait(2)
        if not balle or not balle.Parent then
            local b = scanBalle()
            if not b then b = scanComplet() end
            if b then balle = b; prevBPos = nil; calcSpd = 0 end
        end
    end
end)

-- ═══════════════════════════════════════
--  TARGET CHECK — attributs seulement
-- ═══════════════════════════════════════
local function matchT(t)
    if t == nil then return false end
    if typeof(t) == "Instance" then return t == cachedChar or t == LP end
    if typeof(t) == "string" then return t == lpName or t == lpIdStr end
    if typeof(t) == "number" then return t == lpId end
    return false
end

local function checkAttributs(b)
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
--  PARRY — simple et propre
-- ═══════════════════════════════════════
local function doParry(spd, dist)
    local now = tick()
    -- Cooldown 0.35s = bouclier dure ~0.5s, on peut re-parry apres feinte
    -- Feinte reset le cooldown a 0 pour parry instantane
    local cd = 0.35
    if spd > 200 then cd = 0.25 end

    if now - dernierP < cd then return false end
    dernierP = now
    compteur = compteur + 1
    streak = streak + 1
    if streak > best then best = streak end

    pcall(mouse1click)
    if spd > 100 then
        pcall(mouse1click)
    end
    return true
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
--  GUI
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

local W = 300
local H_OPEN = 310
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
mk("TextLabel", {Size = UDim2.new(0, 130, 0, 14), Position = UDim2.new(0, 80, 0, 14), BackgroundTransparency = 1, Text = "AUTO PARRY v17.3", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
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

-- STATS
local sc = sect(48, "Stats", 46)
local bw = math.floor((W - 20 - 16) / 3)
local function sbox(parent, x, lbl, col)
    mk("TextLabel", {Size = UDim2.new(0, bw, 0, 8), Position = UDim2.new(0, x, 0, 17), BackgroundTransparency = 1, Text = string.upper(lbl), TextColor3 = col, Font = Enum.Font.GothamBold, TextSize = 7, Parent = parent})
    return mk("TextLabel", {Size = UDim2.new(0, bw, 0, 16), Position = UDim2.new(0, x, 0, 26), BackgroundTransparency = 1, Text = "0", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 15, Parent = parent})
end
local lP = sbox(sc, 7, "Parrys", ACCENT)
local lS = sbox(sc, 7 + bw + 8, "Streak", ORANGE)
local lB = sbox(sc, 7 + bw * 2 + 16, "Record", YELLOW)

-- BALLE + STATUS
local bc = sect(100, "Balle", 68)
local lBalle = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 18), BackgroundTransparency = 1, Text = "Recherche...", TextColor3 = ORANGE, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lInfo = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 32), BackgroundTransparency = 1, Text = "", TextColor3 = TXT2, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lMode = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 46), BackgroundTransparency = 1, Text = "", TextColor3 = TXT3, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})

-- TOGGLE
local tBg = mk("Frame", {Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 174), BackgroundColor3 = GREEN, Parent = panel})
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
local ic = sect(210, "Fonctionnement", 52)
mk("TextLabel", {
    Size = UDim2.new(1, -14, 0, 38), Position = UDim2.new(0, 7, 0, 14),
    BackgroundTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Clic SEULEMENT quand tu es rouge + balle proche\nAucun clic si tu n'es pas la cible\nRShift = On/Off  |  RCtrl = Masquer",
    TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 8, Parent = ic,
})

-- BOUTONS
local btnScan = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 22), Position = UDim2.new(0, 10, 0, 268), BackgroundColor3 = BG3, Text = "Chercher balle", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnScan, 6)
btnScan.MouseButton1Click:Connect(function() balle = scanComplet(); prevBPos = nil; calcSpd = 0 end)
local btnRst = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 22), Position = UDim2.new(0.53, 0, 0, 268), BackgroundColor3 = BG3, Text = "Reset stats", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnRst, 6)
btnRst.MouseButton1Click:Connect(function() compteur = 0; streak = 0; best = 0 end)

mk("TextLabel", {Size = UDim2.new(1, -20, 0, 12), Position = UDim2.new(0, 10, 0, 294), BackgroundTransparency = 1, Text = "v17.3 | Anti-Feinte", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 7, Parent = panel})

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
--  CORE — verifie 120 fois par seconde
--
--  Logique ultra simple :
--    1. Je suis confirme cible? (rouge OU attribut)
--    2. La balle est tres proche?
--    3. OUI + OUI = PARRY
--    4. Sinon = RIEN (zero faux clic)
-- ═══════════════════════════════════════
local function coreCheck()
    local b = balle
    if not b or not b.Parent then streak = 0; return end
    if not actif then return end

    local hrp = cachedHRP
    if not hrp then majChar(); hrp = cachedHRP end
    if not hrp then return end

    local okP, bPos = pcall(function() return b.Position end)
    if not okP then balle = nil; return end
    local hPos = hrp.Position
    local dx = bPos.X - hPos.X
    local dy = bPos.Y - hPos.Y
    local dz = bPos.Z - hPos.Z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

    -- Vitesse + direction calculees par position (fiable)
    local now = tick()
    local oldBPos = prevBPos
    local oldBTime = prevBTime
    local velX, velY, velZ = 0, 0, 0
    if oldBPos then
        local dt = now - oldBTime
        if dt > 0.001 then
            velX = (bPos.X - oldBPos.X) / dt
            velY = (bPos.Y - oldBPos.Y) / dt
            velZ = (bPos.Z - oldBPos.Z) / dt
            calcSpd = math.sqrt(velX * velX + velY * velY + velZ * velZ)
        end
    end
    prevBPos = bPos
    prevBTime = now

    -- ═══ SUIS-JE LA CIBLE? ═══
    local confirme = charRouge or checkAttributs(b)

    -- ═══ PREDICTION 5 FRAMES ═══
    local distEff = dist
    if confirme and calcSpd > 30 then
        local dt5 = 5 / 60
        local predX = bPos.X + velX * dt5
        local predY = bPos.Y + velY * dt5
        local predZ = bPos.Z + velZ * dt5
        local pdx = predX - hPos.X
        local pdy = predY - hPos.Y
        local pdz = predZ - hPos.Z
        local predDist = math.sqrt(pdx * pdx + pdy * pdy + pdz * pdz)
        if predDist < dist then distEff = predDist end
    end

    -- ═══ ANTI-FEINTE : detecte chaque changement de direction ═══
    local dot = 0
    if calcSpd > 5 and dist > 0.1 then
        local dirX = -dx / dist
        local dirY = -dy / dist
        local dirZ = -dz / dist
        dot = (velX * dirX + velY * dirY + velZ * dirZ) / calcSpd
    end

    -- Feinte = la balle allait s'eloigner (dot negatif) et revient (dot positif)
    feintDetectee = false
    if prevDot < -0.1 and dot > 0.2 then
        feintDetectee = true
        dernierP = 0
    end
    prevDot = dot

    local seuil = math.clamp(12 + calcSpd * 0.12, 12, 55)

    -- ═══ PARRY ═══
    -- Confirme + proche = PARRY (pas besoin de check approche, la balle courbe)
    -- Feinte detectee = parry instantane (cooldown reset)
    if confirme and distEff < seuil then
        local ok = doParry(calcSpd, dist)
        if ok then
            pcall(function()
                flash.BackgroundTransparency = 0.8
                TweenService:Create(flash, TweenInfo.new(0.06), {BackgroundTransparency = 1}):Play()
            end)
        end
    end

    if not confirme then streak = 0 end
end

-- ═══════════════════════════════════════
--  DOUBLE BOUCLE 120fps
-- ═══════════════════════════════════════
RunService:BindToRenderStep(RK, Enum.RenderPriority.First.Value, function()
    frameN = frameN + 1

    -- Rouge check toutes les 2 frames en plus des events
    if frameN % 2 == 0 then checkRouge() end

    coreCheck()

    -- UI toutes les 20 frames
    if frameN % 20 ~= 0 then return end

    local b = balle
    if not b or not b.Parent then
        lBalle.Text = "Recherche..."
        lBalle.TextColor3 = ORANGE
        lInfo.Text = ""
        lMode.Text = ""
        return
    end

    lP.Text = tostring(compteur)
    lS.Text = tostring(streak)
    lB.Text = tostring(best)
    lBalle.Text = b.Name
    lBalle.TextColor3 = GREEN

    local hrp = cachedHRP
    if hrp then
        local okP, bPos = pcall(function() return b.Position end)
        if okP then
            local dx = bPos.X - hrp.Position.X
            local dy = bPos.Y - hrp.Position.Y
            local dz = bPos.Z - hrp.Position.Z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            local seuil = math.clamp(8 + calcSpd * 0.05, 8, 25)

            local seuil = math.clamp(12 + calcSpd * 0.12, 12, 55)
            lInfo.Text = "Dist " .. math.floor(dist) .. " | Vit " .. math.floor(calcSpd) .. " | Zone " .. math.floor(seuil)
            lInfo.TextColor3 = YELLOW

            if charRouge then
                lMode.Text = "ROUGE — Pret a parry"
                lMode.TextColor3 = RED
            elseif checkAttributs(b) then
                lMode.Text = "CONFIRME — Pret a parry"
                lMode.TextColor3 = GREEN
            else
                lMode.Text = "Pas cible — Aucun clic"
                lMode.TextColor3 = TXT3
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    coreCheck()
end)

print("[AutoParry] v17.3 | Anti-feinte | Re-parry instantane apres feinte")
