-- Blade Ball Auto Parry v3

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════════
--  CONFIGURATION
-- ═══════════════════════════════════════════════
local Config = {
    Active = true,
    DistanceParry = 15,
    DistanceMin = 0,
    Delai = 0,
    ModeDebug = false,
    ToucheToggle = Enum.KeyCode.RightShift,
    TouchePanel = Enum.KeyCode.RightControl,
}

-- ═══════════════════════════════════════════════
--  VARIABLES
-- ═══════════════════════════════════════════════
local balleCachee = nil
local remotesParry = {}
local dernierParry = 0
local compteurParry = 0
local debugInfo = ""

-- ═══════════════════════════════════════════════
--  TROUVER TOUS LES REMOTES POSSIBLES
-- ═══════════════════════════════════════════════
local function chercherRemotes()
    remotesParry = {}

    local function scanner(parent)
        for _, v in pairs(parent:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                local n = v.Name:lower()
                if n:find("parry") or n:find("block") or n:find("deflect")
                    or n:find("ability") or n:find("hit") or n:find("slash")
                    or n:find("swing") or n:find("click") or n:find("action")
                    or n:find("combat") or n:find("attack") then
                    table.insert(remotesParry, v)
                end
            end
        end
    end

    scanner(RS)

    pcall(function()
        local modules = LP:FindFirstChild("PlayerScripts")
        if modules then scanner(modules) end
    end)

    pcall(function()
        local sg = LP:FindFirstChild("PlayerGui")
        if sg then scanner(sg) end
    end)

    if Config.ModeDebug then
        debugInfo = "Remotes: " .. #remotesParry
        for i, r in pairs(remotesParry) do
            if i <= 5 then
                debugInfo = debugInfo .. "\n  " .. r:GetFullName()
            end
        end
    end
end

-- ═══════════════════════════════════════════════
--  DETECTION DE LA BALLE
-- ═══════════════════════════════════════════════
local function estUneBalle(obj)
    if not obj:IsA("BasePart") then return false end
    local n = obj.Name:lower()
    if n == "ball" or n == "balle" then return true end
    if obj:GetAttribute("Target") or obj:GetAttribute("target")
        or obj:GetAttribute("CurrentTarget") then
        return true
    end
    local parent = obj.Parent
    if parent then
        local pn = parent.Name:lower()
        if pn == "balls" or pn == "ball" or pn == "balles" then
            return true
        end
    end
    return false
end

local function surAjout(obj)
    if estUneBalle(obj) then
        balleCachee = obj
        if Config.ModeDebug then
            debugInfo = "Balle trouvee: " .. obj:GetFullName()
        end
    end
end

local function surRetrait(obj)
    if obj == balleCachee then
        balleCachee = nil
    end
end

workspace.DescendantAdded:Connect(surAjout)
workspace.DescendantRemoving:Connect(surRetrait)

-- Scan initial
for _, v in pairs(workspace:GetDescendants()) do
    if estUneBalle(v) then
        balleCachee = v
        break
    end
end

-- Aussi surveiller les enfants directs du workspace
for _, dossier in pairs(workspace:GetChildren()) do
    if dossier:IsA("Folder") or dossier:IsA("Model") then
        dossier.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") or child:IsA("Model") then
                task.wait(0.1)
                for _, d in pairs(child:GetDescendants()) do
                    surAjout(d)
                end
                surAjout(child)
            end
        end)
    end
end

chercherRemotes()

-- Re-scanner les remotes si rien trouve
task.spawn(function()
    task.wait(3)
    if #remotesParry == 0 then
        chercherRemotes()
    end
end)

-- ═══════════════════════════════════════════════
--  VERIFICATION CIBLE
-- ═══════════════════════════════════════════════
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function balleVersJoueur(balle)
    local hrp = getHRP()
    if not hrp then return false, math.huge end

    local dist = (balle.Position - hrp.Position).Magnitude

    -- Methode 1 : attribut sur la balle
    local cible = balle:GetAttribute("Target")
        or balle:GetAttribute("target")
        or balle:GetAttribute("CurrentTarget")
        or balle:GetAttribute("TargetPlayer")

    if cible then
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

    -- Methode 2 : ObjectValue enfant
    for _, child in pairs(balle:GetChildren()) do
        if child:IsA("ObjectValue") and child.Value then
            local n = child.Name:lower()
            if n:find("target") or n:find("cible") or n:find("player") then
                if child.Value == LP.Character or child.Value == LP then
                    return true, dist
                end
                local model = child.Value
                if model:IsA("Model") and model == LP.Character then
                    return true, dist
                end
                return false, dist
            end
        end
    end

    -- Methode 3 : attribut sur le parent/modele
    local parent = balle.Parent
    if parent and parent ~= workspace then
        local cibleP = parent:GetAttribute("Target") or parent:GetAttribute("target")
        if cibleP then
            if typeof(cibleP) == "string" and cibleP == LP.Name then
                return true, dist
            end
            if typeof(cibleP) == "Instance" and (cibleP == LP or cibleP == LP.Character) then
                return true, dist
            end
        end
    end

    -- Methode 4 : direction de la velocite
    local ok, vel = pcall(function() return balle.AssemblyLinearVelocity end)
    if not ok then
        ok, vel = pcall(function() return balle.Velocity end)
    end
    if ok and vel and vel.Magnitude > 10 then
        local vers = (hrp.Position - balle.Position).Unit
        local dot = vel.Unit:Dot(vers)
        if dot > 0.65 then
            return true, dist
        end
    end

    return false, dist
end

-- ═══════════════════════════════════════════════
--  PARRY
-- ═══════════════════════════════════════════════
local function faireParry()
    local maintenant = tick()
    if maintenant - dernierParry < 0.3 then return end
    dernierParry = maintenant
    compteurParry += 1

    if #remotesParry == 0 then
        chercherRemotes()
    end

    for _, remote in pairs(remotesParry) do
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer()
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer()
            end
        end)
    end
end

-- ═══════════════════════════════════════════════
--  INTERFACE - COMPOSANTS
-- ═══════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "AP_" .. tostring(math.random(10000, 99999))
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function creer(classe, props)
    local obj = Instance.new(classe)
    for k, v in pairs(props) do
        if k ~= "Parent" then obj[k] = v end
    end
    if props.Parent then obj.Parent = props.Parent end
    return obj
end

local function coins(parent, r)
    creer("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = parent })
end

-- ═══════════════════════════════════════════════
--  INTERFACE - PANEL
-- ═══════════════════════════════════════════════
local panel = creer("Frame", {
    Size = UDim2.new(0, 280, 0, 420),
    Position = UDim2.new(0, 16, 0.5, -210),
    BackgroundColor3 = Color3.fromRGB(15, 15, 20),
    BackgroundTransparency = 0.03,
    Parent = gui,
})
coins(panel, 12)
creer("UIStroke", { Color = Color3.fromRGB(55, 55, 70), Thickness = 1.5, Parent = panel })

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
    Text = "AUTO PARRY v3",
    TextColor3 = Color3.fromRGB(90, 130, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = barre,
})

-- Statut
local lblStatut = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 18),
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
    Size = UDim2.new(1, -24, 0, 16),
    Position = UDim2.new(0, 14, 0, 68),
    BackgroundTransparency = 1,
    Text = "Parrys: 0  |  Remotes: 0  |  Balle: --",
    TextColor3 = Color3.fromRGB(120, 120, 140),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = panel,
})

-- Debug
local lblDebug = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 40),
    Position = UDim2.new(0, 14, 1, -50),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Color3.fromRGB(255, 200, 50),
    Font = Enum.Font.Code,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Bottom,
    TextWrapped = true,
    Visible = false,
    Parent = panel,
})

-- Separateur
creer("Frame", {
    Size = UDim2.new(1, -28, 0, 1),
    Position = UDim2.new(0, 14, 0, 92),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55),
    BorderSizePixel = 0,
    Parent = panel,
})

-- ═══════════════════════════════════════════════
--  INTERFACE - SLIDER (min 0, max libre)
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
        Size = UDim2.new(1, -28, 0, 6),
        Position = UDim2.new(0, 14, 0, yPos + 22),
        BackgroundColor3 = Color3.fromRGB(35, 35, 48),
        Parent = parent,
    })
    coins(piste, 3)

    local remplissage = creer("Frame", {
        Size = UDim2.new((defaut - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(90, 130, 255),
        Parent = piste,
    })
    coins(remplissage, 3)

    local curseur = creer("TextButton", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new((defaut - min) / (max - min), -8, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(230, 230, 240),
        Text = "",
        Parent = piste,
    })
    coins(curseur, 8)

    local enDrag = false

    curseur.MouseButton1Down:Connect(function()
        enDrag = true
    end)

    piste.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            enDrag = true
            local absPos = piste.AbsolutePosition.X
            local absSize = piste.AbsoluteSize.X
            local rel = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
            local val = math.floor(min + rel * (max - min) + 0.5)
            remplissage.Size = UDim2.new(rel, 0, 1, 0)
            curseur.Position = UDim2.new(rel, -8, 0.5, -8)
            lblVal.Text = tostring(val)
            callback(val)
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            enDrag = false
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if enDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
            local absPos = piste.AbsolutePosition.X
            local absSize = piste.AbsoluteSize.X
            local rel = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
            local val = math.floor(min + rel * (max - min) + 0.5)
            remplissage.Size = UDim2.new(rel, 0, 1, 0)
            curseur.Position = UDim2.new(rel, -8, 0.5, -8)
            lblVal.Text = tostring(val)
            callback(val)
        end
    end)
end

-- ═══════════════════════════════════════════════
--  INTERFACE - TOGGLE
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
    local btn = creer("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = fond,
    })

    btn.MouseButton1Click:Connect(function()
        etat = not etat
        TweenService:Create(fond, TweenInfo.new(0.15), {
            BackgroundColor3 = etat and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(45, 45, 58),
        }):Play()
        TweenService:Create(point, TweenInfo.new(0.15), {
            Position = etat and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2),
        }):Play()
        callback(etat)
    end)

    return function(val)
        etat = val
        fond.BackgroundColor3 = etat and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(45, 45, 58)
        point.Position = etat and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    end
end

-- ═══════════════════════════════════════════════
--  INTERFACE - BOUTONS
-- ═══════════════════════════════════════════════
local function creerBouton(parent, texte, couleur, yPos, callback)
    local btn = creer("TextButton", {
        Size = UDim2.new(1, -28, 0, 28),
        Position = UDim2.new(0, 14, 0, yPos),
        BackgroundColor3 = couleur,
        Text = texte,
        TextColor3 = Color3.fromRGB(230, 230, 240),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Parent = parent,
    })
    coins(btn, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- Creer les controles
creerSlider(panel, "Distance Parry", 0, 100, Config.DistanceParry, 102, function(v)
    Config.DistanceParry = v
end)

creerSlider(panel, "Distance Minimum", 0, 50, Config.DistanceMin, 142, function(v)
    Config.DistanceMin = v
end)

creerSlider(panel, "Delai (ms)", 0, 500, Config.Delai, 182, function(v)
    Config.Delai = v
end)

local majToggle = creerToggle(panel, "Auto Parry", Config.Active, 225, function(v)
    Config.Active = v
    lblStatut.Text = v and "ACTIF" or "DESACTIVE"
    lblStatut.TextColor3 = v and Color3.fromRGB(0, 210, 80) or Color3.fromRGB(210, 50, 50)
end)

creerToggle(panel, "Mode Debug", Config.ModeDebug, 255, function(v)
    Config.ModeDebug = v
    lblDebug.Visible = v
    if v then chercherRemotes() end
end)

-- Separateur
creer("Frame", {
    Size = UDim2.new(1, -28, 0, 1),
    Position = UDim2.new(0, 14, 0, 290),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55),
    BorderSizePixel = 0,
    Parent = panel,
})

creerBouton(panel, "Re-scanner les Remotes", Color3.fromRGB(35, 35, 50), 300, function()
    chercherRemotes()
    lblStats.Text = "Parrys: " .. compteurParry .. "  |  Remotes: " .. #remotesParry
        .. "  |  Balle: " .. (balleCachee and "OUI" or "NON")
end)

-- Raccourcis clavier
creer("TextLabel", {
    Size = UDim2.new(1, -28, 0, 45),
    Position = UDim2.new(0, 14, 0, 340),
    BackgroundTransparency = 1,
    Text = "RShift  =  Activer/Desactiver\nRCtrl   =  Cacher/Montrer le panel",
    TextColor3 = Color3.fromRGB(90, 90, 110),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    LineHeight = 1.6,
    Parent = panel,
})

-- ═══════════════════════════════════════════════
--  DRAG DU PANEL
-- ═══════════════════════════════════════════════
local debutDrag, posDepart

barre.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        debutDrag = input.Position
        posDepart = panel.Position
    end
end)

barre.InputChanged:Connect(function(input)
    if debutDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - debutDrag
        panel.Position = UDim2.new(
            posDepart.X.Scale, posDepart.X.Offset + delta.X,
            posDepart.Y.Scale, posDepart.Y.Offset + delta.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        debutDrag = nil
    end
end)

-- ═══════════════════════════════════════════════
--  RACCOURCIS CLAVIER
-- ═══════════════════════════════════════════════
UIS.InputBegan:Connect(function(input, traite)
    if traite then return end
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
    -- Maj stats
    lblStats.Text = "Parrys: " .. compteurParry .. "  |  Remotes: " .. #remotesParry
        .. "  |  Balle: " .. (balleCachee and balleCachee.Parent and "OUI" or "NON")

    if Config.ModeDebug then
        lblDebug.Text = debugInfo
    end

    if not Config.Active then return end
    if not balleCachee or not balleCachee.Parent then return end

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

warn("[Auto Parry v3] Charge ! Remotes trouves: " .. #remotesParry)
