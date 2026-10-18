-- Auto Parry v22 — Mode Normal + Entrainement
--
-- 2 modes: Normal (1 balle) / Entrainement (2 balles independantes)
-- Detection balle ultra large (nom + forme + folder)
-- Parry uniquement quand confirme (rouge/attribut) + balle proche

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
local modeEntrainement = false
local cachedHRP = nil
local cachedChar = nil
local dernierP = 0
local compteur = 0
local streak = 0
local best = 0
local ouvert = true
local frameN = 0
local charRouge = false

-- ═══════════════════════════════════════
--  COULEURS
-- ═══════════════════════════════════════
local ACCENT = Color3.fromRGB(90, 120, 255)
local GREEN  = Color3.fromRGB(45, 210, 90)
local RED    = Color3.fromRGB(230, 55, 55)
local ORANGE = Color3.fromRGB(255, 165, 40)
local YELLOW = Color3.fromRGB(255, 220, 50)
local CYAN   = Color3.fromRGB(50, 200, 220)
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
            if ok1 and fc and fc.R > 0.5 and fc.G < 0.4 then charRouge = true; return end
            local ok2, oc = pcall(function() return ch.OutlineColor end)
            if ok2 and oc and oc.R > 0.5 and oc.G < 0.4 then charRouge = true; return end
        elseif ch:IsA("SelectionBox") then
            local ok1, c3 = pcall(function() return ch.Color3 end)
            if ok1 and c3 and c3.R > 0.5 and c3.G < 0.4 then charRouge = true; return end
        end
    end
end

local function watchChar(char)
    pcall(function()
        char.ChildAdded:Connect(function(ch)
            if ch:IsA("Highlight") or ch:IsA("SelectionBox") then
                task.spawn(function() task.wait(0.02); checkRouge() end)
            end
        end)
        char.ChildRemoved:Connect(function(ch)
            if ch:IsA("Highlight") or ch:IsA("SelectionBox") then
                charRouge = false; checkRouge()
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
    cachedChar = nil; cachedHRP = nil; charRouge = false
end)

-- ═══════════════════════════════════════
--  DETECTION BALLE — workspace.Balls + realBall
-- ═══════════════════════════════════════
local ballsFolder = nil
local balles = {}
local bState = {}

local function getState(b)
    if not bState[b] then
        bState[b] = {
            prevPos = nil, prevTime = 0, spd = 0,
            velX = 0, velY = 0, velZ = 0,
            prevDist = 9999, closingSpd = 0,
            ch = {0, 0, 0}, ci = 1,
            prevDot = 0,
        }
    end
    return bState[b]
end

local function ajouterBalle(b)
    if bState[b] then return end
    getState(b)
    table.insert(balles, b)
end

local function retirerBalle(b)
    bState[b] = nil
    for i = #balles, 1, -1 do
        if balles[i] == b then table.remove(balles, i); break end
    end
end

local function estVraiBalle(b)
    if not b:IsA("BasePart") then return false end
    local ok, val = pcall(b.GetAttribute, b, "realBall")
    if ok and val == true then return true end
    return false
end

local function scanBalles()
    if not ballsFolder then
        local ok, f = pcall(workspace.FindFirstChild, workspace, "Balls")
        if ok and f then ballsFolder = f end
    end
    if not ballsFolder then return end

    for _, v in pairs(ballsFolder:GetChildren()) do
        if v:IsA("BasePart") then
            if modeEntrainement then
                ajouterBalle(v)
            else
                if estVraiBalle(v) then ajouterBalle(v) end
            end
        elseif v:IsA("Model") then
            local p = v:FindFirstChildWhichIsA("BasePart")
            if p then
                if modeEntrainement then
                    ajouterBalle(p)
                elseif estVraiBalle(p) or estVraiBalle(v) then
                    ajouterBalle(p)
                end
            end
        end
    end

    -- Fallback: si entrainement et rien trouve, chercher partout
    if modeEntrainement and #balles == 0 then
        local ok3, desc = pcall(workspace.GetDescendants, workspace)
        if ok3 then
            for _, v in pairs(desc) do
                if v:IsA("BasePart") and not v.Anchored then
                    local n = v.Name:lower()
                    if n:find("ball") or n:find("orb") or n:find("proj") then
                        local p = v.Parent
                        local isPlayer = false
                        while p and p ~= workspace do
                            if Players:GetPlayerFromCharacter(p) then isPlayer = true; break end
                            p = p.Parent
                        end
                        if not isPlayer then ajouterBalle(v) end
                    end
                end
            end
        end
    end

    for i = #balles, 1, -1 do
        if not balles[i].Parent then retirerBalle(balles[i]) end
    end
end

-- Event: nouvelle balle dans le folder
task.spawn(function()
    if not ballsFolder then
        local ok, f = pcall(workspace.WaitForChild, workspace, "Balls", 30)
        if ok and f then ballsFolder = f end
    end
    if ballsFolder then
        ballsFolder.ChildAdded:Connect(function(b)
            task.wait(0.1)
            if b:IsA("BasePart") then
                if modeEntrainement or estVraiBalle(b) then ajouterBalle(b) end
            elseif b:IsA("Model") then
                local p = b:FindFirstChildWhichIsA("BasePart")
                if p and (modeEntrainement or estVraiBalle(p) or estVraiBalle(b)) then
                    ajouterBalle(p)
                end
            end
        end)
        ballsFolder.ChildRemoved:Connect(function(b)
            if bState[b] then retirerBalle(b) end
            for _, ch in pairs(b:GetDescendants()) do
                if bState[ch] then retirerBalle(ch) end
            end
        end)
    end
end)

-- Scan initial + periodique
scanBalles()
task.spawn(function()
    while true do
        task.wait(1)
        scanBalles()
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
    for _, attr in pairs({"Target", "target", "realTarget", "CurrentTarget", "currentTarget", "TargetPlayer"}) do
        ok, t = pcall(b.GetAttribute, b, attr)
        if ok and matchT(t) then return true end
    end
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
        for _, attr in pairs({"Target", "target"}) do
            ok, t = pcall(p.GetAttribute, p, attr)
            if ok and matchT(t) then return true end
        end
    end
    return false
end

-- ═══════════════════════════════════════
--  PARRY
-- ═══════════════════════════════════════
local function doParry()
    local now = tick()
    if now - dernierP < 0.3 then return false end
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
        if cachedHRP then pcall(function() cachedHRP.CFrame = cachedHRP.CFrame end) end
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
local H_OPEN = 340
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
mk("TextLabel", {Size = UDim2.new(0, 130, 0, 14), Position = UDim2.new(0, 80, 0, 14), BackgroundTransparency = 1, Text = "AUTO PARRY v22", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
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

-- MODE
local mc = sect(48, "Mode", 32)
local btnNormal = mk("TextButton", {Size = UDim2.new(0.45, 0, 0, 18), Position = UDim2.new(0, 7, 0, 14), BackgroundColor3 = ACCENT, Text = "Normal", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 10, Parent = mc})
rnd(btnNormal, 6)
local btnTrain = mk("TextButton", {Size = UDim2.new(0.45, 0, 0, 18), Position = UDim2.new(0.5, 7, 0, 14), BackgroundColor3 = BG4, Text = "Entrainement", TextColor3 = TXT2, Font = Enum.Font.GothamBold, TextSize = 10, Parent = mc})
rnd(btnTrain, 6)

local function majMode()
    if modeEntrainement then
        btnNormal.BackgroundColor3 = BG4; btnNormal.TextColor3 = TXT2
        btnTrain.BackgroundColor3 = CYAN; btnTrain.TextColor3 = TXT1
    else
        btnNormal.BackgroundColor3 = ACCENT; btnNormal.TextColor3 = TXT1
        btnTrain.BackgroundColor3 = BG4; btnTrain.TextColor3 = TXT2
    end
end
btnNormal.MouseButton1Click:Connect(function() modeEntrainement = false; majMode() end)
btnTrain.MouseButton1Click:Connect(function() modeEntrainement = true; majMode(); majBalles() end)

-- STATS
local sc = sect(86, "Stats", 46)
local bw = math.floor((W - 20 - 16) / 3)
local function sbox(parent, x, lbl, col)
    mk("TextLabel", {Size = UDim2.new(0, bw, 0, 8), Position = UDim2.new(0, x, 0, 17), BackgroundTransparency = 1, Text = string.upper(lbl), TextColor3 = col, Font = Enum.Font.GothamBold, TextSize = 7, Parent = parent})
    return mk("TextLabel", {Size = UDim2.new(0, bw, 0, 16), Position = UDim2.new(0, x, 0, 26), BackgroundTransparency = 1, Text = "0", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 15, Parent = parent})
end
local lP = sbox(sc, 7, "Parrys", ACCENT)
local lS = sbox(sc, 7 + bw + 8, "Streak", ORANGE)
local lB = sbox(sc, 7 + bw * 2 + 16, "Record", YELLOW)

-- BALLE
local bc = sect(138, "Balle", 68)
local lBalle = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 18), BackgroundTransparency = 1, Text = "Recherche...", TextColor3 = ORANGE, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lInfo = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 32), BackgroundTransparency = 1, Text = "", TextColor3 = TXT2, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})
local lMode = mk("TextLabel", {Size = UDim2.new(1, -14, 0, 11), Position = UDim2.new(0, 7, 0, 46), BackgroundTransparency = 1, Text = "", TextColor3 = TXT3, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = bc})

-- TOGGLE
local tBg = mk("Frame", {Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 212), BackgroundColor3 = GREEN, Parent = panel})
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
local ic = sect(246, "Info", 42)
mk("TextLabel", {
    Size = UDim2.new(1, -14, 0, 28), Position = UDim2.new(0, 7, 0, 12),
    BackgroundTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Parry auto quand rouge + balle proche\nRShift = On/Off  |  RCtrl = Masquer",
    TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 8, Parent = ic,
})

-- BOUTONS
local btnScan = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 22), Position = UDim2.new(0, 10, 0, 294), BackgroundColor3 = BG3, Text = "Chercher balles", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnScan, 6)
btnScan.MouseButton1Click:Connect(function() majBalles() end)
local btnRst = mk("TextButton", {Size = UDim2.new(0.47, 0, 0, 22), Position = UDim2.new(0.53, 0, 0, 294), BackgroundColor3 = BG3, Text = "Reset stats", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, Parent = panel})
rnd(btnRst, 6)
btnRst.MouseButton1Click:Connect(function() compteur = 0; streak = 0; best = 0 end)

mk("TextLabel", {Size = UDim2.new(1, -20, 0, 12), Position = UDim2.new(0, 10, 0, 322), BackgroundTransparency = 1, Text = "v22 | Normal + Entrainement", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 7, Parent = panel})

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
--  CORE — evalue chaque balle
--
--  Regle simple:
--  - Confirme (rouge OU attribut) → regarde ETA + distance
--  - ETA < 150ms OU dist < 12 → PARRY
--  - Pas confirme → RIEN (zero faux clic)
-- ═══════════════════════════════════════
local uiClosestDist = 9999
local uiClosestSpd = 0
local uiClosestEta = 9999
local uiConfirme = false

RunService:BindToRenderStep(RK, Enum.RenderPriority.First.Value, function()
    frameN = frameN + 1
    if not actif then return end

    local hrp = cachedHRP
    if not hrp then majChar(); hrp = cachedHRP end
    if not hrp then return end
    local hPos = hrp.Position
    local now = tick()

    if frameN % 2 == 0 then checkRouge() end

    local doAttr = (frameN % 6 == 0)
    local didParry = false
    uiConfirme = false
    uiClosestDist = 9999

    -- Nettoyer balles mortes
    for i = #balles, 1, -1 do
        if not balles[i].Parent then
            bState[balles[i]] = nil
            table.remove(balles, i)
        end
    end

    -- En mode Normal: seulement la 1ere balle trouvee
    -- En mode Entrainement: toutes les balles
    local listeBoucle = balles
    if not modeEntrainement and #balles > 1 then
        listeBoucle = { balles[1] }
    end

    for _, b in pairs(listeBoucle) do
        local okP, bPos = pcall(function() return b.Position end)
        if not okP then continue end

        local st = getState(b)
        local dx = bPos.X - hPos.X
        local dy = bPos.Y - hPos.Y
        local dz = bPos.Z - hPos.Z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

        -- Vitesse par delta position
        if st.prevPos then
            local dt = now - st.prevTime
            if dt > 0.001 then
                st.velX = (bPos.X - st.prevPos.X) / dt
                st.velY = (bPos.Y - st.prevPos.Y) / dt
                st.velZ = (bPos.Z - st.prevPos.Z) / dt
                st.spd = math.sqrt(st.velX^2 + st.velY^2 + st.velZ^2)

                local raw = (st.prevDist - dist) / dt
                st.ch[st.ci] = raw
                st.ci = (st.ci % 3) + 1
                st.closingSpd = (st.ch[1] + st.ch[2] + st.ch[3]) / 3
            end
        end
        st.prevPos = bPos
        st.prevTime = now
        st.prevDist = dist

        -- Direction vers joueur
        local dot = 0
        if st.spd > 3 and dist > 0.1 then
            dot = (st.velX * (-dx) + st.velY * (-dy) + st.velZ * (-dz)) / (st.spd * dist)
        end
        st.prevDot = dot

        -- ETA
        local eta = 9999
        if st.closingSpd > 3 then eta = dist / st.closingSpd end

        -- Prediction 5 frames
        if st.spd > 15 then
            local dt5 = 5 / 60
            local px = bPos.X + st.velX * dt5
            local py = bPos.Y + st.velY * dt5
            local pz = bPos.Z + st.velZ * dt5
            local pd = math.sqrt((px - hPos.X)^2 + (py - hPos.Y)^2 + (pz - hPos.Z)^2)
            if pd < dist and st.closingSpd > 3 then
                local etaP = pd / st.closingSpd
                if etaP < eta then eta = etaP end
            end
        end

        -- UI tracking (balle la plus proche)
        if dist < uiClosestDist then
            uiClosestDist = dist
            uiClosestSpd = st.spd
            uiClosestEta = eta
        end

        -- Confirme?
        local confirme = charRouge
        if not confirme and doAttr then confirme = checkAttributs(b) end
        if not confirme and modeEntrainement and dot > 0.2 then confirme = true end

        if confirme then uiConfirme = true end

        -- PARRY: confirme + balle proche + balle approche
        local seuilEta = modeEntrainement and 0.3 or 0.15
        local seuilDist = modeEntrainement and 20 or 12
        if confirme and (eta < seuilEta or dist < seuilDist) and dot > 0.1 and not didParry then
            if doParry() then
                didParry = true
                pcall(function()
                    flash.BackgroundTransparency = 0.8
                    TweenService:Create(flash, TweenInfo.new(0.06), {BackgroundTransparency = 1}):Play()
                end)
            end
        end
    end

    if not uiConfirme and #balles > 0 then streak = 0 end

    -- UI update
    if frameN % 20 ~= 0 then return end

    lP.Text = tostring(compteur)
    lS.Text = tostring(streak)
    lB.Text = tostring(best)

    local nb = #balles
    if nb == 0 then
        lBalle.Text = "Recherche..."
        lBalle.TextColor3 = ORANGE
        lInfo.Text = ""
        lMode.Text = ""
        return
    end

    lBalle.Text = nb .. " balle" .. (nb > 1 and "s" or "")
    lBalle.TextColor3 = GREEN

    local etaStr = uiClosestEta < 99 and string.format("%.2f", uiClosestEta) or "--"
    lInfo.Text = "Dist " .. math.floor(uiClosestDist) .. " | Vit " .. math.floor(uiClosestSpd) .. " | ETA " .. etaStr .. "s"

    if charRouge then
        lMode.Text = "ROUGE — Pret a parry"
        lMode.TextColor3 = RED
    elseif uiConfirme then
        lMode.Text = "CONFIRME — Pret a parry"
        lMode.TextColor3 = GREEN
    else
        lMode.Text = "Pas cible — Surveillance"
        lMode.TextColor3 = TXT3
    end
end)

print("[AutoParry] v22 | Mode Normal + Entrainement | Zero faux clic")
