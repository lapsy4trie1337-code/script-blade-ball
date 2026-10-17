-- Blade Ball Auto Parry v7 — Ultra Reactif
-- Parry predictif base sur la vitesse de la balle

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════════
--  CONFIG RECOMMANDEE
-- ═══════════════════════════════════════════════
local Config = {
    Active = true,
    -- DISTANCE : le script calcule automatiquement
    -- le moment parfait selon la vitesse de la balle.
    -- Ces valeurs sont des limites de securite.
    DistanceMax = 25,       -- commence a surveiller
    DistanceMin = 0,        -- 0 = pas de minimum
    Delai = 0,              -- 0 = instantane (recommande)

    -- MODE DE PARRY
    -- 1 = Instantane (parry des que possible, tres reactif)
    -- 2 = Predictif (calcule le timing parfait selon la vitesse)
    -- 3 = Proche (attend que la balle soit tres proche)
    Mode = 2,

    -- FEATURES
    IndicateurVisuel = true, -- flash rouge quand cible
    AfficherVitesse = true,  -- vitesse de la balle dans le panel
    MultiClic = true,        -- envoie plusieurs clics pour etre sur
    NbClics = 3,             -- nombre de clics rapides

    ToucheToggle = Enum.KeyCode.RightShift,
    TouchePanel = Enum.KeyCode.RightControl,
}

-- ═══════════════════════════════════════════════
--  VARIABLES
-- ═══════════════════════════════════════════════
local balleCachee = nil
local remoteParry = nil
local dernierParry = 0
local compteurParry = 0
local dernierLog = "Demarrage..."
local vitesseBalle = 0
local distanceBalle = 0
local estCible = false

local function log(msg) dernierLog = msg end

-- ═══════════════════════════════════════════════
--  TROUVER LA BALLE
-- ═══════════════════════════════════════════════
local function estUnJoueur(obj)
    local p = obj.Parent
    while p and p ~= workspace do
        if Players:GetPlayerFromCharacter(p) then return true end
        p = p.Parent
    end
    return false
end

local function trouverBalle()
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) then
            local n = v.Name:lower()
            if (n == "ball" or n == "balle" or n:find("projectile") or n:find("orb")) and not estUnJoueur(v) then
                return v
            end
        end
    end
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not estUnJoueur(v) then
            if v:GetAttribute("Target") or v:GetAttribute("target") or v:GetAttribute("realTarget") then
                return v
            end
        end
    end
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not estUnJoueur(v) and not v.Anchored then
            if v.Name ~= "Baseplate" and v.Name ~= "Terrain" then
                local ok, vel = pcall(function() return v.AssemblyLinearVelocity end)
                if ok and vel and vel.Magnitude > 30 and v.Size.Magnitude < 15 then
                    return v
                end
            end
        end
    end
    return nil
end

workspace.DescendantAdded:Connect(function(obj)
    if balleCachee and balleCachee.Parent then return end
    if not (obj:IsA("BasePart") or obj:IsA("MeshPart")) then return end
    if estUnJoueur(obj) then return end
    local n = obj.Name:lower()
    if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb") then
        balleCachee = obj
        log("Balle: " .. obj:GetFullName())
        return
    end
    if obj:GetAttribute("Target") or obj:GetAttribute("target") or obj:GetAttribute("realTarget") then
        balleCachee = obj
        log("Balle (attr): " .. obj:GetFullName())
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if obj == balleCachee then balleCachee = nil end
end)

balleCachee = trouverBalle()
if balleCachee then log("Balle: " .. balleCachee:GetFullName()) end

task.spawn(function()
    while true do
        task.wait(0.5)
        if not balleCachee or not balleCachee.Parent then
            balleCachee = trouverBalle()
            if balleCachee then log("Balle re-trouvee: " .. balleCachee:GetFullName()) end
        end
    end
end)

-- ═══════════════════════════════════════════════
--  TROUVER LE REMOTE
-- ═══════════════════════════════════════════════
pcall(function()
    for _, v in pairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == "ParrySlashAll" then
            remoteParry = v
        end
    end
end)

-- ═══════════════════════════════════════════════
--  DETECTION CIBLE
-- ═══════════════════════════════════════════════
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function balleVersJoueur(balle)
    local hrp = getHRP()
    if not hrp then return false, math.huge, 0 end

    local pos = balle.Position
    local dist = (pos - hrp.Position).Magnitude

    local ok, vel = pcall(function() return balle.AssemblyLinearVelocity end)
    if not ok then ok, vel = pcall(function() return balle.Velocity end) end
    local speed = (ok and vel) and vel.Magnitude or 0

    -- Par attributs
    local cibles = {balle}
    if balle.Parent and balle.Parent ~= workspace then table.insert(cibles, balle.Parent) end

    local noms = {"Target", "target", "realTarget", "RealTarget", "CurrentTarget", "currentTarget", "TargetPlayer", "targetPlayer", "PlayerTarget"}

    for _, obj in pairs(cibles) do
        for _, nom in pairs(noms) do
            local c = obj:GetAttribute(nom)
            if c ~= nil then
                local m = false
                if typeof(c) == "Instance" then m = (c == LP.Character or c == LP)
                elseif typeof(c) == "string" then m = (c == LP.Name or c == tostring(LP.UserId))
                elseif typeof(c) == "number" then m = (c == LP.UserId) end
                return m, dist, speed
            end
        end
    end

    for _, child in pairs(balle:GetChildren()) do
        if child:IsA("ObjectValue") and child.Value then
            return (child.Value == LP.Character or child.Value == LP), dist, speed
        end
    end

    -- Velocite
    if ok and vel and speed > 10 then
        local vers = (hrp.Position - pos).Unit
        if vel.Unit:Dot(vers) > 0.5 then
            return true, dist, speed
        end
    end

    return false, dist, speed
end

-- ═══════════════════════════════════════════════
--  PARRY ULTRA RAPIDE
-- ═══════════════════════════════════════════════
local function faireParry()
    local now = tick()
    if now - dernierParry < 0.1 then return end
    dernierParry = now
    compteurParry += 1

    -- Multi-clic pour etre sur
    if Config.MultiClic then
        for i = 1, Config.NbClics do
            pcall(mouse1click)
        end
    else
        pcall(mouse1click)
    end

    if remoteParry then
        pcall(function() remoteParry:FireServer() end)
    end

    log("PARRY #" .. compteurParry .. " (v=" .. math.floor(vitesseBalle) .. ")")
end

-- ═══════════════════════════════════════════════
--  CALCUL DU TIMING PARFAIT
-- ═══════════════════════════════════════════════
local function doitParry(dist, speed)
    if Config.Mode == 1 then
        -- INSTANTANE : parry des que dans la zone
        return dist <= Config.DistanceMax and dist >= Config.DistanceMin
    elseif Config.Mode == 2 then
        -- PREDICTIF : calcule le temps d'arrivee
        -- et parry au moment optimal
        if dist > Config.DistanceMax or dist < Config.DistanceMin then return false end
        if speed < 10 then return dist <= 15 end

        -- Temps avant impact (en frames a 60fps)
        local tempsImpact = dist / speed
        -- Parry quand la balle arrive dans ~0.15-0.3 secondes
        -- Plus la balle est rapide, plus on parry tot
        local seuil = math.clamp(0.05 + (speed / 1000), 0.05, 0.4)
        return tempsImpact <= seuil
    elseif Config.Mode == 3 then
        -- PROCHE : attend que la balle soit tres proche
        return dist <= math.min(Config.DistanceMax, 10) and dist >= Config.DistanceMin
    end
    return false
end

-- ═══════════════════════════════════════════════
--  GUI
-- ═══════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "AP" .. math.random(10000, 99999)
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function creer(c, p)
    local o = Instance.new(c)
    for k, v in pairs(p) do if k ~= "Parent" then o[k] = v end end
    if p.Parent then o.Parent = p.Parent end
    return o
end
local function coins(p, r) creer("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = p}) end

-- Indicateur visuel (flash rouge quand cible)
local flashFrame = creer("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(255, 0, 0),
    BackgroundTransparency = 1,
    ZIndex = 0,
    Parent = gui,
})

-- Panel
local panel = creer("Frame", {
    Size = UDim2.new(0, 290, 0, 500),
    Position = UDim2.new(0, 16, 0.5, -250),
    BackgroundColor3 = Color3.fromRGB(12, 12, 18),
    BackgroundTransparency = 0.02,
    Parent = gui,
})
coins(panel, 12)
creer("UIStroke", {Color = Color3.fromRGB(50, 50, 70), Thickness = 1.5, Parent = panel})

-- Scroll
local scroll = creer("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -42),
    Position = UDim2.new(0, 0, 0, 42),
    BackgroundTransparency = 1,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Color3.fromRGB(90, 130, 255),
    CanvasSize = UDim2.new(0, 0, 0, 600),
    Parent = panel,
})

-- Barre titre
local barre = creer("Frame", {
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = Color3.fromRGB(18, 18, 28),
    Parent = panel,
})
coins(barre, 12)

creer("TextLabel", {
    Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1, Text = "AUTO PARRY v7",
    TextColor3 = Color3.fromRGB(90, 130, 255), Font = Enum.Font.GothamBold,
    TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = barre,
})

-- Statut
local lblStatut = creer("TextLabel", {
    Size = UDim2.new(0, 80, 0, 22), Position = UDim2.new(0, 14, 0, 6),
    BackgroundColor3 = Color3.fromRGB(0, 180, 60), BackgroundTransparency = 0.8,
    Text = " ACTIF", TextColor3 = Color3.fromRGB(0, 230, 80),
    Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Parent = scroll,
})
coins(lblStatut, 6)

-- Stats en temps reel
local lblStats = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 60), Position = UDim2.new(0, 14, 0, 34),
    BackgroundTransparency = 1, Text = "...",
    TextColor3 = Color3.fromRGB(140, 140, 160), Font = Enum.Font.Gotham,
    TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = scroll,
})

local lblLog = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 14), Position = UDim2.new(0, 14, 0, 96),
    BackgroundTransparency = 1, Text = "",
    TextColor3 = Color3.fromRGB(255, 200, 50), Font = Enum.Font.Code,
    TextSize = 10, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = scroll,
})

creer("Frame", {
    Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0, 116),
    BackgroundColor3 = Color3.fromRGB(35, 35, 50), BorderSizePixel = 0, Parent = scroll,
})

-- ═══════════════════════════════════════════════
--  COMPOSANTS GUI
-- ═══════════════════════════════════════════════
local function creerSlider(parent, texte, min, max, defaut, yPos, callback)
    creer("TextLabel", {
        Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1, Text = texte, TextColor3 = Color3.fromRGB(170, 170, 190),
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    local lblVal = creer("TextLabel", {
        Size = UDim2.new(0, 40, 0, 16), Position = UDim2.new(1, -54, 0, yPos),
        BackgroundTransparency = 1, Text = tostring(defaut), TextColor3 = Color3.fromRGB(210, 210, 220),
        Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = parent,
    })
    local piste = creer("Frame", {
        Size = UDim2.new(1, -28, 0, 8), Position = UDim2.new(0, 14, 0, yPos + 20),
        BackgroundColor3 = Color3.fromRGB(30, 30, 45), Parent = parent,
    })
    coins(piste, 4)
    local remplissage = creer("Frame", {
        Size = UDim2.new((defaut - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(90, 130, 255), Parent = piste,
    })
    coins(remplissage, 4)
    local curseur = creer("TextButton", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new((defaut - min) / (max - min), -9, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(230, 230, 240), Text = "", Parent = piste,
    })
    coins(curseur, 9)
    local enDrag = false
    local function maj(px)
        local rel = math.clamp((px - piste.AbsolutePosition.X) / piste.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + rel * (max - min) + 0.5)
        remplissage.Size = UDim2.new(rel, 0, 1, 0)
        curseur.Position = UDim2.new(rel, -9, 0.5, -9)
        lblVal.Text = tostring(val)
        callback(val)
    end
    curseur.MouseButton1Down:Connect(function() enDrag = true end)
    piste.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then enDrag = true; maj(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then enDrag = false end end)
    UIS.InputChanged:Connect(function(i) if enDrag and i.UserInputType == Enum.UserInputType.MouseMovement then maj(i.Position.X) end end)
end

local function creerToggle(parent, texte, defaut, yPos, callback)
    creer("TextLabel", {
        Size = UDim2.new(1, -64, 0, 22), Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1, Text = texte, TextColor3 = Color3.fromRGB(170, 170, 190),
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    local fond = creer("Frame", {
        Size = UDim2.new(0, 38, 0, 20), Position = UDim2.new(1, -52, 0, yPos + 1),
        BackgroundColor3 = defaut and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(40, 40, 55), Parent = parent,
    })
    coins(fond, 10)
    local point = creer("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = defaut and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Color3.fromRGB(235, 235, 245), Parent = fond,
    })
    coins(point, 8)
    local etat = defaut
    creer("TextButton", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = fond})
    .MouseButton1Click:Connect(function()
        etat = not etat
        TweenService:Create(fond, TweenInfo.new(0.12), {BackgroundColor3 = etat and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(40, 40, 55)}):Play()
        TweenService:Create(point, TweenInfo.new(0.12), {Position = etat and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)}):Play()
        callback(etat)
    end)
    return function(v)
        etat = v
        fond.BackgroundColor3 = etat and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(40, 40, 55)
        point.Position = etat and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    end
end

-- Section titre
local function creerSection(parent, texte, yPos)
    creer("TextLabel", {
        Size = UDim2.new(1, -28, 0, 16), Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1, Text = texte:upper(),
        TextColor3 = Color3.fromRGB(90, 130, 255), Font = Enum.Font.GothamBold,
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    creer("Frame", {
        Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0, yPos + 16),
        BackgroundColor3 = Color3.fromRGB(35, 35, 50), BorderSizePixel = 0, Parent = parent,
    })
end

-- Bouton mode
local function creerBoutonMode(parent, yPos)
    local modeNoms = {"INSTANTANE", "PREDICTIF", "PROCHE"}
    local modeDesc = {
        "Parry des que la balle entre dans la zone",
        "Timing optimal selon la vitesse (recommande)",
        "Attend que la balle soit tres proche",
    }
    local modeCouleurs = {
        Color3.fromRGB(255, 80, 80),
        Color3.fromRGB(90, 130, 255),
        Color3.fromRGB(255, 180, 50),
    }

    creer("TextLabel", {
        Size = UDim2.new(1, -64, 0, 16), Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1, Text = "Mode de Parry",
        TextColor3 = Color3.fromRGB(170, 170, 190), Font = Enum.Font.Gotham,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })

    local lblMode = creer("TextButton", {
        Size = UDim2.new(1, -28, 0, 26), Position = UDim2.new(0, 14, 0, yPos + 20),
        BackgroundColor3 = modeCouleurs[Config.Mode],
        Text = modeNoms[Config.Mode], TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold, TextSize = 12, Parent = parent,
    })
    coins(lblMode, 6)

    local lblDesc = creer("TextLabel", {
        Size = UDim2.new(1, -28, 0, 14), Position = UDim2.new(0, 14, 0, yPos + 48),
        BackgroundTransparency = 1, Text = modeDesc[Config.Mode],
        TextColor3 = Color3.fromRGB(100, 100, 120), Font = Enum.Font.Gotham,
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })

    lblMode.MouseButton1Click:Connect(function()
        Config.Mode = (Config.Mode % 3) + 1
        lblMode.Text = modeNoms[Config.Mode]
        lblMode.BackgroundColor3 = modeCouleurs[Config.Mode]
        lblDesc.Text = modeDesc[Config.Mode]
    end)
end

-- ═══════════════════════════════════════════════
--  CREER LES CONTROLES
-- ═══════════════════════════════════════════════
creerSection(scroll, "Mode", 126)
creerBoutonMode(scroll, 148)

creerSection(scroll, "Distances", 218)
creerSlider(scroll, "Distance Max", 0, 100, Config.DistanceMax, 240, function(v) Config.DistanceMax = v end)
creerSlider(scroll, "Distance Min", 0, 50, Config.DistanceMin, 278, function(v) Config.DistanceMin = v end)
creerSlider(scroll, "Delai (ms)", 0, 500, Config.Delai, 316, function(v) Config.Delai = v end)

creerSection(scroll, "Options", 356)
local majToggle = creerToggle(scroll, "Auto Parry", Config.Active, 378, function(v)
    Config.Active = v
    lblStatut.Text = v and " ACTIF" or " DESACTIVE"
    lblStatut.TextColor3 = v and Color3.fromRGB(0, 230, 80) or Color3.fromRGB(230, 50, 50)
    lblStatut.BackgroundColor3 = v and Color3.fromRGB(0, 180, 60) or Color3.fromRGB(180, 40, 40)
end)

creerToggle(scroll, "Multi-Clic", Config.MultiClic, 408, function(v) Config.MultiClic = v end)
creerToggle(scroll, "Flash Visuel", Config.IndicateurVisuel, 438, function(v) Config.IndicateurVisuel = v end)

creerSlider(scroll, "Nombre de Clics", 1, 10, Config.NbClics, 468, function(v) Config.NbClics = v end)

-- Bouton recherche
creer("Frame", {
    Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0, 510),
    BackgroundColor3 = Color3.fromRGB(35, 35, 50), BorderSizePixel = 0, Parent = scroll,
})

local btn = creer("TextButton", {
    Size = UDim2.new(1, -28, 0, 28), Position = UDim2.new(0, 14, 0, 520),
    BackgroundColor3 = Color3.fromRGB(30, 30, 50), Text = "Forcer recherche balle",
    TextColor3 = Color3.fromRGB(200, 200, 220), Font = Enum.Font.GothamBold, TextSize = 12, Parent = scroll,
})
coins(btn, 6)
btn.MouseButton1Click:Connect(function()
    balleCachee = trouverBalle()
    log(balleCachee and "Balle: " .. balleCachee:GetFullName() or "Aucune balle !")
end)

creer("TextLabel", {
    Size = UDim2.new(1, -28, 0, 40), Position = UDim2.new(0, 14, 0, 556),
    BackgroundTransparency = 1,
    Text = "RShift = ON/OFF  |  RCtrl = Panel",
    TextColor3 = Color3.fromRGB(80, 80, 100), Font = Enum.Font.Gotham,
    TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = scroll,
})

-- ═══════════════════════════════════════════════
--  DRAG
-- ═══════════════════════════════════════════════
local dd, sp
barre.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = i.Position; sp = panel.Position end end)
barre.InputChanged:Connect(function(i) if dd and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - dd; panel.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = nil end end)

-- ═══════════════════════════════════════════════
--  RACCOURCIS
-- ═══════════════════════════════════════════════
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.ToucheToggle then
        Config.Active = not Config.Active
        majToggle(Config.Active)
        lblStatut.Text = Config.Active and " ACTIF" or " DESACTIVE"
        lblStatut.TextColor3 = Config.Active and Color3.fromRGB(0, 230, 80) or Color3.fromRGB(230, 50, 50)
        lblStatut.BackgroundColor3 = Config.Active and Color3.fromRGB(0, 180, 60) or Color3.fromRGB(180, 40, 40)
    elseif input.KeyCode == Config.TouchePanel then
        panel.Visible = not panel.Visible
    end
end)

gui.Parent = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════
--  BOUCLE PRINCIPALE — RenderStepped (plus rapide que Heartbeat)
-- ═══════════════════════════════════════════════
local modeNoms = {"INSTANT", "PREDICT", "PROCHE"}

RunService.RenderStepped:Connect(function()
    local balleOK = balleCachee and balleCachee.Parent and true or false

    if balleOK then
        estCible, distanceBalle, vitesseBalle = balleVersJoueur(balleCachee)
    else
        estCible, distanceBalle, vitesseBalle = false, 0, 0
    end

    -- Flash visuel
    if Config.IndicateurVisuel then
        if estCible and distanceBalle < Config.DistanceMax then
            local intensite = math.clamp(1 - (distanceBalle / Config.DistanceMax), 0, 0.3)
            flashFrame.BackgroundTransparency = 1 - intensite
        else
            flashFrame.BackgroundTransparency = 1
        end
    else
        flashFrame.BackgroundTransparency = 1
    end

    -- Stats
    lblStats.Text = "Parrys: " .. compteurParry
        .. "  |  Mode: " .. modeNoms[Config.Mode]
        .. "\nBalle: " .. (balleOK and "OUI" or "NON")
        .. "  |  Vitesse: " .. math.floor(vitesseBalle)
        .. "\nDistance: " .. math.floor(distanceBalle)
        .. "  |  Cible: " .. (estCible and "OUI" or "non")
    lblLog.Text = dernierLog

    -- Parry
    if not Config.Active then return end
    if not balleOK then return end
    if not estCible then return end

    if doitParry(distanceBalle, vitesseBalle) then
        if Config.Delai > 0 then
            task.delay(Config.Delai / 1000, faireParry)
        else
            faireParry()
        end
    end
end)

log("v7 charge - Mode: " .. modeNoms[Config.Mode])
