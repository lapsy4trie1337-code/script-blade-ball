-- Auto Parry v16 — Ultra Reactif | Detection par position

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
local RK2 = rkey()

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
local cachedRouge = false

-- Tracking par position (pas besoin de AssemblyLinearVelocity)
local prevBPos = nil
local prevBTime = 0
local calcVel = {X = 0, Y = 0, Z = 0, Magnitude = 0}
local prevDist = 999
local prevDistTime = 0

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
            if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb") then
                if not estJoueur(v) then return v end
            end
            local a1
            pcall(function() a1 = v:GetAttribute("Target") end)
            if a1 ~= nil and not estJoueur(v) then return v end
        end
    end
    return nil
end

local function resetBalle()
    prevBPos = nil
    prevBTime = 0
    calcVel = {X = 0, Y = 0, Z = 0, Magnitude = 0}
    prevDist = 999
    prevDistTime = 0
end

workspace.DescendantAdded:Connect(function(o)
    if balle and balle.Parent then return end
    if not (o:IsA("BasePart") or o:IsA("MeshPart")) then return end
    if o.Anchored then return end
    local n = o.Name:lower()
    if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb") then
        balle = o
        resetBalle()
    end
end)
workspace.DescendantRemoving:Connect(function(o)
    if o == balle then balle = nil; resetBalle() end
end)

balle = scanComplet()

task.spawn(function()
    while true do
        task.wait(2)
        if not balle or not balle.Parent then
            local b = scanBalle()
            if not b then b = scanComplet() end
            if b then balle = b; resetBalle() end
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

local function charEstRouge()
    if not cachedChar then return false end
    for _, ch in pairs(cachedChar:GetChildren()) do
        if ch:IsA("Highlight") then
            local ok1, fc = pcall(function() return ch.FillColor end)
            if ok1 and fc and fc.R > 0.5 and fc.G < 0.35 then return true end
            local ok2, oc = pcall(function() return ch.OutlineColor end)
            if ok2 and oc and oc.R > 0.5 and oc.G < 0.35 then return true end
        elseif ch:IsA("SelectionBox") then
            local ok1, c3 = pcall(function() return ch.Color3 end)
            if ok1 and c3 and c3.R > 0.5 and c3.G < 0.35 then return true end
        end
    end
    return false
end

-- ═══════════════════════════════════════
--  PARRY — escalation intelligente
-- ═══════════════════════════════════════
local function doParry(spd, dist, confirme)
    local now = tick()
    local cd, nb

    if confirme and dist < 15 and spd > 200 then
        cd = 0.02; nb = 6
    elseif confirme and dist < 25 and spd > 100 then
        cd = 0.04; nb = 4
    elseif confirme and spd > 50 then
        cd = 0.08; nb = 2
    elseif confirme then
        cd = 0.15; nb = 1
    else
        cd = 0.15; nb = 1
    end

    if now - dernierP < cd then return false end
    dernierP = now
    compteur = compteur + 1
    streak = streak + 1
    if streak > best then best = streak end
    for _ = 1, nb do pcall(mouse1click) end
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

local W = 320
local H_OPEN = 330
local H_CLOSED = 44

local panel = mk("Frame", {
    Size = UDim2.new(0, W, 0, H_OPEN),
    Position = UDim2.new(0, 14, 0.5, -H_OPEN / 2),
    BackgroundColor3 = BG1, BackgroundTransparency = 0.02,
    ClipsDescendants = true, Parent = gui,
})
rnd(panel, 12)
mk("UIStroke", {Color = BORD, Thickness = 1, Parent = panel})

local hdr = mk("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = BG2, Parent = panel})
rnd(hdr, 12)
mk("Frame", {Size = UDim2.new(1, -20, 0, 2), Position = UDim2.new(0, 10, 0, 0), BackgroundColor3 = ACCENT, Parent = hdr})
local statusDot = mk("Frame", {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, 12, 0, 17), BackgroundColor3 = GREEN, Parent = hdr})
rnd(statusDot, 5)
local statusLbl = mk("TextLabel", {Size = UDim2.new(0, 50, 0, 14), Position = UDim2.new(0, 28, 0, 15), BackgroundTransparency = 1, Text = "ACTIF", TextColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
mk("TextLabel", {Size = UDim2.new(0, 140, 0, 14), Position = UDim2.new(0, 82, 0, 15), BackgroundTransparency = 1, Text = "AUTO PARRY v16", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
local btnMin = mk("TextButton", {Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -36, 0, 8), BackgroundColor3 = BG4, Text = "-", TextColor3 = TXT2, Font = Enum.Font.GothamBold, TextSize = 15, Parent = hdr})
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

local sc = sect(50, "Stats", 48)
local bw = math.floor((W - 20 - 16) / 3)
local function sbox(parent, x, lbl, col)
    mk("TextLabel", {Size = UDim2.new(0, bw, 0, 9), Position = UDim2.new(0, x, 0, 18), BackgroundTransparency = 1, Text = string.upper(lbl), TextColor3 = col, Font = Enum.Font.GothamBold, TextSize = 7, Parent = parent})
    return mk("TextLabel", {Size = UDim2.new(0, bw, 0, 16), Position = UDim2.new(0, x, 0, 28), BackgroundTransparency = 1, Text = "0", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 16, Parent = parent})
end
local lP = sbox(sc, 7, "Parrys", ACCENT)
local lS = sbox(sc, 7 + bw + 8, "Streak", ORANGE)
local lB = sbox(sc, 7 + bw * 2 + 16, "Record", YELLOW)

local bc = sect(104, "Balle", 80)
local lBalle = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 18), BackgroundTransparency = 1, Text = "Recherche...", TextColor3 = ORANGE, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lInfo = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 32), BackgroundTransparency = 1, Text = "", TextColor3 = TXT2, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lEta = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 46), BackgroundTransparency = 1, Text = "", TextColor3 = YELLOW, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lMode = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 60), BackgroundTransparency = 1, Text = "", TextColor3 = GREEN, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})

local tBg = mk("Frame", {Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 190), BackgroundColor3 = GREEN, Parent = panel})
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

local ic = sect(228, "Info", 50)
mk("TextLabel", {
    Size = UDim2.new(1, -14, 0, 34), Position = UDim2.new(0, 7, 0, 16),
    BackgroundTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Velocite calculee par position (fiable)\nEscalade clics: proche+rapide = max spam\nRShift = On/Off  |  RCtrl = Masquer",
    TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 8, Parent = ic,
})

local btnScan = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 22), Position = UDim2.new(0, 10, 0, 284), BackgroundColor3 = BG3, Text = "Chercher balle", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnScan, 6)
btnScan.MouseButton1Click:Connect(function() balle = scanComplet(); resetBalle() end)
local btnRst = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 22), Position = UDim2.new(0.53, 0, 0, 284), BackgroundColor3 = BG3, Text = "Reset stats", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnRst, 6)
btnRst.MouseButton1Click:Connect(function() compteur = 0; streak = 0; best = 0 end)

mk("TextLabel", {Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 0, 310), BackgroundTransparency = 1, Text = "v16 | Position Tracking | Double Loop 120fps", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 7, Parent = panel})

local flash = mk("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 100, Parent = gui})

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
--  CORE — la fonction de check qui tourne 120x/sec
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

    -- ═══ VELOCITE CALCULEE PAR POSITION ═══
    -- On ne depend plus de AssemblyLinearVelocity (peut etre nil cote client)
    local now = tick()
    local vx, vy, vz, spd = 0, 0, 0, 0
    if prevBPos then
        local dt = now - prevBTime
        if dt > 0.001 then
            vx = (bPos.X - prevBPos.X) / dt
            vy = (bPos.Y - prevBPos.Y) / dt
            vz = (bPos.Z - prevBPos.Z) / dt
            spd = math.sqrt(vx * vx + vy * vy + vz * vz)
            calcVel = {X = vx, Y = vy, Z = vz, Magnitude = spd}
        end
    else
        local velOk, vel = pcall(function() return b.AssemblyLinearVelocity end)
        if velOk and vel then
            vx, vy, vz = vel.X, vel.Y, vel.Z
            spd = vel.Magnitude
            calcVel = {X = vx, Y = vy, Z = vz, Magnitude = spd}
        end
    end
    prevBPos = bPos
    prevBTime = now

    -- Distance approche?
    local approche = dist < prevDist - 0.1
    if now - prevDistTime > 0.01 then
        prevDist = dist
        prevDistTime = now
    end

    -- ═══ DETECTION CIBLE ═══
    local confirme = checkAttributs(b) or cachedRouge

    if confirme then
        -- CONFIRME : parry agressif
        local seuil = math.clamp(15 + spd * 0.15, 15, 80)

        -- Prediction : position future de la balle
        local predDist = dist
        if spd > 10 then
            local frames = 3
            if spd > 300 then frames = 5
            elseif spd > 150 then frames = 4 end
            local pdt = frames / 60
            local px = bPos.X + vx * pdt - hPos.X
            local py = bPos.Y + vy * pdt - hPos.Y
            local pz = bPos.Z + vz * pdt - hPos.Z
            predDist = math.sqrt(px * px + py * py + pz * pz)
        end

        if dist < seuil or predDist < seuil then
            local ok = doParry(spd, dist, true)
            if ok then
                pcall(function()
                    flash.BackgroundTransparency = 0.85
                    TweenService:Create(flash, TweenInfo.new(0.06), {BackgroundTransparency = 1}):Play()
                end)
            end
        end
    elseif spd > 5 and dist > 0.5 then
        -- ESTIME : dot product avec velocite calculee
        local invD = 1 / dist
        local invS = 1 / math.max(spd, 0.1)
        local dotP = (vx * invS) * ((-dx) * invD) + (vy * invS) * ((-dy) * invD) + (vz * invS) * ((-dz) * invD)
        local seuil = math.clamp(10 + spd * 0.1, 10, 50)

        if dotP > 0.15 and dist < seuil and approche then
            local ok = doParry(spd, dist, false)
            if ok then
                pcall(function()
                    flash.BackgroundTransparency = 0.85
                    TweenService:Create(flash, TweenInfo.new(0.06), {BackgroundTransparency = 1}):Play()
                end)
            end
        end

        if dotP < 0.1 then streak = 0 end
    else
        streak = 0
    end
end

-- ═══════════════════════════════════════
--  DOUBLE BOUCLE — 120 checks/sec
--  RenderStepped (avant render) + Heartbeat (apres physique)
-- ═══════════════════════════════════════
RunService:BindToRenderStep(RK, Enum.RenderPriority.First.Value, function()
    frameN = frameN + 1
    if frameN % 4 == 0 then cachedRouge = charEstRouge() end
    coreCheck()

    -- UI toutes les 20 frames
    if frameN % 20 ~= 0 then return end

    local b = balle
    if not b or not b.Parent then
        lBalle.Text = "Recherche..."
        lBalle.TextColor3 = ORANGE
        lInfo.Text = ""; lEta.Text = ""; lMode.Text = ""
        return
    end

    lP.Text = tostring(compteur)
    lS.Text = tostring(streak)
    lB.Text = tostring(best)
    lBalle.Text = b.Name
    lBalle.TextColor3 = GREEN

    local spd = calcVel.Magnitude
    local hrp = cachedHRP
    local dist = 0
    if hrp then
        local okP, bPos = pcall(function() return b.Position end)
        if okP then
            local dx = bPos.X - hrp.Position.X
            local dy = bPos.Y - hrp.Position.Y
            local dz = bPos.Z - hrp.Position.Z
            dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        end
    end

    lInfo.Text = "Dist " .. math.floor(dist) .. " | Vit " .. math.floor(spd) .. "/s"
    lInfo.TextColor3 = YELLOW

    local confirme = checkAttributs(b) or cachedRouge
    if confirme then
        local seuil = math.clamp(15 + spd * 0.15, 15, 80)
        lEta.Text = "Zone " .. math.floor(seuil) .. " studs"
        lEta.TextColor3 = dist < seuil and RED or YELLOW
        lMode.Text = "CONFIRME"
        lMode.TextColor3 = GREEN
    elseif spd > 5 then
        lEta.Text = "Vit calculee par position"
        lEta.TextColor3 = TXT2
        lMode.Text = "ESTIME"
        lMode.TextColor3 = ORANGE
    else
        lEta.Text = ""
        lMode.Text = ""
    end
end)

RunService.Heartbeat:Connect(function()
    coreCheck()
end)

print("[AutoParry] v16 | Position Tracking | 120fps | Escalade clics")
