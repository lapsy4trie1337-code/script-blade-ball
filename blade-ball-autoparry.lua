-- Auto Parry v21 — Multi-Balle + Zero Mort
--
-- Suit TOUTES les balles independamment (mode normal + entrainement)
-- Chaque balle a son propre tracking: vitesse, ETA, direction
-- Parry sur la balle qui te cible et qui est la plus proche de l'impact

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
local cachedHRP = nil
local cachedChar = nil
local dernierP = 0
local compteur = 0
local streak = 0
local best = 0
local ouvert = true
local frameN = 0
local charRouge = false
local feintDetectee = false

-- Multi-balle: tracking par balle
local balles = {}
local ballData = {}

local function newBallData()
    return {
        prevPos = nil,
        prevTime = 0,
        spd = 0,
        velX = 0, velY = 0, velZ = 0,
        closingHist = {0, 0, 0},
        closingIdx = 1,
        closingSpd = 0,
        prevDist = 9999,
        prevDot = 0,
    }
end

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
    local ok, desc = pcall(cachedChar.GetDescendants, cachedChar)
    if not ok then return end
    for _, ch in pairs(desc) do
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
--  DETECTION MULTI-BALLES
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
    if o.Anchored then return false end
    if estJoueur(o) then return false end
    local n = o.Name:lower()
    return n == "ball" or n == "balle" or n:find("projectile") or n:find("orb")
end

local function ajouterBalle(b)
    if ballData[b] then return end
    ballData[b] = newBallData()
    table.insert(balles, b)
end

local function retirerBalle(b)
    ballData[b] = nil
    for i = #balles, 1, -1 do
        if balles[i] == b then
            table.remove(balles, i)
            break
        end
    end
end

local function scanToutes()
    local found = {}
    for _, name in pairs({"Ball", "ball", "Balle", "Projectile", "projectile", "Orb", "orb"}) do
        local ok, b = pcall(workspace.FindFirstChild, workspace, name, true)
        if ok and b and estBalle(b) then found[b] = true end
    end
    local ok, folder = pcall(workspace.FindFirstChild, workspace, "Balls")
    if ok and folder then
        for _, v in pairs(folder:GetChildren()) do
            if estBalle(v) then
                found[v] = true
            elseif v:IsA("Model") then
                local p = v:FindFirstChildWhichIsA("BasePart")
                if p and not p.Anchored then found[p] = true end
            end
        end
    end
    for b in pairs(found) do ajouterBalle(b) end
    for i = #balles, 1, -1 do
        local b = balles[i]
        if not b.Parent then retirerBalle(b) end
    end
end

workspace.DescendantAdded:Connect(function(o)
    if estBalle(o) then ajouterBalle(o) end
end)
workspace.DescendantRemoving:Connect(function(o)
    if ballData[o] then retirerBalle(o) end
end)

scanToutes()

task.spawn(function()
    while true do
        task.wait(1.5)
        scanToutes()
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
    local okC, children = pcall(b.GetChildren, b)
    if okC then
        for _, ch in pairs(children) do
            if ch:IsA("ObjectValue") then
                local okV, val = pcall(function() return ch.Value end)
                if okV and val and (val == cachedChar or val == LP) then return true end
            end
        end
    end
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
--  PARRY
-- ═══════════════════════════════════════
local function doParry(spd, dist)
    local now = tick()
    local cd = 0.2
    if feintDetectee then cd = 0.04 end

    if now - dernierP < cd then return false end
    dernierP = now
    compteur = compteur + 1
    streak = streak + 1
    if streak > best then best = streak end

    pcall(mouse1click)
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
mk("TextLabel", {Size = UDim2.new(0, 130, 0, 14), Position = UDim2.new(0, 80, 0, 14), BackgroundTransparency = 1, Text = "AUTO PARRY v21", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
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

local sc = sect(48, "Stats", 46)
local bw = math.floor((W - 20 - 16) / 3)
local function sbox(parent, x, lbl, col)
    mk("TextLabel", {Size = UDim2.new(0, bw, 0, 8), Position = UDim2.new(0, x, 0, 17), BackgroundTransparency = 1, Text = string.upper(lbl), TextColor3 = col, Font = Enum.Font.GothamBold, TextSize = 7, Parent = parent})
    return mk("TextLabel", {Size = UDim2.new(0, bw, 0, 16), Position = UDim2.new(0, x, 0, 26), BackgroundTransparency = 1, Text = "0", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 15, Parent = parent})
end
local lP = sbox(sc, 7, "Parrys", ACCENT)
local lS = sbox(sc, 7 + bw + 8, "Streak", ORANGE)
local lB = sbox(sc, 7 + bw * 2 + 16, "Record", YELLOW)

local bc = sect(100, "Balle", 68)
local lBalle = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 18), BackgroundTransparency = 1, Text = "Recherche...", TextColor3 = ORANGE, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lInfo = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 32), BackgroundTransparency = 1, Text = "", TextColor3 = TXT2, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lMode = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 46), BackgroundTransparency = 1, Text = "", TextColor3 = TXT3, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})

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

local ic = sect(210, "Fonctionnement", 52)
mk("TextLabel", {
    Size = UDim2.new(1, -14, 0, 38), Position = UDim2.new(0, 7, 0, 14),
    BackgroundTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Multi-balle: suit toutes les balles\nParry auto sur celle qui te cible\nRShift = On/Off  |  RCtrl = Masquer",
    TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 8, Parent = ic,
})

local btnScan = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 22), Position = UDim2.new(0, 10, 0, 268), BackgroundColor3 = BG3, Text = "Chercher balles", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnScan, 6)
btnScan.MouseButton1Click:Connect(function() scanToutes() end)
local btnRst = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 22), Position = UDim2.new(0.53, 0, 0, 268), BackgroundColor3 = BG3, Text = "Reset stats", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnRst, 6)
btnRst.MouseButton1Click:Connect(function() compteur = 0; streak = 0; best = 0 end)

mk("TextLabel", {Size = UDim2.new(1, -20, 0, 12), Position = UDim2.new(0, 10, 0, 294), BackgroundTransparency = 1, Text = "v21 | Multi-Balle | Zero Mort", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 7, Parent = panel})

local flash = mk("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = GREEN, BackgroundTransparency = 1, ZIndex = 100, Parent = gui})

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
--  CORE — Evalue CHAQUE balle, parry la plus dangereuse
-- ═══════════════════════════════════════
local uiDanger = nil
local uiDist = 9999
local uiEta = 9999
local uiSpd = 0
local uiConf = false
local uiNbBalles = 0

local function coreCheck()
    if not actif then return end

    local hrp = cachedHRP
    if not hrp then majChar(); hrp = cachedHRP end
    if not hrp then return end
    local hPos = hrp.Position
    local now = tick()

    -- Check rouge toutes les 2 frames
    if frameN % 2 == 0 then checkRouge() end

    -- Check attributs toutes les 6 frames (par balle)
    local doAttrCheck = (frameN % 6 == 0)

    local bestParryEta = 9999
    local bestParryDist = 9999
    local bestParrySpd = 0
    local bestParryBall = nil
    local bestConfirme = false
    local anyConfirme = false

    feintDetectee = false

    for i = #balles, 1, -1 do
        local b = balles[i]
        if not b.Parent then
            retirerBalle(b)
        else
            local okP, bPos = pcall(function() return b.Position end)
            if okP then
                local bd = ballData[b]
                if not bd then
                    bd = newBallData()
                    ballData[b] = bd
                end

                local dx = bPos.X - hPos.X
                local dy = bPos.Y - hPos.Y
                local dz = bPos.Z - hPos.Z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                -- Vitesse par position delta
                local oldPos = bd.prevPos
                local oldTime = bd.prevTime
                if oldPos then
                    local dt = now - oldTime
                    if dt > 0.001 then
                        bd.velX = (bPos.X - oldPos.X) / dt
                        bd.velY = (bPos.Y - oldPos.Y) / dt
                        bd.velZ = (bPos.Z - oldPos.Z) / dt
                        bd.spd = math.sqrt(bd.velX * bd.velX + bd.velY * bd.velY + bd.velZ * bd.velZ)

                        -- Closing speed lisse sur 3 frames
                        local raw = (bd.prevDist - dist) / dt
                        bd.closingHist[bd.closingIdx] = raw
                        bd.closingIdx = (bd.closingIdx % 3) + 1
                        bd.closingSpd = (bd.closingHist[1] + bd.closingHist[2] + bd.closingHist[3]) / 3
                    end
                end
                bd.prevPos = bPos
                bd.prevTime = now
                bd.prevDist = dist

                -- Dot product (direction vers joueur)
                local dot = 0
                if bd.spd > 5 and dist > 0.1 then
                    local dirX = -dx / dist
                    local dirY = -dy / dist
                    local dirZ = -dz / dist
                    dot = (bd.velX * dirX + bd.velY * dirY + bd.velZ * dirZ) / bd.spd
                end

                -- Anti-feinte: direction flip
                if bd.prevDot < -0.1 and dot > 0.2 then
                    feintDetectee = true
                    dernierP = 0
                end
                bd.prevDot = dot

                -- Confirme cible?
                local confirme = charRouge
                if not confirme and doAttrCheck then
                    confirme = checkAttributs(b)
                end

                -- ETA
                local eta = 9999
                if bd.closingSpd > 3 then
                    eta = dist / bd.closingSpd
                end

                -- Prediction 5 frames
                local distEff = dist
                if bd.spd > 20 then
                    local dt5 = 5 / 60
                    local px = bPos.X + bd.velX * dt5
                    local py = bPos.Y + bd.velY * dt5
                    local pz = bPos.Z + bd.velZ * dt5
                    local pdist = math.sqrt((px - hPos.X)^2 + (py - hPos.Y)^2 + (pz - hPos.Z)^2)
                    if pdist < dist then distEff = pdist end
                end

                local etaPred = 9999
                if bd.closingSpd > 3 then
                    etaPred = distEff / bd.closingSpd
                end

                -- Score de danger pour cette balle
                local dangerEta = math.min(eta, etaPred)
                local shouldParry = false

                if confirme then
                    anyConfirme = true
                    if dangerEta < 0.15 or dist < 12 then
                        shouldParry = true
                    end
                elseif dist < 8 and bd.closingSpd > 10 then
                    shouldParry = true
                end

                if shouldParry and dangerEta < bestParryEta then
                    bestParryEta = dangerEta
                    bestParryDist = dist
                    bestParrySpd = bd.spd
                    bestParryBall = b
                    bestConfirme = confirme
                end
            end
        end
    end

    -- UI data
    uiNbBalles = #balles
    uiDanger = bestParryBall
    uiConf = anyConfirme

    -- PARRY la balle la plus dangereuse
    if bestParryBall then
        local ok = doParry(bestParrySpd, bestParryDist)
        if ok then
            pcall(function()
                flash.BackgroundTransparency = 0.8
                TweenService:Create(flash, TweenInfo.new(0.06), {BackgroundTransparency = 1}):Play()
            end)
        end
    end

    if not anyConfirme and #balles > 0 then streak = 0 end
end

-- ═══════════════════════════════════════
--  BOUCLE 120fps
-- ═══════════════════════════════════════
RunService:BindToRenderStep(RK, Enum.RenderPriority.First.Value, function()
    frameN = frameN + 1
    coreCheck()

    if frameN % 20 ~= 0 then return end

    lP.Text = tostring(compteur)
    lS.Text = tostring(streak)
    lB.Text = tostring(best)

    local nb = uiNbBalles
    if nb == 0 then
        lBalle.Text = "Recherche..."
        lBalle.TextColor3 = ORANGE
        lInfo.Text = ""
        lMode.Text = ""
        return
    end

    lBalle.Text = nb .. " balle" .. (nb > 1 and "s" or "") .. " detectee" .. (nb > 1 and "s" or "")
    lBalle.TextColor3 = GREEN

    local hrp = cachedHRP
    if hrp and #balles > 0 then
        local closestDist = 9999
        local closestSpd = 0
        local closestEta = 9999
        for _, b in pairs(balles) do
            if b.Parent then
                local okP, bPos = pcall(function() return b.Position end)
                if okP then
                    local d = (bPos - hrp.Position).Magnitude
                    if d < closestDist then
                        closestDist = d
                        local bd = ballData[b]
                        if bd then
                            closestSpd = bd.spd
                            closestEta = (bd.closingSpd > 3) and (d / bd.closingSpd) or 9999
                        end
                    end
                end
            end
        end
        local etaStr = closestEta < 99 and string.format("%.2f", closestEta) or "--"
        lInfo.Text = "Dist " .. math.floor(closestDist) .. " | Vit " .. math.floor(closestSpd) .. " | ETA " .. etaStr .. "s"

        if charRouge then
            lMode.Text = "ROUGE — Pret a parry"
            lMode.TextColor3 = RED
        elseif uiConf then
            lMode.Text = "CONFIRME — Pret a parry"
            lMode.TextColor3 = GREEN
        else
            lMode.Text = "Pas cible — Surveillance"
            lMode.TextColor3 = TXT3
        end
    end
end)

RunService.Heartbeat:Connect(function()
    coreCheck()
end)

print("[AutoParry] v21 | Multi-balle | Zero mort | Entrainement compatible")
