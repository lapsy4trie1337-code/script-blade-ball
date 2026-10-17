-- Blade Ball Auto Parry v5
-- Utilise mouse1click() — la methode native du jeu

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════
local Config = {
    Active = true,
    DistanceParry = 18,
    DistanceMin = 0,
    Delai = 0,
    ToucheToggle = Enum.KeyCode.RightShift,
    TouchePanel = Enum.KeyCode.RightControl,
}

-- ═══════════════════════════════════════════════
--  VARIABLES
-- ═══════════════════════════════════════════════
local balleCachee = nil
local dernierParry = 0
local compteurParry = 0
local dernierLog = "En attente..."

local function log(msg)
    dernierLog = msg
    warn("[AutoParry] " .. msg)
end

-- ═══════════════════════════════════════════════
--  TROUVER LA BALLE
--  Cherche large : tout BasePart/MeshPart rond
--  qui bouge vite et qui n'est pas un joueur
-- ═══════════════════════════════════════════════
local function estUneBalle(obj)
    if not (obj:IsA("BasePart") or obj:IsA("MeshPart")) then return false end

    -- Par nom
    local n = obj.Name:lower()
    if n == "ball" or n == "balle" or n == "projectile" or n == "orb" then
        return true
    end

    -- Par attribut cible
    if obj:GetAttribute("Target") or obj:GetAttribute("target")
        or obj:GetAttribute("realTarget") or obj:GetAttribute("CurrentTarget") then
        return true
    end

    -- Par dossier parent
    if obj.Parent then
        local pn = obj.Parent.Name:lower()
        if pn == "balls" or pn == "ball" then return true end
    end

    return false
end

-- Quand un objet apparait dans le workspace
workspace.DescendantAdded:Connect(function(obj)
    if estUneBalle(obj) then
        balleCachee = obj
        log("Balle trouvee: " .. obj:GetFullName())
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if obj == balleCachee then
        balleCachee = nil
    end
end)

-- Scan initial
for _, v in pairs(workspace:GetDescendants()) do
    if estUneBalle(v) then
        balleCachee = v
        log("Balle au demarrage: " .. v:GetFullName())
        break
    end
end

-- ═══════════════════════════════════════════════
--  DETECTION : est-ce que la balle vient vers moi ?
-- ═══════════════════════════════════════════════
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function balleVersJoueur(balle)
    local hrp = getHRP()
    if not hrp then return false, math.huge end

    local dist = (balle.Position - hrp.Position).Magnitude

    -- Tester les attributs
    local noms = {
        "Target", "target", "realTarget", "RealTarget",
        "CurrentTarget", "currentTarget", "TargetPlayer",
        "targetPlayer", "PlayerTarget"
    }

    -- Sur la balle
    for _, nom in pairs(noms) do
        local cible = balle:GetAttribute(nom)
        if cible ~= nil then
            local estMoi = false
            if typeof(cible) == "Instance" then
                estMoi = (cible == LP.Character) or (cible == LP)
            elseif typeof(cible) == "string" then
                estMoi = (cible == LP.Name) or (cible == tostring(LP.UserId))
            elseif typeof(cible) == "number" then
                estMoi = (cible == LP.UserId)
            end
            return estMoi, dist
        end
    end

    -- Sur le parent de la balle
    if balle.Parent and balle.Parent ~= workspace then
        for _, nom in pairs(noms) do
            local cible = balle.Parent:GetAttribute(nom)
            if cible ~= nil then
                local estMoi = false
                if typeof(cible) == "Instance" then
                    estMoi = (cible == LP.Character) or (cible == LP)
                elseif typeof(cible) == "string" then
                    estMoi = (cible == LP.Name)
                elseif typeof(cible) == "number" then
                    estMoi = (cible == LP.UserId)
                end
                return estMoi, dist
            end
        end
    end

    -- ObjectValue enfant
    for _, child in pairs(balle:GetChildren()) do
        if child:IsA("ObjectValue") and child.Value then
            return (child.Value == LP.Character or child.Value == LP), dist
        end
    end

    -- Dernier recours : direction velocite
    local ok, vel = pcall(function() return balle.AssemblyLinearVelocity end)
    if not ok then ok, vel = pcall(function() return balle.Velocity end) end
    if ok and vel and vel.Magnitude > 10 then
        local vers = (hrp.Position - balle.Position).Unit
        if vel.Unit:Dot(vers) > 0.6 then
            return true, dist
        end
    end

    return false, dist
end

-- ═══════════════════════════════════════════════
--  PARRY : mouse1click() uniquement
-- ═══════════════════════════════════════════════
local function faireParry()
    local maintenant = tick()
    if maintenant - dernierParry < 0.25 then return end
    dernierParry = maintenant
    compteurParry += 1

    pcall(mouse1click)

    log("PARRY #" .. compteurParry)
end

-- ═══════════════════════════════════════════════
--  SCANNER (bouton dans le panel)
-- ═══════════════════════════════════════════════
local function scannerJeu()
    warn("========== SCAN BLADE BALL ==========")

    warn("--- Workspace enfants directs ---")
    for _, v in pairs(workspace:GetChildren()) do
        warn("  [" .. v.ClassName .. "] " .. v.Name)
    end

    warn("--- Recherche balle (tout BasePart) ---")
    local trouves = 0
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not Players:GetPlayerFromCharacter(v.Parent) then
            local n = v.Name:lower()
            if n:find("ball") or n:find("orb") or n:find("proj") then
                warn("  BALLE: " .. v:GetFullName())
                local attrs = v:GetAttributes()
                for k, val in pairs(attrs) do
                    warn("    attr: " .. k .. " = " .. tostring(val))
                end
                for _, child in pairs(v:GetChildren()) do
                    warn("    enfant: [" .. child.ClassName .. "] " .. child.Name)
                end
                trouves += 1
            end
        end
    end
    if trouves == 0 then
        warn("  AUCUNE balle trouvee par nom !")
        warn("  Listing de TOUT ce qui bouge vite :")
        for _, v in pairs(workspace:GetDescendants()) do
            if (v:IsA("BasePart") or v:IsA("MeshPart")) then
                local ok, vel = pcall(function() return v.AssemblyLinearVelocity end)
                if ok and vel and vel.Magnitude > 50 then
                    warn("    RAPIDE: " .. v:GetFullName() .. " (vitesse=" .. math.floor(vel.Magnitude) .. ")")
                end
            end
        end
    end

    warn("--- Dossiers cles ---")
    local endroits = {workspace, game:GetService("ReplicatedStorage")}
    local nomsAChercher = {"Balls", "Ball", "Alive", "Game", "Combat", "Remotes", "Events", "Shared", "Misc", "Assets"}
    for _, parent in pairs(endroits) do
        for _, nom in pairs(nomsAChercher) do
            local obj = parent:FindFirstChild(nom)
            if obj then
                warn("  " .. obj:GetFullName() .. " (" .. obj.ClassName .. ")")
                for _, child in pairs(obj:GetChildren()) do
                    warn("    [" .. child.ClassName .. "] " .. child.Name)
                end
            end
        end
    end

    warn("========== FIN SCAN ==========")
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

-- Panel
local panel = creer("Frame", {
    Size = UDim2.new(0, 280, 0, 430),
    Position = UDim2.new(0, 16, 0.5, -215),
    BackgroundColor3 = Color3.fromRGB(15, 15, 20),
    BackgroundTransparency = 0.03,
    Parent = gui,
})
coins(panel, 12)
creer("UIStroke", {Color = Color3.fromRGB(55, 55, 70), Thickness = 1.5, Parent = panel})

-- Barre titre
local barre = creer("Frame", {
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = Color3.fromRGB(22, 22, 30),
    Parent = panel,
})
coins(barre, 12)

creer("TextLabel", {
    Size = UDim2.new(1, -16, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "AUTO PARRY v5",
    TextColor3 = Color3.fromRGB(90, 130, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = barre,
})

-- Statut
local lblStatut = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 20),
    Position = UDim2.new(0, 14, 0, 48),
    BackgroundTransparency = 1,
    Text = "ACTIF",
    TextColor3 = Color3.fromRGB(0, 210, 80),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = panel,
})

-- Stats
local lblStats = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 40),
    Position = UDim2.new(0, 14, 0, 68),
    BackgroundTransparency = 1,
    Text = "Parrys: 0\nBalle: --  |  Methode: mouse1click",
    TextColor3 = Color3.fromRGB(120, 120, 140),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = panel,
})

-- Log
local lblLog = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 16),
    Position = UDim2.new(0, 14, 0, 108),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Color3.fromRGB(255, 200, 50),
    Font = Enum.Font.Code,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = panel,
})

creer("Frame", {
    Size = UDim2.new(1, -28, 0, 1),
    Position = UDim2.new(0, 14, 0, 130),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55),
    BorderSizePixel = 0,
    Parent = panel,
})

-- ═══════════════════════════════════════════════
--  SLIDER
-- ═══════════════════════════════════════════════
local function creerSlider(parent, texte, min, max, defaut, yPos, callback)
    creer("TextLabel", {
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1,
        Text = texte,
        TextColor3 = Color3.fromRGB(170, 170, 190),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })

    local lblVal = creer("TextLabel", {
        Size = UDim2.new(0, 40, 0, 16),
        Position = UDim2.new(1, -54, 0, yPos),
        BackgroundTransparency = 1,
        Text = tostring(defaut),
        TextColor3 = Color3.fromRGB(210, 210, 220),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = parent,
    })

    local piste = creer("Frame", {
        Size = UDim2.new(1, -28, 0, 8),
        Position = UDim2.new(0, 14, 0, yPos + 20),
        BackgroundColor3 = Color3.fromRGB(35, 35, 48),
        Parent = parent,
    })
    coins(piste, 4)

    local remplissage = creer("Frame", {
        Size = UDim2.new((defaut - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(90, 130, 255),
        Parent = piste,
    })
    coins(remplissage, 4)

    local curseur = creer("TextButton", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new((defaut - min) / (max - min), -9, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(230, 230, 240),
        Text = "",
        Parent = piste,
    })
    coins(curseur, 9)

    local enDrag = false
    local function maj(posX)
        local rel = math.clamp((posX - piste.AbsolutePosition.X) / piste.AbsoluteSize.X, 0, 1)
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

-- ═══════════════════════════════════════════════
--  TOGGLE
-- ═══════════════════════════════════════════════
local function creerToggle(parent, texte, defaut, yPos, callback)
    creer("TextLabel", {
        Size = UDim2.new(1, -64, 0, 22),
        Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1,
        Text = texte,
        TextColor3 = Color3.fromRGB(170, 170, 190),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })
    local fond = creer("Frame", {
        Size = UDim2.new(0, 38, 0, 20),
        Position = UDim2.new(1, -52, 0, yPos + 1),
        BackgroundColor3 = defaut and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(45, 45, 58),
        Parent = parent,
    })
    coins(fond, 10)
    local point = creer("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = defaut and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Color3.fromRGB(235, 235, 245),
        Parent = fond,
    })
    coins(point, 8)
    local etat = defaut
    creer("TextButton", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = fond})
    .MouseButton1Click:Connect(function()
        etat = not etat
        TweenService:Create(fond, TweenInfo.new(0.15), {BackgroundColor3 = etat and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(45, 45, 58)}):Play()
        TweenService:Create(point, TweenInfo.new(0.15), {Position = etat and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)}):Play()
        callback(etat)
    end)
    return function(v)
        etat = v
        fond.BackgroundColor3 = etat and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(45, 45, 58)
        point.Position = etat and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    end
end

-- ═══════════════════════════════════════════════
--  BOUTON
-- ═══════════════════════════════════════════════
local function creerBouton(parent, texte, couleur, yPos, callback)
    local b = creer("TextButton", {
        Size = UDim2.new(1, -28, 0, 28),
        Position = UDim2.new(0, 14, 0, yPos),
        BackgroundColor3 = couleur,
        Text = texte,
        TextColor3 = Color3.fromRGB(230, 230, 240),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Parent = parent,
    })
    coins(b, 6)
    b.MouseButton1Click:Connect(callback)
end

-- ═══════════════════════════════════════════════
--  CREER LES CONTROLES
-- ═══════════════════════════════════════════════
creerSlider(panel, "Distance Parry", 0, 100, Config.DistanceParry, 140, function(v) Config.DistanceParry = v end)
creerSlider(panel, "Distance Minimum", 0, 50, Config.DistanceMin, 178, function(v) Config.DistanceMin = v end)
creerSlider(panel, "Delai (ms)", 0, 500, Config.Delai, 216, function(v) Config.Delai = v end)

local majToggle = creerToggle(panel, "Auto Parry", Config.Active, 256, function(v)
    Config.Active = v
    lblStatut.Text = v and "ACTIF" or "DESACTIVE"
    lblStatut.TextColor3 = v and Color3.fromRGB(0, 210, 80) or Color3.fromRGB(210, 50, 50)
end)

creer("Frame", {
    Size = UDim2.new(1, -28, 0, 1),
    Position = UDim2.new(0, 14, 0, 290),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55),
    BorderSizePixel = 0,
    Parent = panel,
})

creerBouton(panel, "Scanner le Jeu (console F9)", Color3.fromRGB(50, 40, 20), 300, scannerJeu)
creerBouton(panel, "Re-chercher la Balle", Color3.fromRGB(30, 30, 50), 336, function()
    balleCachee = nil
    for _, v in pairs(workspace:GetDescendants()) do
        if estUneBalle(v) then
            balleCachee = v
            log("Balle: " .. v:GetFullName())
            return
        end
    end
    log("Aucune balle !")
end)

creer("TextLabel", {
    Size = UDim2.new(1, -28, 0, 45),
    Position = UDim2.new(0, 14, 0, 375),
    BackgroundTransparency = 1,
    Text = "RShift = Activer/Desactiver\nRCtrl  = Cacher/Montrer",
    TextColor3 = Color3.fromRGB(90, 90, 110),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    LineHeight = 1.6,
    Parent = panel,
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
        lblStatut.Text = Config.Active and "ACTIF" or "DESACTIVE"
        lblStatut.TextColor3 = Config.Active and Color3.fromRGB(0, 210, 80) or Color3.fromRGB(210, 50, 50)
    elseif input.KeyCode == Config.TouchePanel then
        panel.Visible = not panel.Visible
    end
end)

gui.Parent = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════
--  BOUCLE PRINCIPALE
-- ═══════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    local balleOK = balleCachee and balleCachee.Parent and true or false

    lblStats.Text = "Parrys: " .. compteurParry
        .. "\nBalle: " .. (balleOK and "OUI" or "NON") .. "  |  Methode: mouse1click"
    lblLog.Text = dernierLog

    if not Config.Active then return end
    if not balleOK then return end

    local versMoi, dist = balleVersJoueur(balleCachee)
    if not versMoi then return end

    if dist <= Config.DistanceParry and dist >= Config.DistanceMin then
        if Config.Delai > 0 then
            task.delay(Config.Delai / 1000, faireParry)
        else
            faireParry()
        end
    end
end)

-- Scanner au demarrage
task.spawn(function()
    task.wait(3)
    scannerJeu()
end)

log("v5 charge - mouse1click uniquement")
