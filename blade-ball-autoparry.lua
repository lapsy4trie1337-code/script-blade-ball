-- Blade Ball Auto Parry v6
-- Detecte la balle par velocite, pas par nom

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
    DistanceParry = 18,
    DistanceMin = 0,
    Delai = 0,
    ToucheToggle = Enum.KeyCode.RightShift,
    TouchePanel = Enum.KeyCode.RightControl,
}

local balleCachee = nil
local dernierParry = 0
local compteurParry = 0
local dernierLog = "Demarrage..."
local balleNom = "?"

local function log(msg)
    dernierLog = msg
    warn("[AutoParry] " .. msg)
end

-- ═══════════════════════════════════════════════
--  TROUVER LA BALLE PAR VELOCITE
--  Au lieu de chercher par nom, on cherche
--  tout objet qui bouge vite et pas un joueur
-- ═══════════════════════════════════════════════
local function estUnJoueur(obj)
    local parent = obj.Parent
    while parent and parent ~= workspace do
        if Players:GetPlayerFromCharacter(parent) then return true end
        parent = parent.Parent
    end
    return false
end

local function trouverBalle()
    -- Methode 1 : par nom classique
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) then
            local n = v.Name:lower()
            if (n == "ball" or n == "balle" or n:find("projectile") or n:find("orb")) then
                if not estUnJoueur(v) then
                    return v
                end
            end
        end
    end

    -- Methode 2 : objet avec attribut Target
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not estUnJoueur(v) then
            if v:GetAttribute("Target") or v:GetAttribute("target")
                or v:GetAttribute("realTarget") or v:GetAttribute("CurrentTarget") then
                return v
            end
        end
    end

    -- Methode 3 : objet rapide non-joueur, non-terrain
    for _, v in pairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) and not estUnJoueur(v) then
            if v.Name ~= "Baseplate" and v.Name ~= "Terrain" and not v.Anchored then
                local ok, vel = pcall(function() return v.AssemblyLinearVelocity end)
                if ok and vel and vel.Magnitude > 30 then
                    local taille = v.Size.Magnitude
                    if taille < 15 then
                        return v
                    end
                end
            end
        end
    end

    return nil
end

-- Surveiller les nouveaux objets
workspace.DescendantAdded:Connect(function(obj)
    if balleCachee and balleCachee.Parent then return end
    if not (obj:IsA("BasePart") or obj:IsA("MeshPart")) then return end
    if estUnJoueur(obj) then return end

    local n = obj.Name:lower()
    if n == "ball" or n == "balle" or n:find("projectile") or n:find("orb") then
        balleCachee = obj
        balleNom = obj.Name .. " (" .. obj:GetFullName() .. ")"
        log("Balle trouvee: " .. balleNom)
        return
    end

    if obj:GetAttribute("Target") or obj:GetAttribute("target")
        or obj:GetAttribute("realTarget") then
        balleCachee = obj
        balleNom = obj.Name .. " (" .. obj:GetFullName() .. ")"
        log("Balle (attribut): " .. balleNom)
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if obj == balleCachee then balleCachee = nil end
end)

-- Scan initial
balleCachee = trouverBalle()
if balleCachee then
    balleNom = balleCachee.Name .. " (" .. balleCachee:GetFullName() .. ")"
    log("Balle au demarrage: " .. balleNom)
else
    log("Pas de balle - recherche continue...")
end

-- Re-scanner regulierement si pas de balle
task.spawn(function()
    while true do
        task.wait(1)
        if not balleCachee or not balleCachee.Parent then
            balleCachee = trouverBalle()
            if balleCachee then
                balleNom = balleCachee.Name .. " (" .. balleCachee:GetFullName() .. ")"
                log("Balle re-trouvee: " .. balleNom)
            end
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
    if not hrp then return false, math.huge end

    local dist = (balle.Position - hrp.Position).Magnitude

    -- Tester attributs sur la balle et son parent
    local cibles = {balle}
    if balle.Parent and balle.Parent ~= workspace then
        table.insert(cibles, balle.Parent)
    end

    local noms = {
        "Target", "target", "realTarget", "RealTarget",
        "CurrentTarget", "currentTarget", "TargetPlayer",
        "targetPlayer", "PlayerTarget"
    }

    for _, obj in pairs(cibles) do
        for _, nom in pairs(noms) do
            local cible = obj:GetAttribute(nom)
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
    end

    -- ObjectValue enfant
    for _, child in pairs(balle:GetChildren()) do
        if child:IsA("ObjectValue") and child.Value then
            return (child.Value == LP.Character or child.Value == LP), dist
        end
    end

    -- Velocite : la balle vient vers moi ?
    local ok, vel = pcall(function() return balle.AssemblyLinearVelocity end)
    if not ok then ok, vel = pcall(function() return balle.Velocity end) end
    if ok and vel and vel.Magnitude > 10 then
        local vers = (hrp.Position - balle.Position).Unit
        if vel.Unit:Dot(vers) > 0.5 then
            return true, dist
        end
    end

    return false, dist
end

-- ═══════════════════════════════════════════════
--  PARRY
-- ═══════════════════════════════════════════════
local remoteParry = nil

-- Chercher le remote ParrySlashAll
pcall(function()
    for _, v in pairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == "ParrySlashAll" then
            remoteParry = v
            log("Remote ParrySlashAll trouve")
        end
    end
end)

local function faireParry()
    local maintenant = tick()
    if maintenant - dernierParry < 0.25 then return end
    dernierParry = maintenant
    compteurParry += 1

    -- mouse1click en priorite (methode native du jeu)
    pcall(mouse1click)

    -- Aussi essayer le remote ParrySlashAll
    if remoteParry then
        pcall(function() remoteParry:FireServer() end)
    end

    log("PARRY #" .. compteurParry)
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

local panel = creer("Frame", {
    Size = UDim2.new(0, 280, 0, 400),
    Position = UDim2.new(0, 16, 0.5, -200),
    BackgroundColor3 = Color3.fromRGB(15, 15, 20),
    BackgroundTransparency = 0.03,
    Parent = gui,
})
coins(panel, 12)
creer("UIStroke", {Color = Color3.fromRGB(55, 55, 70), Thickness = 1.5, Parent = panel})

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
    Text = "AUTO PARRY v6",
    TextColor3 = Color3.fromRGB(90, 130, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = barre,
})

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

local lblStats = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 48),
    Position = UDim2.new(0, 14, 0, 68),
    BackgroundTransparency = 1,
    Text = "...",
    TextColor3 = Color3.fromRGB(120, 120, 140),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = panel,
})

local lblLog = creer("TextLabel", {
    Size = UDim2.new(1, -24, 0, 14),
    Position = UDim2.new(0, 14, 0, 116),
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
    Position = UDim2.new(0, 14, 0, 136),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55),
    BorderSizePixel = 0,
    Parent = panel,
})

-- Slider
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
        BackgroundColor3 = Color3.fromRGB(35, 35, 48), Parent = parent,
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

-- Toggle
local function creerToggle(parent, texte, defaut, yPos, callback)
    creer("TextLabel", {
        Size = UDim2.new(1, -64, 0, 22), Position = UDim2.new(0, 14, 0, yPos),
        BackgroundTransparency = 1, Text = texte, TextColor3 = Color3.fromRGB(170, 170, 190),
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    local fond = creer("Frame", {
        Size = UDim2.new(0, 38, 0, 20), Position = UDim2.new(1, -52, 0, yPos + 1),
        BackgroundColor3 = defaut and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(45, 45, 58), Parent = parent,
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

creerSlider(panel, "Distance Parry", 0, 100, Config.DistanceParry, 146, function(v) Config.DistanceParry = v end)
creerSlider(panel, "Distance Minimum", 0, 50, Config.DistanceMin, 184, function(v) Config.DistanceMin = v end)
creerSlider(panel, "Delai (ms)", 0, 500, Config.Delai, 222, function(v) Config.Delai = v end)

local majToggle = creerToggle(panel, "Auto Parry", Config.Active, 264, function(v)
    Config.Active = v
    lblStatut.Text = v and "ACTIF" or "DESACTIVE"
    lblStatut.TextColor3 = v and Color3.fromRGB(0, 210, 80) or Color3.fromRGB(210, 50, 50)
end)

creer("Frame", {
    Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0, 296),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55), BorderSizePixel = 0, Parent = panel,
})

-- Bouton forcer cherche
local btnCherche = creer("TextButton", {
    Size = UDim2.new(1, -28, 0, 28), Position = UDim2.new(0, 14, 0, 306),
    BackgroundColor3 = Color3.fromRGB(30, 30, 50),
    Text = "Forcer recherche balle", TextColor3 = Color3.fromRGB(230, 230, 240),
    Font = Enum.Font.GothamBold, TextSize = 12, Parent = panel,
})
coins(btnCherche, 6)
btnCherche.MouseButton1Click:Connect(function()
    balleCachee = trouverBalle()
    if balleCachee then
        balleNom = balleCachee.Name .. " (" .. balleCachee:GetFullName() .. ")"
        log("Balle: " .. balleNom)
    else
        log("Aucune balle !")
    end
end)

creer("TextLabel", {
    Size = UDim2.new(1, -28, 0, 45), Position = UDim2.new(0, 14, 0, 345),
    BackgroundTransparency = 1,
    Text = "RShift = Activer/Desactiver\nRCtrl  = Cacher/Montrer",
    TextColor3 = Color3.fromRGB(90, 90, 110), Font = Enum.Font.Gotham, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, LineHeight = 1.6, Parent = panel,
})

-- Drag
local dd, sp
barre.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = i.Position; sp = panel.Position end end)
barre.InputChanged:Connect(function(i) if dd and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - dd; panel.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dd = nil end end)

-- Raccourcis
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
        .. "\nBalle: " .. (balleOK and "OUI - " .. (balleCachee and balleCachee.Name or "?") or "NON (recherche...)")
        .. "\nRemote: " .. (remoteParry and "ParrySlashAll" or "mouse1click")
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

log("v6 - detection par velocite + ParrySlashAll")
