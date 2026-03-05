-- ====================== UKUSSIA v14 ======================

-- ИЗМЕНЕНИЯ v14:
-- 1. AimLock теперь лочит ближайшего, переключается если умер/ушёл (не залипает на одном)
-- 2. FOV круг для AimLock (Drawing Circle, вкл/выкл отдельно)
-- 3. AimLock FOV слайдер (фильтрация по FOV)
-- 4. Все изменения v13 сохранены
-- 5. Все изменения из v13 сохранены
-- ФИКС: Все функции вкладки Legit работают ТОЛЬКО на игроков с ролью "Target"

-- ====================== ОСНОВНОЙ СКРИПТ ======================

local _S = {}
_S.defaultChatStates = {}

-- servis
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

task.spawn(function()
    local success = pcall(function()
        local chatWindowConfig = TextChatService:FindFirstChild('ChatWindowConfiguration')
        local chatInputConfig = TextChatService:FindFirstChild('ChatInputBarConfiguration')
        _S.defaultChatStates = {
            ChatWindowEnabled = chatWindowConfig and chatWindowConfig.Enabled or false,
            ChatInputEnabled = chatInputConfig and chatInputConfig.Enabled or false,
            CoreGuiChat = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat),
        }
    end)
    if not success then
        _S.defaultChatStates = { ChatWindowEnabled = false, ChatInputEnabled = false, CoreGuiChat = true }
    end
end)

-- ====================== MOD DETECTOR: BOOM FFA ======================
_S.MOD_USERNAMES = {
    ['boomffa_mod'] = true,
    ['boomffaadmin'] = true,
    ['boomffa_admin'] = true,
    ['boomffa_staff'] = true,
    ['boom_moderator'] = true,
    ['boomgamemod'] = true,
    ['test'] = true,
}
_S.MOD_SYMBOLS = { '✅', '☑️', '👑', '⭐', '🛡️', '✨', '🌟', '⚡', '🔱', '💎', '🏆', '🎖️' }
_S.MOD_GROUP_IDS = {
    925309458,
    33991282,
    7431102,
}
_S.MOD_MIN_RANK = 50
_S.detectorEnabled = false
_S.modAction = 'notify'
_S.alertSoundId = 6753645454
_S.notifiedPlayers = {}
_S.activeESP = {}
_S.lastCheck = 0

-- ====================== ПОСТОЯННОЕ СОХРАНЕНИЕ МОДОВ ======================
_S.MOD_STORAGE_FILE = "ukussia_mods_list.txt"
_S.savedMods = {}

local function table_count(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function loadSavedMods()
    pcall(function()
        if readfile then
            local content = readfile(_S.MOD_STORAGE_FILE)
            if content and content ~= "" then
                _S.savedMods = game:GetService("HttpService"):JSONDecode(content)
                print("📁 Загружено " .. table_count(_S.savedMods) .. " сохраненных модераторов")
            end
        end
    end)
end

local function saveMods()
    pcall(function()
        if writefile then
            local content = game:GetService("HttpService"):JSONEncode(_S.savedMods)
            writefile(_S.MOD_STORAGE_FILE, content)
            print("💾 Моды сохранены в файл")
        end
    end)
end

loadSavedMods()

local function addModToSaved(userId, playerName, role)
    if not _S.savedMods[userId] then
        _S.savedMods[userId] = {
            name = playerName,
            role = role or "Reported",
            date = os.date("%Y-%m-%d %H:%M")
        }
        saveMods()
        return true
    end
    return false
end

local function removeModFromSaved(userId)
    if _S.savedMods[userId] then
        _S.savedMods[userId] = nil
        saveMods()
        return true
    end
    return false
end

_S.WeaponsEnabled = {
    ["[Knife]"] = false,
    ["[Shotgun]"] = true,
    ["[TacticalShotgun]"] = true,
    ["[Revolver]"] = true,
    ["[Double-Barrel SG]"] = true,
    ["[Pistol]"] = true,
    ["[SMG]"] = true,
    ["[Rifle]"] = true,
    ["[Sniper]"] = true,
    ["[Deagle]"] = true,
}

_S.AmmoName = "Ammo"
_S.FullMagEnabled = true
_S.MagShots = 6
_S.MagDelay = 0.015
_S.DelayBeforeShot = 0.001
_S.Monitoring = false
_S.StarterPlayer = nil
_S.LastAmmoPerTool = {}

-- [НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ AUTO-SHOOT]
_S.AutoShootRandomDelay = true
_S.AutoShootMinDelay = 0.05
_S.AutoShootMaxDelay = 0.15
_S.AutoShootBurstShots = 1
_S.AutoShootBurstDelay = 0.02

-- ====================== AIMLOCK VARIABLES ======================
_S.AimLockLockedTarget = nil
_S.AimLockEnabled = false
_S.AimLockSmooth = 10
_S.AimLockConnection = nil
_S.AimLockBindKey = nil
_S.AimLockBindMode = "Toggle"
_S.WaitingForAimLockBind = false
_S.AimLockBindBtn = nil
-- [NEW] FOV для AimLock
_S.AimLockFOVEnabled = false
_S.AimLockFOV = 150
_S.AimLockFOVCircle = nil
_S.ShowAimLockFOVCircle = false

-- [НОВАЯ ПЕРЕМЕННАЯ ДЛЯ РОЛИ ПО УМОЛЧАНИЮ]
_S.DefaultPlayerRole = "Target"

_S.AutoReloadEnabled    = false
_S.AutoReloadDelay      = 0.15
_S.AutoReloadMethod     = "ReEquip"
_S.LastAmmoState        = {}
_S.ReloadCooldown       = {}
_S.AutoReloadBindKey    = nil
_S.AutoReloadBindMode2  = "Toggle"
_S.WaitingForReloadBind = false
_S.AutoReloadBindBtn    = nil
_S.ToggleKey = nil
_S.BindMode = "Toggle"
_S.WaitingForBind = false
_S.TripleShotEnabled = false
_S.RapidFireEnabled = false
_S.FastGunEnabled = false
_S.FastGunDelay = 0.05
_S.FastGunConnection = nil
-- ============= НОВАЯ СИСТЕМА ХИТБОКСОВ =============
_S.HitboxSize = Vector3.new(10.8889, 10, 10.4444)
_S.HitboxTransparency = 1
_S.HitboxColor = BrickColor.new("Really black")
_S.HitboxMaterial = Enum.Material.Neon
_S.HitboxEnabled = false

-- Функция обновления хитбокса
local function updateHitbox(hitbox)
    if not hitbox or not hitbox:IsA("BasePart") then return end
    pcall(function()
        hitbox.Size = _S.HitboxSize
        hitbox.Transparency = _S.HitboxTransparency
        hitbox.BrickColor = _S.HitboxColor
        hitbox.Material = _S.HitboxMaterial
        hitbox.CanCollide = false
        hitbox.Massless = true
    end)
end

-- Функция настройки игрока
local function setupPlayer(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        local hitbox = char:WaitForChild("Hitbox", 5)
        if hitbox and _S.HitboxEnabled then
            updateHitbox(hitbox)
        end
    end)
end

-- ====================== ROLE HELPERS ======================
local function GetDefaultRole()
    return _S.DefaultPlayerRole or "Target"
end

local function GetPlayerRole(player)
    return _S.PlayerRoles and _S.PlayerRoles[player.UserId] or GetDefaultRole()
end

local function IsModerator(player)
    return _S.savedMods[player.UserId] ~= nil
end

-- ====================== ГЛАВНАЯ ПРОВЕРКА: ТОЛЬКО TARGET ======================
-- Эта функция используется ВЕЗДЕ во вкладке Legit
local function IsLegitTarget(player)
    if not player then return false end
    if player == LocalPlayer then return false end
    if IsModerator(player) then return false end
    -- ТОЛЬКО роль Target — Friend и Neutral пропускаются
    local role = GetPlayerRole(player)
    return role == "Target"
end

-- Постоянное обновление хитбоксов — ТОЛЬКО для Target
RunService.RenderStepped:Connect(function()
    if not _S.HitboxEnabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        -- ФИКС: проверяем роль перед изменением хитбокса
        if plr ~= LocalPlayer and plr.Character and IsLegitTarget(plr) then
            local hitbox = plr.Character:FindFirstChild("Hitbox")
            updateHitbox(hitbox)
        end
    end
end)

-- Настройка существующих игроков
for _, plr in ipairs(Players:GetPlayers()) do
    setupPlayer(plr)
end

Players.PlayerAdded:Connect(setupPlayer)

-- ============= TRIGGERBOT =============
_S.TriggerbotEnabled = false
_S.TriggerbotConnection = nil
_S.TriggerbotDelay = 0.0001
_S.TriggerbotRMBOnly = false
_S.TriggerBindKey = nil
_S.TriggerBindMode = "Toggle"
_S.WaitingForTriggerBind = false
_S.TriggerKeyBindBtn = nil
_S.TriggerKeyBindMode = "Toggle"
_S.CheckDead = false
_S.CheckWall = false
_S.CheckFriend = false

local function IsPlayerAlive(player)
    if not player then return false end
    local char = player.Character if not char then return false end
    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function IsFriend(player)
    if not player then return false end
    if player == LocalPlayer then return true end
    if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return true end
    local success, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(player.UserId) end)
    return success and isFriend
end

local function HasLineOfSight(targetPart)
    if not targetPart then return false end
    local character = LocalPlayer.Character if not character then return false end
    local camera = workspace.CurrentCamera if not camera then return false end
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local distance = direction.Magnitude local unitDir = direction.Unit
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character}
    rayParams.IgnoreWater = true
    if _S.CheckFriend then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and IsFriend(plr) and plr.Character then
                table.insert(rayParams.FilterDescendantsInstances, plr.Character)
            end
        end
    end
    local rayResult = workspace:Raycast(origin, unitDir * (distance + 1), rayParams)
    if not rayResult then return true end
    local hitPlayer = GetPlayerFromPart(rayResult.Instance)
    if hitPlayer and hitPlayer.Character then
        if hitPlayer.Character == targetPart:FindFirstAncestorWhichIsA("Model") then return true end
    end
    return false
end

local function GetPlayerFromPart(part)
    if not part then return nil end
    local model = part:FindFirstAncestorWhichIsA("Model") if not model then return nil end
    if model:FindFirstChildWhichIsA("Humanoid") then
        for _, plr in pairs(Players:GetPlayers()) do if plr.Character == model then return plr end end
    end
    return nil
end

local function UpdateTriggerbot()
    if _S.TriggerbotConnection then
        _S.TriggerbotConnection:Disconnect()
        _S.TriggerbotConnection = nil
    end
    if _S.TriggerbotEnabled then
        _S.TriggerbotConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                local currentTool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if not currentTool then return end
                if not _S.WeaponsEnabled or not _S.WeaponsEnabled[currentTool.Name] then return end
                if _S.TriggerbotRMBOnly and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
                local mouse = LocalPlayer:GetMouse()
                local target = mouse.Target
                if target then
                    local targetPart = target local targetParent = targetPart.Parent local targetPlayer = nil
                    while targetParent and targetParent ~= game do
                        if targetParent:IsA("Model") then
                            local humanoid = targetParent:FindFirstChildOfClass("Humanoid")
                            if humanoid then
                                for _, plr in pairs(Players:GetPlayers()) do
                                    if plr.Character == targetParent then targetPlayer = plr break end
                                end
                                break
                            end
                        end
                        targetParent = targetParent.Parent
                    end
                    if targetPlayer and targetPlayer ~= LocalPlayer then
                        -- ФИКС: TriggerBot стреляет ТОЛЬКО в Target
                        if not IsLegitTarget(targetPlayer) then return end
                        if _S.CheckDead and not IsPlayerAlive(targetPlayer) then return end
                        if _S.CheckWall and not HasLineOfSight(targetPart) then return end
                        task.wait(_S.TriggerbotDelay)
                        mouse1press()
                        task.wait(0.025 + math.random() * 0.015)
                        mouse1release()
                    end
                end
            end)
        end)
    end
end

_S.SelectHostKey1 = Enum.KeyCode.F1
_S.SelectHostKey2 = Enum.KeyCode.Z
_S.AllowFriendsAsHost = true
_S.ShowTargetEmoji = true
_S.SelectedHostEmoji = nil
_S.HostSelectHotkeyEnabled = true
_S.key1Down = false
_S.key2Down = false
_S.AutoShotToggleBtn = nil
_S.TriggerMainBtn = nil
_S.AutoBindBtn = nil
_S.HitboxBindKey = nil
_S.HitboxBindMode2 = "Toggle"
_S.WaitingForHitboxBind = false
_S.HitboxBindBtn = nil
_S.FlyBindKey = nil
_S.FlyBindMode2 = "Toggle"
_S.WaitingForFlyBind = false
_S.FlyBindBtn = nil
_S.RapidFireBindKey = nil
_S.RapidFireBindMode2 = "Toggle"
_S.WaitingForRapidFireBind = false
_S.RapidFireBindBtn = nil
_S.NoclipBindKey = nil
_S.NoclipBindMode2 = "Toggle"
_S.WaitingForNoclipBind = false
_S.NoclipBindBtn2 = nil
_S.SpeedBindKey = nil
_S.SpeedBindMode2 = "Toggle"
_S.WaitingForSpeedBind = false
_S.SpeedBindBtn = nil
_S._triggerKeyState = false
_S.speedToggleState = false
_S.speedMethod = "CFrame"
_S.speedValue = 16
_S.speedEnabled = false
_S.speedV2Enabled = false
_S.speedV3Enabled = false
_S.NoclipConnection = nil

_S.PlayerRoles = {}

_S.Theme = {
    Background = Color3.fromRGB(0, 0, 0), TopBar = Color3.fromRGB(5, 5, 5),
    Section = Color3.fromRGB(14, 14, 18), TabInactive = Color3.fromRGB(18, 18, 22),
    TabActive = Color3.fromRGB(30, 20, 45), Accent = Color3.fromRGB(110, 60, 180),
    ToggleOn = Color3.fromRGB(12, 12, 16), ToggleOff = Color3.fromRGB(8, 8, 10),
    SliderFill = Color3.fromRGB(240, 240, 245), SliderKnob = Color3.fromRGB(200, 200, 210),
    CloseBtn = Color3.fromRGB(20, 20, 25), CloseBtnHover = Color3.fromRGB(160, 40, 40),
    BindBtn = Color3.fromRGB(75, 40, 130), BindBtnHover = Color3.fromRGB(95, 55, 160),
    PlayerBtn = Color3.fromRGB(18, 18, 22), PlayerBtnHover = Color3.fromRGB(30, 20, 45),
    TitleText = Color3.fromRGB(220, 210, 240), LabelText = Color3.fromRGB(200, 195, 220),
    SectionTitle = Color3.fromRGB(150, 110, 210), InfoText = Color3.fromRGB(180, 175, 200),
}
_S.VisualColors = {
    ESP = { Names=Color3.fromRGB(255,255,255),Distance=Color3.fromRGB(255,255,255),Chams=Color3.fromRGB(255,255,255),Tracers=Color3.fromRGB(255,255,255),Box=Color3.fromRGB(255,255,255),HealthBar=Color3.fromRGB(0,255,0),Tool=Color3.fromRGB(255,200,0),Direction=Color3.fromRGB(255,0,0) },
    Trail = { Color1=Color3.fromRGB(255,110,0),Color2=Color3.fromRGB(255,0,0) },
    Aura = Color3.fromRGB(255,255,255), SelfChams = Color3.fromRGB(255,255,255), Crosshair = Color3.fromRGB(255,255,255),
    RoleESP = {
        Target  = Color3.fromRGB(255, 60, 60),
        Friend  = Color3.fromRGB(60, 220, 120),
        Neutral = Color3.fromRGB(160, 160, 180),
    },
    ModESP = {
        Text = Color3.fromRGB(255, 100, 100),
        Box = Color3.fromRGB(255, 50, 50),
        Tracer = Color3.fromRGB(255, 0, 0)
    }
}
_S.Animations = { TabSlide=true,SectionCollapse=true,ButtonHover=true,MenuOpenClose=true,SliderKnob=true,ToggleColor=true }

local AUTO_RELOAD_COOLDOWN = 1.2

local function SimulateReload(tool)
    if not tool or not tool.Parent then return end
    local method = _S.AutoReloadMethod or "ReEquip"
    if method == "KeyR" or method == "Both" then
        pcall(function()
            local ok, vim = pcall(function() return game:GetService("VirtualInputManager") end)
            if ok and vim then
                vim:SendKeyEvent(true,  Enum.KeyCode.R, false, game)
                task.wait(0.05)
                vim:SendKeyEvent(false, Enum.KeyCode.R, false, game)
            end
        end)
    end
    if method == "ReEquip" or method == "Both" then
        pcall(function()
            local char = LocalPlayer.Character if not char then return end
            local humanoid = char:FindFirstChildOfClass("Humanoid") if not humanoid then return end
            local backpack = LocalPlayer.Backpack if not backpack then return end
            local toolName = tool.Name
            humanoid:UnequipTools()
            task.wait(0.04)
            local foundTool = backpack:FindFirstChild(toolName)
            if foundTool then humanoid:EquipTool(foundTool) end
        end)
    end
end

local function CheckAutoReload()
    if not _S.AutoReloadEnabled then return end
    local char = LocalPlayer.Character if not char then return end
    local tool = char:FindFirstChildOfClass("Tool") if not tool then return end
    if not _S.WeaponsEnabled[tool.Name] then return end
    local ammo = tool:FindFirstChild(_S.AmmoName) if not ammo or not ammo:IsA("IntValue") then return end
    local now = tick()
    local toolKey = tostring(tool) .. "_" .. tool.Name
    if _S.ReloadCooldown[toolKey] and (now - _S.ReloadCooldown[toolKey]) < AUTO_RELOAD_COOLDOWN then return end
    if ammo.Value == 0 then
        _S.ReloadCooldown[toolKey] = now
        local capturedTool = tool
        task.spawn(function()
            task.wait(_S.AutoReloadDelay or 0.15)
            SimulateReload(capturedTool)
        end)
    end
end

local function connectAmmoWatcher(char)
    if not char then return end
    local function watchTool(tool)
        if not tool or not tool.Name then return end
        if not _S.WeaponsEnabled then return end
        if not _S.WeaponsEnabled[tool.Name] then return end
        local ammo = tool:FindFirstChild(_S.AmmoName)
        if not ammo or not ammo:IsA("IntValue") then return end
        ammo.Changed:Connect(function(newVal)
            if not _S.AutoReloadEnabled or newVal ~= 0 then return end
            local toolKey = tostring(tool) .. "_" .. tool.Name
            local now = tick()
            if _S.ReloadCooldown[toolKey] and (now - _S.ReloadCooldown[toolKey]) < AUTO_RELOAD_COOLDOWN then return end
            _S.ReloadCooldown[toolKey] = now
            local capturedTool = tool
            task.spawn(function()
                task.wait(_S.AutoReloadDelay or 0.15)
                SimulateReload(capturedTool)
            end)
        end)
    end
    for _, obj in ipairs(char:GetChildren()) do
        if obj and obj.IsA and obj:IsA("Tool") then watchTool(obj) end
    end
    char.ChildAdded:Connect(function(obj)
        if not obj or not obj.IsA then return end
        local ok = pcall(function() return obj:IsA("Tool") end)
        if not ok then return end
        if obj:IsA("Tool") then
            local capturedObj = obj
            task.spawn(function()
                task.wait(0.05)
                if capturedObj and capturedObj.Parent then
                    watchTool(capturedObj)
                end
            end)
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(connectAmmoWatcher)
if LocalPlayer.Character then connectAmmoWatcher(LocalPlayer.Character) end

local function SimulateClick()
    pcall(function()
        task.wait(_S.DelayBeforeShot)
        mouse1press()
        if _S.AutoShootRandomDelay then
            local randomDelay = _S.AutoShootMinDelay + math.random() * (_S.AutoShootMaxDelay - _S.AutoShootMinDelay)
            task.wait(randomDelay)
        else
            task.wait(0.025 + math.random() * 0.015)
        end
        mouse1release()
    end)
end

local function CheckShot()
    if not _S.Monitoring or not _S.StarterPlayer then return end
    -- ФИКС: AutoShot работает ТОЛЬКО на Target
    if not IsLegitTarget(_S.StarterPlayer) then return end
    local char = _S.StarterPlayer.Character if not char then return end
    local tool = char:FindFirstChildOfClass("Tool") if not tool then return end
    if not _S.WeaponsEnabled then return end
    local toolName = tool.Name if not _S.WeaponsEnabled[toolName] then return end
    local ammo = tool:FindFirstChild(_S.AmmoName) if not ammo or not ammo:IsA("IntValue") then return end
    local curr = ammo.Value local prev = _S.LastAmmoPerTool[tool]
    if prev ~= nil and curr < prev then
        if _S.AutoShootBurstShots > 1 then
            task.spawn(function()
                for i = 1, _S.AutoShootBurstShots do
                    SimulateClick()
                    if i < _S.AutoShootBurstShots then task.wait(_S.AutoShootBurstDelay) end
                end
            end)
        else
            SimulateClick()
        end
    end
    _S.LastAmmoPerTool[tool] = curr
end

-- ====================== AIMLOCK FOV CIRCLE ======================
local aimLockFovCircle = Drawing.new("Circle")
aimLockFovCircle.Visible = false
aimLockFovCircle.Thickness = 1.5
aimLockFovCircle.Color = Color3.fromRGB(180, 100, 255)
aimLockFovCircle.Filled = false
aimLockFovCircle.NumSides = 64

-- ====================== AIMLOCK FUNCTION ======================
local function GetClosestTargetForAim()
    local closestPlayer = nil
    local closestDistance = _S.AimLockFOVEnabled and _S.AimLockFOV or math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local camera = workspace.CurrentCamera
    for _, player in ipairs(Players:GetPlayers()) do
        -- ФИКС: AimLock ищет ТОЛЬКО игроков с ролью Target
        if player ~= LocalPlayer and IsLegitTarget(player) and player.Character then
            local humanoid = player.Character:FindFirstChildWhichIsA("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local head = player.Character:FindFirstChild("Head")
                if head then
                    local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function UpdateAimLock()
    if not _S.AimLockEnabled then
        _S.AimLockLockedTarget = nil
        aimLockFovCircle.Visible = false
        return
    end
    if _S.ShowAimLockFOVCircle then
        local center = UserInputService:GetMouseLocation()
        aimLockFovCircle.Position = center
        aimLockFovCircle.Radius = _S.AimLockFOV
        aimLockFovCircle.Visible = true
    else
        aimLockFovCircle.Visible = false
    end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        _S.AimLockLockedTarget = nil
        return
    end
    -- ФИКС: проверяем, что цель всё ещё Target
    local targetValid = _S.AimLockLockedTarget
        and _S.AimLockLockedTarget.Parent
        and _S.AimLockLockedTarget.Character
        and IsPlayerAlive(_S.AimLockLockedTarget)
        and IsLegitTarget(_S.AimLockLockedTarget)
    if not targetValid then
        _S.AimLockLockedTarget = GetClosestTargetForAim()
    end
    local target = _S.AimLockLockedTarget
    if target and target.Character then
        local head = target.Character:FindFirstChild("Head")
        if head then
            local targetCF = CFrame.new(Camera.CFrame.Position, head.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, 1 / _S.AimLockSmooth)
        end
    end
end

local function CheckTripleShot()
    if not _S.TripleShotEnabled then return end
    local char = LocalPlayer.Character if not char then return end
    local tool = char:FindFirstChildOfClass("Tool") if not tool or tool.Name ~= "[Double-Barrel SG]" then return end
    local ammo = tool:FindFirstChild(_S.AmmoName) if not ammo or not ammo:IsA("IntValue") then return end
    local curr = ammo.Value local prev = _S.LastAmmoPerTool[tool] or curr
    if prev ~= nil and curr < prev then
        local humanoid = char:FindFirstChild("Humanoid") if not humanoid then return end
        local backpack = LocalPlayer.Backpack
        local weapons = {"[Shotgun]", "[TacticalShotgun]", "[Revolver]"}
        for _, wpnName in ipairs(weapons) do
            local wpn = backpack:FindFirstChild(wpnName)
            if wpn then humanoid:EquipTool(wpn) task.wait(0.0000000000000000001) SimulateClick() end
        end
        local doublebarrel = backpack:FindFirstChild("[Double-Barrel SG]")
        if doublebarrel then humanoid:EquipTool(doublebarrel) end
    end
    _S.LastAmmoPerTool[tool] = curr
end

local function UpdateFastGun()
    if _S.FastGunConnection then _S.FastGunConnection:Disconnect() _S.FastGunConnection = nil end
    if _S.FastGunEnabled then
        _S.FastGunConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    local char = LocalPlayer.Character if not char then return end
                    local tool = char:FindFirstChildOfClass("Tool") if not tool then return end
                    if not _S.WeaponsEnabled[tool.Name] then return end
                    mouse1press() task.wait(0.01) mouse1release() task.wait(_S.FastGunDelay)
                end
            end)
        end)
    end
end

local function UpdateHitboxesNEW()
    -- Хитбоксы обновляются через RenderStepped только для Target
end

local function GetClosestPlayerToCrosshair()
    local camera = workspace.CurrentCamera local mouseLoc = UserInputService:GetMouseLocation()
    local closest, dist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
            local head = plr.Character.Head local sp, onScreen = camera:WorldToViewportPoint(head.Position)
            if onScreen then local d = (Vector2.new(sp.X, sp.Y) - mouseLoc).Magnitude if d < dist then dist = d closest = plr end end
        end
    end
    return closest
end

local function RemoveEmoji()
    if _S.SelectedHostEmoji then pcall(function() _S.SelectedHostEmoji:Destroy() end) _S.SelectedHostEmoji = nil end
end

local function AttachEmojiToPlayer(plr)
    RemoveEmoji()
    if not plr or not _S.ShowTargetEmoji then return end
    local char = plr.Character
    if not char then
        plr.CharacterAdded:Once(function() task.wait(0.5) if plr == _S.StarterPlayer then AttachEmojiToPlayer(plr) end end)
        return
    end
    local head = char:WaitForChild("Head", 3) if not head then return end
    local bg = Instance.new("BillboardGui") bg.Name = "TargetEmoji_" .. plr.UserId bg.Adornee = head
    bg.Size = UDim2.new(0, 60, 0, 60) bg.StudsOffset = Vector3.new(0, 2.5, 0) bg.AlwaysOnTop = true
    bg.ResetOnSpawn = false bg.Parent = game.CoreGui
    local lbl = Instance.new("TextLabel", bg) lbl.Size = UDim2.new(1,0,1,0) lbl.BackgroundTransparency = 1
    lbl.Text = "🎯" lbl.TextColor3 = Color3.fromRGB(255,215,0) lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold lbl.TextStrokeTransparency = 0 lbl.TextStrokeColor3 = Color3.new(0,0,0)
    _S.SelectedHostEmoji = bg
end

local oldStarter = nil
RunService.RenderStepped:Connect(function()
    if _S.StarterPlayer ~= oldStarter then oldStarter = _S.StarterPlayer AttachEmojiToPlayer(_S.StarterPlayer) end
end)

Players.PlayerRemoving:Connect(function(plr)
    if plr == _S.StarterPlayer then _S.StarterPlayer = nil RemoveEmoji() end
end)

Players.PlayerAdded:Connect(function(plr)
    if not _S.PlayerRoles[plr.UserId] then
        _S.PlayerRoles[plr.UserId] = GetDefaultRole()
    end
    plr.CharacterAdded:Connect(function()
        task.wait(1) if plr == _S.StarterPlayer and _S.ShowTargetEmoji then AttachEmojiToPlayer(plr) end
    end)
end)

UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == _S.SelectHostKey1 then _S.key1Down = true end
    if inp.KeyCode == _S.SelectHostKey2 then _S.key2Down = true end
    if _S.key1Down and _S.key2Down and _S.HostSelectHotkeyEnabled then
        local closest = GetClosestPlayerToCrosshair()
        if closest then
            if _S.StarterPlayer == closest then _S.StarterPlayer = nil RemoveEmoji()
            else
                if _S.AllowFriendsAsHost or not IsFriend(closest) then
                    _S.StarterPlayer = closest _S.LastAmmoPerTool = {} AttachEmojiToPlayer(closest)
                end
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.KeyCode == _S.SelectHostKey1 then _S.key1Down = false end
    if inp.KeyCode == _S.SelectHostKey2 then _S.key2Down = false end
end)

-- ====================== MOD DETECTOR FUNCTIONS ======================
local function playAlertSound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://".._S.alertSoundId sound.Volume = 10 sound.Parent = workspace sound:Play()
    game:GetService("Debris"):AddItem(sound, 6)
end

local function hasModSymbols(name)
    for _, sym in ipairs(_S.MOD_SYMBOLS) do if string.find(name, sym) then return true end end
    return false
end

local function isBoomFFAMod(player)
    local nameLower = player.Name:lower()
    local displayLower = player.DisplayName:lower()
    if _S.MOD_USERNAMES[nameLower] or _S.MOD_USERNAMES[displayLower] then
        return true, "Known Mod"
    end
    if hasModSymbols(player.Name) or hasModSymbols(player.DisplayName) then
        return true, "Mod Symbol"
    end
    for _, groupId in ipairs(_S.MOD_GROUP_IDS) do
        local ok, inGroup = pcall(function() return player:IsInGroup(groupId) end)
        if ok and inGroup then
            local roleName = "GroupMember"
            local rankOk, rank = pcall(function() return player:GetRankInGroup(groupId) end)
            local roleOk, role = pcall(function() return player:GetRoleInGroup(groupId) end)
            if roleOk and role then roleName = role end
            if rankOk and rank >= _S.MOD_MIN_RANK then
                return true, roleName .. " [Rank:" .. tostring(rank) .. "]"
            end
        end
    end
    return false, nil
end

_S.modVisualEnabled = true
_S.modDetectorEnabled = true

local function clearAllModESP()
    for player, data in pairs(_S.activeESP) do
        if data then
            if data.label then pcall(function() data.label.Visible = false if data.label.Remove then data.label:Remove() end end) end
            if data.box then pcall(function() data.box.Visible = false if data.box.Remove then data.box:Remove() end end) end
            if data.tracer then pcall(function() data.tracer.Visible = false if data.tracer.Remove then data.tracer:Remove() end end) end
        end
    end
    _S.activeESP = {}
    _S.notifiedPlayers = {}
end

local function clearModESPForPlayer(player)
    local data = _S.activeESP[player]
    if data then
        if data.label then pcall(function() data.label.Visible = false if data.label.Remove then data.label:Remove() end end) end
        if data.box then pcall(function() data.box.Visible = false if data.box.Remove then data.box:Remove() end end) end
        if data.tracer then pcall(function() data.tracer.Visible = false if data.tracer.Remove then data.tracer:Remove() end end) end
        _S.activeESP[player] = nil
    end
end

local function createModESP(player, role)
    clearModESPForPlayer(player)
    local label = Drawing.new("Text")
    label.Visible = false label.Center = true label.Outline = true label.Size = 18 label.Color = _S.VisualColors.ModESP.Text label.Font = 3
    local box = Drawing.new("Square")
    box.Visible = false box.Thickness = 2 box.Color = _S.VisualColors.ModESP.Box box.Filled = false
    local tracer = Drawing.new("Line")
    tracer.Visible = false tracer.Thickness = 1.5 tracer.Color = _S.VisualColors.ModESP.Tracer
    _S.activeESP[player] = { label = label, box = box, tracer = tracer, role = role, isMod = true }
    if role == "Reported" then addModToSaved(player.UserId, player.Name, "Reported") end
    return _S.activeESP[player]
end

local function updateModESP()
    if not _S.modVisualEnabled then
        for player, data in pairs(_S.activeESP) do
            if data then
                if data.label then data.label.Visible = false end
                if data.box then data.box.Visible = false end
                if data.tracer then data.tracer.Visible = false end
            end
        end
        return
    end
    for player, data in pairs(_S.activeESP) do
        if player and player.Parent and player.Character and player.Character:FindFirstChild("Head") and data.isMod then
            local head = player.Character.Head
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart") or head
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local isAlive = humanoid and humanoid.Health > 0
            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            local rootPos, rootOnScreen = Camera:WorldToViewportPoint(rootPart.Position)
            if onScreen and isAlive then
                data.label.Position = Vector2.new(screenPos.X, screenPos.Y-30)
                data.label.Text = "🚨 MOD: "..player.Name.." ["..data.role.."]"
                data.label.Visible = true
                if data.box then
                    local headSP = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local feetSP = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
                    local boxHeight = math.max(math.abs(headSP.Y - feetSP.Y), 10)
                    local boxWidth = boxHeight / 2
                    local boxX = headSP.X - boxWidth / 2
                    local boxY = headSP.Y - boxHeight * 0.1
                    data.box.Size = Vector2.new(boxWidth, boxHeight)
                    data.box.Position = Vector2.new(boxX, boxY)
                    data.box.Visible = true
                end
                if data.tracer and rootOnScreen then
                    data.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                    data.tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                    data.tracer.Visible = true
                end
            else
                data.label.Visible = false
                if data.box then data.box.Visible = false end
                if data.tracer then data.tracer.Visible = false end
            end
        else
            if data then
                if data.label then pcall(function() data.label.Visible = false if data.label.Remove then data.label:Remove() end end) end
                if data.box then pcall(function() data.box.Visible = false if data.box.Remove then data.box:Remove() end end) end
                if data.tracer then pcall(function() data.tracer.Visible = false if data.tracer.Remove then data.tracer:Remove() end end) end
            end
            _S.activeESP[player] = nil
        end
    end
end

local function detectMods()
    if not _S.modDetectorEnabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if _S.savedMods[player.UserId] then
            local savedData = _S.savedMods[player.UserId]
            if not _S.activeESP[player] or not _S.activeESP[player].isMod then
                createModESP(player, "Saved ["..savedData.date.."]")
            end
            _S.notifiedPlayers[player.UserId] = true
        end
        if not _S.savedMods[player.UserId] then
            local isMod, roleDisplay = isBoomFFAMod(player)
            if isMod then
                if not _S.activeESP[player] or not _S.activeESP[player].isMod then
                    createModESP(player, roleDisplay or "Staff")
                end
                _S.notifiedPlayers[player.UserId] = true
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(player)
    clearModESPForPlayer(player)
end)

local function onCharacterAdded(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then onCharacterAdded(player) end
end

Players.PlayerAdded:Connect(onCharacterAdded)

task.spawn(function()
    task.wait(1)
    _S.modDetectorEnabled = true
    _S.modVisualEnabled = true
    detectMods()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and _S.savedMods[player.UserId] then
            createModESP(player, "Saved [".._S.savedMods[player.UserId].date.."]")
            _S.notifiedPlayers[player.UserId] = true
        end
    end
    updateModESP()
end)

local function checkAllPlayersForSavedMods()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and _S.savedMods[player.UserId] then
            createModESP(player, "Saved [".._S.savedMods[player.UserId].date.."]")
            _S.notifiedPlayers[player.UserId] = true
        end
    end
end

task.spawn(function()
    task.wait(3)
    checkAllPlayersForSavedMods()
end)

Players.PlayerAdded:Connect(function(player)
    task.wait(3)
    if _S.savedMods[player.UserId] then
        createModESP(player, "Saved [".._S.savedMods[player.UserId].date.."]")
        _S.notifiedPlayers[player.UserId] = true
        if _S.modDetectorEnabled then playAlertSound() end
    end
end)

-- ====================== GUI ======================
local gui = Instance.new("ScreenGui")
gui.Name = "UkussiaAutoShot" gui.ResetOnSpawn = false gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local function corner(obj, r)
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 8) c.Parent = obj
end

local main = Instance.new("Frame", gui)
main.Size = UDim2.fromOffset(760, 520) main.Position = UDim2.new(0.5, -380, 0.5, -260)
main.AnchorPoint = Vector2.new(0.5, 0.5) main.BackgroundColor3 = _S.Theme.Background
main.BorderSizePixel = 0 main.ClipsDescendants = true corner(main, 14)

local top = Instance.new("Frame", main)
top.Size = UDim2.new(1,0,0,56) top.BackgroundColor3 = _S.Theme.TopBar corner(top, 14)

local title = Instance.new("TextLabel", top)
title.Size = UDim2.new(1,-70,1,0) title.Position = UDim2.fromOffset(16,0) title.BackgroundTransparency = 1
title.Text = "Ukussia v14" title.Font = Enum.Font.GothamSemibold title.TextSize = 20
title.TextColor3 = _S.Theme.TitleText title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", top)
closeBtn.Size = UDim2.fromOffset(36,36) closeBtn.Position = UDim2.new(1,-46,0,10)
closeBtn.Text = "×" closeBtn.Font = Enum.Font.GothamBold closeBtn.TextSize = 24
closeBtn.TextColor3 = Color3.fromRGB(180,180,190) closeBtn.BackgroundColor3 = _S.Theme.CloseBtn corner(closeBtn, 18)
closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = _S.Theme.CloseBtnHover, TextColor3 = Color3.fromRGB(255,255,255)}):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = _S.Theme.CloseBtn, TextColor3 = Color3.fromRGB(180,180,190)}):Play() end)

local dragging = false local dragStart, startPos
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true dragStart = input.Position startPos = main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local tabsFrame = Instance.new("Frame", main)
tabsFrame.Position = UDim2.fromOffset(14,64) tabsFrame.Size = UDim2.new(0,140,1,-78) tabsFrame.BackgroundTransparency = 1
local tabLayout = Instance.new("UIListLayout", tabsFrame) tabLayout.Padding = UDim.new(0,6) tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", tabsFrame).PaddingTop = UDim.new(0,8)

local pages = Instance.new("Frame", main)
pages.Position = UDim2.fromOffset(170,64) pages.Size = UDim2.new(1,-184,1,-78)
pages.BackgroundTransparency = 1 pages.ClipsDescendants = true

local function createPage()
    local p = Instance.new("ScrollingFrame", pages)
    p.Size = UDim2.new(1,0,1,0) p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.ScrollBarThickness = 3 p.ScrollBarImageColor3 = _S.Theme.Accent
    p.BackgroundTransparency = 1 p.Visible = false p.Position = UDim2.new(0, 20, 0, 0)
    local l = Instance.new("UIListLayout", p) l.Padding = UDim.new(0,12)
    local pad = Instance.new("UIPadding", p) pad.PaddingTop = UDim.new(0,8) pad.PaddingLeft = UDim.new(0,8) pad.PaddingRight = UDim.new(0,8)
    local function updateScroll()
        local canScroll = p.AbsoluteCanvasSize.Y > p.AbsoluteSize.Y
        p.ScrollBarThickness = canScroll and 3 or 0 p.ScrollingEnabled = canScroll
    end
    p:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateScroll)
    p:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScroll)
    return p
end

local currentPage = nil local isSwitching = false
local function switchToPage(newPage)
    if newPage == currentPage or isSwitching then return end
    isSwitching = true
    local function showNew()
        newPage.Position = UDim2.new(0, 18, 0, 0) newPage.BackgroundTransparency = 1 newPage.Visible = true
        if _S.Animations.TabSlide then
            TweenService:Create(newPage, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
        else newPage.Position = UDim2.new(0, 0, 0, 0) end
        task.delay(0.05, function() isSwitching = false end) currentPage = newPage
    end
    if currentPage then
        local oldPage = currentPage
        if _S.Animations.TabSlide then
            local tweenOut = TweenService:Create(oldPage, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(0, -18, 0, 0)})
            tweenOut:Play()
            tweenOut.Completed:Connect(function() oldPage.Visible = false oldPage.Position = UDim2.new(0, 20, 0, 0) showNew() end)
        else oldPage.Visible = false oldPage.Position = UDim2.new(0, 20, 0, 0) showNew() end
    else showNew() isSwitching = false end
end

local HEADER_H = 36 local SECTION_GAP = 8
local function createSection(parent, text)
    local wrapper = Instance.new("Frame", parent)
    wrapper.BackgroundTransparency = 1 wrapper.Size = UDim2.new(1, 0, 0, HEADER_H) wrapper.ClipsDescendants = true
    local header = Instance.new("TextButton", wrapper)
    header.Size = UDim2.new(1, 0, 0, HEADER_H) header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = _S.Theme.Section header.Text = "" header.AutoButtonColor = false corner(header, 10)
    local titleLabel = Instance.new("TextLabel", header)
    titleLabel.Size = UDim2.new(1,-40,1,0) titleLabel.Position = UDim2.fromOffset(12,0) titleLabel.BackgroundTransparency = 1
    titleLabel.Text = text titleLabel.Font = Enum.Font.GothamSemibold titleLabel.TextSize = 14
    titleLabel.TextColor3 = _S.Theme.SectionTitle titleLabel.TextXAlignment = Enum.TextXAlignment.Left titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    local arrow = Instance.new("TextLabel", header)
    arrow.Size = UDim2.new(0,24,1,0) arrow.Position = UDim2.new(1,-34,0,0) arrow.BackgroundTransparency = 1
    arrow.Text = "▼" arrow.Font = Enum.Font.GothamBold arrow.TextSize = 20 arrow.TextColor3 = _S.Theme.SectionTitle arrow.Rotation = -90
    local normalColor = _S.Theme.Section local hoverColor = Color3.fromRGB(36,36,50)
    header.MouseEnter:Connect(function()
        if not _S.Animations.ButtonHover then header.BackgroundColor3 = hoverColor return end
        TweenService:Create(header, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = hoverColor}):Play()
    end)
    header.MouseLeave:Connect(function()
        if not _S.Animations.ButtonHover then header.BackgroundColor3 = normalColor return end
        TweenService:Create(header, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = normalColor}):Play()
    end)
    local content = Instance.new("Frame", wrapper)
    content.BackgroundTransparency = 1 content.Position = UDim2.new(0, 0, 0, HEADER_H + SECTION_GAP)
    content.Size = UDim2.new(1, 0, 0, 0) content.AutomaticSize = Enum.AutomaticSize.Y
    local contentLayout = Instance.new("UIListLayout", content) contentLayout.Padding = UDim.new(0, 12)
    local contentPad = Instance.new("UIPadding", content)
    contentPad.PaddingLeft = UDim.new(0, 8) contentPad.PaddingRight = UDim.new(0, 8)
    contentPad.PaddingTop = UDim.new(0, 4) contentPad.PaddingBottom = UDim.new(0, 8)
    local isOpen = false local animTween = nil
    local function getFullHeight() return HEADER_H + SECTION_GAP + content.AbsoluteSize.Y end
    local function open()
        isOpen = true if animTween then animTween:Cancel() end task.wait()
        local targetH = getFullHeight()
        if _S.Animations.SectionCollapse then
            animTween = TweenService:Create(wrapper, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, targetH) }) animTween:Play()
            TweenService:Create(arrow, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 0}):Play()
        else wrapper.Size = UDim2.new(1, 0, 0, targetH) arrow.Rotation = 0 end
    end
    local function close()
        isOpen = false if animTween then animTween:Cancel() end
        if _S.Animations.SectionCollapse then
            animTween = TweenService:Create(wrapper, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Size = UDim2.new(1, 0, 0, HEADER_H) }) animTween:Play()
            TweenService:Create(arrow, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Rotation = -90}):Play()
        else wrapper.Size = UDim2.new(1, 0, 0, HEADER_H) arrow.Rotation = -90 end
    end
    header.MouseButton1Click:Connect(function() if isOpen then close() else open() end end)
    return content, function() task.delay(0.08, function() open() end) end
end

local pageLegit = createPage() local pageMisc = createPage() local pagePlayerList = createPage()
local pageMovement = createPage() local pageVisual = createPage() local pageBind = createPage() local pageMenu = createPage()
local allTabs = {}

local function createTab(name, page)
    local b = Instance.new("TextButton", tabsFrame)
    b.Size = UDim2.new(1,-12,0,44) b.BackgroundColor3 = _S.Theme.TabInactive
    b.Text = name b.Font = Enum.Font.GothamSemibold b.TextColor3 = Color3.fromRGB(190,190,210)
    b.TextSize = 15 b.AutoButtonColor = false corner(b,10)
    local stroke = Instance.new("UIStroke", b) stroke.Color = Color3.fromRGB(70,70,100) stroke.Thickness = 1.4 stroke.Transparency = 0.65
    local ind = Instance.new("Frame", b) ind.Size = UDim2.new(0,4,0.5,0) ind.Position = UDim2.new(0,-2,0.25,0) ind.BackgroundColor3 = _S.Theme.Accent corner(ind,2) ind.Visible = false
    local function setActive(active)
        if active then
            if _S.Animations.ButtonHover then TweenService:Create(b, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = _S.Theme.TabActive, TextColor3 = Color3.fromRGB(240,240,255)}):Play()
            else b.BackgroundColor3 = _S.Theme.TabActive b.TextColor3 = Color3.fromRGB(240,240,255) end
            stroke.Transparency = 0.2 stroke.Color = _S.Theme.Accent ind.Visible = true
        else
            if _S.Animations.ButtonHover then TweenService:Create(b, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = _S.Theme.TabInactive, TextColor3 = Color3.fromRGB(190,190,210)}):Play()
            else b.BackgroundColor3 = _S.Theme.TabInactive b.TextColor3 = Color3.fromRGB(190,190,210) end
            stroke.Transparency = 0.65 stroke.Color = Color3.fromRGB(70,70,100) ind.Visible = false
        end
    end
    b.MouseEnter:Connect(function()
        local isActive = false
        for _, t in ipairs(allTabs) do if t.Page == page and t.Page.Visible then isActive = true break end end
        if not isActive then if _S.Animations.ButtonHover then TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(40,40,54)}):Play() else b.BackgroundColor3 = Color3.fromRGB(40,40,54) end end
    end)
    b.MouseLeave:Connect(function()
        local isActive = false
        for _, t in ipairs(allTabs) do if t.Page == page and t.Page.Visible then isActive = true break end end
        if not isActive then if _S.Animations.ButtonHover then TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = _S.Theme.TabInactive}):Play() else b.BackgroundColor3 = _S.Theme.TabInactive end end
    end)
    table.insert(allTabs, {Page = page, SetActive = setActive})
    b.MouseButton1Click:Connect(function()
        for _, t in ipairs(allTabs) do t.SetActive(false) end setActive(true) switchToPage(page)
    end)
    return b
end

createTab("Legit", pageLegit) createTab("Misc", pageMisc) createTab("Player list", pagePlayerList)
createTab("Movment", pageMovement) createTab("Visual", pageVisual) createTab("Bind", pageBind) createTab("Menu", pageMenu)

local function createToggle(parent, text, def, cb)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,0,0,50) f.BackgroundColor3 = _S.Theme.Section corner(f,10)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -85, 1, 0) l.Position = UDim2.fromOffset(12,0) l.BackgroundTransparency = 1
    l.Text = text l.TextColor3 = _S.Theme.LabelText l.TextSize = 15 l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left l.TextTruncate = Enum.TextTruncate.AtEnd
    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(0,60,0,30) btn.Position = UDim2.new(1, -72, 0.5, -15)
    btn.BackgroundColor3 = def and _S.Theme.ToggleOn or _S.Theme.ToggleOff
    btn.Text = def and "ON" or "OFF" btn.TextColor3 = Color3.new(1,1,1) btn.Font = Enum.Font.GothamBold btn.TextSize = 14 corner(btn,15)
    btn.MouseEnter:Connect(function() if not _S.Animations.ButtonHover then return end TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 64, 0, 32)}):Play() end)
    btn.MouseLeave:Connect(function() if not _S.Animations.ButtonHover then return end TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 60, 0, 30)}):Play() end)
    local v = def
    btn.MouseButton1Click:Connect(function()
        v = not v btn.Text = v and "ON" or "OFF"
        if _S.Animations.ToggleColor then TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = v and _S.Theme.ToggleOn or _S.Theme.ToggleOff}):Play()
        else btn.BackgroundColor3 = v and _S.Theme.ToggleOn or _S.Theme.ToggleOff end
        cb(v)
    end)
    return f, btn
end

local _activeSliderCb = nil
local _sliderDragConn = nil

local function createSlider(parent, text, min, max, def, step, fmt, cb)
    if not cb then cb = function() end end
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,0,0,70) f.BackgroundColor3 = _S.Theme.Section corner(f,10)
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1,0,0,20) lbl.Position = UDim2.fromOffset(12,5) lbl.BackgroundTransparency = 1
    lbl.Text = text .. ": " .. string.format(fmt or "%.2f", def) lbl.TextColor3 = Color3.fromRGB(180,180,200)
    lbl.TextSize = 14 lbl.Font = Enum.Font.Gotham lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.TextTruncate = Enum.TextTruncate.AtEnd
    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(1,-24,0,8) bar.Position = UDim2.fromOffset(12,35) bar.BackgroundColor3 = Color3.fromRGB(60,60,70) corner(bar,4)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((def-min)/(max-min),0,1,0) fill.BackgroundColor3 = _S.Theme.SliderFill corner(fill,4)
    local knob = Instance.new("TextButton", bar)
    knob.Size = UDim2.new(0,20,0,20) knob.Position = UDim2.new((def-min)/(max-min),-10,0.5,-10)
    knob.BackgroundColor3 = _S.Theme.SliderKnob knob.Text = "" corner(knob,10)
    knob.MouseEnter:Connect(function()
        if not _S.Animations.SliderKnob then return end
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(150,255,210), Size = UDim2.new(0,24,0,24)}):Play()
    end)
    knob.MouseLeave:Connect(function()
        if not _S.Animations.SliderKnob then return end
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = _S.Theme.SliderKnob, Size = UDim2.new(0,20,0,20)}):Play()
    end)
    local drag = false
    local function onMouseMove(i)
        if not drag then return end
        pcall(function()
            local barPos = bar.AbsolutePosition
            local barSize = bar.AbsoluteSize
            if barSize.X == 0 then return end
            local rel = math.clamp((i.Position.X - barPos.X) / barSize.X, 0, 1)
            knob.Position = UDim2.new(rel, -10, 0.5, -10)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            local val = min + rel * (max - min)
            val = math.floor(val / step + 0.5) * step
            val = math.clamp(val, min, max)
            lbl.Text = text .. ": " .. string.format(fmt or "%.2f", val)
            pcall(cb, val)
        end)
    end
    knob.MouseButton1Down:Connect(function()
        drag = true
        if _sliderDragConn then _sliderDragConn:Disconnect() end
        _sliderDragConn = UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement then
                onMouseMove(i)
            end
        end)
    end)
    local function stopDrag()
        drag = false
        if _sliderDragConn then
            _sliderDragConn:Disconnect()
            _sliderDragConn = nil
        end
    end
    knob.MouseButton1Up:Connect(stopDrag)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            stopDrag()
        end
    end)
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            onMouseMove(i)
        end
    end)
end

local function createColorPicker(parent, label, initColor, onChanged)
    local wrapper = Instance.new("Frame", parent)
    wrapper.Size = UDim2.new(1,0,0,130) wrapper.BackgroundColor3 = _S.Theme.Section corner(wrapper,10)
    local titleLbl = Instance.new("TextLabel", wrapper)
    titleLbl.Size = UDim2.new(1,-120,0,26) titleLbl.Position = UDim2.fromOffset(12,6) titleLbl.BackgroundTransparency = 1
    titleLbl.Text = label titleLbl.Font = Enum.Font.GothamSemibold titleLbl.TextSize = 13 titleLbl.TextColor3 = _S.Theme.SectionTitle titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    local preview = Instance.new("Frame", wrapper)
    preview.Size = UDim2.new(0,60,0,26) preview.Position = UDim2.new(1,-78,0,6) preview.BackgroundColor3 = initColor corner(preview,6)
    local previewStroke = Instance.new("UIStroke", preview) previewStroke.Color = Color3.fromRGB(80,80,100) previewStroke.Thickness = 1
    local r,g,b = math.floor(initColor.R*255+0.5), math.floor(initColor.G*255+0.5), math.floor(initColor.B*255+0.5)
    local function makeRGBSlider(offsetY, channel, initVal, changedCb)
        local names = {"R","G","B"}
        local colors = {Color3.fromRGB(220,80,80), Color3.fromRGB(80,220,80), Color3.fromRGB(80,120,255)}
        local lbl2 = Instance.new("TextLabel",wrapper)
        lbl2.Size=UDim2.new(0,16,0,16) lbl2.Position=UDim2.fromOffset(12,offsetY) lbl2.BackgroundTransparency=1
        lbl2.Text=names[channel] lbl2.Font=Enum.Font.GothamBold lbl2.TextSize=12 lbl2.TextColor3=colors[channel]
        local valLbl = Instance.new("TextLabel",wrapper)
        valLbl.Size=UDim2.new(0,30,0,16) valLbl.Position=UDim2.new(1,-42,0,offsetY) valLbl.BackgroundTransparency=1
        valLbl.Text=tostring(initVal) valLbl.Font=Enum.Font.GothamBold valLbl.TextSize=12
        valLbl.TextColor3=Color3.fromRGB(200,200,220) valLbl.TextXAlignment=Enum.TextXAlignment.Right
        local bar = Instance.new("Frame",wrapper)
        bar.Size=UDim2.new(1,-60,0,8) bar.Position=UDim2.new(0,30,0,offsetY+4) bar.BackgroundColor3=Color3.fromRGB(50,50,60) corner(bar,4)
        local fill = Instance.new("Frame",bar)
        fill.Size=UDim2.new(initVal/255,0,1,0) fill.BackgroundColor3=colors[channel] corner(fill,4)
        local knob = Instance.new("TextButton",bar)
        knob.Size=UDim2.new(0,14,0,14) knob.Position=UDim2.new(initVal/255,-7,0.5,-7)
        knob.BackgroundColor3=Color3.fromRGB(230,230,240) knob.Text="" corner(knob,7)
        local dragging2 = false
        local function onMove(i)
            if not dragging2 then return end
            pcall(function()
                local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                local val = math.floor(rel * 255 + 0.5)
                knob.Position = UDim2.new(rel,-7,0.5,-7)
                fill.Size = UDim2.new(rel,0,1,0)
                valLbl.Text = tostring(val)
                changedCb(val)
            end)
        end
        local dragConn2 = nil
        knob.MouseButton1Down:Connect(function()
            dragging2 = true
            if dragConn2 then dragConn2:Disconnect() end
            dragConn2 = UserInputService.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement then
                    onMove(i)
                end
            end)
        end)
        local function stopDrag2()
            dragging2 = false
            if dragConn2 then dragConn2:Disconnect() dragConn2 = nil end
        end
        knob.MouseButton1Up:Connect(stopDrag2)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                stopDrag2()
            end
        end)
        bar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                onMove(i)
            end
        end)
    end
    makeRGBSlider(34,1,r,function(val) r=val local c=Color3.fromRGB(r,g,b) preview.BackgroundColor3=c onChanged(c) end)
    makeRGBSlider(62,2,g,function(val) g=val local c=Color3.fromRGB(r,g,b) preview.BackgroundColor3=c onChanged(c) end)
    makeRGBSlider(90,3,b,function(val) b=val local c=Color3.fromRGB(r,g,b) preview.BackgroundColor3=c onChanged(c) end)
end

-- ====================== LEGIT TAB ======================
local flyEnabled = false local flySpeed = 50 local flyConnection = nil
local flyBodyVelocity = nil local flyBodyGyro = nil

local function stopFly()
    flyEnabled = false
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if flyBodyVelocity and flyBodyVelocity.Parent then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
    if flyBodyGyro and flyBodyGyro.Parent then flyBodyGyro:Destroy() flyBodyGyro = nil end
    local char = LocalPlayer.Character if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.PlatformStand = false end end
end

local function startFly()
    flyEnabled = true
    local char = LocalPlayer.Character if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    hum.PlatformStand = true
    flyBodyVelocity = Instance.new("BodyVelocity") flyBodyVelocity.Velocity = Vector3.zero flyBodyVelocity.MaxForce = Vector3.new(1e5,1e5,1e5) flyBodyVelocity.Parent = hrp
    flyBodyGyro = Instance.new("BodyGyro") flyBodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5) flyBodyGyro.P = 1e4 flyBodyGyro.CFrame = hrp.CFrame flyBodyGyro.Parent = hrp
    flyConnection = RunService.RenderStepped:Connect(function()
        if not flyEnabled then return end
        local camCF = workspace.CurrentCamera.CFrame local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
        if flyBodyVelocity and flyBodyVelocity.Parent then flyBodyVelocity.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * flySpeed or Vector3.zero end
        if flyBodyGyro and flyBodyGyro.Parent then flyBodyGyro.CFrame = camCF end
    end)
end

local function updateSpeedFlags(state)
    _S.speedToggleState = state
    if _S.speedToggleState then
        _S.speedEnabled = (_S.speedMethod == "CFrame") _S.speedV2Enabled = (_S.speedMethod == "Velocity") _S.speedV3Enabled = (_S.speedMethod == "Impulse")
    else
        _S.speedEnabled = false _S.speedV2Enabled = false _S.speedV3Enabled = false
        pcall(function() local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0,0,0) hrp.AssemblyAngularVelocity = Vector3.new(0,0,0) end end)
        pcall(function() local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed = 16 end end)
    end
end

local function SetupLegitMiscPlayerTabs()
    -- ============= ХИТБОКСЫ =============
    local hitboxContent = createSection(pageLegit, "Hitbox Expander")

    local hitboxToggleFrame, hitboxToggleBtn = createToggle(hitboxContent, "Hitbox Expander", _S.HitboxEnabled, function(v)
        _S.HitboxEnabled = v
    end)

    local sizeLabel = Instance.new("TextLabel", hitboxContent)
    sizeLabel.Size = UDim2.new(1,-20,0,20)
    sizeLabel.BackgroundTransparency = 1
    sizeLabel.Text = string.format("Size X: %.2f Y: %.2f Z: %.2f", _S.HitboxSize.X, _S.HitboxSize.Y, _S.HitboxSize.Z)
    sizeLabel.Font = Enum.Font.GothamMedium
    sizeLabel.TextSize = 13
    sizeLabel.TextColor3 = Color3.fromRGB(170,170,170)
    sizeLabel.TextXAlignment = Enum.TextXAlignment.Left

    createSlider(hitboxContent, "Hitbox X", 2, 20, _S.HitboxSize.X, 0.1, "%.1f", function(v)
        _S.HitboxSize = Vector3.new(v, _S.HitboxSize.Y, _S.HitboxSize.Z)
        sizeLabel.Text = string.format("Size X: %.2f Y: %.2f Z: %.2f", _S.HitboxSize.X, _S.HitboxSize.Y, _S.HitboxSize.Z)
    end)
    createSlider(hitboxContent, "Hitbox Y", 2, 20, _S.HitboxSize.Y, 0.1, "%.1f", function(v)
        _S.HitboxSize = Vector3.new(_S.HitboxSize.X, v, _S.HitboxSize.Z)
        sizeLabel.Text = string.format("Size X: %.2f Y: %.2f Z: %.2f", _S.HitboxSize.X, _S.HitboxSize.Y, _S.HitboxSize.Z)
    end)
    createSlider(hitboxContent, "Hitbox Z", 2, 20, _S.HitboxSize.Z, 0.1, "%.1f", function(v)
        _S.HitboxSize = Vector3.new(_S.HitboxSize.X, _S.HitboxSize.Y, v)
        sizeLabel.Text = string.format("Size X: %.2f Y: %.2f Z: %.2f", _S.HitboxSize.X, _S.HitboxSize.Y, _S.HitboxSize.Z)
    end)
    createSlider(hitboxContent, "Transparency", 0, 1, _S.HitboxTransparency, 0.05, "%.2f", function(v)
        _S.HitboxTransparency = v
    end)

    local roleInfoFrame = Instance.new("Frame", hitboxContent)
    roleInfoFrame.Size = UDim2.new(1,0,0,36) roleInfoFrame.BackgroundColor3 = Color3.fromRGB(30,20,50) corner(roleInfoFrame,8)
    local roleInfoLabel = Instance.new("TextLabel", roleInfoFrame)
    roleInfoLabel.Size = UDim2.new(1,-12,1,0) roleInfoLabel.Position = UDim2.fromOffset(6,0) roleInfoLabel.BackgroundTransparency = 1
    -- ФИКС: обновлённое описание
    roleInfoLabel.Text = "🎯 Работает ТОЛЬКО на игроков с ролью Target (Friend/Neutral игнорируются)"
    roleInfoLabel.TextColor3 = Color3.fromRGB(200,160,255)
    roleInfoLabel.Font = Enum.Font.Gotham roleInfoLabel.TextSize = 12 roleInfoLabel.TextWrapped = true

    -- ============= TRIGGERBOT =============
    local triggerbotContent = createSection(pageLegit, "TriggerBot")

    local _, triggerToggleBtn = createToggle(triggerbotContent, "TriggerBot", _S.TriggerbotEnabled, function(v)
        _S.TriggerbotEnabled = v
        UpdateTriggerbot()
    end)

    local _, rmbOnlyToggleBtn = createToggle(triggerbotContent, "Only RMB", _S.TriggerbotRMBOnly, function(v)
        _S.TriggerbotRMBOnly = v
    end)

    createSlider(triggerbotContent, "Delay (сек)", 0, 0.1, _S.TriggerbotDelay, 0.001, "%.3f", function(v)
        _S.TriggerbotDelay = v
    end)

    createToggle(triggerbotContent, "Не стрелять в мертвых", _S.CheckDead, function(v) _S.CheckDead = v end)
    createToggle(triggerbotContent, "Проверка стен", _S.CheckWall, function(v) _S.CheckWall = v end)
    createToggle(triggerbotContent, "Не стрелять в друзей", _S.CheckFriend, function(v) _S.CheckFriend = v end)

    local triggerbotInfoFrame = Instance.new("Frame", triggerbotContent)
    triggerbotInfoFrame.Size = UDim2.new(1,0,0,50) triggerbotInfoFrame.BackgroundColor3 = Color3.fromRGB(30,20,50) corner(triggerbotInfoFrame,8)
    local triggerbotInfoLabel = Instance.new("TextLabel", triggerbotInfoFrame)
    triggerbotInfoLabel.Size = UDim2.new(1,-12,1,0) triggerbotInfoLabel.Position = UDim2.fromOffset(6,0) triggerbotInfoLabel.BackgroundTransparency = 1
    -- ФИКС: обновлённое описание
    triggerbotInfoLabel.Text = "🔫 Автоматически стреляет ТОЛЬКО при наведении на игрока с ролью Target\n(Friend и Neutral игнорируются)"
    triggerbotInfoLabel.TextColor3 = Color3.fromRGB(200,160,255)
    triggerbotInfoLabel.Font = Enum.Font.Gotham triggerbotInfoLabel.TextSize = 11 triggerbotInfoLabel.TextWrapped = true

    -- Aim Section
    local aimContent = createSection(pageLegit, "Aim")
    local _, autoBtn = createToggle(aimContent, "AutoShot", _S.Monitoring, function(v) _S.Monitoring = v end)
    _S.AutoShotToggleBtn = autoBtn
    createToggle(aimContent, "Random Delay", _S.AutoShootRandomDelay, function(v) _S.AutoShootRandomDelay = v end)
    createSlider(aimContent, "Min Delay (сек)", 0.01, 0.5, _S.AutoShootMinDelay, 0.01, "%.2f", function(v) _S.AutoShootMinDelay = v end)
    createSlider(aimContent, "Max Delay (сек)", 0.01, 0.5, _S.AutoShootMaxDelay, 0.01, "%.2f", function(v) _S.AutoShootMaxDelay = v end)
    createSlider(aimContent, "Burst Shots", 1, 10, _S.AutoShootBurstShots, 1, "%.0f", function(v) _S.AutoShootBurstShots = v end)
    createSlider(aimContent, "Burst Delay (сек)", 0.001, 0.1, _S.AutoShootBurstDelay, 0.001, "%.3f", function(v) _S.AutoShootBurstDelay = v end)
    createToggle(aimContent, "Full Mag Enabled", _S.FullMagEnabled, function(v) _S.FullMagEnabled = v end)
    createSlider(aimContent, "Mag Shots", 1, 10, _S.MagShots, 1, "%.0f", function(v) _S.MagShots = v end)
    createSlider(aimContent, "Mag Delay", 0, 0.1, _S.MagDelay, 0.001, "%.3f", function(v) _S.MagDelay = v end)
    createSlider(aimContent, "Delay Before Shot", 0, 0.01, _S.DelayBeforeShot, 0.0001, "%.4f", function(v) _S.DelayBeforeShot = v end)
    createToggle(aimContent, "TripleShot", _S.TripleShotEnabled, function(v) _S.TripleShotEnabled = v end)

    local aimInfoFrame = Instance.new("Frame", aimContent)
    aimInfoFrame.Size = UDim2.new(1,0,0,36) aimInfoFrame.BackgroundColor3 = Color3.fromRGB(30,20,50) corner(aimInfoFrame,8)
    local aimInfoLabel = Instance.new("TextLabel", aimInfoFrame)
    aimInfoLabel.Size = UDim2.new(1,-12,1,0) aimInfoLabel.Position = UDim2.fromOffset(6,0) aimInfoLabel.BackgroundTransparency = 1
    -- ФИКС: обновлённое описание
    aimInfoLabel.Text = "🎯 AutoShot работает ТОЛЬКО на игроков с ролью Target (Friend/Neutral игнорируются)"
    aimInfoLabel.TextColor3 = Color3.fromRGB(200,160,255)
    aimInfoLabel.Font = Enum.Font.Gotham aimInfoLabel.TextSize = 12 aimInfoLabel.TextWrapped = true

    -- AimLock Section
    local aimLockContent = createSection(pageLegit, "AimLock")
    createToggle(aimLockContent, "AimLock", _S.AimLockEnabled, function(v)
        _S.AimLockEnabled = v
        if v then
            if not _S.AimLockConnection then
                _S.AimLockConnection = RunService.RenderStepped:Connect(UpdateAimLock)
            end
        else
            _S.AimLockLockedTarget = nil
            aimLockFovCircle.Visible = false
            if _S.AimLockConnection then _S.AimLockConnection:Disconnect() _S.AimLockConnection = nil end
        end
    end)
    createSlider(aimLockContent, "Smooth", 1, 50, _S.AimLockSmooth, 1, "%.0f", function(v) _S.AimLockSmooth = v end)
    createToggle(aimLockContent, "🔴 AimLock FOV (фильтр)", _S.AimLockFOVEnabled, function(v) _S.AimLockFOVEnabled = v end)
    createSlider(aimLockContent, "AimLock FOV (пикс)", 10, 800, _S.AimLockFOV, 5, "%.0f", function(v) _S.AimLockFOV = v end)
    createToggle(aimLockContent, "Показывать FOV круг", _S.ShowAimLockFOVCircle, function(v)
        _S.ShowAimLockFOVCircle = v
        if not v then aimLockFovCircle.Visible = false end
    end)

    local aimLockInfoFrame = Instance.new("Frame", aimLockContent)
    aimLockInfoFrame.Size = UDim2.new(1,0,0,56) aimLockInfoFrame.BackgroundColor3 = Color3.fromRGB(30,20,50) corner(aimLockInfoFrame,8)
    local aimLockInfoLabel = Instance.new("TextLabel", aimLockInfoFrame)
    aimLockInfoLabel.Size = UDim2.new(1,-12,1,0) aimLockInfoLabel.Position = UDim2.fromOffset(6,0) aimLockInfoLabel.BackgroundTransparency = 1
    -- ФИКС: обновлённое описание
    aimLockInfoLabel.Text = "🎯 AimLock наводит ТОЛЬКО на Target при зажатой ПКМ\nFriend и Neutral полностью игнорируются\nАвто-переключается если цель умерла/ушла/сменила роль"
    aimLockInfoLabel.TextColor3 = Color3.fromRGB(200,160,255)
    aimLockInfoLabel.Font = Enum.Font.Gotham aimLockInfoLabel.TextSize = 11 aimLockInfoLabel.TextWrapped = true

    -- Gun Section
    local gunContent = createSection(pageLegit, "Gun")
    for wpn, en in pairs(_S.WeaponsEnabled) do
        createToggle(gunContent, wpn, en, function(v) _S.WeaponsEnabled[wpn] = v end)
    end
    createToggle(gunContent, "AUTO RELOAD", _S.AutoReloadEnabled, function(v)
        _S.AutoReloadEnabled = v
        if not v then _S.LastAmmoState = {} _S.ReloadCooldown = {} end
    end)
    createSlider(gunContent, "Reload Delay (сек)", 0, 1.0, _S.AutoReloadDelay, 0.01, "%.2f", function(v) _S.AutoReloadDelay = v end)
    local reloadMethodBtn = Instance.new("TextButton", gunContent)
    reloadMethodBtn.Size = UDim2.new(1, 0, 0, 50) reloadMethodBtn.BackgroundColor3 = _S.Theme.Section
    reloadMethodBtn.Text = "Метод reload: " .. _S.AutoReloadMethod reloadMethodBtn.TextColor3 = _S.Theme.LabelText
    reloadMethodBtn.Font = Enum.Font.GothamSemibold reloadMethodBtn.TextSize = 14 reloadMethodBtn.TextWrapped = true corner(reloadMethodBtn, 10)
    local reloadMethods = {"ReEquip", "KeyR", "Both"} local reloadMethodIndex = 1
    reloadMethodBtn.MouseButton1Click:Connect(function()
        reloadMethodIndex = reloadMethodIndex % #reloadMethods + 1
        _S.AutoReloadMethod = reloadMethods[reloadMethodIndex]
        reloadMethodBtn.Text = "Метод reload: " .. _S.AutoReloadMethod
    end)
    local reloadDescFrame = Instance.new("Frame", gunContent)
    reloadDescFrame.Size = UDim2.new(1, 0, 0, 56) reloadDescFrame.BackgroundColor3 = Color3.fromRGB(18, 12, 32) corner(reloadDescFrame, 8)
    local reloadDescLabel = Instance.new("TextLabel", reloadDescFrame)
    reloadDescLabel.Size = UDim2.new(1, -12, 1, 0) reloadDescLabel.Position = UDim2.fromOffset(6, 0) reloadDescLabel.BackgroundTransparency = 1
    reloadDescLabel.Text = "ReEquip: снять/надеть оружие (надёжно)\nKeyR: нажать клавишу R (быстро)\nBoth: оба метода сразу"
    reloadDescLabel.TextColor3 = Color3.fromRGB(160, 150, 200) reloadDescLabel.Font = Enum.Font.Gotham reloadDescLabel.TextSize = 11 reloadDescLabel.TextWrapped = true
    createToggle(gunContent, "Rapid Fire", _S.RapidFireEnabled, function(v) _S.RapidFireEnabled = v UpdateTriggerbot() end)
    createToggle(gunContent, "Fast Gun", _S.FastGunEnabled, function(v) _S.FastGunEnabled = v UpdateFastGun() end)
    createSlider(gunContent, "Fast Gun Delay (ms)", 1, 200, _S.FastGunDelay * 1000, 1, "%.0f", function(v) _S.FastGunDelay = v / 1000 end)

    -- Utilities Section
    local utilitiesContent = createSection(pageMisc, "Utilities")
    createToggle(utilitiesContent, "Chat Spy", false, function(state)
        if state then
            if TextChatService:FindFirstChild('ChatWindowConfiguration') then TextChatService.ChatWindowConfiguration.Enabled = true end
            if TextChatService:FindFirstChild('ChatInputBarConfiguration') then TextChatService.ChatInputBarConfiguration.Enabled = true end
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
        else
            if TextChatService:FindFirstChild('ChatWindowConfiguration') then TextChatService.ChatWindowConfiguration.Enabled = _S.defaultChatStates.ChatWindowEnabled end
            if TextChatService:FindFirstChild('ChatInputBarConfiguration') then TextChatService.ChatInputBarConfiguration.Enabled = _S.defaultChatStates.ChatInputEnabled end
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, _S.defaultChatStates.CoreGuiChat)
        end
    end)

    -- Mod Detector UI
    local modGroup = Instance.new("Frame", utilitiesContent)
    modGroup.Size = UDim2.new(1,0,0,160) modGroup.BackgroundColor3 = _S.Theme.Section corner(modGroup, 10)
    local modTitle = Instance.new("TextLabel", modGroup)
    modTitle.Size = UDim2.new(1,-20,0,30) modTitle.Position = UDim2.fromOffset(10,5) modTitle.BackgroundTransparency = 1
    modTitle.Text = "🚨 MOD DETECTOR" modTitle.Font = Enum.Font.GothamBold modTitle.TextSize = 16
    modTitle.TextColor3 = Color3.fromRGB(255,100,100) modTitle.TextXAlignment = Enum.TextXAlignment.Left
    local detectToggle = Instance.new("TextButton", modGroup)
    detectToggle.Size = UDim2.new(0,120,0,30) detectToggle.Position = UDim2.new(0,10,0,40)
    detectToggle.BackgroundColor3 = _S.modDetectorEnabled and Color3.fromRGB(80,180,80) or Color3.fromRGB(180,80,80)
    detectToggle.Text = _S.modDetectorEnabled and "🔍 Детектор: ВКЛ" or "🔍 Детектор: ВЫКЛ"
    detectToggle.TextColor3 = Color3.new(1,1,1) detectToggle.Font = Enum.Font.GothamBold detectToggle.TextSize = 13 corner(detectToggle, 8)
    detectToggle.MouseButton1Click:Connect(function()
        _S.modDetectorEnabled = not _S.modDetectorEnabled
        detectToggle.BackgroundColor3 = _S.modDetectorEnabled and Color3.fromRGB(80,180,80) or Color3.fromRGB(180,80,80)
        detectToggle.Text = _S.modDetectorEnabled and "🔍 Детектор: ВКЛ" or "🔍 Детектор: ВЫКЛ"
        if _S.modDetectorEnabled then detectMods() end
    end)
    local visualToggle = Instance.new("TextButton", modGroup)
    visualToggle.Size = UDim2.new(0,120,0,30) visualToggle.Position = UDim2.new(0,140,0,40)
    visualToggle.BackgroundColor3 = _S.modVisualEnabled and Color3.fromRGB(80,180,80) or Color3.fromRGB(180,80,80)
    visualToggle.Text = _S.modVisualEnabled and "👁 Визуал: ВКЛ" or "👁 Визуал: ВЫКЛ"
    visualToggle.TextColor3 = Color3.new(1,1,1) visualToggle.Font = Enum.Font.GothamBold visualToggle.TextSize = 13 corner(visualToggle, 8)
    visualToggle.MouseButton1Click:Connect(function()
        _S.modVisualEnabled = not _S.modVisualEnabled
        visualToggle.BackgroundColor3 = _S.modVisualEnabled and Color3.fromRGB(80,180,80) or Color3.fromRGB(180,80,80)
        visualToggle.Text = _S.modVisualEnabled and "👁 Визуал: ВКЛ" or "👁 Визуал: ВЫКЛ"
        if not _S.modVisualEnabled then
            for player, data in pairs(_S.activeESP) do
                if data then
                    if data.label then data.label.Visible = false end
                    if data.box then data.box.Visible = false end
                    if data.tracer then data.tracer.Visible = false end
                end
            end
        end
    end)
    local modStatusLabel = Instance.new("TextLabel", modGroup)
    modStatusLabel.Size = UDim2.new(1,-20,0,30) modStatusLabel.Position = UDim2.fromOffset(10,115) modStatusLabel.BackgroundTransparency = 1
    modStatusLabel.Text = "📊 Найдено модов: " .. table_count(_S.activeESP)
    modStatusLabel.Font = Enum.Font.Gotham modStatusLabel.TextSize = 12 modStatusLabel.TextColor3 = Color3.fromRGB(200,200,200) modStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    task.spawn(function()
        while true do
            task.wait(2)
            if modStatusLabel and modStatusLabel.Parent then
                modStatusLabel.Text = "📊 Найдено модов: " .. table_count(_S.activeESP)
            end
        end
    end)

    local viewModsBtn = Instance.new("TextButton", utilitiesContent)
    viewModsBtn.Size = UDim2.new(1,-20,0,40) viewModsBtn.BackgroundColor3 = _S.Theme.Section
    viewModsBtn.Text = "📋 Список сохраненных модов ("..table_count(_S.savedMods)..")"
    viewModsBtn.TextColor3 = _S.Theme.LabelText viewModsBtn.Font = Enum.Font.GothamSemibold viewModsBtn.TextSize = 14 viewModsBtn.TextWrapped = true corner(viewModsBtn, 10)
    viewModsBtn.MouseButton1Click:Connect(function()
        local list = "=== СОХРАНЕННЫЕ МОДЫ ===\n"
        for userId, data in pairs(_S.savedMods) do
            list = list .. "👤 " .. data.name .. " (ID:"..userId..")\n   📅 " .. data.date .. " | Роль: " .. data.role .. "\n\n"
        end
        if table_count(_S.savedMods) == 0 then list = "Нет сохраненных модов" end
        warn(list)
        local notif = Instance.new("ScreenGui") notif.Parent = game.CoreGui
        local frame = Instance.new("Frame", notif)
        frame.Size = UDim2.new(0, 400, 0, 300) frame.Position = UDim2.new(0.5, -200, 0.5, -150)
        frame.BackgroundColor3 = Color3.fromRGB(20,20,30) corner(frame, 10)
        local text = Instance.new("TextLabel", frame)
        text.Size = UDim2.new(1, -20, 1, -40) text.Position = UDim2.new(0, 10, 0, 10) text.BackgroundTransparency = 1
        text.Text = list text.TextColor3 = Color3.new(1,1,1) text.TextWrapped = true
        text.TextXAlignment = Enum.TextXAlignment.Left text.TextYAlignment = Enum.TextYAlignment.Top
        text.TextScaled = true text.Font = Enum.Font.Gotham
        local close = Instance.new("TextButton", frame)
        close.Size = UDim2.new(0, 60, 0, 30) close.Position = UDim2.new(0.5, -30, 1, -40)
        close.Text = "OK" close.BackgroundColor3 = Color3.fromRGB(180,40,40) corner(close, 8)
        close.MouseButton1Click:Connect(function() notif:Destroy() end)
        task.delay(10, function() if notif then notif:Destroy() end end)
    end)

    local clearModsBtn = Instance.new("TextButton", utilitiesContent)
    clearModsBtn.Size = UDim2.new(1,-20,0,40) clearModsBtn.BackgroundColor3 = Color3.fromRGB(180,40,40)
    clearModsBtn.Text = "🗑️ Очистить всех сохраненных модов" clearModsBtn.TextColor3 = Color3.new(1,1,1)
    clearModsBtn.Font = Enum.Font.GothamBold clearModsBtn.TextSize = 14 corner(clearModsBtn, 10)
    clearModsBtn.MouseButton1Click:Connect(function()
        _S.savedMods = {} saveMods()
        viewModsBtn.Text = "📋 Список сохраненных модов (0)"
        warn("Все сохраненные моды удалены!")
        for player, _ in pairs(_S.activeESP) do
            if _S.savedMods[player.UserId] == nil then clearModESPForPlayer(player) end
        end
    end)

    _S.modDetectorConnections = {}
    table.insert(_S.modDetectorConnections, Players.PlayerAdded:Connect(function(plr)
        task.wait(2) if _S.modDetectorEnabled then detectMods() end
    end))
    table.insert(_S.modDetectorConnections, RunService.Heartbeat:Connect(function()
        if _S.modDetectorEnabled and tick() - _S.lastCheck > 3 then detectMods() _S.lastCheck = tick() end
    end))
    table.insert(_S.modDetectorConnections, RunService.RenderStepped:Connect(function() updateModESP() end))

    task.spawn(function()
        task.wait(1)
        _S.detectorEnabled = true detectMods()
    end)
end

SetupLegitMiscPlayerTabs()

-- ====================== VISUAL PAGE ======================
local function CreateVisualsPage()
    for _, child in ipairs(pageVisual:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    local function getPlayerToolName(player)
        if not player or not player.Character then return "" end
        local tool = player.Character:FindFirstChildOfClass("Tool") return tool and tool.Name or ""
    end
    local function computeOffscreenArrow(worldPos)
        local cam = workspace.CurrentCamera local pos, vis = cam:WorldToViewportPoint(worldPos)
        if vis then return nil, true end
        local center = cam.ViewportSize / 2 local dir = (Vector2.new(pos.X, pos.Y) - center).Unit
        local angle = math.atan2(dir.Y, dir.X) local tip = center + Vector2.new(math.cos(angle), math.sin(angle)) * (center.Magnitude - 40)
        local perp = Vector2.new(-math.sin(angle), math.cos(angle)) * 12
        local left = tip - dir * 18 + perp local right = tip - dir * 18 - perp
        return {tip, left, right}, false
    end
    local espActive = false local rainbowESP = false local fadingESP = false
    local espModes = {['Names']=false,['Distance']=false,['Chams']=false,['Tracers']=false,['Box']=false,['HealthBar']=false,['Tool']=false,['Direction']=false}
    local espColors = _S.VisualColors.ESP local espObjects = {}
    local function applyEffects(element)
        local color = espColors[element] if rainbowESP then color = getRainbowColor() end
        local alpha = 1 if fadingESP then alpha = getFadingAlpha() end return color, alpha
    end
    local function clearESPForPlayer(player)
        local objs = espObjects[player.UserId]
        if objs then
            if objs.LabelGui then objs.LabelGui:Destroy() end if objs.Highlight then objs.Highlight:Destroy() end
            if objs.TracerLine then objs.TracerLine.Visible = false if objs.TracerLine.Remove then pcall(function() objs.TracerLine:Remove() end) end end
            if objs.Box then if objs.Box.Remove then pcall(function() objs.Box:Remove() end) end end
            if objs.BoxOutline then if objs.BoxOutline.Remove then pcall(function() objs.BoxOutline:Remove() end) end end
            if objs.HealthBar then if objs.HealthBar.Remove then pcall(function() objs.HealthBar:Remove() end) end end
            if objs.HealthBarOutline then if objs.HealthBarOutline.Remove then pcall(function() objs.HealthBarOutline:Remove() end) end end
            if objs.ToolLabel then if objs.ToolLabel.Parent then objs.ToolLabel:Destroy() end end
            if objs.DirectionLines then for _, line in ipairs(objs.DirectionLines) do line.Visible = false if line.Remove then pcall(function() line:Remove() end) end end end
            espObjects[player.UserId] = nil
        end
    end
    local function clearAllESP() for _, player in pairs(Players:GetPlayers()) do clearESPForPlayer(player) end end
    local function createBoxObjects(userId)
        local outline = Drawing.new('Square') outline.Visible = false outline.Color = Color3.new(0,0,0) outline.Thickness = 2 outline.Filled = false
        local box = Drawing.new('Square') box.Visible = false box.Color = espColors.Box box.Thickness = 1 box.Filled = false box.Transparency = 1
        local hbOutline = Drawing.new('Square') hbOutline.Visible = false hbOutline.Color = Color3.new(0,0,0) hbOutline.Thickness = 2 hbOutline.Filled = false
        local hb = Drawing.new('Square') hb.Visible = false hb.Color = espColors.HealthBar hb.Thickness = 1 hb.Filled = true hb.Transparency = 1
        espObjects[userId].BoxOutline = outline espObjects[userId].Box = box espObjects[userId].HealthBarOutline = hbOutline espObjects[userId].HealthBar = hb
    end
    local function applyChams(player)
        local function attach()
            if not espModes['Chams'] or not espActive then return end if not player.Character then return end
            local old = player.Character:FindFirstChild('ESP_Chams') if old then old:Destroy() end
            local hl = Instance.new('Highlight') hl.Name = 'ESP_Chams' hl.Adornee = player.Character
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop hl.FillColor = espColors.Chams
            hl.FillTransparency = 0.5 hl.OutlineColor = Color3.new(0,0,0) hl.OutlineTransparency = 0 hl.Parent = player.Character
            espObjects[player.UserId].Highlight = hl
        end
        attach() player.CharacterAdded:Connect(function() task.wait(0.2) attach() end)
    end
    local function createESPForPlayer(player)
        if player == LocalPlayer then return end
        if IsModerator(player) then return end
        clearESPForPlayer(player) espObjects[player.UserId] = {}
        local screenGui = Instance.new('ScreenGui') screenGui.Name = 'ESP_GUI_'..player.Name screenGui.IgnoreGuiInset = true screenGui.ResetOnSpawn = false screenGui.Parent = game.CoreGui
        local label = Instance.new('TextLabel') label.Size = UDim2.new(0,150,0,50) label.BackgroundTransparency = 1 label.Font = Enum.Font.Code label.TextSize = 14 label.TextColor3 = Color3.new(1,1,1) label.TextStrokeTransparency = 0 label.TextStrokeColor3 = Color3.new(0,0,0) label.TextXAlignment = Enum.TextXAlignment.Center label.TextYAlignment = Enum.TextYAlignment.Top label.Text = '' label.RichText = true label.Visible = false label.Parent = screenGui
        local toolLabel = Instance.new('TextLabel') toolLabel.Size = UDim2.new(0,150,0,18) toolLabel.Position = UDim2.new(0,0,0,36) toolLabel.BackgroundTransparency = 1 toolLabel.Font = Enum.Font.Code toolLabel.TextSize = 14 toolLabel.TextColor3 = espColors.Tool toolLabel.TextStrokeTransparency = 0 toolLabel.TextStrokeColor3 = Color3.new(0,0,0) toolLabel.TextXAlignment = Enum.TextXAlignment.Center toolLabel.TextYAlignment = Enum.TextYAlignment.Top toolLabel.Text = '' toolLabel.RichText = true toolLabel.Visible = false toolLabel.Parent = screenGui
        local dirLines = {}
        for i = 1, 3 do local ln = Drawing.new('Line') ln.Visible = false ln.Thickness = 2 ln.Transparency = 1 ln.Color = espColors.Direction table.insert(dirLines, ln) end
        espObjects[player.UserId].LabelGui = screenGui espObjects[player.UserId].Label = label espObjects[player.UserId].ToolLabel = toolLabel espObjects[player.UserId].DirectionLines = dirLines
        createBoxObjects(player.UserId)
        local line = Drawing.new('Line') line.Thickness = 1.5 line.Transparency = 1 line.Color = espColors.Tracers line.Visible = false
        espObjects[player.UserId].TracerLine = line
        if espModes['Chams'] then applyChams(player) end
    end
    local function updateESPForPlayer(player)
        local objs = espObjects[player.UserId] if not objs then return end
        if IsModerator(player) then return end
        local character = player.Character local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        local rootPart = character and (character:FindFirstChild('UpperTorso') or character:FindFirstChild('HumanoidRootPart'))
        if not rootPart then
            if objs.Label then objs.Label.Visible = false end if objs.TracerLine then objs.TracerLine.Visible = false end if objs.Highlight then objs.Highlight.Enabled = false end if objs.Box then objs.Box.Visible = false end if objs.BoxOutline then objs.BoxOutline.Visible = false end if objs.HealthBar then objs.HealthBar.Visible = false end if objs.HealthBarOutline then objs.HealthBarOutline.Visible = false end if objs.ToolLabel then objs.ToolLabel.Visible = false end if objs.DirectionLines then for _, ln in ipairs(objs.DirectionLines) do ln.Visible = false end end
            return
        end
        local head = character:FindFirstChild('Head')
        local boxScreenPos, boxOnScreen = Camera:WorldToViewportPoint(rootPart.Position)
        local nameDistanceScreenPos, nameDistanceOnScreen = Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0,2.5,0))
        local dist = (Camera.CFrame.Position - rootPart.Position).Magnitude
        local info = ''
        if espModes['Names'] then local c,a = applyEffects('Names') objs.Label.TextColor3 = c objs.Label.TextTransparency = 1-a info = info..string.format('<font color="%s">%s</font>\n',color3ToHex(c),player.DisplayName) end
        if espModes['Distance'] then local c,_ = applyEffects('Distance') info = info..string.format('<font color="%s">Dist: %.1f m</font>\n',color3ToHex(c),dist) end
        if objs.Label then if nameDistanceOnScreen then objs.Label.Text = info objs.Label.Position = UDim2.new(0,nameDistanceScreenPos.X-75,0,nameDistanceScreenPos.Y-30) objs.Label.Visible = info~='' else objs.Label.Visible = false end end
        if head and (espModes['Box'] or espModes['HealthBar']) and boxOnScreen then
            local headPos = Camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.5,0)) local rootPos2 = Camera:WorldToViewportPoint(rootPart.Position-Vector3.new(0,3,0))
            local boxHeight = math.abs(headPos.Y-rootPos2.Y) if boxHeight < 10 then boxHeight = 10 end
            local boxWidth = boxHeight/2 local boxX = headPos.X-boxWidth/2 local boxY = headPos.Y-boxHeight*0.1
            local boxColor,_ = applyEffects('Box')
            objs.Box.Size = Vector2.new(boxWidth,boxHeight) objs.Box.Position = Vector2.new(boxX,boxY) objs.Box.Color = boxColor
            local boxAlpha = fadingESP and getFadingAlpha() or 1 objs.Box.Transparency = boxAlpha objs.Box.Visible = espModes['Box']
            objs.BoxOutline.Size = objs.Box.Size objs.BoxOutline.Position = objs.Box.Position objs.BoxOutline.Color = Color3.new(0,0,0) objs.BoxOutline.Transparency = boxAlpha objs.BoxOutline.Visible = espModes['Box']
            if espModes['HealthBar'] and humanoid then
                local maxHp = (humanoid.MaxHealth and humanoid.MaxHealth>0) and humanoid.MaxHealth or 1 local hpRatio = math.clamp(humanoid.Health/maxHp,0,1) local hbHeight = boxHeight*hpRatio
                local hbColor,_ = applyEffects('HealthBar')
                objs.HealthBar.Size = Vector2.new(2,hbHeight) objs.HealthBar.Position = Vector2.new(boxX-5,boxY+(boxHeight-hbHeight)) objs.HealthBar.Color = hbColor objs.HealthBar.Transparency = fadingESP and getFadingAlpha() or 1 objs.HealthBar.Visible = true
                objs.HealthBarOutline.Size = Vector2.new(2,boxHeight) objs.HealthBarOutline.Position = Vector2.new(boxX-5,boxY) objs.HealthBarOutline.Color = Color3.new(0,0,0) objs.HealthBarOutline.Transparency = fadingESP and getFadingAlpha() or 1 objs.HealthBarOutline.Visible = true
            else objs.HealthBar.Visible = false objs.HealthBarOutline.Visible = false end
        else objs.Box.Visible = false objs.BoxOutline.Visible = false objs.HealthBar.Visible = false objs.HealthBarOutline.Visible = false end
        if espModes['Direction'] and objs.DirectionLines then
            local arrowPoints,onScreen = computeOffscreenArrow(rootPart.Position)
            if arrowPoints and not onScreen then
                local dirColor,_ = applyEffects('Direction')
                objs.DirectionLines[1].From = arrowPoints[1] objs.DirectionLines[1].To = arrowPoints[2] objs.DirectionLines[1].Color = dirColor objs.DirectionLines[1].Transparency = fadingESP and getFadingAlpha() or 1 objs.DirectionLines[1].Visible = true
                objs.DirectionLines[2].From = arrowPoints[2] objs.DirectionLines[2].To = arrowPoints[3] objs.DirectionLines[2].Color = dirColor objs.DirectionLines[2].Transparency = fadingESP and getFadingAlpha() or 1 objs.DirectionLines[2].Visible = true
                objs.DirectionLines[3].From = arrowPoints[3] objs.DirectionLines[3].To = arrowPoints[1] objs.DirectionLines[3].Color = dirColor objs.DirectionLines[3].Transparency = fadingESP and getFadingAlpha() or 1 objs.DirectionLines[3].Visible = true
            else for _, ln in ipairs(objs.DirectionLines) do ln.Visible = false end end
        else if objs.DirectionLines then for _, ln in ipairs(objs.DirectionLines) do ln.Visible = false end end end
        if espModes['Tracers'] and objs.TracerLine and boxOnScreen then
            local tracerColor,_ = applyEffects('Tracers')
            objs.TracerLine.From = Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y) objs.TracerLine.To = Vector2.new(boxScreenPos.X,boxScreenPos.Y) objs.TracerLine.Color = tracerColor objs.TracerLine.Transparency = fadingESP and getFadingAlpha() or 1 objs.TracerLine.Visible = true
        else if objs.TracerLine then objs.TracerLine.Visible = false end end
        if objs.Highlight and objs.Highlight.Parent then
            if espModes['Chams'] then local chamColor,_ = applyEffects('Chams') objs.Highlight.FillColor = chamColor objs.Highlight.FillTransparency = 0.55 objs.Highlight.OutlineColor = Color3.new(0,0,0) objs.Highlight.OutlineTransparency = 0.3 objs.Highlight.Enabled = true
            else objs.Highlight.Enabled = false end
        end
        if objs.ToolLabel then
            if espModes['Tool'] and (nameDistanceOnScreen or boxOnScreen) then
                local toolName = getPlayerToolName(player)
                if toolName and toolName ~= "" then
                    local c,_ = applyEffects('Tool')
                    objs.ToolLabel.Text = string.format('<font color="%s">%s</font>',color3ToHex(c),toolName) objs.ToolLabel.TextColor3 = c objs.ToolLabel.TextTransparency = fadingESP and getFadingAlpha() or 0
                    if nameDistanceOnScreen then objs.ToolLabel.Position = UDim2.new(0,nameDistanceScreenPos.X-75,0,nameDistanceScreenPos.Y+4)
                    else objs.ToolLabel.Position = UDim2.new(0,boxScreenPos.X-75,0,boxScreenPos.Y+objs.Box.Size.Y+4) end
                    objs.ToolLabel.Visible = true
                else objs.ToolLabel.Visible = false end
            else objs.ToolLabel.Visible = false end
        end
    end
    local function refreshAllPlayers() for _, player in pairs(Players:GetPlayers()) do if player ~= LocalPlayer then createESPForPlayer(player) end end end
    local frameCount = 0
    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1 if not espActive or frameCount % 2 ~= 0 then return end
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not espObjects[player.UserId] then createESPForPlayer(player) end updateESPForPlayer(player)
            end
        end
    end)
    Players.PlayerRemoving:Connect(clearESPForPlayer)
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function() task.wait(0.5) if espActive then createESPForPlayer(player) end end)
    end)
    local EspGroup, openEsp = createSection(pageVisual, "ESP")
    createToggle(EspGroup, "Enable ESP", false, function(state) espActive = state if espActive then refreshAllPlayers() else clearAllESP() end end)
    createToggle(EspGroup, "Rainbow ESP", false, function(state) rainbowESP = state end)
    createToggle(EspGroup, "Fading ESP", false, function(state) fadingESP = state end)
    local function CreateESPModeToggle(modeName)
        createToggle(EspGroup, modeName, false, function(state) espModes[modeName] = state if espActive then refreshAllPlayers() end end)
    end
    CreateESPModeToggle('Names') CreateESPModeToggle('Distance') CreateESPModeToggle('Chams') CreateESPModeToggle('Tracers')
    CreateESPModeToggle('Box') CreateESPModeToggle('HealthBar') CreateESPModeToggle('Tool') CreateESPModeToggle('Direction')

    -- Role ESP
    local roleEspObjects = {}
    local roleEspActive = false
    local roleEspSettings = {
        ShowTarget=true, ShowFriend=true, ShowNeutral=false,
        ShowNames=true, ShowBox=true, ShowTracers=false, ShowDistance=true, ShowHealthBar=true,
    }
    local function clearRoleESPForPlayer(player)
        local objs = roleEspObjects[player.UserId]
        if objs then
            if objs.gui then objs.gui:Destroy() end
            if objs.box then pcall(function() objs.box:Remove() end) end
            if objs.boxOutline then pcall(function() objs.boxOutline:Remove() end) end
            if objs.tracer then pcall(function() objs.tracer.Visible = false objs.tracer:Remove() end) end
            if objs.hbar then pcall(function() objs.hbar:Remove() end) end
            if objs.hbarOutline then pcall(function() objs.hbarOutline:Remove() end) end
            roleEspObjects[player.UserId] = nil
        end
    end
    local function clearAllRoleESP()
        for _, player in pairs(Players:GetPlayers()) do clearRoleESPForPlayer(player) end
    end
    local function getRoleESPColor(player)
        local role = GetPlayerRole(player)
        return _S.VisualColors.RoleESP[role] or Color3.fromRGB(160,160,180), role
    end
    local function shouldShowRoleESP(player)
        if player == LocalPlayer then return false end
        if IsModerator(player) then return false end
        local role = GetPlayerRole(player)
        if role == "Target" and roleEspSettings.ShowTarget then return true end
        if role == "Friend" and roleEspSettings.ShowFriend then return true end
        if role == "Neutral" and roleEspSettings.ShowNeutral then return true end
        return false
    end
    local function createRoleESPForPlayer(player)
        clearRoleESPForPlayer(player)
        if not shouldShowRoleESP(player) then return end
        roleEspObjects[player.UserId] = {}
        local objs = roleEspObjects[player.UserId]
        local g = Instance.new("ScreenGui") g.Name = "RoleESP_"..player.Name g.IgnoreGuiInset = true g.ResetOnSpawn = false g.Parent = game.CoreGui
        local nameLabel = Instance.new("TextLabel") nameLabel.Size = UDim2.new(0,180,0,20) nameLabel.BackgroundTransparency = 1 nameLabel.Font = Enum.Font.GothamBold nameLabel.TextSize = 14 nameLabel.TextStrokeTransparency = 0 nameLabel.TextStrokeColor3 = Color3.new(0,0,0) nameLabel.TextXAlignment = Enum.TextXAlignment.Center nameLabel.Visible = false nameLabel.Parent = g
        local distLabel = Instance.new("TextLabel") distLabel.Size = UDim2.new(0,180,0,16) distLabel.BackgroundTransparency = 1 distLabel.Font = Enum.Font.Gotham distLabel.TextSize = 12 distLabel.TextStrokeTransparency = 0 distLabel.TextStrokeColor3 = Color3.new(0,0,0) distLabel.TextXAlignment = Enum.TextXAlignment.Center distLabel.Visible = false distLabel.Parent = g
        local box = Drawing.new("Square") box.Visible = false box.Filled = false box.Thickness = 2
        local boxOutline = Drawing.new("Square") boxOutline.Visible = false boxOutline.Filled = false boxOutline.Thickness = 4 boxOutline.Color = Color3.new(0,0,0)
        local tracer = Drawing.new("Line") tracer.Visible = false tracer.Thickness = 1.5
        local hbar = Drawing.new("Square") hbar.Visible = false hbar.Filled = true
        local hbarOutline = Drawing.new("Square") hbarOutline.Visible = false hbarOutline.Filled = false hbarOutline.Color = Color3.new(0,0,0) hbarOutline.Thickness = 2
        objs.gui = g objs.nameLabel = nameLabel objs.distLabel = distLabel
        objs.box = box objs.boxOutline = boxOutline objs.tracer = tracer objs.hbar = hbar objs.hbarOutline = hbarOutline
    end
    local function updateRoleESPForPlayer(player)
        local objs = roleEspObjects[player.UserId] if not objs then return end
        local show = shouldShowRoleESP(player)
        if not show then
            if objs.nameLabel then objs.nameLabel.Visible = false end if objs.distLabel then objs.distLabel.Visible = false end
            if objs.box then objs.box.Visible = false end if objs.boxOutline then objs.boxOutline.Visible = false end
            if objs.tracer then objs.tracer.Visible = false end if objs.hbar then objs.hbar.Visible = false end if objs.hbarOutline then objs.hbarOutline.Visible = false end
            return
        end
        local char = player.Character if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local rootPart = char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not rootPart then return end
        local roleColor, _ = getRoleESPColor(player)
        local rootSP, rootOnScreen = Camera:WorldToViewportPoint(rootPart.Position)
        local nameSP, nameOnScreen = Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2.5, 0))
        local dist = (Camera.CFrame.Position - rootPart.Position).Magnitude
        if objs.nameLabel then
            if roleEspSettings.ShowNames and nameOnScreen then
                local role = GetPlayerRole(player)
                local icons = {Target="🎯", Friend="💚", Neutral="⚪"}
                objs.nameLabel.Text = (icons[role] or "") .. " " .. player.Name
                objs.nameLabel.TextColor3 = roleColor
                objs.nameLabel.Position = UDim2.new(0, nameSP.X - 90, 0, nameSP.Y - 28)
                objs.nameLabel.Visible = true
            else objs.nameLabel.Visible = false end
        end
        if objs.distLabel then
            if roleEspSettings.ShowDistance and nameOnScreen then
                objs.distLabel.Text = string.format("%.0f m", dist) objs.distLabel.TextColor3 = roleColor
                objs.distLabel.Position = UDim2.new(0, nameSP.X - 90, 0, nameSP.Y - 12) objs.distLabel.Visible = true
            else objs.distLabel.Visible = false end
        end
        if head and rootOnScreen then
            local headSP = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local feetSP = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
            local bh = math.max(math.abs(headSP.Y - feetSP.Y), 10) local bw = bh / 2
            local bx = headSP.X - bw / 2 local by = headSP.Y - bh * 0.1
            if roleEspSettings.ShowBox then
                objs.box.Size = Vector2.new(bw, bh) objs.box.Position = Vector2.new(bx, by) objs.box.Color = roleColor objs.box.Transparency = 1 objs.box.Visible = true
                objs.boxOutline.Size = objs.box.Size objs.boxOutline.Position = objs.box.Position objs.boxOutline.Transparency = 1 objs.boxOutline.Visible = true
            else objs.box.Visible = false objs.boxOutline.Visible = false end
            if roleEspSettings.ShowHealthBar and humanoid then
                local maxHp = math.max(humanoid.MaxHealth or 1, 1) local hpRatio = math.clamp(humanoid.Health / maxHp, 0, 1) local hbh = bh * hpRatio
                local hpColor = Color3.fromRGB(math.floor((1 - hpRatio) * 255), math.floor(hpRatio * 220), 50)
                objs.hbar.Size = Vector2.new(3, hbh) objs.hbar.Position = Vector2.new(bx - 7, by + (bh - hbh)) objs.hbar.Color = hpColor objs.hbar.Transparency = 1 objs.hbar.Visible = true
                objs.hbarOutline.Size = Vector2.new(3, bh) objs.hbarOutline.Position = Vector2.new(bx - 7, by) objs.hbarOutline.Transparency = 1 objs.hbarOutline.Visible = true
            else objs.hbar.Visible = false objs.hbarOutline.Visible = false end
        else
            if objs.box then objs.box.Visible = false end if objs.boxOutline then objs.boxOutline.Visible = false end
            if objs.hbar then objs.hbar.Visible = false end if objs.hbarOutline then objs.hbarOutline.Visible = false end
        end
        if roleEspSettings.ShowTracers and rootOnScreen then
            objs.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            objs.tracer.To = Vector2.new(rootSP.X, rootSP.Y) objs.tracer.Color = roleColor objs.tracer.Transparency = 1 objs.tracer.Visible = true
        else if objs.tracer then objs.tracer.Visible = false end end
    end
    local roleFrameCount = 0
    RunService.RenderStepped:Connect(function()
        if not roleEspActive then return end
        roleFrameCount = roleFrameCount + 1 if roleFrameCount % 2 ~= 0 then return end
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not roleEspObjects[player.UserId] then createRoleESPForPlayer(player) end
                updateRoleESPForPlayer(player)
            end
        end
    end)
    Players.PlayerRemoving:Connect(clearRoleESPForPlayer)

    local RoleESPGroup, openRoleESP = createSection(pageVisual, "🎯 Role ESP")
    local roleEspInfoFrame = Instance.new("Frame", RoleESPGroup)
    roleEspInfoFrame.Size = UDim2.new(1,0,0,36) roleEspInfoFrame.BackgroundColor3 = Color3.fromRGB(20,15,35) corner(roleEspInfoFrame, 8)
    local roleEspInfoLbl = Instance.new("TextLabel", roleEspInfoFrame)
    roleEspInfoLbl.Size = UDim2.new(1,-12,1,0) roleEspInfoLbl.Position = UDim2.fromOffset(6,0) roleEspInfoLbl.BackgroundTransparency = 1
    roleEspInfoLbl.Text = "ESP фильтруется по ролям: Target / Friend / Neutral" roleEspInfoLbl.TextColor3 = Color3.fromRGB(180,150,220) roleEspInfoLbl.Font = Enum.Font.Gotham roleEspInfoLbl.TextSize = 12 roleEspInfoLbl.TextWrapped = true
    createToggle(RoleESPGroup, "Enable Role ESP", false, function(state) roleEspActive = state if not state then clearAllRoleESP() end end)
    createToggle(RoleESPGroup, "🎯 Показывать Target", true, function(v) roleEspSettings.ShowTarget = v end)
    createToggle(RoleESPGroup, "💚 Показывать Friend", true, function(v) roleEspSettings.ShowFriend = v end)
    createToggle(RoleESPGroup, "⚪ Показывать Neutral", false, function(v) roleEspSettings.ShowNeutral = v end)
    createToggle(RoleESPGroup, "Имена", true, function(v) roleEspSettings.ShowNames = v end)
    createToggle(RoleESPGroup, "Box", true, function(v) roleEspSettings.ShowBox = v end)
    createToggle(RoleESPGroup, "Трейсеры", false, function(v) roleEspSettings.ShowTracers = v end)
    createToggle(RoleESPGroup, "Дистанция", true, function(v) roleEspSettings.ShowDistance = v end)
    createToggle(RoleESPGroup, "HP бар", true, function(v) roleEspSettings.ShowHealthBar = v end)
    createColorPicker(RoleESPGroup, "🎯 Target цвет", _S.VisualColors.RoleESP.Target, function(c) _S.VisualColors.RoleESP.Target = c end)
    createColorPicker(RoleESPGroup, "💚 Friend цвет", _S.VisualColors.RoleESP.Friend, function(c) _S.VisualColors.RoleESP.Friend = c end)
    createColorPicker(RoleESPGroup, "⚪ Neutral цвет", _S.VisualColors.RoleESP.Neutral, function(c) _S.VisualColors.RoleESP.Neutral = c end)

    -- Camera Matrix
    local CameraMatrixGroup, openCam = createSection(pageVisual, "Camera Matrix Distort")
    local camEnabled = false local camValues = {1,0,0, 0,1,0, 0,0,1}
    createToggle(CameraMatrixGroup, "Enable Camera Distort", false, function(state) camEnabled = state end)
    local sliderNames = {'R00','R01','R10','R11','R20','R21','R22'}
    for i, name in ipairs(sliderNames) do
        createSlider(CameraMatrixGroup, name, -1.19, 1.19, camValues[i], 0.01, "%.2f", function(v) camValues[i] = v end)
    end
    RunService.RenderStepped:Connect(function()
        if not camEnabled then return end
        local origCFrame = Camera.CFrame
        local distorted = CFrame.new(0,0,0, camValues[1],camValues[2],camValues[3], camValues[4],camValues[5],camValues[6], camValues[7],camValues[8],camValues[9])
        Camera.CFrame = origCFrame * distorted
    end)

    local WorldGroup, openWorld = createSection(pageVisual, "World")
    createToggle(WorldGroup, "Disable Shadows", false, function(state) Lighting.GlobalShadows = not state end)

    local EffectsGroup, openEffects = createSection(pageVisual, "Effects")
    local trailEnabled = false local trailColor1 = _S.VisualColors.Trail.Color1 local trailColor2 = _S.VisualColors.Trail.Color2
    local trailRainbow = false local trailLifetime = 1.6 local trailWidth = 0.1
    local trailObject = nil local rainbowConn = nil local hue = 0
    local function applyTrailColor(c1,c2) if trailObject then trailObject.Color = ColorSequence.new(c1,c2) end end
    local function startRainbow() if rainbowConn then return end rainbowConn = RunService.RenderStepped:Connect(function(dt) hue=(hue+dt*0.15)%1 local c1=Color3.fromHSV(hue,1,1) local c2=Color3.fromHSV((hue+0.15)%1,1,1) applyTrailColor(c1,c2) end) end
    local function stopRainbow() if rainbowConn then rainbowConn:Disconnect() rainbowConn = nil end applyTrailColor(trailColor1,trailColor2) end
    local function updateTrail(state)
        local char = LocalPlayer.Character if not char then return end local hrp = char:FindFirstChild('HumanoidRootPart') if not hrp then return end
        if state then
            if not hrp:FindFirstChild('TrailEffect') then
                local trail = Instance.new('Trail') trail.Name = 'TrailEffect' trail.Parent = hrp
                local att0 = Instance.new('Attachment',hrp) att0.Position = Vector3.new(0,1,0)
                local att1 = Instance.new('Attachment',hrp) att1.Position = Vector3.new(0,-1,0)
                trail.Attachment0 = att0 trail.Attachment1 = att1 trail.Lifetime = trailLifetime
                trail.Transparency = NumberSequence.new(0,0) trail.LightEmission = 0.2 trail.Brightness = 10
                trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0,trailWidth),NumberSequenceKeypoint.new(1,0)})
                trailObject = trail if trailRainbow then startRainbow() else applyTrailColor(trailColor1,trailColor2) end
            end
        else
            stopRainbow() trailObject = nil
            for _, child in ipairs(hrp:GetChildren()) do
                if child:IsA('Trail') and child.Name == 'TrailEffect' then child:Destroy() end
                if child:IsA('Attachment') then child:Destroy() end
            end
        end
    end
    LocalPlayer.CharacterAdded:Connect(function(char) if trailEnabled then task.wait(0.5) updateTrail(true) end end)
    createToggle(EffectsGroup, "Trail", false, function(state) trailEnabled = state updateTrail(state) end)

    local slashesActive = false local slashesColor = _S.VisualColors.Aura
    local slashesRainbow = false local slashesEmitters = {} local slashesRainbowConn = nil local slashesHue = 0
    local function slashesClearEmitters() for _,e in ipairs(slashesEmitters) do if e and e.Parent then e:Destroy() end end slashesEmitters = {} end
    local function slashesApplyColor(c) for _,e in ipairs(slashesEmitters) do if e then e.Color = ColorSequence.new(c) end end end
    local function slashesStartRainbow() if slashesRainbowConn then return end slashesRainbowConn = RunService.RenderStepped:Connect(function(dt) slashesHue=(slashesHue+dt*0.15)%1 slashesApplyColor(Color3.fromHSV(slashesHue,1,1)) end) end
    local function slashesStopRainbow() if slashesRainbowConn then slashesRainbowConn:Disconnect() slashesRainbowConn = nil end slashesApplyColor(slashesColor) end
    local function slashesAttachToCharacter(char)
        slashesClearEmitters() local rootPart = char:FindFirstChild("HumanoidRootPart") if not rootPart then return end
        local attach = rootPart:FindFirstChild("RootAttachment") or rootPart
        local e=Instance.new("ParticleEmitter") e.Texture="rbxassetid://10927170198" e.Rate=10 e.Lifetime=NumberRange.new(0.25,0.5) e.Speed=NumberRange.new(0.012) e.Size=NumberSequence.new(3.8,7.6) e.Transparency=NumberSequence.new(0,0,1) e.Color=ColorSequence.new(slashesColor) e.Parent=attach table.insert(slashesEmitters,e)
        if slashesRainbow then slashesStartRainbow() else slashesApplyColor(slashesColor) end
    end
    local function slashesActivate(state)
        if state then slashesActive=true local char=LocalPlayer.Character if char then task.delay(0.25,function() if slashesActive then slashesAttachToCharacter(char) end end) end
        else slashesActive=false slashesStopRainbow() slashesClearEmitters() end
    end
    createToggle(EffectsGroup, "Aura", false, function(state) slashesActivate(state) end)

    -- Self Chams
    local SelfChamsGroup, openChams = createSection(pageVisual, "Self Chams")
    local chamsEnabled = false local chamsColor = _S.VisualColors.SelfChams local chamsRainbow = false local originalColors = {}
    local _, selfChamsBtn = createToggle(SelfChamsGroup, "Enable Chams", false, function(state) chamsEnabled = state end)
    task.spawn(function()
        while true do
            task.wait()
            local char = LocalPlayer.Character if not char then continue end
            local shouldEnable = chamsEnabled
            if shouldEnable then
                for _,v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        if not originalColors[v] then originalColors[v] = {Color=v.Color, Material=v.Material} end
                        v.Material = Enum.Material.ForceField
                        v.Color = chamsRainbow and getRainbowColor() or chamsColor
                    end
                end
            else
                for v,data in pairs(originalColors) do
                    if v and v.Parent then v.Color = data.Color v.Material = data.Material end
                end
                originalColors = {}
            end
        end
    end)

    local CrosshairGroup, openCross = createSection(pageVisual, "Crosshair")
    local crossSettings = { enabled=false, image="rbxassetid://17459159263", color=_S.VisualColors.Crosshair, rainbow=false, size=50, transparency=0, baseRot=0, rotate=false, rotateSpeed=1 }
    local crossSpin = 0
    createToggle(CrosshairGroup, "Enable Crosshair", false, function(s) crossSettings.enabled = s end)
    RunService.PreRender:Connect(function()
        if not crossSettings.enabled then UserInputService.MouseIconEnabled = true local g=game.CoreGui:FindFirstChild("CustomCrosshair") if g then g.Enabled=false end return end
        UserInputService.MouseIconEnabled = false
        if crossSettings.rotate then crossSpin=crossSpin+crossSettings.rotateSpeed if crossSpin>=180 then crossSpin=crossSpin-360 end end
        if crossSettings.rainbow then crossSettings.color=getRainbowColor() end
        local mousePos = UserInputService:GetMouseLocation()
        local g = game.CoreGui:FindFirstChild("CustomCrosshair")
        if not g then g=Instance.new("ScreenGui") g.Name="CustomCrosshair" g.IgnoreGuiInset=true g.ResetOnSpawn=false g.ZIndexBehavior=Enum.ZIndexBehavior.Global g.DisplayOrder=2147483647 g.Parent=game.CoreGui end
        g.Enabled = true
        local img = g:FindFirstChild("CrosshairImage")
        if not img then img=Instance.new("ImageLabel") img.Name="CrosshairImage" img.BackgroundTransparency=1 img.AnchorPoint=Vector2.new(0.5,0.5) img.Parent=g end
        img.Image=crossSettings.image img.ImageColor3=crossSettings.color img.ImageTransparency=crossSettings.transparency
        img.Size=UDim2.new(0,crossSettings.size,0,crossSettings.size) img.Rotation=crossSettings.baseRot+crossSpin img.Position=UDim2.new(0,mousePos.X,0,mousePos.Y)
    end)

    local PostFXGroup, openFX = createSection(pageVisual, "PostFX")
    local fxSettings = { enabled=false, bloomIntensity=1, bloomSize=24, blurSize=0, brightness=0, contrast=0, saturation=0 }
    createToggle(PostFXGroup, "Enable PostFX", false, function(s) fxSettings.enabled = s end)
    RunService.PreRender:Connect(function()
        local bloom=Lighting:FindFirstChild("CustomBloom") or Instance.new("BloomEffect") bloom.Name="CustomBloom" bloom.Parent=Lighting bloom.Enabled=fxSettings.enabled bloom.Intensity=fxSettings.bloomIntensity bloom.Size=fxSettings.bloomSize
        local blur=Lighting:FindFirstChild("CustomBlur") or Instance.new("BlurEffect") blur.Name="CustomBlur" blur.Parent=Lighting blur.Enabled=fxSettings.enabled blur.Size=fxSettings.blurSize
        local cc=Lighting:FindFirstChild("CustomColorCorrection") or Instance.new("ColorCorrectionEffect") cc.Name="CustomColorCorrection" cc.Parent=Lighting cc.Enabled=fxSettings.enabled cc.Brightness=fxSettings.brightness cc.Contrast=fxSettings.contrast cc.Saturation=fxSettings.saturation
    end)
end

local function CreateVisualColorsPage()
    local VisualColorsGroup, openGroup = createSection(pageVisual, "Visual Colors")
    local colorTargets = {
        {"ESP Names","Names",function(c) _S.VisualColors.ESP.Names=c end},
        {"ESP Distance","Distance",function(c) _S.VisualColors.ESP.Distance=c end},
        {"ESP Chams","Chams",function(c) _S.VisualColors.ESP.Chams=c end},
        {"ESP Tracers","Tracers",function(c) _S.VisualColors.ESP.Tracers=c end},
        {"ESP Box","Box",function(c) _S.VisualColors.ESP.Box=c end},
        {"ESP HealthBar","HealthBar",function(c) _S.VisualColors.ESP.HealthBar=c end},
        {"ESP Tool","Tool",function(c) _S.VisualColors.ESP.Tool=c end},
        {"ESP Direction","Direction",function(c) _S.VisualColors.ESP.Direction=c end},
        {"Trail Color 1","TrailColor1",function(c) _S.VisualColors.Trail.Color1=c end},
        {"Trail Color 2","TrailColor2",function(c) _S.VisualColors.Trail.Color2=c end},
        {"Aura Color","Aura",function(c) _S.VisualColors.Aura=c end},
        {"Self Chams Color","SelfChams",function(c) _S.VisualColors.SelfChams=c end},
        {"Crosshair Color","Crosshair",function(c) _S.VisualColors.Crosshair=c end},
        {"Mod Text Color","ModText",function(c) _S.VisualColors.ModESP.Text=c end},
        {"Mod Box Color","ModBox",function(c) _S.VisualColors.ModESP.Box=c end},
        {"Mod Tracer Color","ModTracer",function(c) _S.VisualColors.ModESP.Tracer=c end},
        {"AimLock FOV Color","AimLockFOV",function(c) aimLockFovCircle.Color=c end},
    }
    for _, def in ipairs(colorTargets) do
        local label, key, applyFn = def[1], def[2], def[3]
        local currentColor
        if key == "TrailColor1" then currentColor = _S.VisualColors.Trail.Color1
        elseif key == "TrailColor2" then currentColor = _S.VisualColors.Trail.Color2
        elseif key == "Aura" then currentColor = _S.VisualColors.Aura
        elseif key == "SelfChams" then currentColor = _S.VisualColors.SelfChams
        elseif key == "Crosshair" then currentColor = _S.VisualColors.Crosshair
        elseif key == "ModText" then currentColor = _S.VisualColors.ModESP.Text
        elseif key == "ModBox" then currentColor = _S.VisualColors.ModESP.Box
        elseif key == "ModTracer" then currentColor = _S.VisualColors.ModESP.Tracer
        elseif key == "AimLockFOV" then currentColor = Color3.fromRGB(180, 100, 255)
        else currentColor = _S.VisualColors.ESP[key] end
        createColorPicker(VisualColorsGroup, label, currentColor, applyFn)
    end
end
CreateVisualsPage()
CreateVisualColorsPage()

-- ====================== PLAYER LIST ======================
local _playerListUpdateCallbacks = {}

local function SetupPlayerListTab()
    local playersContent = createSection(pagePlayerList, "Players")

    local defaultRoleFrame = Instance.new("Frame", playersContent)
    defaultRoleFrame.Size = UDim2.new(1,-20,0,60) defaultRoleFrame.BackgroundColor3 = _S.Theme.Section corner(defaultRoleFrame,10)
    local defaultRoleLabel = Instance.new("TextLabel", defaultRoleFrame)
    defaultRoleLabel.Size = UDim2.new(0,120,1,0) defaultRoleLabel.Position = UDim2.fromOffset(10,0) defaultRoleLabel.BackgroundTransparency = 1
    defaultRoleLabel.Text = "Роль по умолчанию:" defaultRoleLabel.TextColor3 = _S.Theme.LabelText defaultRoleLabel.Font = Enum.Font.GothamSemibold defaultRoleLabel.TextSize = 13 defaultRoleLabel.TextWrapped = true
    local defaultRoleOptions = {"Target", "Friend", "Neutral"}
    local defaultRoleColors = { Target = Color3.fromRGB(200,50,50), Friend = Color3.fromRGB(50,180,90), Neutral = Color3.fromRGB(120,120,140) }
    for i, role in ipairs(defaultRoleOptions) do
        local btn = Instance.new("TextButton", defaultRoleFrame)
        btn.Size = UDim2.new(0,70,0,32) btn.Position = UDim2.new(0, 130 + (i-1)*80, 0.5, -16)
        btn.BackgroundColor3 = defaultRoleColors[role] btn.Text = role btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.GothamBold btn.TextSize = 13 corner(btn, 8)
        if role == _S.DefaultPlayerRole then
            local highlight = Instance.new("UIStroke", btn) highlight.Color = Color3.fromRGB(255,255,255) highlight.Thickness = 2
        end
        btn.MouseButton1Click:Connect(function()
            _S.DefaultPlayerRole = role
            for _, child in ipairs(defaultRoleFrame:GetChildren()) do
                if child:IsA("TextButton") then local stroke = child:FindFirstChildOfClass("UIStroke") if stroke then stroke:Destroy() end end
            end
            local newStroke = Instance.new("UIStroke", btn) newStroke.Color = Color3.fromRGB(255,255,255) newStroke.Thickness = 2
            print("✅ Роль по умолчанию изменена на: " .. role)
        end)
    end

    local bulkFrame = Instance.new("Frame", playersContent)
    bulkFrame.Size = UDim2.new(1,-20,0,50) bulkFrame.BackgroundColor3 = _S.Theme.Section corner(bulkFrame,10)
    local bulkLabel = Instance.new("TextLabel", bulkFrame)
    bulkLabel.Size = UDim2.new(0,80,1,0) bulkLabel.Position = UDim2.fromOffset(10,0) bulkLabel.BackgroundTransparency = 1
    bulkLabel.Text = "Все игроки:" bulkLabel.TextColor3 = _S.Theme.LabelText bulkLabel.Font = Enum.Font.GothamSemibold bulkLabel.TextSize = 13
    local BULK_ROLES = {
        {label="🎯 Target", role="Target", color=Color3.fromRGB(200,50,50)},
        {label="💚 Friend", role="Friend", color=Color3.fromRGB(50,180,90)},
        {label="⚪ Neutral", role="Neutral", color=Color3.fromRGB(120,120,140)},
    }
    local _bulkBtnRefs = {}
    for i, def in ipairs(BULK_ROLES) do
        local btn = Instance.new("TextButton", bulkFrame)
        btn.Size = UDim2.new(0,74,0,32) btn.Position = UDim2.new(0, 82 + (i-1)*80, 0.5, -16)
        btn.BackgroundColor3 = def.color btn.Text = def.label btn.TextColor3 = Color3.new(1,1,1) btn.Font = Enum.Font.GothamBold btn.TextSize = 13 corner(btn, 8)
        btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), {Size = UDim2.new(0, 78, 0, 34), Position = UDim2.new(0, 80 + (i-1)*80, 0.5, -17)}):Play() end)
        btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), {Size = UDim2.new(0, 74, 0, 32), Position = UDim2.new(0, 82 + (i-1)*80, 0.5, -16)}):Play() end)
        local capturedRole = def.role
        btn.MouseButton1Click:Connect(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then _S.PlayerRoles[plr.UserId] = capturedRole end
            end
            for _, cb in ipairs(_playerListUpdateCallbacks) do pcall(cb) end
            print("✅ Всем игрокам назначена роль: " .. capturedRole)
        end)
        table.insert(_bulkBtnRefs, btn)
    end

    local PlayerListFrame = Instance.new("ScrollingFrame", playersContent)
    PlayerListFrame.Size = UDim2.new(1,-20,0,360) PlayerListFrame.BackgroundColor3 = Color3.fromRGB(28,28,36)
    PlayerListFrame.ScrollBarThickness = 4 PlayerListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y corner(PlayerListFrame, 8)
    local function updateScroll()
        local can = PlayerListFrame.AbsoluteCanvasSize.Y > PlayerListFrame.AbsoluteSize.Y
        PlayerListFrame.ScrollBarThickness = can and 4 or 0 PlayerListFrame.ScrollingEnabled = can
    end
    PlayerListFrame:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateScroll)
    PlayerListFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScroll)

    local spectatingPlayer = nil local spectateConnection = nil
    local followingPlayer = nil local followConnection = nil
    local ignoredPlayers = {} local activeDropdown = nil local activeBackdrop = nil

    local ROLE_COLORS = {Target=Color3.fromRGB(255,60,60), Friend=Color3.fromRGB(60,220,120), Neutral=Color3.fromRGB(160,160,180)}
    local ROLE_ICONS = {Target="🎯", Friend="💚", Neutral="⚪"}

    local function GetPlayerRoleLocal(player) return _S.PlayerRoles[player.UserId] or GetDefaultRole() end
    local function SetPlayerRole(player, role) _S.PlayerRoles[player.UserId] = role end
    local function CycleRole(player)
        local current = GetPlayerRoleLocal(player) local roles = {"Neutral", "Target", "Friend"} local nextRole = "Neutral"
        for i, r in ipairs(roles) do if r == current then nextRole = roles[(i % #roles) + 1] break end end
        SetPlayerRole(player, nextRole)
    end
    local function StopSpectate()
        if spectateConnection then spectateConnection:Disconnect() spectateConnection = nil end
        if spectatingPlayer then spectatingPlayer = nil workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            workspace.CurrentCamera.CameraSubject = hum end
    end
    local function StopFollow()
        if followConnection then followConnection:Disconnect() followConnection = nil end followingPlayer = nil
    end
    local function SpectatePlayer(plr)
        StopSpectate() spectatingPlayer = plr workspace.CurrentCamera.CameraType = Enum.CameraType.Follow
        spectateConnection = RunService.RenderStepped:Connect(function()
            if not plr or not plr.Character then StopSpectate() return end
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum then workspace.CurrentCamera.CameraSubject = hum end
        end)
    end
    local function FollowPlayer(plr)
        StopFollow() followingPlayer = plr
        followConnection = RunService.Heartbeat:Connect(function()
            if not plr or not plr.Character then StopFollow() return end
            local char = LocalPlayer.Character if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart") local targetHrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp and targetHrp then hrp.CFrame = CFrame.new(targetHrp.Position+Vector3.new(4,0,4), targetHrp.Position) end
        end)
    end
    local function TeleportToPlayer(plr)
        if not plr or not plr.Character then return end
        local char = LocalPlayer.Character if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart") local targetHrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp and targetHrp then hrp.CFrame = targetHrp.CFrame+Vector3.new(2,0,2) end
    end
    local function CloseActiveDropdown()
        if activeBackdrop and activeBackdrop.Parent then activeBackdrop:Destroy() activeBackdrop = nil end
        if activeDropdown and activeDropdown.Parent then activeDropdown:Destroy() activeDropdown = nil end
    end

    local _roleButtonRefs = {}

    local function UpdatePlayerList()
        _roleButtonRefs = {}
        for _, c in ipairs(PlayerListFrame:GetChildren()) do if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end end
        local y = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local isIgnored = ignoredPlayers[plr.UserId] == true
                local isHost = _S.StarterPlayer == plr local isSpectating = spectatingPlayer == plr local isFollowing = followingPlayer == plr
                local playerRole = GetPlayerRoleLocal(plr)
                local roleColor = ROLE_COLORS[playerRole] local roleIcon = ROLE_ICONS[playerRole]
                local container = Instance.new("Frame", PlayerListFrame)
                container.Size = UDim2.new(1,-10,0,52) container.Position = UDim2.new(0,5,0,y)
                container.BackgroundColor3 = isHost and Color3.fromRGB(40,20,70) or isIgnored and Color3.fromRGB(50,20,20) or _S.Theme.PlayerBtn
                container.BorderSizePixel = 0 corner(container,8)
                local roleBar = Instance.new("Frame", container)
                roleBar.Size = UDim2.new(0, 4, 1, -8) roleBar.Position = UDim2.new(0, 2, 0, 4) roleBar.BackgroundColor3 = roleColor corner(roleBar, 2)
                local roleIconLabel = Instance.new("TextLabel", container)
                roleIconLabel.Size = UDim2.new(0, 22, 0, 22) roleIconLabel.Position = UDim2.new(0, 8, 0.5, -11)
                roleIconLabel.BackgroundTransparency = 1 roleIconLabel.Text = roleIcon roleIconLabel.TextScaled = true roleIconLabel.Font = Enum.Font.GothamBold
                local roleBtn = Instance.new("TextButton", container)
                roleBtn.Size = UDim2.new(0, 72, 0, 26) roleBtn.Position = UDim2.new(0, 34, 0.5, -13)
                roleBtn.BackgroundColor3 = roleColor roleBtn.Text = playerRole roleBtn.TextColor3 = Color3.new(1,1,1) roleBtn.Font = Enum.Font.GothamBold roleBtn.TextSize = 13 corner(roleBtn, 8)
                local cPlr = plr
                roleBtn.MouseButton1Click:Connect(function()
                    CycleRole(cPlr)
                    local newRole = GetPlayerRoleLocal(cPlr)
                    roleBtn.BackgroundColor3 = ROLE_COLORS[newRole] roleBtn.Text = newRole roleBar.BackgroundColor3 = ROLE_COLORS[newRole] roleIconLabel.Text = ROLE_ICONS[newRole]
                    if _S.HitboxEnabled then UpdateHitboxesNEW() end
                end)
                _roleButtonRefs[plr.UserId] = {roleBtn=roleBtn, roleBar=roleBar, roleIconLabel=roleIconLabel}
                local statusDot = Instance.new("Frame", container)
                statusDot.Size = UDim2.new(0,6,0,6) statusDot.Position = UDim2.new(0,110,0.5,-3)
                statusDot.BackgroundColor3 = isHost and Color3.fromRGB(180,80,255) or isSpectating and Color3.fromRGB(0,180,255) or isFollowing and Color3.fromRGB(0,255,150) or isIgnored and Color3.fromRGB(255,60,60) or Color3.fromRGB(80,80,100)
                corner(statusDot,3)
                local suffix = (isHost and " 🎯" or "")..(isSpectating and " 👁" or "")..(isFollowing and " 🔗" or "")..(isIgnored and " 🚫" or "")
                -- Показываем display name / original name
                local hasCustomDisplay = plr.DisplayName ~= plr.Name
                -- Строка 1: Display name (крупнее, белый/красный)
                local nameLabel = Instance.new("TextLabel", container)
                nameLabel.Size = UDim2.new(1,-168,0,22) nameLabel.Position = UDim2.new(0,120,0,5) nameLabel.BackgroundTransparency = 1
                nameLabel.Text = (hasCustomDisplay and plr.DisplayName or plr.Name) .. suffix
                nameLabel.TextColor3 = isIgnored and Color3.fromRGB(180,100,100) or Color3.new(1,1,1)
                nameLabel.Font = Enum.Font.GothamSemibold nameLabel.TextSize = 14 nameLabel.TextXAlignment = Enum.TextXAlignment.Left nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                -- Строка 2: Original username (мельче, серый) — показывается только если display ≠ username
                local origLabel = Instance.new("TextLabel", container)
                origLabel.Size = UDim2.new(1,-168,0,16) origLabel.Position = UDim2.new(0,120,0,28) origLabel.BackgroundTransparency = 1
                origLabel.Text = hasCustomDisplay and ("@" .. plr.Name) or ""
                origLabel.TextColor3 = isIgnored and Color3.fromRGB(140,80,80) or Color3.fromRGB(140,130,160)
                origLabel.Font = Enum.Font.Gotham origLabel.TextSize = 11 origLabel.TextXAlignment = Enum.TextXAlignment.Left origLabel.TextTruncate = Enum.TextTruncate.AtEnd
                local menuBtn = Instance.new("TextButton", container)
                menuBtn.Size = UDim2.new(0,36,0,30) menuBtn.Position = UDim2.new(1,-42,0.5,-15)
                menuBtn.BackgroundColor3 = _S.Theme.Accent menuBtn.Text = "⋯" menuBtn.TextColor3 = Color3.new(1,1,1)
                menuBtn.Font = Enum.Font.GothamBold menuBtn.TextSize = 18 menuBtn.ZIndex = 5 corner(menuBtn,8)
                menuBtn.MouseEnter:Connect(function() TweenService:Create(menuBtn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(140,80,220)}):Play() end)
                menuBtn.MouseLeave:Connect(function() TweenService:Create(menuBtn,TweenInfo.new(0.12),{BackgroundColor3=_S.Theme.Accent}):Play() end)
                local cIgn=isIgnored local cHost=isHost local cSpec=isSpectating local cFol=isFollowing
                menuBtn.MouseButton1Click:Connect(function()
                    if activeDropdown then CloseActiveDropdown() return end
                    local IH=36 local PAD=8
                    local actions = {
                        {icon="👁", label=cSpec and "Stop Spectate" or "Spectate", color=Color3.fromRGB(0,180,255)},
                        {icon="🔗", label=cFol and "Stop Follow" or "Follow", color=Color3.fromRGB(0,220,140)},
                        {icon="⚡", label="Teleport", color=Color3.fromRGB(255,200,0)},
                        {icon=cIgn and "✅" or "🚫", label=cIgn and "Remove Ignore" or "Ignore", color=cIgn and Color3.fromRGB(100,220,100) or Color3.fromRGB(255,80,80)},
                        {icon="🎯", label=cHost and "Remove Host" or "Set as Host", color=Color3.fromRGB(180,80,255)},
                        {icon="🚨", label="Report as Mod", color=Color3.fromRGB(255,100,0)},
                    }
                    local totalH = PAD*2+#actions*IH+(#actions-1)*2
                    local bdGui = Instance.new("ScreenGui") bdGui.Name="DropdownBackdrop" bdGui.DisplayOrder=200 bdGui.IgnoreGuiInset=true bdGui.ResetOnSpawn=false bdGui.ZIndexBehavior=Enum.ZIndexBehavior.Global bdGui.Parent=LocalPlayer.PlayerGui
                    local bd = Instance.new("TextButton",bdGui) bd.Size=UDim2.new(1,0,1,0) bd.BackgroundTransparency=1 bd.Text="" bd.ZIndex=1
                    activeBackdrop = bdGui
                    local dGui = Instance.new("ScreenGui") dGui.Name="DropdownMenu" dGui.DisplayOrder=201 dGui.IgnoreGuiInset=true dGui.ResetOnSpawn=false dGui.ZIndexBehavior=Enum.ZIndexBehavior.Global dGui.Parent=LocalPlayer.PlayerGui
                    local dd = Instance.new("Frame",dGui) dd.BackgroundColor3=Color3.fromRGB(18,18,28) dd.BorderSizePixel=0 dd.ZIndex=1 corner(dd,10)
                    local dstroke = Instance.new("UIStroke",dd) dstroke.Color=_S.Theme.Accent dstroke.Thickness=1.5
                    local ap=menuBtn.AbsolutePosition local as2=menuBtn.AbsoluteSize local vp=workspace.CurrentCamera.ViewportSize
                    local dW=190 local dX=ap.X+as2.X-dW local dY=ap.Y+as2.Y+4
                    if dY+totalH>vp.Y-10 then dY=ap.Y-totalH-4 end if dX<4 then dX=4 end
                    dd.Size=UDim2.new(0,dW,0,totalH) dd.Position=UDim2.new(0,dX,0,dY)
                    local dlay=Instance.new("UIListLayout",dd) dlay.Padding=UDim.new(0,2)
                    local dpad=Instance.new("UIPadding",dd) dpad.PaddingTop=UDim.new(0,PAD) dpad.PaddingBottom=UDim.new(0,PAD) dpad.PaddingLeft=UDim.new(0,6) dpad.PaddingRight=UDim.new(0,6)
                    local aFns = {
                        function() if cSpec then StopSpectate() else SpectatePlayer(cPlr) end end,
                        function() if cFol then StopFollow() else FollowPlayer(cPlr) end end,
                        function() TeleportToPlayer(cPlr) end,
                        function() if cIgn then ignoredPlayers[cPlr.UserId]=nil else ignoredPlayers[cPlr.UserId]=true end end,
                        function() if cHost then _S.StarterPlayer=nil _S.LastAmmoPerTool={} RemoveEmoji() else _S.StarterPlayer=cPlr _S.LastAmmoPerTool={} AttachEmojiToPlayer(cPlr) end end,
                        function()
                            if not _S.activeESP[cPlr] or not _S.activeESP[cPlr].isMod then createModESP(cPlr, "Reported") end
                            if not _S.notifiedPlayers[cPlr.UserId] then _S.notifiedPlayers[cPlr.UserId] = true playAlertSound() end
                        end,
                    }
                    for i, act in ipairs(actions) do
                        local btn=Instance.new("TextButton",dd) btn.Size=UDim2.new(1,0,0,IH) btn.BackgroundColor3=Color3.fromRGB(28,28,40)
                        btn.Text=act.icon.." "..act.label btn.TextColor3=act.color btn.Font=Enum.Font.GothamSemibold btn.TextSize=14 btn.TextXAlignment=Enum.TextXAlignment.Left btn.AutoButtonColor=false btn.ZIndex=2 corner(btn,7)
                        local p2=Instance.new("UIPadding",btn) p2.PaddingLeft=UDim.new(0,10)
                        btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(45,45,65)}):Play() end)
                        btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(28,28,40)}):Play() end)
                        local fn=aFns[i]
                        btn.MouseButton1Click:Connect(function() CloseActiveDropdown() fn() task.wait(0.05) UpdatePlayerList() end)
                    end
                    activeDropdown=dGui bd.MouseButton1Click:Connect(function() CloseActiveDropdown() end)
                    dd.BackgroundTransparency=1
                    TweenService:Create(dd,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
                end)
                y = y+56
            end
        end
        PlayerListFrame.CanvasSize = UDim2.new(0,0,0,y)
    end

    table.insert(_playerListUpdateCallbacks, function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local refs = _roleButtonRefs[plr.UserId]
                if refs then
                    local newRole = _S.PlayerRoles[plr.UserId] or GetDefaultRole()
                    local newColor = ROLE_COLORS[newRole] local newIcon = ROLE_ICONS[newRole]
                    refs.roleBtn.BackgroundColor3 = newColor refs.roleBtn.Text = newRole
                    refs.roleBar.BackgroundColor3 = newColor refs.roleIconLabel.Text = newIcon
                end
            end
        end
        if _S.HitboxEnabled then UpdateHitboxesNEW() end
    end)

    UpdatePlayerList()
    Players.PlayerAdded:Connect(function(plr)
        if not _S.PlayerRoles[plr.UserId] then _S.PlayerRoles[plr.UserId] = GetDefaultRole() end
        task.wait(0.5) UpdatePlayerList()
    end)
    spawn(function() while task.wait(3) do UpdatePlayerList() end end)

    local hostContent = createSection(pagePlayerList, "Auto Host (F1 + Z)")
    createToggle(hostContent, "Выбирать друзей как хоста", _S.AllowFriendsAsHost, function(v) _S.AllowFriendsAsHost = v end)
    createToggle(hostContent, "Показывать 🎯 над хостом", _S.ShowTargetEmoji, function(v)
        _S.ShowTargetEmoji = v
        if not v then RemoveEmoji() else if _S.StarterPlayer then AttachEmojiToPlayer(_S.StarterPlayer) end end
    end)
end
SetupPlayerListTab()

-- ====================== BIND TAB ======================
local function GetBindText(key)
    if key == nil then return "Не назначен" end
    return tostring(key.Name)
end

local function createBindButton(parent, bindName, keyVar, modeVar, waitingVarName, btnRefName)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1,0,0,50)
    container.BackgroundColor3 = _S.Theme.Section
    corner(container, 10)
    local nameLabel = Instance.new("TextLabel", container)
    nameLabel.Size = UDim2.new(0, 80, 1, 0)
    nameLabel.Position = UDim2.fromOffset(12, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = bindName
    nameLabel.TextColor3 = _S.Theme.LabelText
    nameLabel.TextSize = 15
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    local keyCell = Instance.new("TextButton", container)
    keyCell.Size = UDim2.new(0, 100, 0, 34)
    keyCell.Position = UDim2.new(0.5, -112, 0.5, -17)
    keyCell.BackgroundColor3 = _S.Theme.BindBtn
    keyCell.Text = GetBindText(keyVar)
    keyCell.TextColor3 = Color3.new(1,1,1)
    keyCell.Font = Enum.Font.GothamBold
    keyCell.TextSize = 14
    corner(keyCell, 8)
    keyCell.MouseEnter:Connect(function()
        TweenService:Create(keyCell, TweenInfo.new(0.15), {BackgroundColor3 = _S.Theme.BindBtnHover}):Play()
    end)
    keyCell.MouseLeave:Connect(function()
        TweenService:Create(keyCell, TweenInfo.new(0.15), {BackgroundColor3 = _S.Theme.BindBtn}):Play()
    end)
    if bindName == "AutoShot" then _S.AutoBindBtn = keyCell
    elseif bindName == "AimLock" then _S.AimLockBindBtn = keyCell
    elseif bindName == "TriggerBot" then _S.TriggerKeyBindBtn = keyCell
    elseif bindName == "Hitbox" then _S.HitboxBindBtn = keyCell
    elseif bindName == "Fly" then _S.FlyBindBtn = keyCell
    elseif bindName == "Rapid Fire" then _S.RapidFireBindBtn = keyCell
    elseif bindName == "Noclip" then _S.NoclipBindBtn2 = keyCell
    elseif bindName == "Speed" then _S.SpeedBindBtn = keyCell
    end
    keyCell.MouseButton1Click:Connect(function()
        keyCell.Text = "Нажми клавишу..."
        keyCell.BackgroundColor3 = Color3.fromRGB(100, 60, 160)
        if bindName == "AutoShot" then _S.WaitingForBind = true
        elseif bindName == "AimLock" then _S.WaitingForAimLockBind = true
        elseif bindName == "TriggerBot" then _S.WaitingForTriggerBind = true
        elseif bindName == "Hitbox" then _S.WaitingForHitboxBind = true
        elseif bindName == "Fly" then _S.WaitingForFlyBind = true
        elseif bindName == "Rapid Fire" then _S.WaitingForRapidFireBind = true
        elseif bindName == "Noclip" then _S.WaitingForNoclipBind = true
        elseif bindName == "Speed" then _S.WaitingForSpeedBind = true
        end
    end)
    local isToggle = (modeVar == "Toggle")
    -- Toggle/Hold кнопка — сдвинута левее чтобы освободить место для крестика
    local modeBtn = Instance.new("TextButton", container)
    modeBtn.Size = UDim2.new(0, 72, 0, 30)
    modeBtn.Position = UDim2.new(1, -120, 0.5, -15)
    modeBtn.BackgroundColor3 = isToggle and Color3.fromRGB(80,50,140) or Color3.fromRGB(40,40,60)
    modeBtn.Text = isToggle and "Toggle" or "Hold"
    modeBtn.TextColor3 = Color3.new(1,1,1)
    modeBtn.Font = Enum.Font.GothamBold
    modeBtn.TextSize = 13
    corner(modeBtn, 15)
    modeBtn.MouseButton1Click:Connect(function()
        isToggle = not isToggle
        local newMode = isToggle and "Toggle" or "Hold"
        modeBtn.Text = newMode
        TweenService:Create(modeBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = isToggle and Color3.fromRGB(80,50,140) or Color3.fromRGB(40,40,60)
        }):Play()
        if bindName == "AutoShot" then _S.BindMode = newMode
        elseif bindName == "AimLock" then _S.AimLockBindMode = newMode
        elseif bindName == "TriggerBot" then _S.TriggerKeyBindMode = newMode
        elseif bindName == "Hitbox" then _S.HitboxBindMode2 = newMode
        elseif bindName == "Fly" then _S.FlyBindMode2 = newMode
        elseif bindName == "Rapid Fire" then _S.RapidFireBindMode2 = newMode
        elseif bindName == "Noclip" then _S.NoclipBindMode2 = newMode
        elseif bindName == "Speed" then _S.SpeedBindMode2 = newMode
        end
    end)
    -- Крестик — сбрасывает бинд
    local clearBtn = Instance.new("TextButton", container)
    clearBtn.Size = UDim2.new(0, 28, 0, 28)
    clearBtn.Position = UDim2.new(1, -38, 0.5, -14)
    clearBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    clearBtn.Text = "✕"
    clearBtn.TextColor3 = Color3.fromRGB(220, 100, 100)
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 14
    corner(clearBtn, 6)
    clearBtn.MouseEnter:Connect(function()
        TweenService:Create(clearBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(160, 40, 40), TextColor3 = Color3.fromRGB(255,255,255)}):Play()
    end)
    clearBtn.MouseLeave:Connect(function()
        TweenService:Create(clearBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 30, 30), TextColor3 = Color3.fromRGB(220, 100, 100)}):Play()
    end)
    clearBtn.MouseButton1Click:Connect(function()
        -- Сбрасываем клавишу бинда на nil
        if bindName == "AutoShot" then
            _S.ToggleKey = nil _S.WaitingForBind = false
        elseif bindName == "AimLock" then
            _S.AimLockBindKey = nil _S.WaitingForAimLockBind = false
            _S.AimLockLockedTarget = nil
        elseif bindName == "TriggerBot" then
            _S.TriggerBindKey = nil _S.WaitingForTriggerBind = false
        elseif bindName == "Hitbox" then
            _S.HitboxBindKey = nil _S.WaitingForHitboxBind = false
        elseif bindName == "Fly" then
            _S.FlyBindKey = nil _S.WaitingForFlyBind = false
        elseif bindName == "Rapid Fire" then
            _S.RapidFireBindKey = nil _S.WaitingForRapidFireBind = false
        elseif bindName == "Noclip" then
            _S.NoclipBindKey = nil _S.WaitingForNoclipBind = false
        elseif bindName == "Speed" then
            _S.SpeedBindKey = nil _S.WaitingForSpeedBind = false
        end
        keyCell.Text = "Не назначен"
        keyCell.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        -- Анимация сброса
        TweenService:Create(clearBtn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(200, 50, 50)}):Play()
        task.delay(0.12, function()
            TweenService:Create(clearBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 30, 30)}):Play()
        end)
    end)
    local function updateKeyText(key)
        keyCell.Text = GetBindText(key)
        keyCell.BackgroundColor3 = key ~= nil and _S.Theme.BindBtn or Color3.fromRGB(40, 40, 50)
    end
    if bindName == "AutoShot" then _S.AutoBindBtnUpdate = updateKeyText
    elseif bindName == "AimLock" then _S.AimLockBindBtnUpdate = updateKeyText
    elseif bindName == "TriggerBot" then _S.TriggerKeyBindBtnUpdate = updateKeyText
    elseif bindName == "Hitbox" then _S.HitboxBindBtnUpdate = updateKeyText
    elseif bindName == "Fly" then _S.FlyBindBtnUpdate = updateKeyText
    elseif bindName == "Rapid Fire" then _S.RapidFireBindBtnUpdate = updateKeyText
    elseif bindName == "Noclip" then _S.NoclipBindBtn2Update = updateKeyText
    elseif bindName == "Speed" then _S.SpeedBindBtnUpdate = updateKeyText
    end
    return container
end

local function SetupBindTab()
    local bindContent = createSection(pageBind, "Binds")
    local mouseBindInfoFrame = Instance.new("Frame", bindContent)
    mouseBindInfoFrame.Size = UDim2.new(1,0,0,50)
    mouseBindInfoFrame.BackgroundColor3 = Color3.fromRGB(20,15,35)
    corner(mouseBindInfoFrame, 8)
    local infoLayout = Instance.new("UIListLayout", mouseBindInfoFrame)
    infoLayout.Padding = UDim.new(0, 4)
    infoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    local mouseBindInfoLabel1 = Instance.new("TextLabel", mouseBindInfoFrame)
    mouseBindInfoLabel1.Size = UDim2.new(1,-12,0,20)
    mouseBindInfoLabel1.Position = UDim2.fromOffset(6,6)
    mouseBindInfoLabel1.BackgroundTransparency = 1
    mouseBindInfoLabel1.Text = "⌨️ Нажми на ячейку с клавишей, затем нажми нужную клавишу"
    mouseBindInfoLabel1.TextColor3 = Color3.fromRGB(180,150,220)
    mouseBindInfoLabel1.Font = Enum.Font.Gotham
    mouseBindInfoLabel1.TextSize = 13
    mouseBindInfoLabel1.TextWrapped = true
    local mouseBindInfoLabel2 = Instance.new("TextLabel", mouseBindInfoFrame)
    mouseBindInfoLabel2.Size = UDim2.new(1,-12,0,20)
    mouseBindInfoLabel2.BackgroundTransparency = 1
    mouseBindInfoLabel2.Text = "Кнопка справа переключает режим Toggle/Hold"
    mouseBindInfoLabel2.TextColor3 = Color3.fromRGB(150,120,200)
    mouseBindInfoLabel2.Font = Enum.Font.Gotham
    mouseBindInfoLabel2.TextSize = 13
    mouseBindInfoLabel2.TextWrapped = true
    createBindButton(bindContent, "AutoShot", _S.ToggleKey, _S.BindMode)
    createBindButton(bindContent, "AimLock", _S.AimLockBindKey, _S.AimLockBindMode)
    createBindButton(bindContent, "TriggerBot", _S.TriggerBindKey, _S.TriggerKeyBindMode)
    createBindButton(bindContent, "Hitbox", _S.HitboxBindKey, _S.HitboxBindMode2)
    createBindButton(bindContent, "Fly", _S.FlyBindKey, _S.FlyBindMode2)
    createBindButton(bindContent, "Rapid Fire", _S.RapidFireBindKey, _S.RapidFireBindMode2)
    createBindButton(bindContent, "Noclip", _S.NoclipBindKey, _S.NoclipBindMode2)
    createBindButton(bindContent, "Speed", _S.SpeedBindKey, _S.SpeedBindMode2)
end

SetupBindTab()

-- ====================== MOVEMENT TAB ======================
local function SetupMovementTab()
    local function setSpeed()
        pcall(function()
            local char=LocalPlayer.Character if not char then return end
            local hrp=char:FindFirstChild("HumanoidRootPart") local hum=char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then return end
            local move=hum.MoveDirection local delta=1/60
            if _S.speedEnabled then hrp.CFrame+=move*_S.speedValue*delta
            elseif _S.speedV2Enabled then hrp.AssemblyLinearVelocity=Vector3.new(move.X*_S.speedValue,hrp.AssemblyLinearVelocity.Y,move.Z*_S.speedValue)
            elseif _S.speedV3Enabled then if move.Magnitude>0 then hrp:ApplyImpulse(move*_S.speedValue*0.6) end end
        end)
    end
    local MovementContent = createSection(pageMovement, "Движение")
    LocalPlayer.CharacterAdded:Connect(function() if flyEnabled then task.wait(0.5) startFly() end end)
    createToggle(MovementContent,"Fly",false,function(state) if state then startFly() else stopFly() end end)
    createSlider(MovementContent,"Fly Speed",10,500,50,5,"%.0f",function(v) flySpeed=v end)
    createToggle(MovementContent,"Speed",false,function(state) updateSpeedFlags(state) end)
    local SpeedModeDropdown=Instance.new("TextButton",MovementContent)
    SpeedModeDropdown.Size=UDim2.new(1,0,0,50) SpeedModeDropdown.BackgroundColor3=_S.Theme.Section
    SpeedModeDropdown.Text="Speed Mode: CFrame" SpeedModeDropdown.TextColor3=_S.Theme.LabelText SpeedModeDropdown.Font=Enum.Font.Gotham SpeedModeDropdown.TextSize=15 corner(SpeedModeDropdown,10)
    SpeedModeDropdown.MouseButton1Click:Connect(function()
        local values={"CFrame","Velocity","Impulse"} local current=_S.speedMethod local nextIndex=1
        for i,v in ipairs(values) do if v==current then nextIndex=i+1 if nextIndex>#values then nextIndex=1 end break end end
        _S.speedMethod=values[nextIndex] SpeedModeDropdown.Text="Speed Mode: ".._S.speedMethod if _S.speedToggleState then updateSpeedFlags(true) end
    end)
    createSlider(MovementContent,"Speed Amount",1,1500,16,1,"%.0f",function(v) _S.speedValue=v end)
    createToggle(MovementContent,"No Jump Cooldown",false,function(state)
        if state then local player=game.Players.LocalPlayer local function njc(character) character:WaitForChild('Humanoid').UseJumpPower=false end player.CharacterAdded:Connect(njc) if player.Character then njc(player.Character) end end
    end)
    createToggle(MovementContent,"No Slow Down",false,function(state)
        if state then
            RunService:BindToRenderStep('NoSlowDown',0,function()
                local character=LocalPlayer.Character if not character then return end
                local bodyEffects=character:FindFirstChild('BodyEffects') if not bodyEffects then return end
                local movement=bodyEffects:FindFirstChild('Movement')
                if movement then local nws=movement:FindFirstChild('NoWalkSpeed') if nws then nws:Destroy() end local rw=movement:FindFirstChild('ReduceWalk') if rw then rw:Destroy() end local nj=movement:FindFirstChild('NoJumping') if nj then nj:Destroy() end end
                if bodyEffects:FindFirstChild('Reload') and bodyEffects.Reload.Value==true then bodyEffects.Reload.Value=false end
            end)
        else RunService:UnbindFromRenderStep('NoSlowDown') end
    end)
    createToggle(MovementContent,"Noclip",false,function(state)
        if state then
            if _S.NoclipConnection then _S.NoclipConnection:Disconnect() end
            _S.NoclipConnection=RunService.Stepped:Connect(function()
                local char=LocalPlayer.Character if not char then return end
                for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide=false end end
            end)
        else
            if _S.NoclipConnection then _S.NoclipConnection:Disconnect() _S.NoclipConnection=nil end
            task.wait(0.1) local char=LocalPlayer.Character
            if char then for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then part.CanCollide=true end end end
        end
    end)
    LocalPlayer.CharacterAdded:Connect(function(char)
        if _S.NoclipConnection then task.wait(0.3) for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide=false end end end
    end)
    local MovementSettings={
        Bhop=false,BhopMode="Velocity",JumpPowerOverride=false,JumpPower=50,Gravity=196.2,
        Float=false,FloatQ=false,FloatE=false,Step=false,MaxStepHeight=3.2,
        WalkSpeedOverride=false,WalkSpeed=16,WalkSpeedMultiplier=1,MinWalkSpeed=0,MaxWalkSpeed=500,
        WalkSpeedMode="Velocity (Undetectable)",RigidWalk=false,AirJump=false,
        JumpPowerMode="Velocity (Undetectable)",EdgeJumpEnabled=false,EdgeJumpDelay=0,
    }
    createToggle(MovementContent,"Bhop",false,function(state) MovementSettings.Bhop=state end)
    local BhopModeDropdown=Instance.new("TextButton",MovementContent)
    BhopModeDropdown.Size=UDim2.new(1,0,0,50) BhopModeDropdown.BackgroundColor3=_S.Theme.Section
    BhopModeDropdown.Text="Bhop mode: Velocity" BhopModeDropdown.TextColor3=_S.Theme.LabelText BhopModeDropdown.Font=Enum.Font.Gotham BhopModeDropdown.TextSize=15 corner(BhopModeDropdown,10)
    BhopModeDropdown.MouseButton1Click:Connect(function()
        local values={"Velocity","Teleport","Classic"} local current=MovementSettings.BhopMode local nextIndex=1
        for i,v in ipairs(values) do if v==current then nextIndex=i+1 if nextIndex>#values then nextIndex=1 end break end end
        MovementSettings.BhopMode=values[nextIndex] BhopModeDropdown.Text="Bhop mode: "..MovementSettings.BhopMode
    end)
    createToggle(MovementContent,"Step",false,function(state) MovementSettings.Step=state end)
    createSlider(MovementContent,"Max high",0.5,100,3.2,0.1,"%.1f",function(v) MovementSettings.MaxStepHeight=v end)
    UserInputService.InputBegan:Connect(function(input,gpe)
        if gpe then return end
        if input.KeyCode==Enum.KeyCode.Q then MovementSettings.FloatQ=true elseif input.KeyCode==Enum.KeyCode.E then MovementSettings.FloatE=true end
    end)
    UserInputService.InputEnded:Connect(function(input,gpe)
        if gpe then return end
        if input.KeyCode==Enum.KeyCode.Q then MovementSettings.FloatQ=false elseif input.KeyCode==Enum.KeyCode.E then MovementSettings.FloatE=false end
    end)
    local floatPart=nil
    RunService.PreRender:Connect(function()
        workspace.Gravity=MovementSettings.Gravity
        local char=LocalPlayer.Character if not char then return end
        local hrp=char:FindFirstChild("HumanoidRootPart") local humanoid=char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not humanoid then return end
        if MovementSettings.Bhop and humanoid.FloorMaterial~=Enum.Material.Air then
            local jp=MovementSettings.JumpPowerOverride and MovementSettings.JumpPower or humanoid.JumpPower
            if MovementSettings.BhopMode=="Velocity" then hrp.AssemblyLinearVelocity=Vector3.new(hrp.AssemblyLinearVelocity.X,jp,hrp.AssemblyLinearVelocity.Z)
            elseif MovementSettings.BhopMode=="Teleport" then hrp.CFrame=hrp.CFrame+Vector3.new(0,jp,0) hrp.AssemblyLinearVelocity=Vector3.new(hrp.AssemblyLinearVelocity.X,0,hrp.AssemblyLinearVelocity.Z)
            elseif MovementSettings.BhopMode=="Classic" then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
        if not floatPart or not floatPart.Parent then
            floatPart=Instance.new("Part") floatPart.Name="__FL0ATP4RT" floatPart.Anchored=true floatPart.CanQuery=false
            floatPart.Locked=true floatPart.CanTouch=false floatPart.Archivable=true floatPart.Size=Vector3.new(5,0.5,5) floatPart.Parent=workspace
        end
        if MovementSettings.Float then
            if MovementSettings.FloatQ then floatPart.Transparency=0.5 floatPart.CanCollide=false floatPart.Position=hrp.Position-Vector3.new(0,3.25,0)
            elseif MovementSettings.FloatE then floatPart.Transparency=0 floatPart.CanCollide=true floatPart.Position=hrp.Position-Vector3.new(0,2,0)
            else floatPart.Transparency=0 floatPart.CanCollide=true floatPart.Position=hrp.Position-Vector3.new(0,3.25,0) end
        else floatPart.Transparency=1 floatPart.CanCollide=false floatPart.Position=hrp.Position-Vector3.new(0,3.25,0) end
        if MovementSettings.WalkSpeedOverride or MovementSettings.RigidWalk then
            local base=humanoid.WalkSpeed if MovementSettings.WalkSpeedOverride then base=MovementSettings.WalkSpeed end
            local final=math.clamp(base*MovementSettings.WalkSpeedMultiplier,MovementSettings.MinWalkSpeed,MovementSettings.MaxWalkSpeed)
            if MovementSettings.WalkSpeedMode=="Velocity (Undetectable)" and humanoid:GetState()~=Enum.HumanoidStateType.Climbing then
                hrp.AssemblyLinearVelocity=Vector3.new(humanoid.MoveDirection.X*final,hrp.AssemblyLinearVelocity.Y,humanoid.MoveDirection.Z*final)
            elseif MovementSettings.WalkSpeedMode=="Teleport" and humanoid:GetState()~=Enum.HumanoidStateType.Climbing then
                hrp.CFrame=hrp.CFrame+Vector3.new(humanoid.MoveDirection.X*final*0.016,0,humanoid.MoveDirection.Z*final*0.016)
            elseif MovementSettings.WalkSpeedMode=="Classic" then humanoid.WalkSpeed=final end
        end
    end)
    local stepConnection=nil
    local function setupStep(char)
        if stepConnection then stepConnection:Disconnect() stepConnection=nil end
        local root=char:WaitForChild("HumanoidRootPart",8) if not root then return end
        stepConnection=root.Touched:Connect(function(hit)
            if not MovementSettings.Step then return end
            if hit:IsA("Terrain") or hit.Transparency>=1 or not hit.CanQuery then return end
            local top=hit.Position.Y+(hit.Size.Y/2) local feet=root.Position.Y-(root.Size.Y/2) local dist=top-feet
            if dist>0 and dist<MovementSettings.MaxStepHeight then
                local lift=dist+(root.Size.Y*0.65) root.CFrame=root.CFrame+Vector3.new(0,lift,0)
                root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z)
            end
        end)
    end
    if LocalPlayer.Character then task.spawn(setupStep,LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(function(newChar) task.wait(0.1) setupStep(newChar) end)
    UserInputService.InputBegan:Connect(function(input,gpe)
        if gpe then return end
        if input.KeyCode==Enum.KeyCode.Space and MovementSettings.JumpPowerOverride then
            local char=LocalPlayer.Character if not char then return end
            local hrp=char:FindFirstChild("HumanoidRootPart") local hum=char:FindFirstChildWhichIsA("Humanoid")
            if not hrp or not hum then return end
            if hum.FloorMaterial==Enum.Material.Air and not MovementSettings.AirJump then return end
            local val=MovementSettings.JumpPower
            if MovementSettings.JumpPowerMode=="Velocity (Undetectable)" then hrp.AssemblyLinearVelocity=Vector3.new(hrp.AssemblyLinearVelocity.X,val,hrp.AssemblyLinearVelocity.Z)
            elseif MovementSettings.JumpPowerMode=="Teleport" then hrp.CFrame=hrp.CFrame+Vector3.new(0,val,0) hrp.AssemblyLinearVelocity=Vector3.new(hrp.AssemblyLinearVelocity.X,0,hrp.AssemblyLinearVelocity.Z)
            elseif MovementSettings.JumpPowerMode=="Classic" then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
    RunService.Heartbeat:Connect(function() if _S.speedEnabled or _S.speedV2Enabled or _S.speedV3Enabled then setSpeed() end end)
end
SetupMovementTab()

-- ====================== MENU TAB ======================
local function SetupMenuTab()
    local animSection = createSection(pageMenu, "Анимации")
    local animDefs = {
        {"Слайд вкладок","TabSlide"},{"Сворачивание секций","SectionCollapse"},{"Hover эффекты","ButtonHover"},
        {"Открытие/закрытие","MenuOpenClose"},{"Ползунок","SliderKnob"},{"Цвет toggle","ToggleColor"},
    }
    for _, p in ipairs(animDefs) do
        local lbl,key = p[1],p[2]
        createToggle(animSection,lbl,_S.Animations[key],function(v) _S.Animations[key]=v end)
    end
    local colorSection = createSection(pageMenu, "Цвета интерфейса")
    local colorDefs = {
        {"Фон","Background",function(c) main.BackgroundColor3=c end},
        {"Верхняя панель","TopBar",function(c) top.BackgroundColor3=c end},
        {"Акцент / индикатор","Accent",function(c)
            _S.Theme.Accent=c
            for _,child in ipairs(tabsFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    local ind=child:FindFirstChildWhichIsA("Frame") if ind then ind.BackgroundColor3=c end
                    local stroke=child:FindFirstChildWhichIsA("UIStroke") if stroke and stroke.Transparency<0.5 then stroke.Color=c end
                end
            end
        end},
        {"Toggle ON","ToggleOn",function(c) _S.Theme.ToggleOn=c end},
        {"Toggle OFF","ToggleOff",function(c) _S.Theme.ToggleOff=c end},
        {"Заливка слайдера","SliderFill",function(c) _S.Theme.SliderFill=c end},
        {"Bind кнопки","BindBtn",function(c)
            _S.Theme.BindBtn=c
            local btns = {_S.AutoBindBtn, _S.AimLockBindBtn, _S.TriggerKeyBindBtn, _S.HitboxBindBtn, _S.FlyBindBtn, _S.RapidFireBindBtn, _S.NoclipBindBtn2, _S.SpeedBindBtn}
            for _, btn in ipairs(btns) do if btn then btn.BackgroundColor3=c end end
        end},
    }
    for _, def in ipairs(colorDefs) do
        local label,themeKey,applyFn = def[1],def[2],def[3]
        createColorPicker(colorSection,label,_S.Theme[themeKey],function(c) _S.Theme[themeKey]=c applyFn(c) end)
    end
end
SetupMenuTab()

-- ====================== MENU OPEN/CLOSE ======================
local menuOpen = false main.Visible = false
local openT = TweenService:Create(main,TweenInfo.new(0.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(760,520)})
local closeT = TweenService:Create(main,TweenInfo.new(0.34,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Size=UDim2.fromOffset(0,0)})
local function toggleMenu()
    menuOpen = not menuOpen
    if menuOpen then
        main.Visible=true
        if _S.Animations.MenuOpenClose then openT:Play() else main.Size=UDim2.fromOffset(760,520) end
    else
        if _S.Animations.MenuOpenClose then closeT:Play() task.delay(0.35,function() if not menuOpen then main.Visible=false end end)
        else main.Visible=false end
    end
end
closeBtn.MouseButton1Click:Connect(toggleMenu)

local function isBindPressed(key, inputType)
    return false
end

local function isKeyBind(key)
    return key ~= nil
end

-- ====================== INPUT HANDLERS ======================
UserInputService.InputEnded:Connect(function(i, gp)
    if gp then return end
    if _S.AimLockBindKey and _S.AimLockBindMode == "Hold" then
        if (isKeyBind(_S.AimLockBindKey) and i.KeyCode == _S.AimLockBindKey) or isBindPressed(_S.AimLockBindKey, i.UserInputType) then
            _S.AimLockEnabled = false _S.AimLockLockedTarget = nil aimLockFovCircle.Visible = false
            if _S.AimLockConnection then _S.AimLockConnection:Disconnect() _S.AimLockConnection = nil end
        end
    end
    if _S.ToggleKey and _S.BindMode == "Hold" then
        if (isKeyBind(_S.ToggleKey) and i.KeyCode == _S.ToggleKey) or isBindPressed(_S.ToggleKey, i.UserInputType) then
            _S.Monitoring = false
            if _S.AutoShotToggleBtn then _S.AutoShotToggleBtn.Text="OFF" _S.AutoShotToggleBtn.BackgroundColor3=_S.Theme.ToggleOff end
        end
    end
    if _S.TriggerBindKey and _S.TriggerKeyBindMode == "Hold" then
        if (isKeyBind(_S.TriggerBindKey) and i.KeyCode == _S.TriggerBindKey) or isBindPressed(_S.TriggerBindKey, i.UserInputType) then
            _S.TriggerbotEnabled = false UpdateTriggerbot()
        end
    end
    if _S.HitboxBindKey and _S.HitboxBindMode2 == "Hold" then
        if (isKeyBind(_S.HitboxBindKey) and i.KeyCode == _S.HitboxBindKey) or isBindPressed(_S.HitboxBindKey, i.UserInputType) then
            _S.HitboxEnabled = false
        end
    end
    if _S.FlyBindKey and _S.FlyBindMode2 == "Hold" then
        if (isKeyBind(_S.FlyBindKey) and i.KeyCode == _S.FlyBindKey) or isBindPressed(_S.FlyBindKey, i.UserInputType) then
            stopFly()
        end
    end
    if _S.RapidFireBindKey and _S.RapidFireBindMode2 == "Hold" then
        if (isKeyBind(_S.RapidFireBindKey) and i.KeyCode == _S.RapidFireBindKey) or isBindPressed(_S.RapidFireBindKey, i.UserInputType) then
            _S.RapidFireEnabled = false UpdateTriggerbot()
        end
    end
    if _S.NoclipBindKey and _S.NoclipBindMode2 == "Hold" then
        if (isKeyBind(_S.NoclipBindKey) and i.KeyCode == _S.NoclipBindKey) or isBindPressed(_S.NoclipBindKey, i.UserInputType) then
            if _S.NoclipConnection then _S.NoclipConnection:Disconnect() _S.NoclipConnection = nil end
        end
    end
    if _S.SpeedBindKey and _S.SpeedBindMode2 == "Hold" then
        if (isKeyBind(_S.SpeedBindKey) and i.KeyCode == _S.SpeedBindKey) or isBindPressed(_S.SpeedBindKey, i.UserInputType) then
            updateSpeedFlags(false)
        end
    end
end)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift or i.KeyCode == Enum.KeyCode.End then
        toggleMenu() return
    end
    if _S.WaitingForBind and i.KeyCode ~= Enum.KeyCode.Unknown then
        _S.ToggleKey = i.KeyCode
        if _S.AutoBindBtnUpdate then _S.AutoBindBtnUpdate(i.KeyCode) end
        _S.WaitingForBind = false return
    end
    if _S.WaitingForAimLockBind and i.KeyCode ~= Enum.KeyCode.Unknown then
        _S.AimLockBindKey = i.KeyCode
        if _S.AimLockBindBtnUpdate then _S.AimLockBindBtnUpdate(i.KeyCode) end
        _S.WaitingForAimLockBind = false return
    end
    if _S.WaitingForTriggerBind and i.KeyCode ~= Enum.KeyCode.Unknown then
        _S.TriggerBindKey = i.KeyCode
        if _S.TriggerKeyBindBtnUpdate then _S.TriggerKeyBindBtnUpdate(i.KeyCode) end
        _S.WaitingForTriggerBind = false return
    end
    if _S.WaitingForHitboxBind and i.KeyCode ~= Enum.KeyCode.Unknown then
        _S.HitboxBindKey = i.KeyCode
        if _S.HitboxBindBtnUpdate then _S.HitboxBindBtnUpdate(i.KeyCode) end
        _S.WaitingForHitboxBind = false return
    end
    if _S.WaitingForFlyBind and i.KeyCode ~= Enum.KeyCode.Unknown then
        _S.FlyBindKey = i.KeyCode
        if _S.FlyBindBtnUpdate then _S.FlyBindBtnUpdate(i.KeyCode) end
        _S.WaitingForFlyBind = false return
    end
    if _S.WaitingForRapidFireBind and i.KeyCode ~= Enum.KeyCode.Unknown then
        _S.RapidFireBindKey = i.KeyCode
        if _S.RapidFireBindBtnUpdate then _S.RapidFireBindBtnUpdate(i.KeyCode) end
        _S.WaitingForRapidFireBind = false return
    end
    if _S.WaitingForNoclipBind and i.KeyCode ~= Enum.KeyCode.Unknown then
        _S.NoclipBindKey = i.KeyCode
        if _S.NoclipBindBtn2Update then _S.NoclipBindBtn2Update(i.KeyCode) end
        _S.WaitingForNoclipBind = false return
    end
    if _S.WaitingForSpeedBind and i.KeyCode ~= Enum.KeyCode.Unknown then
        _S.SpeedBindKey = i.KeyCode
        if _S.SpeedBindBtnUpdate then _S.SpeedBindBtnUpdate(i.KeyCode) end
        _S.WaitingForSpeedBind = false return
    end
    if _S.ToggleKey then
        if (isKeyBind(_S.ToggleKey) and i.KeyCode == _S.ToggleKey) or isBindPressed(_S.ToggleKey, i.UserInputType) then
            if _S.BindMode == "Toggle" then
                _S.Monitoring = not _S.Monitoring
                if _S.AutoShotToggleBtn then _S.AutoShotToggleBtn.Text = _S.Monitoring and "ON" or "OFF" _S.AutoShotToggleBtn.BackgroundColor3 = _S.Monitoring and _S.Theme.ToggleOn or _S.Theme.ToggleOff end
            elseif _S.BindMode == "Hold" then
                _S.Monitoring = true
                if _S.AutoShotToggleBtn then _S.AutoShotToggleBtn.Text = "ON (hold)" _S.AutoShotToggleBtn.BackgroundColor3 = _S.Theme.ToggleOn end
            end
        end
    end
    if _S.AimLockBindKey then
        if (isKeyBind(_S.AimLockBindKey) and i.KeyCode == _S.AimLockBindKey) or isBindPressed(_S.AimLockBindKey, i.UserInputType) then
            if _S.AimLockBindMode == "Toggle" then
                _S.AimLockEnabled = not _S.AimLockEnabled
                if _S.AimLockEnabled then if not _S.AimLockConnection then _S.AimLockConnection = RunService.RenderStepped:Connect(UpdateAimLock) end
                else _S.AimLockLockedTarget = nil aimLockFovCircle.Visible = false if _S.AimLockConnection then _S.AimLockConnection:Disconnect() _S.AimLockConnection = nil end end
            elseif _S.AimLockBindMode == "Hold" then
                _S.AimLockEnabled = true if not _S.AimLockConnection then _S.AimLockConnection = RunService.RenderStepped:Connect(UpdateAimLock) end
            end
        end
    end
    if _S.TriggerBindKey then
        if (isKeyBind(_S.TriggerBindKey) and i.KeyCode == _S.TriggerBindKey) or isBindPressed(_S.TriggerBindKey, i.UserInputType) then
            if _S.TriggerKeyBindMode == "Toggle" then _S.TriggerbotEnabled = not _S.TriggerbotEnabled UpdateTriggerbot()
            elseif _S.TriggerKeyBindMode == "Hold" then _S.TriggerbotEnabled = true UpdateTriggerbot() end
        end
    end
    if _S.HitboxBindKey then
        if (isKeyBind(_S.HitboxBindKey) and i.KeyCode == _S.HitboxBindKey) or isBindPressed(_S.HitboxBindKey, i.UserInputType) then
            if _S.HitboxBindMode2 == "Toggle" then _S.HitboxEnabled = not _S.HitboxEnabled
            elseif _S.HitboxBindMode2 == "Hold" then _S.HitboxEnabled = true end
        end
    end
    if _S.FlyBindKey then
        if (isKeyBind(_S.FlyBindKey) and i.KeyCode == _S.FlyBindKey) or isBindPressed(_S.FlyBindKey, i.UserInputType) then
            if _S.FlyBindMode2 == "Toggle" then if flyEnabled then stopFly() else startFly() end
            elseif _S.FlyBindMode2 == "Hold" then startFly() end
        end
    end
    if _S.RapidFireBindKey then
        if (isKeyBind(_S.RapidFireBindKey) and i.KeyCode == _S.RapidFireBindKey) or isBindPressed(_S.RapidFireBindKey, i.UserInputType) then
            if _S.RapidFireBindMode2 == "Toggle" then _S.RapidFireEnabled = not _S.RapidFireEnabled UpdateTriggerbot()
            elseif _S.RapidFireBindMode2 == "Hold" then _S.RapidFireEnabled = true UpdateTriggerbot() end
        end
    end
    if _S.NoclipBindKey then
        if (isKeyBind(_S.NoclipBindKey) and i.KeyCode == _S.NoclipBindKey) or isBindPressed(_S.NoclipBindKey, i.UserInputType) then
            if _S.NoclipBindMode2 == "Toggle" then
                if _S.NoclipConnection then _S.NoclipConnection:Disconnect() _S.NoclipConnection = nil task.wait(0.1) local char = LocalPlayer.Character if char then for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then part.CanCollide=true end end end
                else _S.NoclipConnection = RunService.Stepped:Connect(function() local char = LocalPlayer.Character if not char then return end for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide=false end end end) end
            elseif _S.NoclipBindMode2 == "Hold" then
                if _S.NoclipConnection then _S.NoclipConnection:Disconnect() end
                _S.NoclipConnection = RunService.Stepped:Connect(function() local char = LocalPlayer.Character if not char then return end for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide=false end end end)
            end
        end
    end
    if _S.SpeedBindKey then
        if (isKeyBind(_S.SpeedBindKey) and i.KeyCode == _S.SpeedBindKey) or isBindPressed(_S.SpeedBindKey, i.UserInputType) then
            if _S.SpeedBindMode2 == "Toggle" then updateSpeedFlags(not _S.speedToggleState)
            elseif _S.SpeedBindMode2 == "Hold" then updateSpeedFlags(true) end
        end
    end
end)

RunService.Heartbeat:Connect(CheckShot)
RunService.Heartbeat:Connect(CheckAutoReload)
RunService.Heartbeat:Connect(function() if _S.TripleShotEnabled then CheckTripleShot() end end)

-- ====================== LOADING SCREEN ======================
task.delay(0.15, function()
    main.Visible = true
    main.Size = UDim2.fromOffset(0, 0)
    if _S.Animations.MenuOpenClose then openT:Play() else main.Size=UDim2.fromOffset(760,520) end
    task.delay(0.15, function() allTabs[1].SetActive(true) switchToPage(pageLegit) end)
end)

print("Ukussia v14 (ФИКС: Target-only Legit) загружен!")
print("RightShift / End — меню")
print("✅ ВСЕ функции Legit работают ТОЛЬКО на игроков с ролью Target")
print("✅ Friend и Neutral полностью игнорируются в Legit")
print("✅ AimLock, AutoShot, TriggerBot, Hitbox — только Target")
print("✅ Если цель сменила роль — AimLock автоматически переключится")

Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        local waitTime = 0
        while waitTime < 5 and not (player.Character and player.Character:FindFirstChild("Head")) do task.wait(0.5) waitTime = waitTime + 0.5 end
        if _S.savedMods[player.UserId] then
            createModESP(player, "Saved [".._S.savedMods[player.UserId].date.."]")
            _S.notifiedPlayers[player.UserId] = true
        end
    end)
end)

print("✅ Система постоянного сохранения модов активирована!")
print("📁 Файл: " .. (_S.MOD_STORAGE_FILE or "ukussia_mods_list.txt"))
print("📊 Сохранено модов: " .. table_count(_S.savedMods))
