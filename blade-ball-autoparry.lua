-- Blade Ball Auto Parry v4

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════
local Config = {
    Active = true,
    DistanceParry = 15,
    DistanceMin = 0,
    Delai = 0,
    ModeDebug = true,
    ToucheToggle = Enum.KeyCode.RightShift,
    TouchePanel = Enum.KeyCode.RightControl,
}

-- ═══════════════════════════════════════════════
--  VARIABLES
-- ═══════════════════════════════════════════════
local balleCachee = nil
local remoteTrouve = nil
local dernierParry = 0
local compteurParry = 0
local logMessages = {}

local function log(msg)
    table.insert(logMessages, os.clock() .. " | " .. msg)
    if #logMessages > 30 then table.remove(logMessages, 1) end
    warn("[AutoParry] " .. msg)
end

-- ═══════════════════════════════════════════════
--  SCANNER : DUMP TOUT LE JEU DANS LA CONSOLE
-- ═══════════════════════════════════════════════
local function scannerJeu()
    log("=== SCAN DU JEU ===")

    -- Lister tous les remotes dans ReplicatedStorage
    log("--- REMOTES dans ReplicatedStorage ---")
    local nbRemotes = 0
    for _, v in pairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            log("  Remote: " .. v:GetFullName() .. " [" .. v.ClassName .. "]")
            nbRemotes += 1
        end
    end
    log("Total remotes RS: " .. nbRemotes)

    -- Lister les enfants directs du workspace
    log("--- ENFANTS du Workspace ---")
    for _, v in pairs(workspace:GetChildren()) do
        log("  " .. v.ClassName .. ": " .. v.Name)
    end

    -- Chercher tout ce qui ressemble a une balle
    log("--- RECHERCHE BALLE ---")
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            if n:find("ball") or n:find("balle") or n:find("projectile")
                or n:find("orb") or n:find("sphere") then
                log("  Balle possible: " .. v:GetFullName())
                -- Lister ses attributs
                for _, attr in pairs(v:GetAttributes()) do end
                local attrs = v:GetAttributes()
                for k, val in pairs(attrs) do
                    log("    Attribut: " .. k .. " = " .. tostring(val))
                end
                -- Lister ses enfants
                for _, child in pairs(v:GetChildren()) do
                    log("    Enfant: " .. child.ClassName .. " " .. child.Name)
                    if child:IsA("ObjectValue") then
                        log("      Valeur: " .. tostring(child.Value))
                    end
                end
            end
        end
    end

    -- Chercher des modules/dossiers importants
    log("--- DOSSIERS IMPORTANTS ---")
    local noms = {"Balls", "Ball", "Remotes", "Events", "Game", "Combat", "Abilities", "Shared"}
    for _, nom in pairs(noms) do
        local obj = workspace:FindFirstChild(nom) or RS:FindFirstChild(nom)
        if obj then
            log("  Trouve: " .. obj:GetFullName())
            for _, child in pairs(obj:GetChildren()) do
                log("    " .. child.ClassName .. ": " .. child.Name)
            end
        end
    end

    log("=== FIN SCAN ===")
end

-- ═══════════════════════════════════════════════
--  TROUVER LA BALLE
-- ═══════════════════════════════════════════════
local function estUneBalle(obj)
    if not (obj:IsA("BasePart") or obj:IsA("MeshPart")) then return false end
    local n = obj.Name:lower()
    if n == "ball" or n == "balle" or n == "projectile" or n == "orb" then
        return true
    end
    if obj.Shape and obj.Shape == Enum.PartType.Ball then
        local attrs = obj:GetAttributes()
        if attrs["Target"] or attrs["target"] or attrs["realTarget"] or attrs["CurrentTarget"] then
            return true
        end
    end
    if obj.Parent then
        local pn = obj.Parent.Name:lower()
        if pn == "balls" or pn == "ball" or pn == "balles" then
            return true
        end
    end
    return false
end

local function surAjout(obj)
    if estUneBalle(obj) then
        balleCachee = obj
        log("Balle detectee: " .. obj:GetFullName())

        -- Surveiller les changements d'attributs
        obj.AttributeChanged:Connect(function(attr)
            if Config.ModeDebug then
                log("Attribut change: " .. attr .. " = " .. tostring(obj:GetAttribute(attr)))
            end
        end)
    end
end

local function surRetrait(obj)
    if obj == balleCachee then
        balleCachee = nil
        log("Balle disparue")
    end
end

workspace.DescendantAdded:Connect(surAjout)
workspace.DescendantRemoving:Connect(surRetrait)

-- Scan initial
for _, v in pairs(workspace:GetDescendants()) do
    if estUneBalle(v) then
        balleCachee = v
        log("Balle trouvee au demarrage: " .. v:GetFullName())
        break
    end
end

-- ═══════════════════════════════════════════════
--  TROUVER LE REMOTE
-- ═══════════════════════════════════════════════
local function chercherRemote()
    -- Chercher dans tout RS
    for _, v in pairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("parry") or n:find("block") or n:find("deflect") then
                remoteTrouve = v
                log("Remote principal: " .. v:GetFullName())
                return
            end
        end
    end

    -- Si rien, chercher plus large
    for _, v in pairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("hit") or n:find("slash") or n:find("swing")
                or n:find("click") or n:find("action") or n:find("ability")
                or n:find("combat") or n:find("attack") or n:find("use") then
                remoteTrouve = v
                log("Remote secondaire: " .. v:GetFullName())
                return
            end
        end
    end

    log("AUCUN remote trouve - utilise mouse1click en fallback")
end

chercherRemote()

-- ═══════════════════════════════════════════════
--  DETECTION CIBLE
-- ═══════════════════════════════════════════════
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function balleVersJoueur(balle)
    local hrp = getHRP()
    if not hrp then return false, math.huge end

    local dist = (balle.Position - hrp.Position).Magnitude

    -- Tester tous les noms d'attributs possibles
    local nomsAttributs = {
        "Target", "target", "CurrentTarget", "realTarget",
        "RealTarget", "TargetPlayer", "targetPlayer",
        "currentTarget", "PlayerTarget"
    }

    for _, nom in pairs(nomsAttributs) do
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
            if Config.ModeDebug and estMoi then
                log("Cible par attribut '" .. nom .. "': " .. tostring(cible))
            end
            return estMoi, dist
        end
    end

    -- Verifier le parent aussi
    if balle.Parent and balle.Parent ~= workspace then
        for _, nom in pairs(nomsAttributs) do
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
            if child.Value == LP.Character or child.Value == LP then
                return true, dist
            end
            return false, dist
        end
    end

    -- Dernier recours : velocite
    local ok, vel = pcall(function() return balle.AssemblyLinearVelocity end)
    if not ok then
        ok, vel = pcall(function() return balle.Velocity end)
    end
    if ok and vel and vel.Magnitude > 10 then
        local vers = (hrp.Position - balle.Position).Unit
        local dot = vel.Unit:Dot(vers)
        if dot > 0.6 then
            return true, dist
        end
    end

    return false, dist
end

-- ═══════════════════════════════════════════════
--  PARRY (multi-methode)
-- ═══════════════════════════════════════════════
local function faireParry()
    local maintenant = tick()
    if maintenant - dernierParry < 0.25 then return end
    dernierParry = maintenant
    compteurParry += 1

    -- Methode 1 : Remote
    if remoteTrouve then
        pcall(function()
            remoteTrouve:FireServer()
        end)
        if Config.ModeDebug then log("Parry via remote") end
        return
    end

    -- Methode 2 : mouse1click (fonctionne sur la plupart des executors)
    pcall(function()
        mouse1click()
    end)

    -- Methode 3 : fireclick si ClickDetector present
    pcall(function()
        local char = LP.Character
        if char then
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool then
                tool:Activate()
            end
        end
    end)

    if Config.ModeDebug then log("Parry via mouse1click/tool") end
end

-- ═══════════════════════════════════════════════
--  GUI
-- ═══════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "AP_" .. math.random(10000, 99999)
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

local function coins(p, r) creer("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p }) end

-- Panel
local panel = creer("Frame", {
    Size = UDim2.new(0, 290, 0, 480),
    Position = UDim2.new(0, 16, 0.5, -240),
    BackgroundColor3 = Color3.fromRGB(15, 15, 20),
    BackgroundTransparency = 0.03,
    Parent = gui,
})
coins(panel, 12)
creer("UIStroke", { Color = Color3.fromRGB(55, 55, 70), Thickness = 1.5, Parent = panel })

-- ScrollFrame pour le contenu
local contenu = creer("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -42),
    Position = UDim2.new(0, 0, 0, 42),
    BackgroundTransparency = 1,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Color3.fromRGB(90, 130, 255),
    CanvasSize = UDim2.new(0, 0, 0, 520),
    Parent = panel,
})

-- Barre titre
local barre = creer("Frame", {
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = Color3.fromRGB(22, 22, 30),
    Parent = panel,
})
coins(barre, 12)

creer("TextLabel", {
    Size = UDim2.new(1, -16, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "AUTO PARRY v4",
    TextColor3 = Color3.fromRGB(90, 130, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = barre,
})

-- Statut
local lblStatut = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 18),
    Position = UDim2.new(0, 14, 0, 6),
    BackgroundTransparency = 1,
    Text = "ACTIF",
    TextColor3 = Color3.fromRGB(0, 210, 80),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = contenu,
})

-- Stats
local lblStats = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 32),
    Position = UDim2.new(0, 14, 0, 26),
    BackgroundTransparency = 1,
    Text = "Parrys: 0\nBalle: NON  |  Remote: NON",
    TextColor3 = Color3.fromRGB(120, 120, 140),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true,
    Parent = contenu,
})

-- Log debug
local lblLog = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 100),
    Position = UDim2.new(0, 14, 0, 410),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Color3.fromRGB(255, 200, 50),
    Font = Enum.Font.Code,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
    Parent = contenu,
})

-- Separateur
creer("Frame", {
    Size = UDim2.new(1, -28, 0, 1),
    Position = UDim2.new(0, 14, 0, 64),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55),
    BorderSizePixel = 0,
    Parent = contenu,
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
        Position = UDim2.new(0, 14, 0, yPos + 22),
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

    local function majSlider(posX)
        local absPos = piste.AbsolutePosition.X
        local absSize = piste.AbsoluteSize.X
        local rel = math.clamp((posX - absPos) / absSize, 0, 1)
        local val = math.floor(min + rel * (max - min) + 0.5)
        remplissage.Size = UDim2.new(rel, 0, 1, 0)
        curseur.Position = UDim2.new(rel, -9, 0.5, -9)
        lblVal.Text = tostring(val)
        callback(val)
    end

    curseur.MouseButton1Down:Connect(function() enDrag = true end)
    piste.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            enDrag = true
            majSlider(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then enDrag = false end
    end)
    UIS.InputChanged:Connect(function(input)
        if enDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
            majSlider(input.Position.X)
        end
    end)
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
    creer("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = fond,
    }).MouseButton1Click:Connect(function()
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
--  BOUTON
-- ═══════════════════════════════════════════════
local function creerBouton(parent, texte, couleur, yPos, callback)
    local btn = creer("TextButton", {
        Size = UDim2.new(1, -28, 0, 30),
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

-- ═══════════════════════════════════════════════
--  CREER LES CONTROLES
-- ═══════════════════════════════════════════════
creerSlider(contenu, "Distance Parry", 0, 100, Config.DistanceParry, 74, function(v)
    Config.DistanceParry = v
end)

creerSlider(contenu, "Distance Minimum", 0, 50, Config.DistanceMin, 114, function(v)
    Config.DistanceMin = v
end)

creerSlider(contenu, "Delai (ms)", 0, 500, Config.Delai, 154, function(v)
    Config.Delai = v
end)

local majToggle = creerToggle(contenu, "Auto Parry", Config.Active, 198, function(v)
    Config.Active = v
    lblStatut.Text = v and "ACTIF" or "DESACTIVE"
    lblStatut.TextColor3 = v and Color3.fromRGB(0, 210, 80) or Color3.fromRGB(210, 50, 50)
end)

creerToggle(contenu, "Mode Debug", Config.ModeDebug, 228, function(v)
    Config.ModeDebug = v
    lblLog.Visible = v
end)

creer("Frame", {
    Size = UDim2.new(1, -28, 0, 1),
    Position = UDim2.new(0, 14, 0, 260),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55),
    BorderSizePixel = 0,
    Parent = contenu,
})

creerBouton(contenu, "Scanner le Jeu (voir console F9)", Color3.fromRGB(50, 40, 20), 270, function()
    scannerJeu()
end)

creerBouton(contenu, "Re-chercher Remote", Color3.fromRGB(30, 30, 50), 308, function()
    remoteTrouve = nil
    chercherRemote()
end)

creerBouton(contenu, "Re-chercher Balle", Color3.fromRGB(30, 30, 50), 346, function()
    balleCachee = nil
    for _, v in pairs(workspace:GetDescendants()) do
        if estUneBalle(v) then
            balleCachee = v
            log("Balle re-trouvee: " .. v:GetFullName())
            break
        end
    end
    if not balleCachee then log("Aucune balle trouvee") end
end)

creer("TextLabel", {
    Size = UDim2.new(1, -28, 0, 45),
    Position = UDim2.new(0, 14, 0, 385),
    BackgroundTransparency = 1,
    Text = "RShift = Activer/Desactiver\nRCtrl  = Cacher/Montrer le panel",
    TextColor3 = Color3.fromRGB(90, 90, 110),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    LineHeight = 1.6,
    Parent = contenu,
})

-- ═══════════════════════════════════════════════
--  DRAG
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
    if input.UserInputType == Enum.UserInputType.MouseButton1 then debutDrag = nil end
end)

-- ═══════════════════════════════════════════════
--  RACCOURCIS
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
    -- Maj affichage
    lblStats.Text = "Parrys: " .. compteurParry
        .. "\nBalle: " .. (balleCachee and balleCachee.Parent and "OUI" or "NON")
        .. "  |  Remote: " .. (remoteTrouve and remoteTrouve.Name or "mouse1click")

    if Config.ModeDebug and #logMessages > 0 then
        local txt = ""
        for i = math.max(1, #logMessages - 6), #logMessages do
            txt = txt .. logMessages[i] .. "\n"
        end
        lblLog.Text = txt
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

-- Scan au demarrage
task.spawn(function()
    task.wait(2)
    scannerJeu()
end)

log("Script charge ! Ouvre la console (F9) pour voir les details")
