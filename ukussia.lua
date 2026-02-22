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
local defaultChatStates = {
    ChatWindowEnabled = TextChatService:FindFirstChild('ChatWindowConfiguration') and TextChatService.ChatWindowConfiguration.Enabled or false,
    ChatInputEnabled = TextChatService:FindFirstChild('ChatInputBarConfiguration') and TextChatService.ChatInputBarConfiguration.Enabled or false,
    CoreGuiChat = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat),
}

-- ==================== MOD DETECTOR ====================
local MOD_USERNAMES = { ['test'] = true }
local MOD_SYMBOLS = { '✅', '☑️', '👑', '⭐', '🛡️', '✨', '🌟' }
local MOD_GROUP_IDS = { 925309458 }
local detectorEnabled = false
local modAction = 'notify'
local alertSoundId = 6753645454
local notifiedPlayers = {}
local activeESP = {}
local lastCheck = 0

-- ====================== НАСТРОЙКИ ======================
local AmmoName = "Ammo"
local FullMagEnabled = true
local MagShots = 6
local MagDelay = 0.015
local DelayBeforeShot = 0.001
local Monitoring = false
local StarterPlayer = nil
local LastAmmoPerTool = {}
local ToggleKey = Enum.KeyCode.V
local BindMode = "Toggle"
local WaitingForBind = false
local TripleShotEnabled = false
local HitboxEnabled = false
local HitboxSize = 10
local HitboxTransparency = 1
local HitboxConnection = nil
local OriginalSizes = {}
local TriggerbotEnabled = false
local TriggerbotConnection = nil
local TriggerbotDelay = 0.0001
local TriggerBindMode = "Hold"
local CheckDead = false
local CheckWall = false
local CheckFriend = false
local WeaponsEnabled = {
    ["[Double-Barrel SG]"] = true,
    ["[Shotgun]"] = true,
    ["[TacticalShotgun]"] = true,
    ["[Revolver]"] = true,
    ["[Knife]"] = true
}
local SelectHostKey1 = Enum.KeyCode.F1
local SelectHostKey2 = Enum.KeyCode.Z
local AllowFriendsAsHost = true
local ShowTargetEmoji = true
local SelectedHostEmoji = nil
local HostSelectHotkeyEnabled = true
local key1Down = false
local key2Down = false
local AutoShotToggleBtn = nil
local TriggerMainBtn = nil
local AutoBindBtn = nil
local TriggerBindBtn = nil
local NoclipConnection = nil

-- ====================== MOVEMENT VARS ======================
local speedToggleState = false
local speedMethod = "CFrame"
local speedValue = 16
local speedEnabled = false
local speedV2Enabled = false
local speedV3Enabled = false

-- ==================== RAGE (INSTA KILL) ====================
local InstaKillEnabled = false
local InstaKillRadius = 150
local MaxTargets = 1
local InstaKillDelay = 0.01
local XDamage = 10
local ArraySize = 20
local tracer_pool = {}
local lastShotTime = 0

-- ==================== RAGE ФУНКЦИИ ====================
local function create_tracer()
    local t = {}
    t.line = Drawing.new("Line")
    t.line.Color = Color3.fromRGB(255,255,255)
    t.line.Thickness = 2.5
    t.line.Transparency = 1
    t.line.Visible = false
    return t
end

local function get_tracer(i)
    if not tracer_pool[i] then tracer_pool[i] = create_tracer() end
    return tracer_pool[i]
end

local function hide_tracer(i)
    local t = tracer_pool[i]
    if t then t.line.Visible = false end
end

local function hide_all()
    for i = 1, 10 do hide_tracer(i) end
end

local function isKO(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return true end
    local be = char:FindFirstChild("BodyEffects")
    if be then
        local ko = be:FindFirstChild("K.O")
        if ko and ko.Value then return true end
    end
    return false
end

local function isGrabbed(char)
    if char:FindFirstChild("ForceField") then return true end
    for _,v in ipairs(char:GetChildren()) do
        if (v:IsA("BodyVelocity") or v:IsA("BodyPosition")) and v.Name == "Grabbing" then
            return true
        end
    end
    return false
end

local function valid(plr)
    if plr == LocalPlayer then return false end
    local char = plr.Character
    if not char then return false end
    if isKO(char) then return false end
    if isGrabbed(char) then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return false end
    return true
end

local function get_targets()
    local mouse = UserInputService:GetMouseLocation()
    local list = {}
    for _,plr in ipairs(Players:GetPlayers()) do
        if valid(plr) then
            local hrp = plr.Character.HumanoidRootPart
            local screen, on = Camera:WorldToViewportPoint(hrp.Position)
            if on then
                local dist = (Vector2.new(screen.X,screen.Y) - mouse).Magnitude
                if dist <= InstaKillRadius then
                    table.insert(list,{plr = plr, pos = Vector2.new(screen.X,screen.Y), dist = dist})
                end
            end
        end
    end
    table.sort(list,function(a,b) return a.dist < b.dist end)
    local result = {}
    for i=1,math.min(#list,MaxTargets) do result[i] = list[i] end
    return result
end

local function fire(plr)
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local tool
    for _,v in ipairs(LocalPlayer.Character:GetChildren()) do
        if v:IsA("Tool") and v:FindFirstChild("Handle") then tool = v break end
    end
    if not tool then return end
    local pos = head.Position
    local pos_array, head_array = {}, {}
    for i = 1, ArraySize do
        pos_array[i] = pos
        head_array[i] = head
    end
    local event = game:GetService("ReplicatedStorage"):FindFirstChild("ShootEvent")
    if not event then return end
    event:FireServer("ShootGun", tool.Handle, pos, pos_array, head_array,
        {Vector3.new(0,1,0),Vector3.new(0,1,0),Vector3.new(0,1,0)}, {}, os.clock(), 1e9, pos_array, XDamage, 0.01, pos)
end

RunService.Heartbeat:Connect(function()
    if not InstaKillEnabled then hide_all() return end
    hide_all()
    local targets = get_targets()
    local origin = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2 + 35)
    for i = 1, MaxTargets do
        local data = targets[i]
        if data and valid(data.plr) then
            local tracer = get_tracer(i)
            tracer.line.From = origin
            tracer.line.To = data.pos
            tracer.line.Visible = true
        end
    end
    if tick() - lastShotTime >= InstaKillDelay then
        for i, t in ipairs(targets) do
            task.delay(0.003 * (i - 1), function()
                if valid(t.plr) then fire(t.plr) end
            end)
        end
        lastShotTime = tick()
    end
end)

-- ====================== ЦВЕТА ======================
local Theme = {
    Background = Color3.fromRGB(0, 0, 0),
    TopBar = Color3.fromRGB(5, 5, 5),
    Section = Color3.fromRGB(14, 14, 18),
    TabInactive = Color3.fromRGB(18, 18, 22),
    TabActive = Color3.fromRGB(30, 20, 45),
    Accent = Color3.fromRGB(110, 60, 180),
    ToggleOn = Color3.fromRGB(12, 12, 16),
    ToggleOff = Color3.fromRGB(8, 8, 10),
    SliderFill = Color3.fromRGB(240, 240, 245),
    SliderKnob = Color3.fromRGB(200, 200, 210),
    CloseBtn = Color3.fromRGB(20, 20, 25),
    CloseBtnHover = Color3.fromRGB(160, 40, 40),
    BindBtn = Color3.fromRGB(75, 40, 130),
    BindBtnHover = Color3.fromRGB(95, 55, 160),
    PlayerBtn = Color3.fromRGB(18, 18, 22),
    PlayerBtnHover = Color3.fromRGB(30, 20, 45),
    TitleText = Color3.fromRGB(220, 210, 240),
    LabelText = Color3.fromRGB(200, 195, 220),
    SectionTitle = Color3.fromRGB(150, 110, 210),
    InfoText = Color3.fromRGB(180, 175, 200),
}

local Animations = {
    TabSlide = true, SectionCollapse = true, ButtonHover = true,
    MenuOpenClose = true, SliderKnob = true, ToggleColor = true,
}

-- ====================== ФУНКЦИИ ======================
local function SafeTween(obj, info, props)
    if Animations.ButtonHover or Animations.ToggleColor or Animations.TabSlide or Animations.MenuOpenClose or Animations.SectionCollapse or Animations.SliderKnob then
        return TweenService:Create(obj, info, props)
    else
        return TweenService:Create(obj, TweenInfo.new(0), props)
    end
end

local function IsPlayerAlive(player)
    if not player then return false end
    local char = player.Character
    if not char then return false end
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

local function GetPlayerFromPart(part)
    if not part then return nil end
    local model = part:FindFirstAncestorWhichIsA("Model")
    if not model then return nil end
    if model:FindFirstChildWhichIsA("Humanoid") then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr.Character == model then return plr end
        end
    end
    return nil
end

local function HasLineOfSight(targetPart)
    if not targetPart then return false end
    local character = LocalPlayer.Character
    if not character then return false end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return false end
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local distance = direction.Magnitude
    local unitDir = direction.Unit
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character}
    rayParams.IgnoreWater = true
    rayParams.RespectCanQuery = false
    if CheckFriend then
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

local function SimulateClick()
    pcall(function()
        task.wait(DelayBeforeShot)
        mouse1press()
        task.wait(0.025 + math.random() * 0.015)
        mouse1release()
    end)
end

local function CheckShot()
    if not Monitoring or not StarterPlayer then return end
    local char = StarterPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local toolName = tool.Name
    if not WeaponsEnabled[toolName] then return end
    local ammo = tool:FindFirstChild(AmmoName)
    if not ammo or not ammo:IsA("IntValue") then return end
    local curr = ammo.Value
    local prev = LastAmmoPerTool[tool]
    if prev ~= nil and curr < prev then
        if FullMagEnabled then
            for i = 1, MagShots do
                SimulateClick()
                task.wait(MagDelay)
            end
            print("[AutoShot] Выпущено " .. MagShots .. " патронов на " .. toolName)
        else
            SimulateClick()
            print("[AutoShot] Одиночный выстрел на " .. toolName)
        end
    end
    LastAmmoPerTool[tool] = curr
end

local function CheckTripleShot()
    if not TripleShotEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or tool.Name ~= "[Double-Barrel SG]" then return end
    local ammo = tool:FindFirstChild(AmmoName)
    if not ammo or not ammo:IsA("IntValue") then return end
    local curr = ammo.Value
    local prev = LastAmmoPerTool[tool] or curr
    if prev ~= nil and curr < prev then
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid then return end
        local backpack = LocalPlayer.Backpack
        local shotgun = backpack:FindFirstChild("[Shotgun]")
        if shotgun then humanoid:EquipTool(shotgun) task.wait(0.03) SimulateClick() end
        local tactical = backpack:FindFirstChild("[TacticalShotgun]")
        if tactical then humanoid:EquipTool(tactical) task.wait(0.03) SimulateClick() end
        local doublebarrel = backpack:FindFirstChild("[Double-Barrel SG]")
        if doublebarrel then humanoid:EquipTool(doublebarrel) end
    end
    LastAmmoPerTool[tool] = curr
end

local function UpdateHitboxes()
    if HitboxConnection then HitboxConnection:Disconnect() HitboxConnection = nil end
    for player, data in pairs(OriginalSizes) do
        pcall(function()
            if player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp and data.size then
                    hrp.Size = data.size
                    hrp.Transparency = data.transparency
                    hrp.CanCollide = data.canCollide
                end
            end
        end)
    end
    OriginalSizes = {}
    if HitboxEnabled then
        HitboxConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and humanoid and humanoid.Health > 0 then
                            if not OriginalSizes[player] then
                                OriginalSizes[player] = {size = hrp.Size, transparency = hrp.Transparency, canCollide = hrp.CanCollide}
                            end
                            hrp.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                            hrp.Transparency = HitboxTransparency
                            hrp.CanCollide = false
                        end
                    end
                end
            end)
        end)
    end
end

local function UpdateTriggerbot()
    if TriggerbotConnection then TriggerbotConnection:Disconnect() TriggerbotConnection = nil end
    if TriggerbotEnabled then
        TriggerbotConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                local tool = char:FindFirstChildOfClass("Tool")
                if not tool then return end
                if not WeaponsEnabled[tool.Name] then return end
                local mouse = LocalPlayer:GetMouse()
                local target = mouse.Target
                if target then
                    local targetPart = target
                    local targetParent = targetPart.Parent
                    local targetPlayer = nil
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
                        if CheckDead and not IsPlayerAlive(targetPlayer) then return end
                        if CheckFriend and IsFriend(targetPlayer) then return end
                        if CheckWall and not HasLineOfSight(targetPart) then return end
                        task.wait(TriggerbotDelay)
                        mouse1press()
                        task.wait(0.025 + math.random() * 0.015)
                        mouse1release()
                    end
                end
            end)
        end)
    end
end

local function ToggleAutoshot()
    if BindMode == "Toggle" then
        Monitoring = not Monitoring
        if AutoShotToggleBtn then
            AutoShotToggleBtn.Text = Monitoring and "ON" or "OFF"
            AutoShotToggleBtn.BackgroundColor3 = Monitoring and Theme.ToggleOn or Theme.ToggleOff
        end
    end
end

local function ToggleTriggerbot()
    if TriggerBindMode == "Toggle" then
        TriggerbotEnabled = not TriggerbotEnabled
        if TriggerMainBtn then
            TriggerMainBtn.Text = TriggerbotEnabled and "ON" or "OFF"
            TriggerMainBtn.BackgroundColor3 = TriggerbotEnabled and Theme.ToggleOn or Theme.ToggleOff
        end
        UpdateTriggerbot()
    end
end

RunService.RenderStepped:Connect(function()
    if BindMode == "Hold" then
        local should = UserInputService:IsKeyDown(ToggleKey)
        if Monitoring ~= should then
            Monitoring = should
            if AutoShotToggleBtn then
                AutoShotToggleBtn.Text = Monitoring and "ON (hold)" or "OFF"
                AutoShotToggleBtn.BackgroundColor3 = Monitoring and Theme.ToggleOn or Theme.ToggleOff
            end
        end
    end
    if TriggerBindMode == "Hold" then
        local should = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if TriggerbotEnabled ~= should then
            TriggerbotEnabled = should
            if TriggerMainBtn then
                TriggerMainBtn.Text = TriggerbotEnabled and "ON (ПКМ)" or "OFF"
                TriggerMainBtn.BackgroundColor3 = TriggerbotEnabled and Theme.ToggleOn or Theme.ToggleOff
            end
            UpdateTriggerbot()
        end
    end
end)

-- ====================== АВТО-ХОСТ (ТОГГЛ F1+Z) ======================
local function GetClosestPlayerToCrosshair()
    local camera = workspace.CurrentCamera
    local mouseLoc = UserInputService:GetMouseLocation()
    local closest, dist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
            local head = plr.Character.Head
            local sp, onScreen = camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local d = (Vector2.new(sp.X, sp.Y) - mouseLoc).Magnitude
                if d < dist then
                    dist = d
                    closest = plr
                end
            end
        end
    end
    return closest
end

local function RemoveEmoji()
    if SelectedHostEmoji then
        pcall(function() SelectedHostEmoji:Destroy() end)
        SelectedHostEmoji = nil
    end
end

local function AttachEmojiToPlayer(plr)
    RemoveEmoji()
    if not plr or not ShowTargetEmoji then return end
    local char = plr.Character
    if not char then
        plr.CharacterAdded:Once(function()
            task.wait(0.5)
            if plr == StarterPlayer then AttachEmojiToPlayer(plr) end
        end)
        return
    end
    local head = char:WaitForChild("Head", 3)
    if not head then return end
    local bg = Instance.new("BillboardGui")
    bg.Name = "TargetEmoji_" .. plr.UserId
    bg.Adornee = head
    bg.Size = UDim2.new(0, 60, 0, 60)
    bg.StudsOffset = Vector3.new(0, 2.5, 0)
    bg.AlwaysOnTop = true
    bg.ResetOnSpawn = false
    bg.Parent = game.CoreGui
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "🎯"
    lbl.TextColor3 = Color3.fromRGB(255,215,0)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.new(0,0,0)
    SelectedHostEmoji = bg
end

local oldStarter = nil
RunService.RenderStepped:Connect(function()
    if StarterPlayer ~= oldStarter then
        oldStarter = StarterPlayer
        AttachEmojiToPlayer(StarterPlayer)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    if plr == StarterPlayer then
        StarterPlayer = nil
        RemoveEmoji()
    end
end)

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(1)
        if plr == StarterPlayer and ShowTargetEmoji then
            AttachEmojiToPlayer(plr)
        end
    end)
end)

UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == SelectHostKey1 then key1Down = true end
    if inp.KeyCode == SelectHostKey2 then key2Down = true end
    if key1Down and key2Down and HostSelectHotkeyEnabled then
        local closest = GetClosestPlayerToCrosshair()
        if closest then
            if StarterPlayer == closest then
                StarterPlayer = nil
                RemoveEmoji()
                print("[Host Select] Метка хоста убрана")
            else
                if AllowFriendsAsHost or not IsFriend(closest) then
                    StarterPlayer = closest
                    LastAmmoPerTool = {}
                    print("[Host Select] Выбран: " .. closest.Name)
                    AttachEmojiToPlayer(closest)
                else
                    print("[Host Select] Друзей выбирать запрещено")
                end
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.KeyCode == SelectHostKey1 then key1Down = false end
    if inp.KeyCode == SelectHostKey2 then key2Down = false end
end)

-- ====================== GUI ======================
local gui = Instance.new("ScreenGui")
gui.Name = "UkussiaAutoShot"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local function corner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = obj
end

local main = Instance.new("Frame", gui)
main.Size = UDim2.fromOffset(760, 520)
main.Position = UDim2.new(0.5, -380, 0.5, -260)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = Theme.Background
main.BorderSizePixel = 0
main.ClipsDescendants = true
corner(main, 14)

local top = Instance.new("Frame", main)
top.Size = UDim2.new(1,0,0,56)
top.BackgroundColor3 = Theme.TopBar
corner(top, 14)

local title = Instance.new("TextLabel", top)
title.Size = UDim2.new(1,-70,1,0)
title.Position = UDim2.fromOffset(16,0)
title.BackgroundTransparency = 1
title.Text = "Ukussia"
title.Font = Enum.Font.GothamSemibold
title.TextSize = 20
title.TextColor3 = Theme.TitleText
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", top)
closeBtn.Size = UDim2.fromOffset(36,36)
closeBtn.Position = UDim2.new(1,-46,0,10)
closeBtn.Text = "×"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 24
closeBtn.TextColor3 = Color3.fromRGB(180,180,190)
closeBtn.BackgroundColor3 = Theme.CloseBtn
corner(closeBtn, 18)

closeBtn.MouseEnter:Connect(function()
    if not Animations.ButtonHover then closeBtn.BackgroundColor3 = Theme.CloseBtnHover closeBtn.TextColor3 = Color3.fromRGB(255,255,255) return end
    TweenService:Create(closeBtn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = Theme.CloseBtnHover,
        TextColor3 = Color3.fromRGB(255, 255, 255)
    }):Play()
end)
closeBtn.MouseLeave:Connect(function()
    if not Animations.ButtonHover then closeBtn.BackgroundColor3 = Theme.CloseBtn closeBtn.TextColor3 = Color3.fromRGB(180,180,190) return end
    TweenService:Create(closeBtn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = Theme.CloseBtn,
        TextColor3 = Color3.fromRGB(180, 180, 190)
    }):Play()
end)

local dragging = false
local dragStart, startPos
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local tabsFrame = Instance.new("Frame", main)
tabsFrame.Position = UDim2.fromOffset(14,64)
tabsFrame.Size = UDim2.new(0,140,1,-78)
tabsFrame.BackgroundTransparency = 1
local tabLayout = Instance.new("UIListLayout", tabsFrame) tabLayout.Padding = UDim.new(0,6) tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", tabsFrame).PaddingTop = UDim.new(0,8)

local pages = Instance.new("Frame", main)
pages.Position = UDim2.fromOffset(170,64)
pages.Size = UDim2.new(1,-184,1,-78)
pages.BackgroundTransparency = 1
pages.ClipsDescendants = true

local function createPage()
    local p = Instance.new("ScrollingFrame", pages)
    p.Size = UDim2.new(1,0,1,0)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = Theme.Accent
    p.BackgroundTransparency = 1
    p.Visible = false
    p.Position = UDim2.new(0, 20, 0, 0)
    local l = Instance.new("UIListLayout", p) l.Padding = UDim.new(0,12)
    local pad = Instance.new("UIPadding", p) pad.PaddingTop = UDim.new(0,8) pad.PaddingLeft = UDim.new(0,8) pad.PaddingRight = UDim.new(0,8)
    local function updateScroll()
        local canScroll = p.AbsoluteCanvasSize.Y > p.AbsoluteSize.Y
        p.ScrollBarThickness = canScroll and 3 or 0
        p.ScrollingEnabled = canScroll
    end
    p:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateScroll)
    p:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScroll)
    return p
end

local currentPage = nil
local isSwitching = false
local function switchToPage(newPage)
    if newPage == currentPage or isSwitching then return end
    isSwitching = true
    local function showNew()
        newPage.Position = UDim2.new(0, 18, 0, 0)
        newPage.BackgroundTransparency = 1
        newPage.Visible = true
        if Animations.TabSlide then
            TweenService:Create(newPage, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0, 0)
            }):Play()
        else
            newPage.Position = UDim2.new(0, 0, 0, 0)
        end
        task.delay(0.05, function()
            isSwitching = false
        end)
        currentPage = newPage
    end
    if currentPage then
        local oldPage = currentPage
        if Animations.TabSlide then
            local tweenOut = TweenService:Create(oldPage, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(0, -18, 0, 0)
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                oldPage.Visible = false
                oldPage.Position = UDim2.new(0, 20, 0, 0)
                showNew()
            end)
        else
            oldPage.Visible = false
            oldPage.Position = UDim2.new(0, 20, 0, 0)
            showNew()
        end
    else
        showNew()
        isSwitching = false
    end
end

local HEADER_H = 36
local SECTION_GAP = 8
local function createSection(parent, text)
    local wrapper = Instance.new("Frame", parent)
    wrapper.BackgroundTransparency = 1
    wrapper.Size = UDim2.new(1, 0, 0, HEADER_H)
    wrapper.ClipsDescendants = true
    local header = Instance.new("TextButton", wrapper)
    header.Size = UDim2.new(1, 0, 0, HEADER_H)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Theme.Section
    header.Text = ""
    header.AutoButtonColor = false
    corner(header, 10)
    local titleLabel = Instance.new("TextLabel", header)
    titleLabel.Size = UDim2.new(1,-40,1,0)
    titleLabel.Position = UDim2.fromOffset(12,0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = text
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = Theme.SectionTitle
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    local arrow = Instance.new("TextLabel", header)
    arrow.Size = UDim2.new(0,24,1,0)
    arrow.Position = UDim2.new(1,-34,0,0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 20
    arrow.TextColor3 = Theme.SectionTitle
    arrow.Rotation = -90
    local normalColor = Theme.Section
    local hoverColor = Color3.fromRGB(36,36,50)
    header.MouseEnter:Connect(function()
        if not Animations.ButtonHover then header.BackgroundColor3 = hoverColor return end
        TweenService:Create(header, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = hoverColor}):Play()
    end)
    header.MouseLeave:Connect(function()
        if not Animations.ButtonHover then header.BackgroundColor3 = normalColor return end
        TweenService:Create(header, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = normalColor}):Play()
    end)
    local content = Instance.new("Frame", wrapper)
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 0, 0, HEADER_H + SECTION_GAP)
    content.Size = UDim2.new(1, 0, 0, 0)
    content.AutomaticSize = Enum.AutomaticSize.Y
    local contentLayout = Instance.new("UIListLayout", content)
    contentLayout.Padding = UDim.new(0, 12)
    local contentPad = Instance.new("UIPadding", content)
    contentPad.PaddingLeft = UDim.new(0, 8)
    contentPad.PaddingRight = UDim.new(0, 8)
    contentPad.PaddingTop = UDim.new(0, 4)
    contentPad.PaddingBottom = UDim.new(0, 8)
    local isOpen = false
    local animTween = nil
    local function getFullHeight()
        return HEADER_H + SECTION_GAP + content.AbsoluteSize.Y
    end
    local function open()
        isOpen = true
        if animTween then animTween:Cancel() end
        task.wait()
        local targetH = getFullHeight()
        if Animations.SectionCollapse then
            animTween = TweenService:Create(wrapper,
                TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Size = UDim2.new(1, 0, 0, targetH) }
            )
            animTween:Play()
            TweenService:Create(arrow, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 0}):Play()
        else
            wrapper.Size = UDim2.new(1, 0, 0, targetH)
            arrow.Rotation = 0
        end
    end
    local function close()
        isOpen = false
        if animTween then animTween:Cancel() end
        if Animations.SectionCollapse then
            animTween = TweenService:Create(wrapper,
                TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                { Size = UDim2.new(1, 0, 0, HEADER_H) }
            )
            animTween:Play()
            TweenService:Create(arrow, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Rotation = -90}):Play()
        else
            wrapper.Size = UDim2.new(1, 0, 0, HEADER_H)
            arrow.Rotation = -90
        end
    end
    header.MouseButton1Click:Connect(function()
        if isOpen then close() else open() end
    end)
    return content, function() task.delay(0.08, function() open() end) end
end

local pageLegit = createPage()
local pageMisc = createPage()
local pagePlayerList = createPage()
local pageMovement = createPage()
local pageVisual = createPage()
local pageBind = createPage()
local pageMenu = createPage()

local allTabs = {}
local function createTab(name, page)
    local b = Instance.new("TextButton", tabsFrame)
    b.Size = UDim2.new(1,-12,0,44)
    b.BackgroundColor3 = Theme.TabInactive
    b.Text = name
    b.Font = Enum.Font.GothamSemibold
    b.TextColor3 = Color3.fromRGB(190,190,210)
    b.TextSize = 15
    b.AutoButtonColor = false
    corner(b,10)
    local stroke = Instance.new("UIStroke", b) stroke.Color = Color3.fromRGB(70,70,100) stroke.Thickness = 1.4 stroke.Transparency = 0.65
    local ind = Instance.new("Frame", b) ind.Size = UDim2.new(0,4,0.5,0) ind.Position = UDim2.new(0,-2,0.25,0) ind.BackgroundColor3 = Theme.Accent corner(ind,2) ind.Visible = false
    local function setActive(active)
        if active then
            if Animations.ButtonHover then
                TweenService:Create(b, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Theme.TabActive,
                    TextColor3 = Color3.fromRGB(240,240,255)
                }):Play()
            else
                b.BackgroundColor3 = Theme.TabActive
                b.TextColor3 = Color3.fromRGB(240,240,255)
            end
            stroke.Transparency = 0.2
            stroke.Color = Theme.Accent
            ind.Visible = true
        else
            if Animations.ButtonHover then
                TweenService:Create(b, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Theme.TabInactive,
                    TextColor3 = Color3.fromRGB(190,190,210)
                }):Play()
            else
                b.BackgroundColor3 = Theme.TabInactive
                b.TextColor3 = Color3.fromRGB(190,190,210)
            end
            stroke.Transparency = 0.65
            stroke.Color = Color3.fromRGB(70,70,100)
            ind.Visible = false
        end
    end
    b.MouseEnter:Connect(function()
        local isActive = false
        for _, t in ipairs(allTabs) do
            if t.Page == page and t.Page.Visible then isActive = true break end
        end
        if not isActive then
            if Animations.ButtonHover then
                TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = Color3.fromRGB(40,40,54)
                }):Play()
            else
                b.BackgroundColor3 = Color3.fromRGB(40,40,54)
            end
        end
    end)
    b.MouseLeave:Connect(function()
        local isActive = false
        for _, t in ipairs(allTabs) do
            if t.Page == page and t.Page.Visible then isActive = true break end
        end
        if not isActive then
            if Animations.ButtonHover then
                TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = Theme.TabInactive
                }):Play()
            else
                b.BackgroundColor3 = Theme.TabInactive
            end
        end
    end)
    table.insert(allTabs, {Page = page, SetActive = setActive})
    b.MouseButton1Click:Connect(function()
        for _, t in ipairs(allTabs) do t.SetActive(false) end
        setActive(true)
        switchToPage(page)
    end)
    return b
end

createTab("Legit", pageLegit)
createTab("Misc", pageMisc)
createTab("Player list", pagePlayerList)
createTab("Movment", pageMovement)
createTab("Visual", pageVisual)
createTab("Bind", pageBind)
createTab("Menu", pageMenu)

local function createToggle(parent, text, def, cb)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,0,0,50)
    f.BackgroundColor3 = Theme.Section
    corner(f,10)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -85, 1, 0)
    l.Position = UDim2.fromOffset(12,0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Theme.LabelText
    l.TextSize = 15
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(0,60,0,30)
    btn.Position = UDim2.new(1, -72, 0.5, -15)
    btn.BackgroundColor3 = def and Theme.ToggleOn or Theme.ToggleOff
    btn.Text = def and "ON" or "OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    corner(btn,15)
    btn.MouseEnter:Connect(function()
        if not Animations.ButtonHover then return end
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 64, 0, 32)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        if not Animations.ButtonHover then return end
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 60, 0, 30)
        }):Play()
    end)
    local v = def
    btn.MouseButton1Click:Connect(function()
        v = not v
        btn.Text = v and "ON" or "OFF"
        if Animations.ToggleColor then
            TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = v and Theme.ToggleOn or Theme.ToggleOff
            }):Play()
        else
            btn.BackgroundColor3 = v and Theme.ToggleOn or Theme.ToggleOff
        end
        cb(v)
    end)
    return f, btn
end

local function createSlider(parent, text, min, max, def, step, fmt, cb)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,0,0,70)
    f.BackgroundColor3 = Theme.Section
    corner(f,10)
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1,0,0,20)
    lbl.Position = UDim2.fromOffset(12,5)
    lbl.BackgroundTransparency = 1
    lbl.Text = text .. ": " .. string.format(fmt or "%.2f", def)
    lbl.TextColor3 = Color3.fromRGB(180,180,200)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(1,-24,0,8)
    bar.Position = UDim2.fromOffset(12,35)
    bar.BackgroundColor3 = Color3.fromRGB(60,60,70)
    corner(bar,4)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((def-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = Theme.SliderFill
    corner(fill,4)
    local knob = Instance.new("TextButton", bar)
    knob.Size = UDim2.new(0,20,0,20)
    knob.Position = UDim2.new((def-min)/(max-min),-10,0.5,-10)
    knob.BackgroundColor3 = Theme.SliderKnob
    knob.Text = ""
    corner(knob,10)
    knob.MouseEnter:Connect(function()
        if not Animations.SliderKnob then return end
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = Color3.fromRGB(150,255,210),
            Size = UDim2.new(0, 24, 0, 24)
        }):Play()
    end)
    knob.MouseLeave:Connect(function()
        if not Animations.SliderKnob then return end
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = Theme.SliderKnob,
            Size = UDim2.new(0, 20, 0, 20)
        }):Play()
    end)
    local drag = false
    knob.MouseButton1Down:Connect(function() drag = true end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            knob.Position = UDim2.new(rel, -10, 0.5, -10)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            local val = min + rel * (max - min)
            val = math.floor(val / step) * step
            lbl.Text = text .. ": " .. string.format(fmt or "%.2f", val)
            cb(val)
        end
    end)
end

-- ====================== ЗАПОЛНЕНИЕ ВКЛАДОК ======================
-- ====================== VISUAL: ОБЩИЕ УТИЛИТЫ ======================
local function color3ToHex(c)
    return string.format('#%02X%02X%02X', math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
end
local function getRainbowColor(offset)
    return Color3.fromHSV(((tick()*60+(offset or 0))%360)/360, 1, 1)
end
local function getFadingAlpha()
    return (math.sin(tick()*2)+1)/2
end

-- ====================== VISUAL: ESP STATE ======================
local espActive   = false
local rainbowESP  = false
local fadingESP   = false
local espModes    = {Names=false,Distance=false,Chams=false,Tracers=false,Box=false,HealthBar=false,Tool=false,Direction=false}
local espColors   = {
    Names    ={Color1=Color3.fromRGB(255,255,255),Color2=Color3.fromRGB(255,255,255)},
    Distance ={Color1=Color3.fromRGB(255,255,255),Color2=Color3.fromRGB(255,255,255)},
    Chams    ={Color1=Color3.fromRGB(255,255,255),Color2=Color3.fromRGB(255,255,255)},
    Tracers  ={Color1=Color3.fromRGB(255,255,255),Color2=Color3.fromRGB(255,255,255)},
    Box      ={Color1=Color3.fromRGB(255,255,255),Color2=Color3.fromRGB(255,255,255)},
    HealthBar={Color1=Color3.fromRGB(0,255,0),    Color2=Color3.fromRGB(255,255,255)},
    Tool     ={Color1=Color3.fromRGB(255,200,0),  Color2=Color3.fromRGB(255,255,0)  },
    Direction={Color1=Color3.fromRGB(255,0,0),    Color2=Color3.fromRGB(255,100,100)},
}
local espObjects = {}

local function espFX(c1,c2)
    local fc=Color3.new((c1.R+c2.R)/2,(c1.G+c2.G)/2,(c1.B+c2.B)/2)
    if rainbowESP then fc=getRainbowColor() end
    return fc, fadingESP and getFadingAlpha() or 1
end

local function espArrow(wp)
    local p,v=Camera:WorldToViewportPoint(wp)
    if v then return nil,true end
    local ctr=Camera.ViewportSize/2
    local dir=(Vector2.new(p.X,p.Y)-ctr).Unit
    local ang=math.atan2(dir.Y,dir.X)
    local tip=ctr+Vector2.new(math.cos(ang),math.sin(ang))*(ctr.Magnitude-40)
    local perp=Vector2.new(-math.sin(ang),math.cos(ang))*12
    return {tip,tip-dir*18+perp,tip-dir*18-perp},false
end

local function espClear(player)
    local o=espObjects[player.UserId] if not o then return end
    if o.LabelGui then o.LabelGui:Destroy() end
    if o.Highlight then pcall(function()o.Highlight:Destroy()end) end
    for _,k in ipairs({"TracerLine","Box","BoxOutline","HealthBar","HealthBarOutline"}) do
        if o[k] then pcall(function()o[k].Visible=false o[k]:Remove()end) end
    end
    if o.ToolLabel and o.ToolLabel.Parent then o.ToolLabel:Destroy() end
    if o.DirectionLines then for _,l in ipairs(o.DirectionLines) do pcall(function()l.Visible=false l:Remove()end) end end
    espObjects[player.UserId]=nil
end

local function espClearAll()
    for _,p in pairs(Players:GetPlayers()) do espClear(p) end
end

local function espMakeBoxes(uid)
    local o=espObjects[uid]
    local out=Drawing.new('Square') out.Visible=false out.Color=Color3.new(0,0,0) out.Thickness=2 out.Filled=false
    local box=Drawing.new('Square') box.Visible=false box.Color=espColors.Box.Color1 box.Thickness=1 box.Filled=false box.Transparency=1
    local hbo=Drawing.new('Square') hbo.Visible=false hbo.Color=Color3.new(0,0,0) hbo.Thickness=2 hbo.Filled=false
    local hb =Drawing.new('Square') hb.Visible=false  hb.Color=espColors.HealthBar.Color1 hb.Thickness=1 hb.Filled=true hb.Transparency=1
    o.BoxOutline=out o.Box=box o.HealthBarOutline=hbo o.HealthBar=hb
end

local function espChams(player)
    local function go()
        if not espModes.Chams or not espActive or not player.Character then return end
        local old=player.Character:FindFirstChild('ESP_Chams') if old then old:Destroy() end
        local hl=Instance.new('Highlight')
        hl.Name='ESP_Chams' hl.Adornee=player.Character
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor=espColors.Chams.Color1 hl.FillTransparency=0.5
        hl.OutlineColor=Color3.new(0,0,0) hl.OutlineTransparency=0
        hl.Parent=player.Character
        espObjects[player.UserId].Highlight=hl
    end
    go()
    player.CharacterAdded:Connect(function() task.wait(0.2) go() end)
end

local function espCreate(player)
    if player==LocalPlayer then return end
    espClear(player)
    espObjects[player.UserId]={}
    local sg=Instance.new('ScreenGui')
    sg.Name='ESP_GUI_'..player.Name sg.IgnoreGuiInset=true sg.ResetOnSpawn=false sg.Parent=game.CoreGui
    local lbl=Instance.new('TextLabel')
    lbl.Size=UDim2.new(0,150,0,50) lbl.BackgroundTransparency=1 lbl.Font=Enum.Font.Code lbl.TextSize=14
    lbl.TextColor3=Color3.new(1,1,1) lbl.TextStrokeTransparency=0 lbl.TextStrokeColor3=Color3.new(0,0,0)
    lbl.TextXAlignment=Enum.TextXAlignment.Center lbl.TextYAlignment=Enum.TextYAlignment.Top
    lbl.Text='' lbl.RichText=true lbl.Visible=false lbl.Parent=sg
    local tl=Instance.new('TextLabel')
    tl.Size=UDim2.new(0,150,0,18) tl.Position=UDim2.new(0,0,0,36) tl.BackgroundTransparency=1
    tl.Font=Enum.Font.Code tl.TextSize=14 tl.TextColor3=espColors.Tool.Color1
    tl.TextStrokeTransparency=0 tl.TextStrokeColor3=Color3.new(0,0,0)
    tl.TextXAlignment=Enum.TextXAlignment.Center tl.Text='' tl.RichText=true tl.Visible=false tl.Parent=sg
    local dl={}
    for _=1,3 do
        local ln=Drawing.new('Line') ln.Visible=false ln.Thickness=2 ln.Transparency=1 ln.Color=espColors.Direction.Color1
        table.insert(dl,ln)
    end
    local tr=Drawing.new('Line') tr.Thickness=1.5 tr.Transparency=1 tr.Color=espColors.Tracers.Color1 tr.Visible=false
    local o=espObjects[player.UserId]
    o.LabelGui=sg o.Label=lbl o.ToolLabel=tl o.DirectionLines=dl o.TracerLine=tr
    espMakeBoxes(player.UserId)
    if espModes.Chams then espChams(player) end
end

local function espUpdate(player)
    local o=espObjects[player.UserId] if not o then return end
    local ch=player.Character
    local hum=ch and ch:FindFirstChildOfClass('Humanoid')
    local root=ch and (ch:FindFirstChild('UpperTorso') or ch:FindFirstChild('HumanoidRootPart'))
    if not root then
        if o.Label then o.Label.Visible=false end
        if o.TracerLine then o.TracerLine.Visible=false end
        if o.Highlight then o.Highlight.Enabled=false end
        if o.Box then o.Box.Visible=false o.BoxOutline.Visible=false o.HealthBar.Visible=false o.HealthBarOutline.Visible=false end
        if o.ToolLabel then o.ToolLabel.Visible=false end
        if o.DirectionLines then for _,l in ipairs(o.DirectionLines) do l.Visible=false end end
        return
    end
    local bsp,bon=Camera:WorldToViewportPoint(root.Position)
    local nsp,non=Camera:WorldToViewportPoint(root.Position+Vector3.new(0,2.5,0))
    local dist=(Camera.CFrame.Position-root.Position).Magnitude
    local info=''
    if espModes.Names then
        local c,a=espFX(espColors.Names.Color1,espColors.Names.Color2)
        o.Label.TextColor3=c o.Label.TextTransparency=1-a
        info=info..string.format('<font color="%s">%s</font>\n',color3ToHex(c),player.DisplayName)
    end
    if espModes.Distance then
        local c=espFX(espColors.Distance.Color1,espColors.Distance.Color2)
        info=info..string.format('<font color="%s">%.0fm</font>\n',color3ToHex(c),dist)
    end
    if o.Label then
        o.Label.Text=info o.Label.Position=UDim2.new(0,nsp.X-75,0,nsp.Y-30) o.Label.Visible=non and info~=''
    end
    local head=ch:FindFirstChild('Head')
    if head and (espModes.Box or espModes.HealthBar) and bon then
        local hp=Camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.5,0))
        local rp=Camera:WorldToViewportPoint(root.Position-Vector3.new(0,3,0))
        local bH=math.max(math.abs(hp.Y-rp.Y),10)
        local bW=bH/2 local bX=hp.X-bW/2 local bY=hp.Y-bH*0.1
        local bc,ba=espFX(espColors.Box.Color1,espColors.Box.Color2)
        o.Box.Size=Vector2.new(bW,bH) o.Box.Position=Vector2.new(bX,bY)
        o.Box.Color=rainbowESP and getRainbowColor() or bc o.Box.Transparency=ba o.Box.Visible=espModes.Box
        o.BoxOutline.Size=Vector2.new(bW,bH) o.BoxOutline.Position=Vector2.new(bX,bY) o.BoxOutline.Transparency=ba o.BoxOutline.Visible=espModes.Box
        if espModes.HealthBar and hum then
            local ratio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
            local hc,ha=espFX(espColors.HealthBar.Color1,espColors.HealthBar.Color2)
            local hbH=bH*ratio
            o.HealthBar.Size=Vector2.new(3,hbH) o.HealthBar.Position=Vector2.new(bX-7,bY+(bH-hbH))
            o.HealthBar.Color=hc o.HealthBar.Transparency=ha o.HealthBar.Visible=true
            o.HealthBarOutline.Size=Vector2.new(3,bH) o.HealthBarOutline.Position=Vector2.new(bX-7,bY) o.HealthBarOutline.Transparency=ba o.HealthBarOutline.Visible=true
        else o.HealthBar.Visible=false o.HealthBarOutline.Visible=false end
    else
        if o.Box then o.Box.Visible=false o.BoxOutline.Visible=false o.HealthBar.Visible=false o.HealthBarOutline.Visible=false end
    end
    if espModes.Direction then
        local pts,os2=espArrow(root.Position)
        if pts and not os2 then
            local dc,da=espFX(espColors.Direction.Color1,espColors.Direction.Color2)
            o.DirectionLines[1].From=pts[1] o.DirectionLines[1].To=pts[2] o.DirectionLines[1].Color=dc o.DirectionLines[1].Transparency=da o.DirectionLines[1].Visible=true
            o.DirectionLines[2].From=pts[2] o.DirectionLines[2].To=pts[3] o.DirectionLines[2].Color=dc o.DirectionLines[2].Transparency=da o.DirectionLines[2].Visible=true
            o.DirectionLines[3].From=pts[3] o.DirectionLines[3].To=pts[1] o.DirectionLines[3].Color=dc o.DirectionLines[3].Transparency=da o.DirectionLines[3].Visible=true
        else for _,l in ipairs(o.DirectionLines) do l.Visible=false end end
    else for _,l in ipairs(o.DirectionLines) do l.Visible=false end end
    if espModes.Tracers and bon then
        local tc,ta=espFX(espColors.Tracers.Color1,espColors.Tracers.Color2)
        o.TracerLine.From=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
        o.TracerLine.To=Vector2.new(bsp.X,bsp.Y) o.TracerLine.Color=tc o.TracerLine.Transparency=ta o.TracerLine.Visible=true
    elseif o.TracerLine then o.TracerLine.Visible=false end
    if o.Highlight and o.Highlight.Parent then
        if espModes.Chams then
            local cc=espFX(espColors.Chams.Color1,espColors.Chams.Color2)
            o.Highlight.FillColor=cc o.Highlight.FillTransparency=0.5 o.Highlight.Enabled=true
        else o.Highlight.Enabled=false end
    end
    if o.ToolLabel then
        if espModes.Tool and (non or bon) then
            local tool=ch:FindFirstChildOfClass('Tool')
            local tn=tool and tool.Name or ''
            if tn~='' then
                local tc2=espFX(espColors.Tool.Color1,espColors.Tool.Color2)
                o.ToolLabel.Text=string.format('<font color="%s">%s</font>',color3ToHex(tc2),tn)
                o.ToolLabel.TextColor3=tc2
                o.ToolLabel.Position=non and UDim2.new(0,nsp.X-75,0,nsp.Y+4) or UDim2.new(0,bsp.X-75,0,bsp.Y+20)
                o.ToolLabel.Visible=true
            else o.ToolLabel.Visible=false end
        else o.ToolLabel.Visible=false end
    end
end

local function espRefreshAll()
    for _,p in pairs(Players:GetPlayers()) do if p~=LocalPlayer then espCreate(p) end end
end

do
    local fc=0
    RunService.RenderStepped:Connect(function()
        fc=fc+1 if not espActive or fc%2~=0 then return end
        for _,p in pairs(Players:GetPlayers()) do
            if p~=LocalPlayer then
                if not espObjects[p.UserId] then espCreate(p) end
                espUpdate(p)
            end
        end
    end)
end
Players.PlayerRemoving:Connect(espClear)
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(0.5) if espActive then espCreate(p) end end)
end)

-- ====================== VISUAL: GUI СЕКЦИИ ======================
local function SetupESP()
    local g=createSection(pageVisual,"ESP")
    createToggle(g,"Enable ESP",false,function(s) espActive=s if s then espRefreshAll() else espClearAll() end end)
    createToggle(g,"Rainbow ESP",false,function(s) rainbowESP=s end)
    createToggle(g,"Fading ESP", false,function(s) fadingESP=s  end)
    for _,mn in ipairs({"Names","Distance","Chams","Tracers","Box","HealthBar","Tool","Direction"}) do
        local m=mn
        createToggle(g,m,false,function(s) espModes[m]=s if espActive then espRefreshAll() end end)
    end
end

local function SetupCamera()
    local g=createSection(pageVisual,"Camera Matrix Distort")
    local on=false local v={1,0,0,0,1,0,0,0,1}
    createToggle(g,"Enable Camera Distort",false,function(s) on=s end)
    for i,nm in ipairs({'R00','R01','R10','R11','R20','R21','R22'}) do
        local ci=i
        createSlider(g,nm,-1.19,1.19,v[ci],0.01,"%.2f",function(val) v[ci]=val end)
    end
    RunService.RenderStepped:Connect(function()
        if not on then return end
        local orig=Camera.CFrame
        Camera.CFrame=orig*CFrame.new(0,0,0,v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9])
    end)
end

local function SetupWorld()
    local g=createSection(pageVisual,"World")
    createToggle(g,"Disable Shadows",false,function(s) Lighting.GlobalShadows=not s end)
end

local function SetupEffects()
    local g=createSection(pageVisual,"Effects")
    -- Trail
    local tOn=false local tC1=Color3.fromRGB(255,110,0) local tC2=Color3.fromRGB(255,0,0)
    local tRain=false local tLife=1.6 local tW=0.1 local tObj=nil local tRC=nil local tHue=0
    local function applyTC(c1,c2) if tObj then tObj.Color=ColorSequence.new(c1,c2) end end
    local function startTR()
        if tRC then return end
        tRC=RunService.RenderStepped:Connect(function(dt)
            tHue=(tHue+dt*0.15)%1
            applyTC(Color3.fromHSV(tHue,1,1),Color3.fromHSV((tHue+0.15)%1,1,1))
        end)
    end
    local function stopTR() if tRC then tRC:Disconnect() tRC=nil end applyTC(tC1,tC2) end
    local function updateTrail(s)
        local ch=LocalPlayer.Character if not ch then return end
        local hrp=ch:FindFirstChild('HumanoidRootPart') if not hrp then return end
        if s then
            if not hrp:FindFirstChild('TrailEffect') then
                local tr=Instance.new('Trail') tr.Name='TrailEffect' tr.Parent=hrp
                local a0=Instance.new('Attachment',hrp) a0.Position=Vector3.new(0,1,0)
                local a1=Instance.new('Attachment',hrp) a1.Position=Vector3.new(0,-1,0)
                tr.Attachment0=a0 tr.Attachment1=a1 tr.Lifetime=tLife
                tr.Transparency=NumberSequence.new(0,0) tr.LightEmission=0.2 tr.Brightness=10
                tr.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,tW),NumberSequenceKeypoint.new(1,0)})
                tObj=tr if tRain then startTR() else applyTC(tC1,tC2) end
            end
        else
            stopTR() tObj=nil
            for _,c in ipairs(hrp:GetChildren()) do
                if c:IsA('Trail') and c.Name=='TrailEffect' then c:Destroy() end
                if c:IsA('Attachment') then c:Destroy() end
            end
        end
    end
    LocalPlayer.CharacterAdded:Connect(function() if tOn then task.wait(0.5) updateTrail(true) end end)
    createToggle(g,"Trail",false,function(s) tOn=s updateTrail(s) end)
    -- Aura
    local aOn=false local aC=Color3.fromRGB(255,255,255) local aEm={} local aRC2=nil local aHue=0
    local function aClear() for _,e in ipairs(aEm) do if e and e.Parent then e:Destroy() end end aEm={} end
    local function aColor(c) for _,e in ipairs(aEm) do if e then e.Color=ColorSequence.new(c) end end end
    local function aAttach(ch)
        aClear()
        local hrp=ch:FindFirstChild("HumanoidRootPart") if not hrp then return end
        local att=hrp:FindFirstChild("RootAttachment") or hrp
        local e=Instance.new("ParticleEmitter")
        e.Texture="rbxassetid://10927170198" e.Rate=10 e.Lifetime=NumberRange.new(0.25,0.5)
        e.Speed=NumberRange.new(0.012) e.Size=NumberSequence.new(3.8,7.6)
        e.Transparency=NumberSequence.new(0,0,1) e.Color=ColorSequence.new(aC) e.Parent=att
        table.insert(aEm,e) aColor(aC)
    end
    createToggle(g,"Aura",false,function(s)
        aOn=s
        if s then local ch=LocalPlayer.Character if ch then task.delay(0.25,function() if aOn then aAttach(ch) end end) end
        else aClear() end
    end)
    LocalPlayer.CharacterAdded:Connect(function(c) if aOn then task.wait(0.5) aAttach(c) end end)
end

local function SetupSelfChams()
    local g=createSection(pageVisual,"Self Chams")
    local on=false local col=Color3.fromRGB(255,255,255) local orig={}
    createToggle(g,"Enable Chams",false,function(s) on=s end)
    task.spawn(function()
        while true do task.wait()
            local ch=LocalPlayer.Character if not ch then continue end
            if on then
                for _,v in pairs(ch:GetDescendants()) do
                    if v:IsA("BasePart") then
                        if not orig[v] then orig[v]={Color=v.Color,Material=v.Material} end
                        v.Material=Enum.Material.ForceField v.Color=col
                    end
                end
            else
                for v,d in pairs(orig) do if v and v.Parent then v.Color=d.Color v.Material=d.Material end end
                orig={}
            end
        end
    end)
end

local function SetupCrosshair()
    local g=createSection(pageVisual,"Crosshair")
    local cs={enabled=false,image="rbxassetid://17459159263",color=Color3.fromRGB(255,255,255),rainbow=false,size=50,transparency=0,baseRot=0,rotate=false,rotateSpeed=1}
    local spin=0
    createToggle(g,"Enable Crosshair",false,function(s) cs.enabled=s end)
    RunService.PreRender:Connect(function()
        if not cs.enabled then
            UserInputService.MouseIconEnabled=true
            local gg=game.CoreGui:FindFirstChild("CustomCrosshair") if gg then gg.Enabled=false end
            return
        end
        UserInputService.MouseIconEnabled=false
        if cs.rotate then spin=spin+cs.rotateSpeed if spin>=180 then spin=spin-360 end end
        if cs.rainbow then cs.color=getRainbowColor() end
        local mp=UserInputService:GetMouseLocation()
        local gg=game.CoreGui:FindFirstChild("CustomCrosshair")
        if not gg then
            gg=Instance.new("ScreenGui") gg.Name="CustomCrosshair" gg.IgnoreGuiInset=true
            gg.ResetOnSpawn=false gg.ZIndexBehavior=Enum.ZIndexBehavior.Global gg.DisplayOrder=2147483647 gg.Parent=game.CoreGui
        end
        gg.Enabled=true
        local img=gg:FindFirstChild("CrosshairImage")
        if not img then img=Instance.new("ImageLabel") img.Name="CrosshairImage" img.BackgroundTransparency=1 img.AnchorPoint=Vector2.new(0.5,0.5) img.Parent=gg end
        img.Image=cs.image img.ImageColor3=cs.color img.ImageTransparency=cs.transparency
        img.Size=UDim2.new(0,cs.size,0,cs.size) img.Rotation=cs.baseRot+spin img.Position=UDim2.new(0,mp.X,0,mp.Y)
    end)
end

local function SetupPostFX()
    local g=createSection(pageVisual,"PostFX")
    local fx={enabled=false,bloomIntensity=1,bloomSize=24,blurSize=0,brightness=0,contrast=0,saturation=0}
    createToggle(g,"Enable PostFX",false,function(s) fx.enabled=s end)
    RunService.PreRender:Connect(function()
        local bl=Lighting:FindFirstChild("CustomBloom") or Instance.new("BloomEffect")
        bl.Name="CustomBloom" bl.Parent=Lighting bl.Enabled=fx.enabled bl.Intensity=fx.bloomIntensity bl.Size=fx.bloomSize
        local br=Lighting:FindFirstChild("CustomBlur") or Instance.new("BlurEffect")
        br.Name="CustomBlur" br.Parent=Lighting br.Enabled=fx.enabled br.Size=fx.blurSize
        local cc=Lighting:FindFirstChild("CustomColorCorrection") or Instance.new("ColorCorrectionEffect")
        cc.Name="CustomColorCorrection" cc.Parent=Lighting cc.Enabled=fx.enabled
        cc.Brightness=fx.brightness cc.Contrast=fx.contrast cc.Saturation=fx.saturation
    end)
end

SetupESP()
SetupCamera()
SetupWorld()
SetupEffects()
SetupSelfChams()
SetupCrosshair()
SetupPostFX()

-- Legit tab — all collapsed
local hitboxContent = createSection(pageLegit, "Hitbox Expander")
createToggle(hitboxContent, "Hitbox Expander", HitboxEnabled, function(v) HitboxEnabled = v UpdateHitboxes() end)
createSlider(hitboxContent, "Hitbox Size", 1, 30, HitboxSize, 1, "%.0f", function(v) HitboxSize = v if HitboxEnabled then UpdateHitboxes() end end)
createSlider(hitboxContent, "Hitbox Transparency", 0, 1, HitboxTransparency, 0.01, "%.2f", function(v) HitboxTransparency = v if HitboxEnabled then UpdateHitboxes() end end)

local aimContent = createSection(pageLegit, "Aim")
local _, autoBtn = createToggle(aimContent, "AutoShot", Monitoring, function(v) Monitoring = v end)
AutoShotToggleBtn = autoBtn
createToggle(aimContent, "Full Mag Enabled", FullMagEnabled, function(v) FullMagEnabled = v end)
createSlider(aimContent, "Mag Shots", 1, 10, MagShots, 1, "%.0f", function(v) MagShots = v end)
createSlider(aimContent, "Mag Delay", 0, 0.1, MagDelay, 0.001, "%.3f", function(v) MagDelay = v end)
createSlider(aimContent, "Delay Before Shot", 0, 0.01, DelayBeforeShot, 0.0001, "%.4f", function(v) DelayBeforeShot = v end)
createToggle(aimContent, "TriggerBot", TriggerbotEnabled, function(v) TriggerbotEnabled = v UpdateTriggerbot() end)
local _, trigBtn = createToggle(aimContent, "TriggerBot (ПКМ)", TriggerbotEnabled, function(v) TriggerbotEnabled = v UpdateTriggerbot() end)
TriggerMainBtn = trigBtn

local gunContent = createSection(pageLegit, "Gun")
for wpn, en in pairs(WeaponsEnabled) do
    createToggle(gunContent, wpn, en, function(v) WeaponsEnabled[wpn] = v end)
end
createToggle(gunContent, "TripleShot", TripleShotEnabled, function(v) TripleShotEnabled = v end)

-- ==================== RAGE ПОДГРУППА ВО ВКЛАДКЕ LEGIT ====================
local rageContent = createSection(pageLegit, "Rage")

createToggle(rageContent, "Insta Kill", false, function(v)
    InstaKillEnabled = v
end)

createSlider(rageContent, "Max Targets", 1, 10, 1, 1, "%.0f", function(v)
    MaxTargets = v
end)

createSlider(rageContent, "Radius Range", 50, 1000, 150, 0, "%.0f", function(v)
    InstaKillRadius = v
end)

createSlider(rageContent, "Shoot Delay", 0.01, 0.5, 0.01, 0.001, "%.3f", function(v)
    InstaKillDelay = v
end)

createSlider(rageContent, "Double Damage (XDamage)", 1, 50, 10, 1, "%.0f", function(v)
    XDamage = v
end)

createSlider(rageContent, "Height Offset (ArraySize)", 1, 50, 20, 1, "%.0f", function(v)
    ArraySize = v
end)

-- Misc tab — collapsed
local checksContent = createSection(pageMisc, "Checks")
createToggle(checksContent, "Не стрелять в мертвых", CheckDead, function(v) CheckDead = v end)
createToggle(checksContent, "Проверка стен", CheckWall, function(v) CheckWall = v end)
createToggle(checksContent, "Не стрелять в друзей", CheckFriend, function(v) CheckFriend = v end)

local utilitiesContent = createSection(pageMisc, "Utilities")
createToggle(utilitiesContent, "Chat Spy", false, function(state)
    if state then
        if TextChatService:FindFirstChild('ChatWindowConfiguration') then
            TextChatService.ChatWindowConfiguration.Enabled = true
        end
        if TextChatService:FindFirstChild('ChatInputBarConfiguration') then
            TextChatService.ChatInputBarConfiguration.Enabled = true
        end
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
    else
        if TextChatService:FindFirstChild('ChatWindowConfiguration') then
            TextChatService.ChatWindowConfiguration.Enabled = defaultChatStates.ChatWindowEnabled
        end
        if TextChatService:FindFirstChild('ChatInputBarConfiguration') then
            TextChatService.ChatInputBarConfiguration.Enabled = defaultChatStates.ChatInputEnabled
        end
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, defaultChatStates.CoreGuiChat)
    end
end)

createToggle(utilitiesContent, "Mod Detector", false, function(state)
    detectorEnabled = state
    if state then
        detectMods()
        Players.PlayerAdded:Connect(detectMods)
        RunService.Heartbeat:Connect(function()
            if detectorEnabled and tick() - lastCheck > 2 then
                detectMods()
                lastCheck = tick()
            end
        end)
        RunService.RenderStepped:Connect(updateESP)
    else
        for _, drawings in pairs(activeESP) do
            if drawings.label then drawings.label:Remove() end
        end
        activeESP = {}
        notifiedPlayers = {}
    end
end)

local modActionBtn = Instance.new("TextButton")
modActionBtn.Size = UDim2.new(1, -20, 0, 50)
modActionBtn.BackgroundColor3 = Theme.Section
modActionBtn.Text = "Detect Action: Notify"
modActionBtn.TextColor3 = Theme.LabelText
modActionBtn.Font = Enum.Font.GothamSemibold
modActionBtn.TextSize = 15
modActionBtn.TextWrapped = true
modActionBtn.Parent = utilitiesContent
corner(modActionBtn, 10)
modActionBtn.MouseButton1Click:Connect(function()
    if modAction == "notify" then
        modAction = "kick"
        modActionBtn.Text = "Detect Action: Kick"
    else
        modAction = "notify"
        modActionBtn.Text = "Detect Action: Notify"
    end
end)

local function playAlertSound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. alertSoundId
    sound.Volume = 10
    sound.Parent = workspace
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 6)
end

local function detectMods()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local nameLower = player.Name:lower()
        local displayLower = player.DisplayName:lower()
        local isModUser = MOD_USERNAMES[nameLower] or MOD_USERNAMES[displayLower]
        local hasEmoji = hasModSymbols(player.Name) or hasModSymbols(player.DisplayName)
        local inGroup, groupRole = getModInfo(player)
        if isModUser or hasEmoji or inGroup then
            local roleDisplay = groupRole or "Staff"
            if not activeESP[player] then
                activeESP[player] = createESP(player, roleDisplay)
            else
                activeESP[player].label.Text = "ADMIN: " .. player.Name .. " [" .. roleDisplay .. "]"
            end
            if modAction == 'kick' then
                playAlertSound()
                task.wait(0.6)
                LocalPlayer:Kick('Admin Detected: ' .. player.Name .. ' [' .. roleDisplay .. ']')
            else
                if not notifiedPlayers[player.UserId] then
                    notifiedPlayers[player.UserId] = true
                    Library:Notify('🚨 Admin Detected: ' .. player.Name .. ' [' .. roleDisplay .. ']', 5)
                    playAlertSound()
                end
            end
        end
    end
end

-- Player List tab
local playersContent, openPlayers = createSection(pagePlayerList, "Players")
local PlayerListFrame = Instance.new("ScrollingFrame", playersContent)
PlayerListFrame.Size = UDim2.new(1, -20, 0, 320)
PlayerListFrame.BackgroundColor3 = Color3.fromRGB(28,28,36)
PlayerListFrame.ScrollBarThickness = 4
PlayerListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
corner(PlayerListFrame,8)

local function updatePlayerListScroll()
    local canScroll = PlayerListFrame.AbsoluteCanvasSize.Y > PlayerListFrame.AbsoluteSize.Y
    PlayerListFrame.ScrollBarThickness = canScroll and 4 or 0
    PlayerListFrame.ScrollingEnabled = canScroll
end
PlayerListFrame:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updatePlayerListScroll)
PlayerListFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePlayerListScroll)

local spectatingPlayer = nil
local spectateConnection = nil
local followingPlayer = nil
local followConnection = nil
local ignoredPlayers = {}
local activeDropdown = nil
local activeBackdrop = nil

local function StopSpectate()
    if spectateConnection then spectateConnection:Disconnect() spectateConnection = nil end
    if spectatingPlayer then
        spectatingPlayer = nil
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        workspace.CurrentCamera.CameraSubject = hum
    end
end

local function StopFollow()
    if followConnection then followConnection:Disconnect() followConnection = nil end
    followingPlayer = nil
end

local function SpectatePlayer(plr)
    StopSpectate()
    spectatingPlayer = plr
    workspace.CurrentCamera.CameraType = Enum.CameraType.Follow
    spectateConnection = RunService.RenderStepped:Connect(function()
        if not plr or not plr.Character then StopSpectate() return end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then workspace.CurrentCamera.CameraSubject = hum end
    end)
end

local function FollowPlayer(plr)
    StopFollow()
    followingPlayer = plr
    followConnection = RunService.Heartbeat:Connect(function()
        if not plr or not plr.Character then StopFollow() return end
        local char = LocalPlayer.Character if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local targetHrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp and targetHrp then hrp.CFrame = CFrame.new(targetHrp.Position + Vector3.new(4,0,4), targetHrp.Position) end
    end)
end

local function TeleportToPlayer(plr)
    if not plr or not plr.Character then return end
    local char = LocalPlayer.Character if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local targetHrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if hrp and targetHrp then hrp.CFrame = targetHrp.CFrame + Vector3.new(2,0,2) end
end

local function CloseActiveDropdown()
    if activeBackdrop and activeBackdrop.Parent then activeBackdrop:Destroy() activeBackdrop = nil end
    if activeDropdown and activeDropdown.Parent then activeDropdown:Destroy() activeDropdown = nil end
end

local function UpdatePlayerList()
    for _, c in ipairs(PlayerListFrame:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
    local y = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local isIgnored = ignoredPlayers[plr.UserId] == true
            local isHost = StarterPlayer == plr
            local isSpectating = spectatingPlayer == plr
            local isFollowing = followingPlayer == plr
            local container = Instance.new("Frame", PlayerListFrame)
            container.Size = UDim2.new(1,-10,0,42)
            container.Position = UDim2.new(0,5,0,y)
            container.BackgroundColor3 = isHost and Color3.fromRGB(40,20,70) or isIgnored and Color3.fromRGB(50,20,20) or Theme.PlayerBtn
            container.BorderSizePixel = 0
            corner(container, 8)
            local statusDot = Instance.new("Frame", container)
            statusDot.Size = UDim2.new(0,8,0,8)
            statusDot.Position = UDim2.new(0,8,0.5,-4)
            statusDot.BackgroundColor3 = isHost and Color3.fromRGB(180,80,255) or isSpectating and Color3.fromRGB(0,180,255) or isFollowing and Color3.fromRGB(0,255,150) or isIgnored and Color3.fromRGB(255,60,60) or Color3.fromRGB(80,80,100)
            corner(statusDot, 4)
            local suffix = (isHost and " 🎯" or "")..(isSpectating and " 👁" or "")..(isFollowing and " 🔗" or "")..(isIgnored and " 🚫" or "")
            local nameLabel = Instance.new("TextLabel", container)
            nameLabel.Size = UDim2.new(1,-80,1,0) nameLabel.Position = UDim2.new(0,22,0,0) nameLabel.BackgroundTransparency = 1
            nameLabel.Text = plr.Name..suffix nameLabel.TextColor3 = isIgnored and Color3.fromRGB(180,100,100) or Color3.new(1,1,1)
            nameLabel.Font = Enum.Font.Gotham nameLabel.TextSize = 14 nameLabel.TextXAlignment = Enum.TextXAlignment.Left nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            local menuBtn = Instance.new("TextButton", container)
            menuBtn.Size = UDim2.new(0,36,0,30) menuBtn.Position = UDim2.new(1,-42,0.5,-15)
            menuBtn.BackgroundColor3 = Theme.Accent menuBtn.Text = "⋯" menuBtn.TextColor3 = Color3.new(1,1,1)
            menuBtn.Font = Enum.Font.GothamBold menuBtn.TextSize = 18 menuBtn.ZIndex = 5
            corner(menuBtn, 8)
            menuBtn.MouseEnter:Connect(function()
                TweenService:Create(menuBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(140,80,220)}):Play()
            end)
            menuBtn.MouseLeave:Connect(function()
                TweenService:Create(menuBtn, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Accent}):Play()
            end)
            local capturedPlr = plr
            local capturedIsIgnored = isIgnored
            local capturedIsHost = isHost
            local capturedIsSpectating = isSpectating
            local capturedIsFollowing = isFollowing
            menuBtn.MouseButton1Click:Connect(function()
                if activeDropdown then CloseActiveDropdown() return end
                local ITEM_H = 36
                local PADDING = 8
                local actions = {
                    { icon = "👁", label = capturedIsSpectating and "Stop Spectate" or "Spectate", color = Color3.fromRGB(0,180,255) },
                    { icon = "🔗", label = capturedIsFollowing and "Stop Follow" or "Follow", color = Color3.fromRGB(0,220,140) },
                    { icon = "⚡", label = "Teleport", color = Color3.fromRGB(255,200,0) },
                    { icon = capturedIsIgnored and "✅" or "🚫", label = capturedIsIgnored and "Remove Ignore" or "Ignore", color = capturedIsIgnored and Color3.fromRGB(100,220,100) or Color3.fromRGB(255,80,80) },
                    { icon = "🎯", label = capturedIsHost and "Remove Host" or "Set as Host", color = Color3.fromRGB(180,80,255) },
                }
                local totalH = PADDING*2 + #actions*ITEM_H + (#actions-1)*2
                local backdropGui = Instance.new("ScreenGui")
                backdropGui.Name = "DropdownBackdrop" backdropGui.DisplayOrder = 200 backdropGui.IgnoreGuiInset = true
                backdropGui.ResetOnSpawn = false backdropGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
                backdropGui.Parent = LocalPlayer.PlayerGui
                local backdrop = Instance.new("TextButton", backdropGui)
                backdrop.Size = UDim2.new(1,0,1,0) backdrop.BackgroundTransparency = 1 backdrop.Text = "" backdrop.ZIndex = 1
                activeBackdrop = backdropGui
                local dropGui = Instance.new("ScreenGui")
                dropGui.Name = "DropdownMenu" dropGui.DisplayOrder = 201 dropGui.IgnoreGuiInset = true
                dropGui.ResetOnSpawn = false dropGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
                dropGui.Parent = LocalPlayer.PlayerGui
                local dropdown = Instance.new("Frame", dropGui)
                dropdown.BackgroundColor3 = Color3.fromRGB(18,18,28) dropdown.BorderSizePixel = 0 dropdown.ZIndex = 1
                corner(dropdown, 10)
                local stroke = Instance.new("UIStroke", dropdown)
                stroke.Color = Theme.Accent stroke.Thickness = 1.5
                local absPos = menuBtn.AbsolutePosition
                local absSize = menuBtn.AbsoluteSize
                local vpSize = workspace.CurrentCamera.ViewportSize
                local dropW = 178
                local dropX = absPos.X + absSize.X - dropW
                local dropY = absPos.Y + absSize.Y + 4
                if dropY + totalH > vpSize.Y - 10 then dropY = absPos.Y - totalH - 4 end
                if dropX < 4 then dropX = 4 end
                dropdown.Size = UDim2.new(0,dropW,0,totalH)
                dropdown.Position = UDim2.new(0,dropX,0,dropY)
                local layout = Instance.new("UIListLayout", dropdown)
                layout.Padding = UDim.new(0,2)
                local pad = Instance.new("UIPadding", dropdown)
                pad.PaddingTop = UDim.new(0,PADDING) pad.PaddingBottom = UDim.new(0,PADDING)
                pad.PaddingLeft = UDim.new(0,6) pad.PaddingRight = UDim.new(0,6)
                local actionFunctions = {
                    function() if capturedIsSpectating then StopSpectate() else SpectatePlayer(capturedPlr) end end,
                    function() if capturedIsFollowing then StopFollow() else FollowPlayer(capturedPlr) end end,
                    function() TeleportToPlayer(capturedPlr) end,
                    function()
                        if capturedIsIgnored then ignoredPlayers[capturedPlr.UserId] = nil
                        else ignoredPlayers[capturedPlr.UserId] = true end
                    end,
                    function()
                        if capturedIsHost then StarterPlayer = nil LastAmmoPerTool = {} RemoveEmoji()
                        else StarterPlayer = capturedPlr LastAmmoPerTool = {} AttachEmojiToPlayer(capturedPlr) end
                    end,
                }
                for i, act in ipairs(actions) do
                    local btn = Instance.new("TextButton", dropdown)
                    btn.Size = UDim2.new(1,0,0,ITEM_H) btn.BackgroundColor3 = Color3.fromRGB(28,28,40)
                    btn.Text = act.icon.." "..act.label btn.TextColor3 = act.color
                    btn.Font = Enum.Font.GothamSemibold btn.TextSize = 14 btn.TextXAlignment = Enum.TextXAlignment.Left
                    btn.AutoButtonColor = false btn.ZIndex = 2
                    corner(btn, 7)
                    local p2 = Instance.new("UIPadding", btn) p2.PaddingLeft = UDim.new(0,10)
                    btn.MouseEnter:Connect(function()
                        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(45,45,65)}):Play()
                    end)
                    btn.MouseLeave:Connect(function()
                        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(28,28,40)}):Play()
                    end)
                    local capturedFn = actionFunctions[i]
                    btn.MouseButton1Click:Connect(function()
                        CloseActiveDropdown()
                        capturedFn()
                        task.wait(0.05)
                        UpdatePlayerList()
                    end)
                end
                activeDropdown = dropGui
                backdrop.MouseButton1Click:Connect(function()
                    CloseActiveDropdown()
                end)
                dropdown.GroupTransparency = 1
                TweenService:Create(dropdown, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    GroupTransparency = 0
                }):Play()
            end)
            y = y + 46
        end
    end
    PlayerListFrame.CanvasSize = UDim2.new(0,0,0,y)
end
UpdatePlayerList()
spawn(function() while task.wait(3) do UpdatePlayerList() end end)

local hostContent, openHost = createSection(pagePlayerList, "Auto Host (F1 + Z)")
createToggle(hostContent, "Выбирать друзей как хоста", AllowFriendsAsHost, function(v) AllowFriendsAsHost = v end)
createToggle(hostContent, "Показывать 🎯 над хостом", ShowTargetEmoji, function(v)
    ShowTargetEmoji = v
    if not v then RemoveEmoji() else if StarterPlayer then AttachEmojiToPlayer(StarterPlayer) end end
end)

local bindContent = createSection(pageBind, "Binds")
AutoBindBtn = Instance.new("TextButton", bindContent)
AutoBindBtn.Size = UDim2.new(1,-20,0,50) AutoBindBtn.BackgroundColor3 = Theme.BindBtn
AutoBindBtn.Text = "Сменить бинд автошота (V - "..BindMode..")" AutoBindBtn.TextColor3 = Color3.new(1,1,1)
AutoBindBtn.Font = Enum.Font.GothamBold AutoBindBtn.TextSize = 15 AutoBindBtn.TextWrapped = true AutoBindBtn.TextTruncate = Enum.TextTruncate.AtEnd
corner(AutoBindBtn,10)
AutoBindBtn.MouseEnter:Connect(function()
    if Animations.ButtonHover then TweenService:Create(AutoBindBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Theme.BindBtnHover}):Play()
    else AutoBindBtn.BackgroundColor3 = Theme.BindBtnHover end
end)
AutoBindBtn.MouseLeave:Connect(function()
    if Animations.ButtonHover then TweenService:Create(AutoBindBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Theme.BindBtn}):Play()
    else AutoBindBtn.BackgroundColor3 = Theme.BindBtn end
end)
AutoBindBtn.MouseButton1Click:Connect(function()
    AutoBindBtn.Text = "Нажми клавишу..."
    WaitingForBind = true
end)

TriggerBindBtn = Instance.new("TextButton", bindContent)
TriggerBindBtn.Size = UDim2.new(1,-20,0,50) TriggerBindBtn.BackgroundColor3 = Theme.BindBtn
TriggerBindBtn.Text = "TriggerBot: Зажми ПКМ (Hold)" TriggerBindBtn.TextColor3 = Color3.new(1,1,1)
TriggerBindBtn.Font = Enum.Font.GothamBold TriggerBindBtn.TextSize = 15 TriggerBindBtn.TextWrapped = true TriggerBindBtn.TextTruncate = Enum.TextTruncate.AtEnd
corner(TriggerBindBtn,10)
TriggerBindBtn.MouseEnter:Connect(function()
    if Animations.ButtonHover then TweenService:Create(TriggerBindBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Theme.BindBtnHover}):Play()
    else TriggerBindBtn.BackgroundColor3 = Theme.BindBtnHover end
end)
TriggerBindBtn.MouseLeave:Connect(function()
    if Animations.ButtonHover then TweenService:Create(TriggerBindBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Theme.BindBtn}):Play()
    else TriggerBindBtn.BackgroundColor3 = Theme.BindBtn end
end)

createToggle(bindContent, "AutoShot Mode Toggle/Hold", BindMode == "Toggle", function(v)
    BindMode = v and "Toggle" or "Hold"
    AutoBindBtn.Text = "Сменить бинд автошота ("..tostring(ToggleKey.Name).." - "..BindMode..")"
end)

-- ====================== MOVEMENT ======================
local function resetWalkSpeed()
    pcall(function() local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed = 16 end end)
end
local function antiFlingReset()
    pcall(function() local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") if hrp then hrp.AssemblyLinearVelocity=Vector3.new(0,0,0) hrp.AssemblyAngularVelocity=Vector3.new(0,0,0) end end)
end
local function updateSpeedFlags(state)
    speedToggleState = state
    if speedToggleState then
        speedEnabled = (speedMethod == "CFrame") speedV2Enabled = (speedMethod == "Velocity") speedV3Enabled = (speedMethod == "Impulse")
    else
        speedEnabled = false speedV2Enabled = false speedV3Enabled = false antiFlingReset() resetWalkSpeed()
    end
end
local function setSpeed()
    pcall(function()
        local char = LocalPlayer.Character if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart") local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local move = hum.MoveDirection local delta = 1/60
        if speedEnabled then hrp.CFrame += move*speedValue*delta
        elseif speedV2Enabled then hrp.AssemblyLinearVelocity = Vector3.new(move.X*speedValue, hrp.AssemblyLinearVelocity.Y, move.Z*speedValue)
        elseif speedV3Enabled then if move.Magnitude > 0 then hrp:ApplyImpulse(move*speedValue*0.6) end end
    end)
end

local MovementContent, openMovement = createSection(pageMovement, "Движение")
local flyEnabled = false local flySpeed = 50 local flyConnection = nil local flyBodyVelocity = nil local flyBodyGyro = nil
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
        if flyBodyVelocity and flyBodyVelocity.Parent then flyBodyVelocity.Velocity = moveDir.Magnitude>0 and moveDir.Unit*flySpeed or Vector3.zero end
        if flyBodyGyro and flyBodyGyro.Parent then flyBodyGyro.CFrame = camCF end
    end)
end
LocalPlayer.CharacterAdded:Connect(function() if flyEnabled then task.wait(0.5) startFly() end end)
createToggle(MovementContent, "Fly", false, function(state) if state then startFly() else stopFly() end end)
createSlider(MovementContent, "Fly Speed", 10, 500, 50, 5, "%.0f", function(v) flySpeed = v end)
createToggle(MovementContent, "Speed", false, function(state) updateSpeedFlags(state) end)
local SpeedModeDropdown = Instance.new("TextButton", MovementContent)
SpeedModeDropdown.Size = UDim2.new(1,0,0,50) SpeedModeDropdown.BackgroundColor3 = Theme.Section
SpeedModeDropdown.Text = "Speed Mode: CFrame" SpeedModeDropdown.TextColor3 = Theme.LabelText
SpeedModeDropdown.Font = Enum.Font.Gotham SpeedModeDropdown.TextSize = 15
corner(SpeedModeDropdown,10)
SpeedModeDropdown.MouseButton1Click:Connect(function()
    local values = {"CFrame","Velocity","Impulse"} local current = speedMethod local nextIndex = 1
    for i, v in ipairs(values) do if v == current then nextIndex = i+1 if nextIndex > #values then nextIndex = 1 end break end end
    speedMethod = values[nextIndex] SpeedModeDropdown.Text = "Speed Mode: "..speedMethod
    if speedToggleState then updateSpeedFlags(true) end
end)
createSlider(MovementContent, "Speed Amount", 1, 1500, 16, 1, "%.0f", function(v) speedValue = v end)
createToggle(MovementContent, "No Jump Cooldown", false, function(state)
    if state then
        local player = game.Players.LocalPlayer
        local function nojumpcooldown(character) character:WaitForChild('Humanoid').UseJumpPower = false end
        player.CharacterAdded:Connect(nojumpcooldown) if player.Character then nojumpcooldown(player.Character) end
    end
end)
createToggle(MovementContent, "No Slow Down", false, function(state)
    if state then
        RunService:BindToRenderStep('NoSlowDown', 0, function()
            local character = LocalPlayer.Character if not character then return end
            local bodyEffects = character:FindFirstChild('BodyEffects') if not bodyEffects then return end
            local movement = bodyEffects:FindFirstChild('Movement')
            if movement then
                local noWalkSpeed = movement:FindFirstChild('NoWalkSpeed') if noWalkSpeed then noWalkSpeed:Destroy() end
                local reduceWalk = movement:FindFirstChild('ReduceWalk') if reduceWalk then reduceWalk:Destroy() end
                local noJumping = movement:FindFirstChild('NoJumping') if noJumping then noJumping:Destroy() end
            end
            if bodyEffects:FindFirstChild('Reload') and bodyEffects.Reload.Value == true then bodyEffects.Reload.Value = false end
        end)
    else RunService:UnbindFromRenderStep('NoSlowDown') end
end)
createToggle(MovementContent, "Noclip", false, function(state)
    if state then
        if NoclipConnection then NoclipConnection:Disconnect() end
        NoclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character if not char then return end
            for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
        end)
    else
        if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
        task.wait(0.1) local char = LocalPlayer.Character
        if char then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.CanCollide = true end end end
    end
end)
LocalPlayer.CharacterAdded:Connect(function(char)
    if NoclipConnection then task.wait(0.3) for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end end
end)

local MovementSettings = {
    Bhop=false, BhopMode="Velocity", JumpPowerOverride=false, JumpPower=50, Gravity=196.2,
    Float=false, FloatQ=false, FloatE=false, Step=false, MaxStepHeight=3.2,
    WalkSpeedOverride=false, WalkSpeed=16, WalkSpeedMultiplier=1, MinWalkSpeed=0, MaxWalkSpeed=500,
    WalkSpeedMode="Velocity (Undetectable)", RigidWalk=false, AirJump=false,
    JumpPowerMode="Velocity (Undetectable)", EdgeJumpEnabled=false, EdgeJumpDelay=0,
}
local BhopToggle = createToggle(MovementContent, "Bhop", false, function(state) MovementSettings.Bhop = state end)
local BhopModeDropdown = Instance.new("TextButton", MovementContent)
BhopModeDropdown.Size = UDim2.new(1,0,0,50) BhopModeDropdown.BackgroundColor3 = Theme.Section
BhopModeDropdown.Text = "Bhop mode: Velocity" BhopModeDropdown.TextColor3 = Theme.LabelText
BhopModeDropdown.Font = Enum.Font.Gotham BhopModeDropdown.TextSize = 15
corner(BhopModeDropdown,10)
BhopModeDropdown.MouseButton1Click:Connect(function()
    local values = {"Velocity","Teleport","Classic"} local current = MovementSettings.BhopMode local nextIndex = 1
    for i, v in ipairs(values) do if v == current then nextIndex = i+1 if nextIndex > #values then nextIndex = 1 end break end end
    MovementSettings.BhopMode = values[nextIndex] BhopModeDropdown.Text = "Bhop mode: "..MovementSettings.BhopMode
end)
createToggle(MovementContent, "Step", false, function(state) MovementSettings.Step = state end)
createSlider(MovementContent, "Max high", 0.5, 100, 3.2, 0.1, "%.1f", function(v) MovementSettings.MaxStepHeight = v end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Q then MovementSettings.FloatQ = true
    elseif input.KeyCode == Enum.KeyCode.E then MovementSettings.FloatE = true end
end)
UserInputService.InputEnded:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Q then MovementSettings.FloatQ = false
    elseif input.KeyCode == Enum.KeyCode.E then MovementSettings.FloatE = false end
end)

local floatPart = nil
RunService.PreRender:Connect(function()
    workspace.Gravity = MovementSettings.Gravity
    local char = LocalPlayer.Character if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if not hrp or not humanoid then return end
    if MovementSettings.Bhop and humanoid.FloorMaterial ~= Enum.Material.Air then
        local jp = MovementSettings.JumpPowerOverride and MovementSettings.JumpPower or humanoid.JumpPower
        if MovementSettings.BhopMode == "Velocity" then hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jp, hrp.AssemblyLinearVelocity.Z)
        elseif MovementSettings.BhopMode == "Teleport" then hrp.CFrame = hrp.CFrame+Vector3.new(0,jp,0) hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X,0,hrp.AssemblyLinearVelocity.Z)
        elseif MovementSettings.BhopMode == "Classic" then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
    if not floatPart or not floatPart.Parent then
        floatPart = Instance.new("Part") floatPart.Name = "__FL0ATP4RT" floatPart.Anchored = true floatPart.CanQuery = false
        floatPart.Locked = true floatPart.CanTouch = false floatPart.Archivable = true floatPart.Size = Vector3.new(5,0.5,5) floatPart.Parent = workspace
    end
    if MovementSettings.Float then
        if MovementSettings.FloatQ then floatPart.Transparency=0.5 floatPart.CanCollide=false floatPart.Position=hrp.Position-Vector3.new(0,3.25,0)
        elseif MovementSettings.FloatE then floatPart.Transparency=0 floatPart.CanCollide=true floatPart.Position=hrp.Position-Vector3.new(0,2,0)
        else floatPart.Transparency=0 floatPart.CanCollide=true floatPart.Position=hrp.Position-Vector3.new(0,3.25,0) end
    else floatPart.Transparency=1 floatPart.CanCollide=false floatPart.Position=hrp.Position-Vector3.new(0,3.25,0) end
    if MovementSettings.WalkSpeedOverride or MovementSettings.RigidWalk then
        local base = humanoid.WalkSpeed if MovementSettings.WalkSpeedOverride then base = MovementSettings.WalkSpeed end
        local final = math.clamp(base*MovementSettings.WalkSpeedMultiplier, MovementSettings.MinWalkSpeed, MovementSettings.MaxWalkSpeed)
        if MovementSettings.WalkSpeedMode == "Velocity (Undetectable)" and humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
            hrp.AssemblyLinearVelocity = Vector3.new(humanoid.MoveDirection.X*final, hrp.AssemblyLinearVelocity.Y, humanoid.MoveDirection.Z*final)
        elseif MovementSettings.WalkSpeedMode == "Teleport" and humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
            hrp.CFrame = hrp.CFrame+Vector3.new(humanoid.MoveDirection.X*final*0.016, 0, humanoid.MoveDirection.Z*final*0.016)
        elseif MovementSettings.WalkSpeedMode == "Classic" then humanoid.WalkSpeed = final end
    end
end)

local stepConnection = nil
local function setupStep(char)
    if stepConnection then stepConnection:Disconnect() stepConnection = nil end
    local root = char:WaitForChild("HumanoidRootPart", 8) if not root then return end
    stepConnection = root.Touched:Connect(function(hit)
        if not MovementSettings.Step then return end
        if hit:IsA("Terrain") or hit.Transparency >= 1 or not hit.CanQuery then return end
        local top = hit.Position.Y+(hit.Size.Y/2) local feet = root.Position.Y-(root.Size.Y/2) local dist = top-feet
        if dist > 0 and dist < MovementSettings.MaxStepHeight then
            local lift = dist+(root.Size.Y*0.65) root.CFrame = root.CFrame+Vector3.new(0,lift,0)
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z)
        end
    end)
end
if LocalPlayer.Character then task.spawn(setupStep, LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(newChar) task.wait(0.1) setupStep(newChar) end)

local edgeConnection = nil
local function setupEdge(char)
    if edgeConnection then edgeConnection:Disconnect() edgeConnection = nil end
    local hum = char:WaitForChild("Humanoid", 8) if not hum then return end
    edgeConnection = hum.StateChanged:Connect(function(old, new)
        if not MovementSettings.EdgeJumpEnabled then return end
        if new == Enum.HumanoidStateType.Freefall and old ~= Enum.HumanoidStateType.Freefall then
            task.delay(MovementSettings.EdgeJumpDelay, function() if hum and hum.Parent then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end)
        end
    end)
end
if LocalPlayer.Character then task.spawn(setupEdge, LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(setupEdge)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Space and MovementSettings.JumpPowerOverride then
        local char = LocalPlayer.Character if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart") local hum = char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum then return end
        if hum.FloorMaterial == Enum.Material.Air and not MovementSettings.AirJump then return end
        local val = MovementSettings.JumpPower
        if MovementSettings.JumpPowerMode == "Velocity (Undetectable)" then hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X,val,hrp.AssemblyLinearVelocity.Z)
        elseif MovementSettings.JumpPowerMode == "Teleport" then hrp.CFrame = hrp.CFrame+Vector3.new(0,val,0) hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X,0,hrp.AssemblyLinearVelocity.Z)
        elseif MovementSettings.JumpPowerMode == "Classic" then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.Heartbeat:Connect(function() if speedEnabled or speedV2Enabled or speedV3Enabled then setSpeed() end end)

-- ====================== ВКЛАДКА MENU ======================
local function createColorPicker(parent, label, initColor, onChanged)
    local wrapper = Instance.new("Frame", parent)
    wrapper.Size = UDim2.new(1,0,0,130) wrapper.BackgroundColor3 = Theme.Section corner(wrapper,10)
    local titleLbl = Instance.new("TextLabel", wrapper)
    titleLbl.Size = UDim2.new(1,-120,0,26) titleLbl.Position = UDim2.fromOffset(12,6) titleLbl.BackgroundTransparency = 1
    titleLbl.Text = label titleLbl.Font = Enum.Font.GothamSemibold titleLbl.TextSize = 13 titleLbl.TextColor3 = Theme.SectionTitle titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    local preview = Instance.new("Frame", wrapper)
    preview.Size = UDim2.new(0,60,0,26) preview.Position = UDim2.new(1,-78,0,6) preview.BackgroundColor3 = initColor corner(preview,6)
    local previewStroke = Instance.new("UIStroke", preview) previewStroke.Color = Color3.fromRGB(80,80,100) previewStroke.Thickness = 1
    local r,g,b = math.floor(initColor.R*255+0.5), math.floor(initColor.G*255+0.5), math.floor(initColor.B*255+0.5)
    local function makeRGBSlider(offsetY, channel, initVal, changedCb)
        local names = {"R","G","B"} local colors = {Color3.fromRGB(220,80,80),Color3.fromRGB(80,220,80),Color3.fromRGB(80,120,255)}
        local lbl = Instance.new("TextLabel",wrapper) lbl.Size=UDim2.new(0,16,0,16) lbl.Position=UDim2.fromOffset(12,offsetY) lbl.BackgroundTransparency=1 lbl.Text=names[channel] lbl.Font=Enum.Font.GothamBold lbl.TextSize=12 lbl.TextColor3=colors[channel]
        local valLbl = Instance.new("TextLabel",wrapper) valLbl.Size=UDim2.new(0,30,0,16) valLbl.Position=UDim2.new(1,-42,0,offsetY) valLbl.BackgroundTransparency=1 valLbl.Text=tostring(initVal) valLbl.Font=Enum.Font.GothamBold valLbl.TextSize=12 valLbl.TextColor3=Color3.fromRGB(200,200,220) valLbl.TextXAlignment=Enum.TextXAlignment.Right
        local bar = Instance.new("Frame",wrapper) bar.Size=UDim2.new(1,-60,0,8) bar.Position=UDim2.new(0,30,0,offsetY+4) bar.BackgroundColor3=Color3.fromRGB(50,50,60) corner(bar,4)
        local fill = Instance.new("Frame",bar) fill.Size=UDim2.new(initVal/255,0,1,0) fill.BackgroundColor3=colors[channel] corner(fill,4)
        local knob = Instance.new("TextButton",bar) knob.Size=UDim2.new(0,14,0,14) knob.Position=UDim2.new(initVal/255,-7,0.5,-7) knob.BackgroundColor3=Color3.fromRGB(230,230,240) knob.Text="" corner(knob,7)
        local dragging = false
        knob.MouseButton1Down:Connect(function() dragging = true end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                local rel = math.clamp((i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
                local val = math.floor(rel*255+0.5)
                knob.Position=UDim2.new(rel,-7,0.5,-7) fill.Size=UDim2.new(rel,0,1,0) valLbl.Text=tostring(val) changedCb(val)
            end
        end)
    end
    makeRGBSlider(34,1,r,function(val) r=val local c=Color3.fromRGB(r,g,b) preview.BackgroundColor3=c onChanged(c) end)
    makeRGBSlider(62,2,g,function(val) g=val local c=Color3.fromRGB(r,g,b) preview.BackgroundColor3=c onChanged(c) end)
    makeRGBSlider(90,3,b,function(val) b=val local c=Color3.fromRGB(r,g,b) preview.BackgroundColor3=c onChanged(c) end)
end

local animSection = createSection(pageMenu, "Анимации")
local animDefs = {
    {"Слайд вкладок","TabSlide"}, {"Сворачивание секций","SectionCollapse"}, {"Hover эффекты","ButtonHover"},
    {"Открытие/закрытие","MenuOpenClose"}, {"Ползунок","SliderKnob"}, {"Цвет toggle","ToggleColor"},
}
for _, pair in ipairs(animDefs) do
    local lbl, key = pair[1], pair[2]
    createToggle(animSection, lbl, Animations[key], function(v) Animations[key] = v end)
end

local colorSection = createSection(pageMenu, "Цвета интерфейса")
local colorDefs = {
    {"Фон","Background",function(c) main.BackgroundColor3=c end},
    {"Верхняя панель","TopBar",function(c) top.BackgroundColor3=c end},
    {"Акцент / индикатор","Accent",function(c)
        Theme.Accent=c
        for _,child in ipairs(tabsFrame:GetChildren()) do
            if child:IsA("TextButton") then
                local ind=child:FindFirstChildWhichIsA("Frame") if ind then ind.BackgroundColor3=c end
                local stroke=child:FindFirstChildWhichIsA("UIStroke") if stroke and stroke.Transparency<0.5 then stroke.Color=c end
            end
        end
    end},
    {"Toggle ON","ToggleOn",function(c) Theme.ToggleOn=c if AutoShotToggleBtn and Monitoring then AutoShotToggleBtn.BackgroundColor3=c end if TriggerMainBtn and TriggerbotEnabled then TriggerMainBtn.BackgroundColor3=c end end},
    {"Toggle OFF","ToggleOff",function(c) Theme.ToggleOff=c if AutoShotToggleBtn and not Monitoring then AutoShotToggleBtn.BackgroundColor3=c end if TriggerMainBtn and not TriggerbotEnabled then TriggerMainBtn.BackgroundColor3=c end end},
    {"Заливка слайдера","SliderFill",function(c) Theme.SliderFill=c end},
    {"Bind кнопки","BindBtn",function(c) Theme.BindBtn=c AutoBindBtn.BackgroundColor3=c TriggerBindBtn.BackgroundColor3=c end},
}
for _, def in ipairs(colorDefs) do
    local label, themeKey, applyFn = def[1], def[2], def[3]
    createColorPicker(colorSection, label, Theme[themeKey], function(c) Theme[themeKey]=c applyFn(c) end)
end

local menuOpen = false
main.Visible = false
local openT = TweenService:Create(main, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(760,520)})
local closeT = TweenService:Create(main, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.fromOffset(0,0)})

local function toggleMenu()
    menuOpen = not menuOpen
    if menuOpen then
        main.Visible = true
        if Animations.MenuOpenClose then openT:Play() else main.Size = UDim2.fromOffset(760,520) end
    else
        if Animations.MenuOpenClose then closeT:Play() task.delay(0.35, function() if not menuOpen then main.Visible = false end end)
        else main.Visible = false end
    end
end

closeBtn.MouseButton1Click:Connect(toggleMenu)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift or i.KeyCode == Enum.KeyCode.End then toggleMenu() end
    if i.KeyCode == ToggleKey then ToggleAutoshot() end
    if WaitingForBind then
        ToggleKey = i.KeyCode
        AutoBindBtn.Text = "Сменить бинд автошота ("..tostring(i.KeyCode.Name).." - "..BindMode..")"
        WaitingForBind = false
    end
end)

RunService.Heartbeat:Connect(CheckShot)
RunService.Heartbeat:Connect(function() if TripleShotEnabled then CheckTripleShot() end end)

task.delay(0.3, function()
    main.Visible = true
    if Animations.MenuOpenClose then openT:Play() else main.Size = UDim2.fromOffset(760,520) end
    task.delay(0.15, function()
        allTabs[3].SetActive(true)
        switchToPage(pagePlayerList)
    end)
end)

print("Ukussia + Auto-Shot v9.14 с Rage загружен!")
print("RightShift / End — меню | V — автошот | ПКМ — триггербот | F1+Z — авто-хост")
print("Rage Insta Kill добавлен во вкладку Legit!")
