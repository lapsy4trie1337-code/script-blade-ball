-- Auto Parry v28
-- Cible  : attribut "target" de la balle (sinon Highlight rouge)
-- Vitesse: ball.zoomies.VectorVelocity > AssemblyLinearVelocity > delta de position
-- Timing : trajectoire simulee (courbes incluses), clic quand l'impact prevu <= anticipation + ping
-- Balles : tout dossier dont le nom contient "ball" (Balls, TrainingBalls...),
--          parts marquees (realBall / target / zoomies), + apprentissage auto en entrainement

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer

-- Une seule instance : si le script est relance, l'ancienne est nettoyee
local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.__AutoParryCleanup) == "function" then
    pcall(env.__AutoParryCleanup)
end

local alive = true
local connections = {}
local function bind(signal, fn)
    local c = signal:Connect(fn)
    connections[#connections + 1] = c
    return c
end

local function rkey()
    local s = ""
    for _ = 1, 16 do s = s .. string.char(math.random(97, 122)) end
    return s
end

-- ═══════════════════════════════════════
--  CONFIG (sauvegardee si l'executor a writefile)
-- ═══════════════════════════════════════
local CFG_FILE = "autoparry_cfg.json"
local cfg = {
    actif = true,
    mode = "auto",          -- auto | normal | train
    anticipation = 0.35,    -- secondes avant l'impact (le ping aller-retour s'ajoute)
    pingComp = true,
    spam = true,
}

local function loadCfg()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    local ok, data = pcall(function()
        if not isfile(CFG_FILE) then return nil end
        return HttpService:JSONDecode(readfile(CFG_FILE))
    end)
    if not ok or type(data) ~= "table" then return end
    if data.mode == "auto" or data.mode == "normal" or data.mode == "train" then cfg.mode = data.mode end
    if type(data.anticipation) == "number" then cfg.anticipation = math.clamp(data.anticipation, 0.1, 1.0) end
    if type(data.pingComp) == "boolean" then cfg.pingComp = data.pingComp end
    if type(data.spam) == "boolean" then cfg.spam = data.spam end
end

local function saveCfg()
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(CFG_FILE, HttpService:JSONEncode({
            mode = cfg.mode,
            anticipation = cfg.anticipation,
            pingComp = cfg.pingComp,
            spam = cfg.spam,
        }))
    end)
end
loadCfg()

-- ═══════════════════════════════════════
--  ETAT
-- ═══════════════════════════════════════
local SPAM_RANGE = 18
local MAX_BALLS = 40
local compteur, streak, best = 0, 0, 0
local charRouge = false
local pingSec = 0.1
local lastClick, lastParry = 0, 0
local lastError, lastErrorAt = nil, 0
local diagMsg, diagUntil = nil, 0
local frameN = 0
local panel, flash = nil, nil
local ui = { n = 0, active = 0, dist = 0, speed = 0, eta = 999, mine = false, why = "", src = "", folder = "" }

-- ═══════════════════════════════════════
--  PERSONNAGE
-- ═══════════════════════════════════════
local cachedChar, cachedHRP = nil, nil

local function onChar(c)
    cachedChar = c
    local hrp = c:WaitForChild("HumanoidRootPart", 10)
    if cachedChar ~= c then return end
    cachedHRP = hrp
    local hum = c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 5)
    if hum and cachedChar == c then
        bind(hum.Died, function() streak = 0 end)
    end
end
if LP.Character then task.spawn(onChar, LP.Character) end
bind(LP.CharacterAdded, function(c) task.spawn(onChar, c) end)
bind(LP.CharacterRemoving, function()
    cachedChar = nil
    cachedHRP = nil
    charRouge = false
end)

local function checkRouge()
    local c = cachedChar
    if not c then
        charRouge = false
        return
    end
    local ok, h = pcall(c.FindFirstChildWhichIsA, c, "Highlight")
    charRouge = ok and h ~= nil
end

local function needsConfirm()
    if cfg.mode == "normal" then return true end
    if cfg.mode == "train" then return false end
    return #Players:GetPlayers() > 1
end

-- ═══════════════════════════════════════
--  PING
-- ═══════════════════════════════════════
local function readPing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(v) == "number" and v > 0 then return v / 1000 end
    local ok2, v2 = pcall(function() return LP:GetNetworkPing() end)
    if ok2 and type(v2) == "number" and v2 > 0 then return v2 * 2 end
    return 0.1
end
task.spawn(function()
    while alive do
        pingSec = readPing()
        task.wait(1)
    end
end)

-- ═══════════════════════════════════════
--  CLIC (mouse1click, touche F si la souris est sur le panneau)
-- ═══════════════════════════════════════
local VIM = nil

local function mouseOverPanel()
    if not panel or not panel.Visible then return false end
    local ok, over = pcall(function()
        local m = UIS:GetMouseLocation() - GuiService:GetGuiInset()
        local p, s = panel.AbsolutePosition, panel.AbsoluteSize
        return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
    end)
    return ok and over
end

local function pressF()
    task.spawn(function()
        pcall(keypress, 0x46)
        task.wait(0.03)
        pcall(keyrelease, 0x46)
    end)
end

local function rawClick()
    local canKey = type(keypress) == "function" and type(keyrelease) == "function"
    if canKey and mouseOverPanel() then
        pressF()
        return true
    end
    if type(mouse1click) == "function" and pcall(mouse1click) then return true end
    if canKey then
        pressF()
        return true
    end
    local ok = pcall(function()
        VIM = VIM or game:GetService("VirtualInputManager")
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
    return ok
end

local function click(isSpam)
    local now = tick()
    if now - lastClick < 0.04 then return false end
    if not rawClick() then return false end
    lastClick = now
    if not isSpam then
        compteur = compteur + 1
        streak = streak + 1
        if streak > best then best = streak end
        if flash then
            flash.BackgroundTransparency = 0.85
            TweenService:Create(flash, TweenInfo.new(0.08), {BackgroundTransparency = 1}):Play()
        end
    end
    return true
end

-- ═══════════════════════════════════════
--  REGISTRE DES BALLES (evenements + scan lent de secours)
-- ═══════════════════════════════════════
local balls = {}
local ballCount = 0
local learnedParts, learnedContainers, learnedNames = {}, {}, {}

local function hasBallName(inst)
    if not inst or inst == workspace or inst:IsA("BasePart") then return false end
    if not inst:IsDescendantOf(workspace) then return false end
    return string.find(string.lower(inst.Name), "ball", 1, true) ~= nil
end

local function inCharacter(p)
    local a = p.Parent
    while a and a ~= workspace do
        if a:IsA("Model") and a:FindFirstChildOfClass("Humanoid") then return true end
        a = a.Parent
    end
    return false
end

local function strongMark(p)
    local par = p.Parent
    return hasBallName(par)
        or (par ~= workspace and hasBallName(par.Parent))
        or p:GetAttribute("realBall") ~= nil
        or p:GetAttribute("target") ~= nil
        or p:FindFirstChild("zoomies") ~= nil
end

local function weakMark(p)
    local par = p.Parent
    return learnedParts[p] == true
        or learnedContainers[par] == true
        or (par == workspace and learnedNames[p.Name] == true)
end

local function track(p)
    if balls[p] or ballCount >= MAX_BALLS then return end
    if not p.Parent then return end
    local strong = strongMark(p)
    if not strong and not weakMark(p) then return end
    if p.Size.Magnitude > 25 then return end
    if not p:IsDescendantOf(workspace) or inCharacter(p) then return end
    local st = {
        buf = { { t = tick(), p = p.Position } },
        vel = Vector3.zero,
        stable = 0,
        parried = false,
        parriedAt = 0,
        lastParryAt = 0,
        clashUntil = 0,
        omega = 0,
        dir = nil,
        dirT = 0,
        strong = strong,
    }
    st.conn = p:GetAttributeChangedSignal("target"):Connect(function()
        st.parried = false
    end)
    balls[p] = st
    ballCount = ballCount + 1
end

local function untrack(p)
    local st = balls[p]
    if not st then return end
    if st.conn then st.conn:Disconnect() end
    balls[p] = nil
    ballCount = ballCount - 1
end

bind(workspace.DescendantAdded, function(d)
    if d:IsA("BasePart") then
        pcall(track, d)
    elseif d.Name == "zoomies" then
        local par = d.Parent
        if par and par:IsA("BasePart") then pcall(track, par) end
    end
end)
bind(workspace.DescendantRemoving, function(d)
    if balls[d] then untrack(d) end
end)

local function fullScan()
    local ok, desc = pcall(workspace.GetDescendants, workspace)
    if not ok then return end
    for i = 1, #desc do
        local d = desc[i]
        if not alive then return end
        if d:IsA("BasePart") and not balls[d] then pcall(track, d) end
        if i % 1000 == 0 then task.wait() end
    end
end
task.spawn(function()
    while alive do
        fullScan()
        task.wait(5)
    end
end)

-- Apprentissage : trouve les petites parts qui bougent pres de toi (balle d'entrainement inconnue)
local function learn(part)
    local isNew = not learnedParts[part]
    learnedParts[part] = true
    local par = part.Parent
    if par and par ~= workspace then
        if #par:GetChildren() <= 10 then learnedContainers[par] = true end
    else
        learnedNames[part.Name] = true
    end
    pcall(track, part)
    return isNew
end

local function findMovingParts(center)
    local snap = {}
    local ok, desc = pcall(workspace.GetDescendants, workspace)
    if not ok then return {} end
    for i = 1, #desc do
        local d = desc[i]
        if d:IsA("BasePart") and not balls[d] and d.Size.Magnitude <= 12 then
            local okp, pos = pcall(function() return d.Position end)
            if okp and (pos - center).Magnitude <= 120 then
                snap[#snap + 1] = { part = d, pos = pos }
            end
        end
        if i % 3000 == 0 then task.wait() end
    end
    task.wait(0.2)
    local found = {}
    for _, e in ipairs(snap) do
        local d = e.part
        if d.Parent and not inCharacter(d) then
            local okp, p1 = pcall(function() return d.Position end)
            if okp then
                local moved = (p1 - e.pos).Magnitude
                if moved > 2 and moved < 400 then
                    found[#found + 1] = { part = d, speed = moved / 0.2 }
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.speed > b.speed end)
    return found
end

task.spawn(function()
    while alive do
        task.wait(2)
        local trainLike = cfg.mode == "train" or (cfg.mode == "auto" and not needsConfirm())
        if alive and cfg.actif and trainLike and ui.active == 0 and cachedHRP then
            local found = findMovingParts(cachedHRP.Position)
            for i = 1, math.min(#found, 3) do
                if learn(found[i].part) then
                    print("[AutoParry] Balle apprise: " .. found[i].part:GetFullName())
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════
--  CALCUL PAR BALLE
-- ═══════════════════════════════════════
local HIT_R = 2.5

local function readVelocity(p, st, now, pos)
    local buf = st.buf
    local last = buf[#buf]
    if not last then
        buf[1] = { t = now, p = pos }
    elseif now - last.t > 0.0005 then
        local jump = pos - last.p
        local jm = jump.Magnitude
        local vm = st.vel.Magnitude
        if jm > 50 and jm > vm * (now - last.t) * 4 then
            -- teleport (respawn) : on repart de zero
            buf = {}
            st.buf = buf
            st.vel = Vector3.zero
        elseif st.stable >= 2 and vm > 20 and jm > vm * (now - last.t) * 0.3 and jump:Dot(st.vel) < -0.5 * jm * vm then
            -- demi-tour (parry) : la fenetre repart du point de rebond
            buf = { last }
            st.buf = buf
        end
        buf[#buf + 1] = { t = now, p = pos }
        if #buf > 24 then table.remove(buf, 1) end
    end

    -- Vitesse mesuree sur ~0.08 s : robuste aux FPS irreguliers et au ping qui varie
    st.stable = 0
    local n = #buf
    if n >= 2 then
        local old = buf[1]
        for i = n - 1, 1, -1 do
            old = buf[i]
            if now - old.t >= 0.08 then break end
        end
        local span = now - old.t
        if span >= 0.03 then
            st.vel = (pos - old.p) / span
            st.stable = n >= 3 and 2 or 1
        end
    end

    local vel, src = nil, "aucune"
    local z = p:FindFirstChild("zoomies")
    if z then
        local ok, v = pcall(function() return z.VectorVelocity end)
        if ok and typeof(v) == "Vector3" and v.Magnitude > 1 then vel, src = v, "zoomies" end
    end
    if not vel then
        local ok, v = pcall(function() return p.AssemblyLinearVelocity end)
        if ok and typeof(v) == "Vector3" and v.Magnitude > 1 then vel, src = v, "physique" end
    end
    if not vel and st.stable >= 2 then vel, src = st.vel, "delta" end
    if not vel then return Vector3.zero, 0, src end

    local speed = vel.Magnitude
    if speed < 0.01 then return Vector3.zero, 0, src end
    -- Si la direction donnee contredit le mouvement observe, on garde la vitesse mais la direction observee
    if src ~= "delta" and st.stable >= 2 and st.vel.Magnitude > 2 then
        local du = st.vel.Unit
        if (vel / speed):Dot(du) < 0.5 then vel = du * speed end
    end
    return vel, speed, src
end

-- Vitesse de virage de la balle (rad/s), lissee
local function updateTurn(st, vel, speed, now)
    if speed < 2 then return end
    local u = vel / speed
    if st.dir then
        local dt = now - st.dirT
        if dt > 0.001 then
            local w = math.acos(math.clamp(u:Dot(st.dir), -1, 1)) / dt
            if w < 25 then st.omega = st.omega + (w - st.omega) * 0.35 end
        end
    end
    st.dir = u
    st.dirT = now
end

-- Simule la trajectoire (la balle vire vers toi a omega rad/s) et renvoie le temps avant impact
local function predictEta(pos, vel, speed, hPos, omega, horizon)
    if speed < 2 then return 999 end
    local p, d = pos, vel / speed
    local h = 1 / 120
    local stepLen = speed * h
    local maxTurn = omega * h
    local t = 0
    while t < horizon do
        local toT = hPos - p
        local dist = toT.Magnitude
        if dist <= HIT_R then return t end
        if maxTurn > 0 then
            local want = toT / dist
            local ang = math.acos(math.clamp(d:Dot(want), -1, 1))
            if ang <= maxTurn then
                d = want
            else
                local k = maxTurn / ang
                d = (d * (1 - k) + want * k).Unit
            end
        end
        local along = math.clamp(toT:Dot(d), 0, stepLen)
        if (toT - d * along).Magnitude <= HIT_R then
            return t + along / speed
        end
        p = p + d * stepLen
        t = t + h
    end
    return 999
end

local function evalBall(p, st, now, hPos, confirm, threshold)
    local pos = p.Position
    local toMe = hPos - pos
    local dist = toMe.Magnitude
    local vel, speed, src = readVelocity(p, st, now, pos)
    updateTurn(st, vel, speed, now)
    local approach = 0
    if dist > 0.01 and speed > 0 then
        approach = vel:Dot(toMe) / dist
    end

    local target = p:GetAttribute("target")
    local mine, why
    if type(target) == "string" and target ~= "" then
        mine = target == LP.Name
        why = "attr"
    elseif not confirm then
        mine = true
        why = "train"
    else
        mine = charRouge
        why = "rouge"
    end

    -- Rearmement : changement de "target" (signal), sinon la balle repart / delai depasse
    if st.parried then
        if now - st.parriedAt > 1.0 then
            st.parried = false
        elseif why ~= "attr" and approach < -5 then
            st.parried = false
        end
    end

    -- Trajectoire predite (gere les courbes). Une balle confirmee sur toi est supposee te suivre.
    local omega = st.omega
    if mine and why ~= "train" then omega = math.max(omega, 2) end
    local eta = predictEta(pos, vel, speed, hPos, omega, threshold + 0.15)
    local etaShown = eta
    if eta >= 999 and speed > 2 then etaShown = math.max(0, dist - HIT_R) / speed end

    local should = false
    if not st.parried and speed > 2 then
        if why == "attr" then
            should = mine and eta <= threshold
        elseif why == "train" then
            should = approach > 0 and eta <= threshold
        elseif st.strong then
            if mine then
                should = eta <= threshold
            else
                should = approach > 0 and dist <= 6 and eta <= threshold
            end
        end
    end

    local spam = cfg.spam and mine and (st.strong or not confirm) and now < st.clashUntil and dist <= SPAM_RANGE
    return dist, speed, etaShown, mine, why, src, should, spam
end

local function step()
    local now = tick()
    if frameN % 3 == 0 then checkRouge() end

    local realParents = {}
    for p in pairs(balls) do
        if p.Parent == nil or not p:IsDescendantOf(workspace) then
            untrack(p)
        elseif p:GetAttribute("realBall") == true then
            realParents[p.Parent] = true
        end
    end

    local hrp = cachedHRP
    if not hrp or not hrp.Parent then
        ui.n = 0
        ui.active = 0
        return
    end
    local hPos = hrp.Position
    local confirm = needsConfirm()
    local threshold = cfg.anticipation
    -- La balle vue est en retard de ping/2 et le clic arrive ping/2 plus tard : on anticipe d'un ping complet
    if cfg.pingComp then threshold = threshold + math.min(pingSec, 0.35) end

    local n, active = 0, 0
    local bestScore = math.huge
    local toMark, toSpam = {}, {}

    for p, st in pairs(balls) do
        local real = p:GetAttribute("realBall")
        if real ~= false and (real == true or not realParents[p.Parent]) then
            local dist, speed, eta, mine, why, src, should, spam = evalBall(p, st, now, hPos, confirm, threshold)
            n = n + 1
            if speed > 2 and dist < 200 then active = active + 1 end
            if should then toMark[#toMark + 1] = st end
            if spam then toSpam[#toSpam + 1] = st end
            local score = mine and math.min(eta, 999) or (1000 + dist)
            if score < bestScore then
                bestScore = score
                ui.dist, ui.speed, ui.eta, ui.mine, ui.why, ui.src = dist, speed, eta, mine, why, src
                ui.folder = p.Parent and p.Parent.Name or ""
            end
        end
    end
    ui.n = n
    ui.active = active

    if not cfg.actif then return end
    if #toMark > 0 and now - lastParry >= 0.15 then
        if click(false) then
            for i = 1, #toMark do
                local st = toMark[i]
                st.parried = true
                st.parriedAt = now
                -- Clash = la MEME balle revient sur toi en moins de 0.7 s
                if now - st.lastParryAt < 0.7 then st.clashUntil = now + 0.6 end
                st.lastParryAt = now
            end
            lastParry = now
        end
    elseif #toSpam > 0 then
        if click(true) then
            for i = 1, #toSpam do toSpam[i].clashUntil = now + 0.5 end
        end
    end
end

-- ═══════════════════════════════════════
--  GUI
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

local gui = Instance.new("ScreenGui")
gui.Name = rkey()
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function mk(class, props)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then pcall(function() o[k] = v end) end
    end
    if props.Parent then o.Parent = props.Parent end
    return o
end
local function rnd(o, r)
    mk("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = o})
end

local W, H_OPEN, H_CLOSED = 300, 354, 42
local ouvert = true

panel = mk("Frame", {
    Size = UDim2.new(0, W, 0, H_OPEN),
    Position = UDim2.new(0, 14, 0.5, -H_OPEN / 2),
    BackgroundColor3 = BG1, BackgroundTransparency = 0.02,
    ClipsDescendants = true, Parent = gui,
})
rnd(panel, 12)
mk("UIStroke", {Color = BORD, Thickness = 1, Parent = panel})

local hdr = mk("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = BG2, Parent = panel})
rnd(hdr, 12)
mk("Frame", {Size = UDim2.new(1, -20, 0, 2), Position = UDim2.new(0, 10, 0, 0), BackgroundColor3 = ACCENT, BorderSizePixel = 0, Parent = hdr})
local statusDot = mk("Frame", {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, 12, 0, 16), BackgroundColor3 = GREEN, Parent = hdr})
rnd(statusDot, 5)
local statusLbl = mk("TextLabel", {Size = UDim2.new(0, 60, 0, 14), Position = UDim2.new(0, 28, 0, 14), BackgroundTransparency = 1, Text = "ACTIF", TextColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
mk("TextLabel", {Size = UDim2.new(0, 140, 0, 14), Position = UDim2.new(0, 92, 0, 14), BackgroundTransparency = 1, Text = "AUTO PARRY v28", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr})
local btnMin = mk("TextButton", {Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -34, 0, 8), BackgroundColor3 = BG4, Text = "-", TextColor3 = TXT2, Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false, Parent = hdr})
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

local function btn(parent, x, y, w, h, text)
    local b = mk("TextButton", {Size = UDim2.new(0, w, 0, h), Position = UDim2.new(0, x, 0, y), BackgroundColor3 = BG4, Text = text, TextColor3 = TXT2, Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false, Parent = parent})
    rnd(b, 6)
    return b
end

local function lbl(parent, y, color, font)
    return mk("TextLabel", {Size = UDim2.new(1, -14, 0, 12), Position = UDim2.new(0, 7, 0, y), BackgroundTransparency = 1, Text = "", TextColor3 = color, Font = font, TextSize = font == Enum.Font.Code and 9 or 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent})
end

-- MODE
local mc = sect(48, "Mode", 36)
local modeBtns = {
    auto = btn(mc, 7, 15, 84, 18, "Auto"),
    normal = btn(mc, 98, 15, 84, 18, "Normal"),
    train = btn(mc, 189, 15, 84, 18, "Entrainement"),
}
local function majMode()
    for m, b in pairs(modeBtns) do
        local on = cfg.mode == m
        b.BackgroundColor3 = on and (m == "train" and CYAN or ACCENT) or BG4
        b.TextColor3 = on and TXT1 or TXT2
    end
end
local function setMode(m)
    cfg.mode = m
    majMode()
    saveCfg()
end
for m, b in pairs(modeBtns) do
    b.MouseButton1Click:Connect(function() setMode(m) end)
end

-- REGLAGES
local rc = sect(90, "Reglages", 58)
local lAnt = mk("TextLabel", {Size = UDim2.new(0, 180, 0, 18), Position = UDim2.new(0, 7, 0, 15), BackgroundTransparency = 1, Text = "", TextColor3 = TXT1, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = rc})
local bMinus = btn(rc, 201, 15, 34, 18, "-")
local bPlus = btn(rc, 239, 15, 34, 18, "+")
local bSpam = btn(rc, 7, 36, 130, 18, "")
local bPing = btn(rc, 143, 36, 130, 18, "")
local function majReglages()
    lAnt.Text = string.format("Anticipation : %.2fs", cfg.anticipation)
    bSpam.Text = "Spam clash : " .. (cfg.spam and "ON" or "OFF")
    bSpam.BackgroundColor3 = cfg.spam and GREEN or BG4
    bSpam.TextColor3 = cfg.spam and TXT1 or TXT2
    bPing.Text = "Comp. ping : " .. (cfg.pingComp and "ON" or "OFF")
    bPing.BackgroundColor3 = cfg.pingComp and GREEN or BG4
    bPing.TextColor3 = cfg.pingComp and TXT1 or TXT2
end
bMinus.MouseButton1Click:Connect(function()
    cfg.anticipation = math.max(0.1, math.floor((cfg.anticipation - 0.05) * 100 + 0.5) / 100)
    majReglages()
    saveCfg()
end)
bPlus.MouseButton1Click:Connect(function()
    cfg.anticipation = math.min(1.0, math.floor((cfg.anticipation + 0.05) * 100 + 0.5) / 100)
    majReglages()
    saveCfg()
end)
bSpam.MouseButton1Click:Connect(function()
    cfg.spam = not cfg.spam
    majReglages()
    saveCfg()
end)
bPing.MouseButton1Click:Connect(function()
    cfg.pingComp = not cfg.pingComp
    majReglages()
    saveCfg()
end)

-- STATS
local sc = sect(154, "Stats", 46)
local bw = math.floor((W - 20 - 16) / 3)
local function sbox(x, title, col)
    mk("TextLabel", {Size = UDim2.new(0, bw, 0, 8), Position = UDim2.new(0, x, 0, 17), BackgroundTransparency = 1, Text = string.upper(title), TextColor3 = col, Font = Enum.Font.GothamBold, TextSize = 7, Parent = sc})
    return mk("TextLabel", {Size = UDim2.new(0, bw, 0, 16), Position = UDim2.new(0, x, 0, 26), BackgroundTransparency = 1, Text = "0", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 15, Parent = sc})
end
local lP = sbox(7, "Parrys", ACCENT)
local lS = sbox(7 + bw + 8, "Streak", ORANGE)
local lB = sbox(7 + bw * 2 + 16, "Record", YELLOW)

-- BALLE
local bc = sect(206, "Balle", 64)
local lBalle = lbl(bc, 18, ORANGE, Enum.Font.Gotham)
local lInfo = lbl(bc, 33, TXT2, Enum.Font.Code)
local lDiag = lbl(bc, 47, TXT3, Enum.Font.Code)
lBalle.Text = "Recherche..."

-- TOGGLE
local tBg = mk("Frame", {Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 276), BackgroundColor3 = GREEN, Parent = panel})
rnd(tBg, 9)
local tBtn = mk("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", TextColor3 = TXT1, Font = Enum.Font.GothamBold, TextSize = 11, Parent = tBg})
local function majToggle()
    tBg.BackgroundColor3 = cfg.actif and GREEN or RED
    tBtn.Text = cfg.actif and "ACTIF — Cliquer pour desactiver" or "INACTIF — Cliquer pour activer"
    statusLbl.Text = cfg.actif and "ACTIF" or "INACTIF"
    statusLbl.TextColor3 = cfg.actif and GREEN or RED
    statusDot.BackgroundColor3 = cfg.actif and GREEN or RED
end
tBtn.MouseButton1Click:Connect(function()
    cfg.actif = not cfg.actif
    majToggle()
end)

-- BOUTONS
local bRst = mk("TextButton", {Size = UDim2.new(0.5, -14, 0, 22), Position = UDim2.new(0, 10, 0, 310), BackgroundColor3 = BG3, Text = "Reset stats", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, AutoButtonColor = false, Parent = panel})
rnd(bRst, 6)
bRst.MouseButton1Click:Connect(function()
    compteur = 0
    streak = 0
    best = 0
end)
local bDiag = mk("TextButton", {Size = UDim2.new(0.5, -14, 0, 22), Position = UDim2.new(0.5, 4, 0, 310), BackgroundColor3 = BG3, Text = "Diagnostic", TextColor3 = TXT2, Font = Enum.Font.Gotham, TextSize = 9, AutoButtonColor = false, Parent = panel})
rnd(bDiag, 6)
bDiag.MouseButton1Click:Connect(function()
    local hrp = cachedHRP
    if not hrp then return end
    diagMsg = "Scan en cours..."
    diagUntil = tick() + 5
    task.spawn(function()
        local found = findMovingParts(hrp.Position)
        print("[AutoParry] ===== DIAGNOSTIC =====")
        print("[AutoParry] Balles suivies: " .. ballCount .. " | mode: " .. cfg.mode .. " | confirmation: " .. tostring(needsConfirm()))
        for p in pairs(balls) do
            print("[AutoParry]   suivie: " .. p:GetFullName() .. " target=" .. tostring(p:GetAttribute("target")) .. " realBall=" .. tostring(p:GetAttribute("realBall")))
        end
        for i = 1, math.min(#found, 8) do
            print("[AutoParry]   bouge: " .. found[i].part:GetFullName() .. " vit=" .. math.floor(found[i].speed))
        end
        if #found > 0 then
            learn(found[1].part)
            diagMsg = "Appris: " .. found[1].part:GetFullName()
        else
            diagMsg = "Rien ne bouge pres de toi (F9 = details)"
        end
        diagUntil = tick() + 10
    end)
end)

mk("TextLabel", {Size = UDim2.new(1, -20, 0, 12), Position = UDim2.new(0, 10, 0, 336), BackgroundTransparency = 1, Text = "RShift On/Off  |  RCtrl Masquer  |  RAlt Mode", TextColor3 = TXT3, Font = Enum.Font.Gotham, TextSize = 8, Parent = panel})

flash = mk("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = GREEN, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 100, Parent = gui})

-- DRAG
local dragStart, startPos = nil, nil
bind(hdr.InputBegan, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = i.Position
        startPos = panel.Position
    end
end)
bind(UIS.InputChanged, function(i)
    if dragStart and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
bind(UIS.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = nil end
end)

-- RACCOURCIS
local MODES = {"auto", "normal", "train"}
bind(UIS.InputBegan, function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        cfg.actif = not cfg.actif
        majToggle()
    elseif input.KeyCode == Enum.KeyCode.RightControl then
        panel.Visible = not panel.Visible
    elseif input.KeyCode == Enum.KeyCode.RightAlt then
        local idx = 1
        for i, m in ipairs(MODES) do
            if m == cfg.mode then idx = i end
        end
        setMode(MODES[idx % #MODES + 1])
    end
end)

majMode()
majReglages()
majToggle()
gui.Parent = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════
--  AFFICHAGE
-- ═══════════════════════════════════════
local WHY_TXT = { attr = "cible", train = "entrainement", rouge = "rouge" }

local function updateUI()
    lP.Text = tostring(compteur)
    lS.Text = tostring(streak)
    lB.Text = tostring(best)

    if ui.n == 0 then
        lBalle.Text = "Aucune balle detectee"
        lBalle.TextColor3 = ORANGE
        lInfo.Text = ""
    else
        local why = WHY_TXT[ui.why] or ui.why
        if ui.mine then
            lBalle.Text = "BALLE SUR TOI (" .. why .. ")"
            lBalle.TextColor3 = GREEN
        else
            lBalle.Text = "Balle sur un autre (" .. why .. ")"
            lBalle.TextColor3 = TXT2
        end
        local etaTxt = ui.eta < 99 and string.format("%.2fs", ui.eta) or "--"
        lInfo.Text = "Dist " .. math.floor(ui.dist) .. " | Vit " .. math.floor(ui.speed) .. " | ETA " .. etaTxt
    end

    local now = tick()
    if lastError and now - lastErrorAt < 5 then
        lDiag.Text = "ERR " .. string.sub(lastError, 1, 70)
        lDiag.TextColor3 = RED
    elseif diagMsg and now < diagUntil then
        lDiag.Text = diagMsg
        lDiag.TextColor3 = YELLOW
    else
        local auto = ""
        if cfg.mode == "auto" then auto = needsConfirm() and " | auto:normal" or " | auto:train" end
        local folder = ui.folder ~= "" and (" [" .. ui.folder .. "]") or ""
        lDiag.Text = "Balles " .. ui.n .. folder .. " | " .. math.floor(pingSec * 1000) .. "ms | " .. ui.src .. auto
        lDiag.TextColor3 = TXT3
    end
end

-- ═══════════════════════════════════════
--  BOUCLE
-- ═══════════════════════════════════════
bind(RunService.Heartbeat, function()
    frameN = frameN + 1
    local ok, err = pcall(step)
    if not ok then
        lastError = tostring(err)
        lastErrorAt = tick()
    end
    if frameN % 6 == 0 then pcall(updateUI) end
end)

-- Anti-AFK
pcall(function()
    local VU = game:GetService("VirtualUser")
    bind(LP.Idled, function()
        pcall(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end)
end)

env.__AutoParryCleanup = function()
    alive = false
    for i = 1, #connections do
        pcall(function() connections[i]:Disconnect() end)
    end
    for p in pairs(balls) do untrack(p) end
    pcall(function() gui:Destroy() end)
end

print("[AutoParry] v28 charge | RShift On/Off | RCtrl Masquer | RAlt Mode | Diagnostic si besoin")
