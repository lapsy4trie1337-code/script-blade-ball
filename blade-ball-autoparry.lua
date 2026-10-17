-- Auto Parry v15 — Ultra Reactif | Zero Lag | Intelligent

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
local frameN = 0
local cachedRouge = false

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
--  DETECTION BALLE — events + scan leger
-- ═══════════════════════════════════════
local function resetTracking()
    prevDist = 999
    closingSpd = 0
    approcheSuite = 0
    eta = 999
end

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

local function scanComplet()
    local r = scanBalle()
    if r then return r end
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not v.Anchored then
            local n = v.Name:lower()
            if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb") then return v end
            local a1, a2
            pcall(function() a1 = v:GetAttribute("Target") end)
            pcall(function() a2 = v:GetAttribute("target") end)
            if a1 ~= nil or a2 ~= nil then return v end
            local s, vel = pcall(function() return v.AssemblyLinearVelocity end)
            if s and vel and vel.Magnitude > 30 and v.Size.Magnitude < 15 and v.Name ~= "Baseplate" then return v end
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
        resetTracking()
    end
end)
workspace.DescendantRemoving:Connect(function(o)
    if o == balle then
        balle = nil
        resetTracking()
    end
end)

balle = scanComplet()

task.spawn(function()
    while true do
        task.wait(2)
        if not balle or not balle.Parent then
            local b = scanBalle()
            if not b then b = scanComplet() end
            if b then balle = b; resetTracking() end
        end
    end
end)

-- ═══════════════════════════════════════
--  TARGET CHECK — chaque frame pour max reactivite
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
            local ok, fc = pcall(function() return ch.FillColor end)
            if ok and fc and fc.R > 0.5 and fc.G < 0.35 then return true end
            local ok2, oc = pcall(function() return ch.OutlineColor end)
            if ok2 and oc and oc.R > 0.5 and oc.G < 0.35 then return true end
        elseif ch:IsA("SelectionBox") then
            local ok, c3 = pcall(function() return ch.Color3 end)
            if ok and c3 and c3.R > 0.5 and c3.G < 0.35 then return true end
        end
    end
    return false
end

-- ═══════════════════════════════════════
--  PARRY
-- ═══════════════════════════════════════
local function doParry(spd)
    local now = tick()
    if now - dernierP < 0.35 then return end
    dernierP = now
    compteur = compteur + 1
    streak = streak + 1
    if streak > best then best = streak end
    pcall(mouse1click)
    if spd > 250 then pcall(mouse1click) end
    prevDist = curDist
    closingSpd = 0
    approcheSuite = 0
    eta = 999
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
local H_OPEN = 360
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
mk("TextLabel", {Size = UDim2.new(0, 140, 0, 14), Position = UDim2.new(0, 82, 0, 15), BackgroundTransparency = 1, Text = "AUTO PARRY v15", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
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

local ic = sect(228, "Info", 72)
mk("TextLabel", {
    Size = UDim2.new(1, -14, 0, 56), Position = UDim2.new(0, 7, 0, 18),
    BackgroundTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Confirme = parry agressif (distance + vitesse)\nEstime = parry prudent (ETA + approche)\n1-2 clics | Cooldown 0.35s | Anti-detection\n\nRShift = On/Off  |  RCtrl = Masquer",
    TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 8, Parent = ic,
})

local btnScan = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 24), Position = UDim2.new(0, 10, 0, 306), BackgroundColor3 = BG3, Text = "Chercher balle", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnScan, 6)
btnScan.MouseButton1Click:Connect(function() balle = scanComplet(); resetTracking() end)
local btnRst = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 24), Position = UDim2.new(0.53, 0, 0, 306), BackgroundColor3 = BG3, Text = "Reset stats", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnRst, 6)
btnRst.MouseButton1Click:Connect(function() compteur = 0; streak = 0; best = 0 end)

mk("TextLabel", {Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 0, 336), BackgroundTransparency = 1, Text = "v15 | Ultra Reactif | Zero Lag", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 7, Parent = panel})

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
--  BOUCLE PRINCIPALE
--
--  CONFIRME (attribut) = parry agressif par distance + vitesse
--  ESTIME (velocite)   = parry prudent par ETA + approche
--
--  Attributs checkes CHAQUE FRAME pour zero delai
--  UI mise a jour toutes les 15 frames
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

    local okP, bPos = pcall(function() return b.Position end)
    if not okP then balle = nil; return end
    local hPos = hrp.Position
    local dx = bPos.X - hPos.X
    local dy = bPos.Y - hPos.Y
    local dz = bPos.Z - hPos.Z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    curDist = dist

    -- Closing speed (lissage rapide 0.5)
    local now = tick()
    local dt = now - prevTime
    if dt > 0.005 then
        local raw = (prevDist - dist) / dt
        if closingSpd == 0 and raw > 0 then
            closingSpd = raw
        else
            closingSpd = closingSpd * 0.5 + raw * 0.5
        end
        if dist < prevDist - 0.2 then
            approcheSuite = approcheSuite + 1
        else
            approcheSuite = 0
        end
        prevDist = dist
        prevTime = now
    end

    if closingSpd > 2 then
        eta = dist / closingSpd
    else
        eta = 999
    end

    -- Vitesse balle
    local velOk, vel = pcall(function() return b.AssemblyLinearVelocity end)
    if not velOk then velOk, vel = pcall(function() return b.Velocity end) end
    local spd = (velOk and vel) and vel.Magnitude or 0

    -- ═══ DETECTION + PARRY ═══

    if frameN % 4 == 0 then cachedRouge = charEstRouge() end

    -- 1) CONFIRME — attribut OU personnage rouge = on sait que c'est nous
    --    Parry AGRESSIF : distance + vitesse + PREDICTION
    local confirme = checkAttributs(b) or cachedRouge

    if actif and confirme then
        local seuil = math.clamp(12 + spd * 0.14, 12, 75)

        local predFrames = 3
        if spd > 300 then predFrames = 5
        elseif spd > 150 then predFrames = 4 end

        local predDist = dist
        if velOk and vel and spd > 5 then
            local pdt = predFrames / 60
            local px = bPos.X + vel.X * pdt - hPos.X
            local py = bPos.Y + vel.Y * pdt - hPos.Y
            local pz = bPos.Z + vel.Z * pdt - hPos.Z
            predDist = math.sqrt(px * px + py * py + pz * pz)
        end

        if dist < seuil or predDist < seuil then
            doParry(spd)
            pcall(function()
                flash.BackgroundTransparency = 0.85
                TweenService:Create(flash, TweenInfo.new(0.08), {BackgroundTransparency = 1}):Play()
            end)
        end
    end

    -- 2) ESTIME — velocite seulement, etre prudent
    --    Parry quand ETA < 0.38s + balle approche 3+ frames + dot > 0.2
    if actif and not confirme and velOk and vel and spd > 10 and dist > 0.5 then
        local invD = 1 / dist
        local invS = 1 / spd
        local dotP = (vel.X * invS) * ((-dx) * invD) + (vel.Y * invS) * ((-dy) * invD) + (vel.Z * invS) * ((-dz) * invD)
        if dotP > 0.2 and approcheSuite >= 3 and closingSpd > 10 and eta > 0.03 and eta < 0.38 then
            doParry(spd)
            pcall(function()
                flash.BackgroundTransparency = 0.85
                TweenService:Create(flash, TweenInfo.new(0.08), {BackgroundTransparency = 1}):Play()
            end)
        end
    end

    if not confirme and approcheSuite < 3 then streak = 0 end

    -- ═══ UI (toutes les 15 frames) ═══
    if frameN % 15 ~= 0 then return end

    lP.Text = tostring(compteur)
    lS.Text = tostring(streak)
    lB.Text = tostring(best)
    lBalle.Text = b.Name
    lBalle.TextColor3 = GREEN

    if confirme then
        local seuil = math.clamp(12 + spd * 0.14, 12, 75)
        lInfo.Text = "Dist " .. math.floor(dist) .. "/" .. math.floor(seuil) .. " | Vit " .. math.floor(spd)
        lInfo.TextColor3 = YELLOW
        lEta.Text = "Zone parry: " .. math.floor(seuil) .. " studs"
        lEta.TextColor3 = dist < seuil and RED or YELLOW
        lMode.Text = "CONFIRME"
        lMode.TextColor3 = GREEN
    elseif approcheSuite >= 3 and closingSpd > 10 then
        lInfo.Text = "Dist " .. math.floor(dist) .. " | Approche " .. math.floor(closingSpd) .. "/s"
        lInfo.TextColor3 = ORANGE
        if eta < 30 then
            lEta.Text = "ETA " .. string.format("%.2f", eta) .. "s"
        else
            lEta.Text = "ETA ---"
        end
        lEta.TextColor3 = eta < 0.5 and RED or YELLOW
        lMode.Text = "ESTIME"
        lMode.TextColor3 = ORANGE
    else
        lInfo.Text = "Dist " .. math.floor(dist) .. " | Vit " .. math.floor(spd)
        lInfo.TextColor3 = TXT3
        lEta.Text = ""
        lMode.Text = ""
    end
end)

print("[AutoParry] v15 | Ultra Reactif | Zero Lag")
