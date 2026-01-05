-- Lightweight Singleton (Prevent Double Execution)
if getgenv().MinakoLoaded then return end
getgenv().MinakoLoaded = true

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Variable Setup --
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Pre-Load UI Cleanup (Fix Stacking) -- WRAPPED IN PCALL
local function CleanOldUI()
    pcall(function()
        for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
            if v.Name == "Dungeon Quest!" or (v:FindFirstChild("Title") and v.Title.Text == "Dungeon Quest!") then
                v:Destroy()
            end
        end
        for _, v in pairs(Players.LocalPlayer.PlayerGui:GetChildren()) do
            if v.Name == "Dungeon Quest!" or (v:FindFirstChild("Title") and v.Title.Text == "Dungeon Quest!") then
                 v:Destroy()
            end
        end
    end)
end
CleanOldUI()

-- Ensure queue_on_teleport is available
if not queue_on_teleport and syn and syn.queue_on_teleport then
    queue_on_teleport = syn.queue_on_teleport
end

local Character = Players.LocalPlayer.Character
local PlayerGui = Players.LocalPlayer.PlayerGui

-- Logic Variables
local WaitingToTp = false
local GreggCoin, RealCoin = false, nil
local OldTick = tick()
local BestDungeon, BestDifficulty = "nil", "Insane"
local NameHideName, NameHideTitle = "", ""
local RemoteModule
local LastplayerPos, StuckTime = Vector3.zero, 0
local OldName, OldTitle

-- Settings Table (Default)
local Settings = {
    AutoFarm = {Enabled = false, Delay = 2, Distance = 6, UseSkills = false, RaidFarm = false},
    Dungeon = {Enabled = false, EnabledBest = false, Name = "", Diffculty = "", Mode = "Normal", RaidEnabled = false, RaidName = "", Tier = "1"},
    AutoSell = {Enabled = false, Raritys = {}, ItemTypes = {}},
    Misc = {AutoRetry = false, GetGreggCoin = false, NameHide = false, RejoinIfStuck = false, RejoinStuckDelay = 120, RemovePulseVisuals = true, SkillDelay = 0.1}, 
    DebugMode = false,
    UI = {Keybind = "RightControl"}
}

-- Game Data (Preserved)
local DungeonLevels = {
    ["0"] = {["Dungeon"] = "Desert Temple", ["Easy"] = 0, ["Medium"] = 5, ["Hard"] = 15},
    ["30"] = {["Dungeon"] = "Winter Outpost", ["Easy"] = 30, ["Medium"] = 40, ["Hard"] = 50},
    ["60"] = {["Dungeon"] = "Pirate Island", ["Insane"] = 60, ["Nightmare"] = 65},
    ["70"] = {["Dungeon"] = "King's Castle", ["Insane"] = 70, ["Nightmare"] = 75},
    ["80"] = {["Dungeon"] = "The Underworld", ["Insane"] = 80, ["Nightmare"] = 85},
    ["90"] = {["Dungeon"] = "Samurai Palace", ["Insane"] = 90, ["Nightmare"] = 95},
    ["100"] = {["Dungeon"] = "The Canals", ["Insane"] = 100, ["Nightmare"] = 105},
    ["110"] = {["Dungeon"] = "Ghastly Harbor", ["Insane"] = 110, ["Nightmare"] = 115},
    ["120"] = {["Dungeon"] = "Steampunk Sewers", ["Insane"] = 120, ["Nightmare"] = 125},
    ["135"] = {["Dungeon"] = "Orbital Outpost", ["Insane"] = 135, ["Nightmare"] = 140},
    ["150"] = {["Dungeon"] = "Volcanic Chambers", ["Insane"] = 150, ["Nightmare"] = 155},   
    ["160"] = {["Dungeon"] = "Aquatic Temple", ["Insane"] = 160, ["Nightmare"] = 165},
    ["170"] = {["Dungeon"] = "Enchanted Forest", ["Insane"] = 170, ["Nightmare"] = 175},
    ["180"] = {["Dungeon"] = "Northern Lands", ["Insane"] = 180, ["Nightmare"] = 185},
    ["190"] = {["Dungeon"] = "Gilded Skies", ["Insane"] = 190, ["Nightmare"] = 195},
    ["200"] = {["Dungeon"] = "Yokai Peak", ["Insane"] = 200, ["Nightmare"] = 205},
    ["210"] = {["Dungeon"] = "Abyssal Void", ["Insane"] = 210, ["Nightmare"] = 215},
}

local Raritys = {
    ["Legendary"] = Color3.fromRGB(244, 154, 9),
    ["Epic"] = Color3.fromRGB(146, 70, 159),
    ["Rare"] = Color3.fromRGB(75, 77, 195),
    ["Uncommon"] = Color3.fromRGB(91, 194, 80),
    ["Common"] = Color3.fromRGB(152, 152, 152),
}

local RemoteCodes = {}

-- Functions --

local function SaveSettings()
    if writefile then
        writefile("dungeonquest_settings.json", HttpService:JSONEncode(Settings))
    end
end

local function LoadSettings()
    if readfile and isfile and isfile("dungeonquest_settings.json") then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile("dungeonquest_settings.json"))
        end)
        if success and result then
            for k, v in pairs(result) do
                if Settings[k] ~= nil then
                    Settings[k] = v
                end
            end
        end
    end
end

LoadSettings() -- Load on start

local Functions = {}

Players.LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    repeat task.wait() until Character:FindFirstChild("HumanoidRootPart")
end)

function Functions:GetInventoryItems()
    local tbl = {}
    local inventory = Players.LocalPlayer.PlayerGui:FindFirstChild("sellShop") 
        and Players.LocalPlayer.PlayerGui.sellShop.Frame.innerFrame.rightSideFrame.ScrollingFrame
    
    if inventory then
        for i,v in pairs(inventory:GetChildren()) do
            if v:IsA("ImageLabel") and v:FindFirstChild("itemType") and v.itemType:FindFirstChild("uniqueItemNum") then
                local isEquipped = false
                if v:FindFirstChild("equipped") or v:FindFirstChild("Equipped") then
                    isEquipped = true
                elseif v:FindFirstChild("Checkmark") and v.Checkmark.Visible then
                    isEquipped = true
                end

                local Item = {
                    ["index"]=v:FindFirstChild("itemType"):FindFirstChild("uniqueItemNum").Value,
                    ["rarity"]="",
                    ["itemType"]=v:FindFirstChild("itemType").Value,
                    ["equipped"]=isEquipped
                }
                for i2,v2 in pairs(Raritys) do
                    if v.ImageColor3 == v2 then
                        Item["rarity"] = i2
                    end
                end
                table.insert(tbl,Item)
            end
        end
    end
    return tbl
end

function Functions:DoSkills(RepeatCount)
    if not Players.LocalPlayer.Backpack then return end
    for i, v in pairs(Players.LocalPlayer.Backpack:GetChildren()) do
        -- Skip Weapon (Basic Attack) to prevent auto-clicking
        if v:FindFirstChild("itemType") and v.itemType.Value == "weapon" then
            continue
        end

        for k = 1, (RepeatCount or 1) do -- Loop 10 times
            task.spawn(function()
                if v:FindFirstChild("cooldown") and v.cooldown.Value and (v:FindFirstChild("abilityEvent") or v:FindFirstChild("spellEvent")) then
                    (v:FindFirstChild("abilityEvent") or v:FindFirstChild("spellEvent")):FireServer()
                elseif v:FindFirstChild("cooldown") and v.cooldown.Value then
                    ReplicatedStorage:WaitForChild("dataRemoteEvent"):FireServer({[1] = {["\t"] = v},[2] = RemoteCodes["Abilities"]})
                end
            end)
        end
    end
end

function Functions:Teleport(Cframe)
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    LastplayerPos = Character:GetPivot().p
    if WaitingToTp == true then return end
    
    local bodyPosition = Character.HumanoidRootPart:FindFirstChildOfClass("BodyPosition")
    local bodyGyro = Character.HumanoidRootPart:FindFirstChildOfClass("BodyGyro")
    
    if not bodyGyro then
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
        bodyGyro.CFrame = Character.HumanoidRootPart.CFrame
        bodyGyro.D = 500
        bodyGyro.Parent = Character.HumanoidRootPart
    end
    
    if not bodyPosition then
        bodyPosition = Instance.new("BodyPosition")
        bodyPosition.MaxForce = Vector3.new(400000, 400000, 400000)
        bodyPosition.Position = Cframe.Position
        bodyPosition.D = 300
        bodyPosition.Parent = Character.HumanoidRootPart
        Character.HumanoidRootPart.Velocity = Vector3.zero
    end
    
    local oldTime = tick()
    WaitingToTp = true
    Character.HumanoidRootPart.Anchored = false
    
    repeat task.wait()
        if Character:FindFirstChild("HumanoidRootPart") and bodyPosition and bodyGyro then
            local targetPos = Cframe.Position
            local myPos = Cframe.p + Vector3.new(0, Settings.AutoFarm.Distance * 2, 0)
            local lookCFrame = CFrame.lookAt(myPos, targetPos)
            Character:PivotTo(lookCFrame * CFrame.Angles(math.rad(-90), 0, 0))
            bodyPosition.Position = myPos
            bodyGyro.CFrame = lookCFrame * CFrame.Angles(math.rad(-90), 0, 0)
        end
    until tick() - oldTime >= Settings.AutoFarm.Delay or not Character:FindFirstChild("HumanoidRootPart")
    
    WaitingToTp = false
    if Character:FindFirstChild("HumanoidRootPart") then
        Character.HumanoidRootPart.Anchored = true
        if bodyPosition then bodyPosition:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
    end
end

function Functions:GetEnemys()
    if not workspace:FindFirstChild("dungeon") then 
        return workspace:FindFirstChild("enemies") and workspace.enemies:GetChildren()
    end
    for i, v in pairs(workspace.dungeon:GetChildren()) do
        if v:FindFirstChild("enemyFolder") and v.enemyFolder:FindFirstChildOfClass("Model") then
            return v.enemyFolder:GetChildren()
        end
    end
    return nil
end

function Functions:GetClosestEnemy()
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    local enemies = Functions:GetEnemys()
    if not enemies then return end

    local closestEnemy = nil
    local shortestDistance = math.huge
    local maxHealth = -math.huge
    
    for _, v in pairs(enemies) do
        local enemyPosition = v:FindFirstChild("HumanoidRootPart") and v.HumanoidRootPart.Position
        local enemyHumanoid = v:FindFirstChild("Humanoid")
        if enemyPosition and enemyHumanoid then
            local distance = (Character.HumanoidRootPart.Position - enemyPosition).Magnitude
            if distance < shortestDistance or (distance == shortestDistance and enemyHumanoid.MaxHealth > maxHealth) then
                shortestDistance = distance
                closestEnemy = v
                maxHealth = enemyHumanoid.MaxHealth
            end
        end
    end

    return closestEnemy
end

function Functions:GetBestDungeon()
    local highestLevelDungeon = 0
    local level = Players.LocalPlayer.leaderstats.Level.Value
    
    for i, v in pairs(DungeonLevels) do
        if level >= tonumber(i) then
            if tonumber(i) > highestLevelDungeon then
                highestLevelDungeon = tonumber(i)
                if v["Nightmare"] and level >= v["Nightmare"] then
                    BestDungeon = v["Dungeon"]; BestDifficulty = "Nightmare"
                elseif v["Insane"] and level >= v["Insane"] then
                    BestDungeon = v["Dungeon"]; BestDifficulty = "Insane"
                elseif v["Hard"] and level >= v["Hard"] then
                    BestDungeon = v["Dungeon"]; BestDifficulty = "Hard"
                elseif v["Medium"] and level >= v["Medium"] then
                    BestDungeon = v["Dungeon"]; BestDifficulty = "Medium"
                elseif v["Easy"] and level >= v["Easy"] then
                    BestDungeon = v["Dungeon"]; BestDifficulty = "Easy"
                end
            end
        end
    end
end

-- Initialize Remotes
if getupvalue ~= nil then
    repeat task.wait() until ReplicatedStorage:FindFirstChild("Utility") and ReplicatedStorage.Utility:FindFirstChild("BridgeNet2") and ReplicatedStorage.Utility.BridgeNet2:FindFirstChild("Client") and ReplicatedStorage.Utility.BridgeNet2.Client:FindFirstChild("ClientIdentifiers")
    RemoteModule = require(ReplicatedStorage.Utility.BridgeNet2.Client.ClientIdentifiers)
    for i,v in pairs(getupvalue(RemoteModule["deser"],2)) do
        RemoteCodes[v] = i
    end
else
    RemoteCodes={["DungeonRetryBridge"]="/",["CharacterSelection"]="M",["PartySystem"]="d",["Cutscene"]="\184",["Intro"]="5",["DungeonHandler"]=";",["Abilities"]="G"}
end

repeat task.wait() until Players.LocalPlayer and Players.LocalPlayer.PlayerGui

-- UI Creation --

local Window = WindUI:CreateWindow({
    Title = "Dungeon Quest!",
    Icon = "door-open",
    Author = "by Minako",
})

Window:EditOpenButton({
    Title = "Open Config",
    Icon = "settings",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

-- Initialize Dropdown Variables
local DungeonDropdown, DifficultyDropdown

-- Safe Defaults to prevent Blank UI
if Settings.Dungeon.Name == "" or Settings.Dungeon.Name == "nil" then Settings.Dungeon.Name = "Desert Temple" end
if Settings.Dungeon.Diffculty == "" then Settings.Dungeon.Diffculty = "Easy" end

-- Get Best Dungeon for Defaults (Async Update)
task.spawn(function()
    pcall(function()
        if not Players.LocalPlayer:FindFirstChild("leaderstats") then
            Players.LocalPlayer:WaitForChild("leaderstats", 10)
        end
        Functions:GetBestDungeon()
        
        -- Update UI if discovered better dungeon
        if BestDungeon and BestDungeon ~= "nil" then
             if DungeonDropdown and DungeonDropdown.Set then DungeonDropdown:Set(BestDungeon) end
             Settings.Dungeon.Name = BestDungeon
        end
        if BestDifficulty then
             if DifficultyDropdown and DifficultyDropdown.Set then DifficultyDropdown:Set(BestDifficulty) end
             Settings.Dungeon.Diffculty = BestDifficulty
        end
    end)
end)

-- 1. Auto Farm Tab --
local TabAutoFarm = Window:Tab({Title = "AutoFarm", Icon = "activity"}) do
    
    TabAutoFarm:Section({Title = "Farm Settings"})
    
    TabAutoFarm:Toggle({
        Title = "Auto Farm",
        Desc = "Teleports to enemies and attacks",
        Value = Settings.AutoFarm.Enabled,
        Callback = function(v) 
            Settings.AutoFarm.Enabled = v
            SaveSettings()
        end
    })

    TabAutoFarm:Toggle({
        Title = "Use Skills",
        Desc = "Automatically casts skills",
        Value = Settings.AutoFarm.UseSkills,
        Callback = function(v) 
            Settings.AutoFarm.UseSkills = v
            SaveSettings()
        end
    })

    TabAutoFarm:Slider({
        Title = "Teleport Delay",
        Desc = "Delay between teleports",
        Step = 0.1,
        Value = {
            Min = 1,
            Max = 4,
            Default = Settings.AutoFarm.Delay,
        },
        Callback = function(v)
            Settings.AutoFarm.Delay = v
            SaveSettings()
        end
    })

    TabAutoFarm:Slider({
        Title = "Distance",
        Desc = "Height above enemies",
        Step = 1,
        Value = {
             Min = 0,
             Max = 10,
             Default = Settings.AutoFarm.Distance,
        },
        Callback = function(v)
            Settings.AutoFarm.Distance = v
            SaveSettings()
        end
    })

    TabAutoFarm:Section({Title = "Dungeon Creation"})

    TabAutoFarm:Toggle({
        Title = "Auto Create Best",
        Desc = "Automatically creates the best dungeon for your level",
        Value = Settings.Dungeon.EnabledBest,
        Callback = function(v)
            Settings.Dungeon.EnabledBest = v
            SaveSettings()
        end
    })

    TabAutoFarm:Toggle({
        Title = "Auto Create Selected",
        Desc = "Creates the dungeon selected below",
        Value = Settings.Dungeon.Enabled,
        Callback = function(v)
            Settings.Dungeon.Enabled = v
            SaveSettings()
        end
    })

    local DungeonList = {"Desert Temple","Winter Outpost","Pirate Island","King's Castle","The Underworld","Samurai Palace","The Canals","Ghastly Harbor","Steampunk Sewers","Orbital Outpost","Volcanic Chambers","Aquatic Temple","Enchanted Forest","Northen Lands","Gilded Skies","Yokai Peak","Abyssal Void"}
    DungeonDropdown = TabAutoFarm:Dropdown({
        Title = "Dungeon",
        Values = DungeonList,
        Value = Settings.Dungeon.Name,
        Callback = function(v)
            Settings.Dungeon.Name = v
            SaveSettings()
        end
    })

    DifficultyDropdown = TabAutoFarm:Dropdown({
        Title = "Difficulty",
        Values = {"Easy", "Medium", "Hard", "Insane", "Nightmare"},
        Value = Settings.Dungeon.Diffculty,
        Callback = function(v)
            Settings.Dungeon.Diffculty = v
            SaveSettings()
        end
    })

    TabAutoFarm:Dropdown({
        Title = "Mode",
        Values = {"Normal", "Hardcore"},
        Value = Settings.Dungeon.Mode,
        Callback = function(v)
            Settings.Dungeon.Mode = v
            SaveSettings()
        end
    })

    TabAutoFarm:Section({Title = "Raid Creation"})
    
    TabAutoFarm:Toggle({
        Title = "Raid Farm",
        Desc = "Teleport to lobby after finish",
        Value = Settings.AutoFarm.RaidFarm,
        Callback = function(v)
            Settings.AutoFarm.RaidFarm = v
            SaveSettings()
        end
    })

    TabAutoFarm:Toggle({
        Title = "Auto Create Raid",
        Desc = "Creates raid lobby",
        Value = Settings.Dungeon.RaidEnabled,
        Callback = function(v)
            Settings.Dungeon.RaidEnabled = v
            SaveSettings()
        end
    })

    TabAutoFarm:Dropdown({
        Title = "Raid",
        Values = {"Hela Raid", "Goliath Raid"},
        Value = Settings.Dungeon.RaidName,
        Callback = function(v)
            Settings.Dungeon.RaidName = v
            SaveSettings()
        end
    })

    TabAutoFarm:Dropdown({
        Title = "Tier",
        Values = {"1","2","3","4","5"},
        Value = Settings.Dungeon.Tier,
        Callback = function(v)
            Settings.Dungeon.Tier = v
            SaveSettings()
        end
    })
end

-- 2. Misc Tab --
local TabMisc = Window:Tab({Title = "Misc", Icon = "house"}) do
    TabMisc:Section({Title = "Spam Settings"})

    TabMisc:Slider({
        Title = "Skill Spam Delay",
        Desc = "Delay for skill usage (Lower = Faster)",
        Step = 0.01,
        Value = {
            Min = 0.01,
            Max = 0.5,
            Default = Settings.Misc.SkillDelay,
        },
        Callback = function(v)
            Settings.Misc.SkillDelay = v
            SaveSettings()
        end
    })

    TabMisc:Section({Title = "General"})

    TabMisc:Toggle({
        Title = "Auto Retry",
        Desc = "Replays dungeon automatically",
        Value = Settings.Misc.AutoRetry,
        Callback = function(v)
            Settings.Misc.AutoRetry = v
            SaveSettings()
        end
    })

    TabMisc:Toggle({
        Title = "Get Gregg Coin",
        Desc = "Collects coins",
        Value = Settings.Misc.GetGreggCoin,
        Callback = function(v)
            Settings.Misc.GetGreggCoin = v
            SaveSettings()
        end
    })

    TabMisc:Section({Title = "Auto Sell"})

    TabMisc:Toggle({
        Title = "Enabled",
        Desc = "Sells items automatically",
        Value = Settings.AutoSell.Enabled,
        Callback = function(v)
            Settings.AutoSell.Enabled = v
            SaveSettings()
        end
    })

    TabMisc:Dropdown({
        Title = "Item Types",
        Multi = true,
        Values = {"weapon","ability","ring","helmet","chest"},
        Value = Settings.AutoSell.ItemTypes,
        Callback = function(v)
            Settings.AutoSell.ItemTypes = v
            SaveSettings()
        end
    })

    TabMisc:Dropdown({
        Title = "Rarities",
        Multi = true,
        Values = {"Ultimate","Legendary","Epic","Rare","Uncommon","Common"},
        Value = Settings.AutoSell.Raritys,
        Callback = function(v)
            Settings.AutoSell.Raritys = v
            SaveSettings()
        end
    })

    TabMisc:Section({Title = "Name Hider"})

    TabMisc:Toggle({
        Title = "Hide Name",
        Desc = "Masks your name locally",
        Value = Settings.Misc.NameHide,
        Callback = function(v)
            Settings.Misc.NameHide = v
            SaveSettings()
        end
    })
    
    TabMisc:Input({
        Title = "Fake Name",
        Default = "Float.Balls",
        Callback = function(v)
            NameHideName = v
        end
    })

    TabMisc:Input({
        Title = "Fake Title",
        Default = "🤖",
        Callback = function(v)
            NameHideTitle = v
        end
    })

    TabMisc:Section({Title = "Anti Stuck"})

    TabMisc:Toggle({
        Title = "Rejoin If Stuck",
        Desc = "Rejoins lobby if stuck for a while",
        Value = Settings.Misc.RejoinIfStuck,
        Callback = function(v)
            Settings.Misc.RejoinIfStuck = v
            SaveSettings()
        end
    })

    TabMisc:Slider({
        Title = "Stuck Delay (s)",
        Step = 1,
        Value = {
            Min = 30,
            Max = 300,
            Default = Settings.Misc.RejoinStuckDelay,
        },
        Callback = function(v)
            Settings.Misc.RejoinStuckDelay = v
            SaveSettings()
        end
    })

    TabMisc:Section({Title = "Visual Settings"})

    TabMisc:Toggle({
        Title = "Remove Pulse Visuals",
        Desc = "Boosts FPS by removing visual effects",
        Value = Settings.Misc.RemovePulseVisuals,
        Callback = function(v)
            Settings.Misc.RemovePulseVisuals = v
            SaveSettings()
            
            -- Apply Lighting Changes Immediately
            if v then
                Lighting.GlobalShadows = false
            else
                Lighting.GlobalShadows = true
            end
        end
    })
end

-- 3. Settings Tab --
local TabSettings = Window:Tab({Title = "Settings", Icon = "settings"}) do
    TabSettings:Section({Title = "Configuration"})

    TabSettings:Button({
        Title = "Save Settings",
        Callback = function()
            SaveSettings()
            WindUI:Notify({Title = "Saved", Content = "Settings saved successfully", Duration = 3})
        end
    })
    
    TabSettings:Keybind({
        Title = "Menu Keybind",
        Desc = "Key to toggle UI",
        Value = Settings.UI.Keybind or "RightControl",
        Callback = function(v)
            Settings.UI.Keybind = v.Name
            SaveSettings() -- Just save, generic listener handles toggle
        end
    })
end

-- Default Keybind Init --
local isToggled = true
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode[Settings.UI.Keybind or "RightControl"] then
        isToggled = not isToggled
        Window.Enabled = isToggled 
        pcall(function() Window:Toggle() end)
        pcall(function() if Window.Instance then Window.Instance.Enabled = isToggled end end)
    end
end)

-- Queue Function Wrapper
local function RegisterQueue()
    if queue_on_teleport then
        queue_on_teleport([[
            repeat task.wait() until game:IsLoaded()
            repeat task.wait() until game:GetService("Players").LocalPlayer
            repeat task.wait() until game:GetService("Players").LocalPlayer.PlayerGui
            task.wait(3) 
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Guyeiei/MinakoHub/main/DungeonQuest.lua"))()
        ]])
    end
end

-- Logic Loops --

-- Rejoin If Stuck Loop
task.spawn(function()
    while true do task.wait(1)
        if Settings.Misc.RejoinIfStuck == true then
            -- Don't rejoin if we are handling a Soft Kick ("Return to Lobby" detected)
            local gui = Players.LocalPlayer.PlayerGui
            local softKickDetect = false
             -- Quick scan for kick UI to prevent conflict
            if gui:FindFirstChild("LoginKick") or gui:FindFirstChild("KickMsg") then 
                softKickDetect = true 
            end

            if not softKickDetect then
                if LastplayerPos and Character and (LastplayerPos - Character:GetPivot().p).Magnitude < 1 then
                    StuckTime = StuckTime + 1
                elseif StuckTime == Settings.Misc.RejoinStuckDelay then
                    RegisterQueue() -- Ensure queue before TP
                    TeleportService:Teleport(2414851778, Players.LocalPlayer)
                else
                    StuckTime = 0
                end
            end
        end
    end
end)

-- Name Hider Loop
task.spawn(function()
    while true do task.wait()
        pcall(function()
            if Character and Character:FindFirstChild("Head") and Character.Head:FindFirstChild("playerNameplate") then
                local hud = Players.LocalPlayer.PlayerGui:FindFirstChild("HUD")
                local status = hud and hud:FindFirstChild("Main") and hud.Main:FindFirstChild("PlayerStatus") and hud.Main.PlayerStatus:FindFirstChild("PlayerStatus")
                local pName = status and status:FindFirstChild("PlayerName")
                
                if pName then
                    if Settings.Misc.NameHide == true then
                        status.Portrait.Frame.ImageLabel.Visible = false
                        pName.Text = NameHideName
                        Character.Head.playerNameplate.PlayerName.Text = NameHideName
                        Character.Head.playerNameplate.Title.Text = NameHideTitle
                    else
                        status.Portrait.Frame.ImageLabel.Visible = true
                        pName.Text = OldName or Players.LocalPlayer.Name
                        Character.Head.playerNameplate.PlayerName.Text = OldName or Players.LocalPlayer.Name
                        Character.Head.playerNameplate.Title.Text = OldTitle or "Title"
                    end
                end
            end
        end)
    end    
end)

-- NEW: Return to Lobby Soft-Kick Recovery
task.spawn(function()
    local function FindBtn(parent, name) 
        -- Recursive Search for Button matches by Name OR Text
        local function scan(obj)
            for _, child in pairs(obj:GetChildren()) do
                if child:IsA("GuiButton") then
                    if child.Name == name then return child end
                    if child:IsA("TextButton") and string.find(string.lower(child.Text), string.lower(name)) then return child end
                    if child:IsA("ImageButton") then
                        for _, desc in pairs(child:GetDescendants()) do
                             if desc:IsA("TextLabel") and string.find(string.lower(desc.Text), string.lower(name)) then return child end
                        end
                    end
                end
                local res = scan(child)
                if res then return res end
            end
        end
        local success, btn = pcall(function() return scan(parent) end)
        return (success and btn and btn.Visible) and btn or nil
    end

    while true do task.wait(0.1) -- FASTER CHECK (0.1s)
        local gui = Players.LocalPlayer.PlayerGui
        
        -- Check for 'Return to Lobby' Button text
        local returnBtn = FindBtn(gui, "Return to Lobby")
        if returnBtn then
             -- FIRE USER REMOTE: pressReturnToLobby
             -- Confirmed strict structure from user
             local args = {{{event = "pressReturnToLobby"}, "\017"}}
             ReplicatedStorage:WaitForChild("dataRemoteEvent"):FireServer(unpack(args))
             
             -- Wait for 'Yes' confirmation and click it
             task.wait(0.5)
             local yesBtn = FindBtn(gui, "Yes")
             if yesBtn then
                 local x = yesBtn.AbsolutePosition.X + (yesBtn.AbsoluteSize.X / 2)
                 local y = yesBtn.AbsolutePosition.Y + (yesBtn.AbsoluteSize.Y / 2)
                 VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                 task.wait(0.05)
                 VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
             end
        end
    end
end)

local JoinDebounce = false
-- Main Logic Loop (Auto Sell, Dungeon Join, Auto Farm)
task.spawn(function()
    while true do task.wait(Settings.Misc.SkillDelay or 0.1) -- Ensure default isn't too low
        -- Auto Sell
        if Settings.AutoSell.Enabled == true then
            local args = {["chest"] = {},["helmet"] = {},["ability"] = {},["ring"] = {},["weapon"] = {}}
            local counters = {["chest"] = 0, ["helmet"] = 0, ["ability"] = 0, ["ring"] = 1, ["weapon"] = 0}
            for i,v in pairs(Functions:GetInventoryItems()) do
                if not v.equipped then -- Check Equipped
                    if table.find(Settings.AutoSell.ItemTypes, v["itemType"]) and table.find(Settings.AutoSell.Raritys, v["rarity"]) then
                        counters[v["itemType"]] = counters[v["itemType"]] + 1
                        args[v["itemType"]][counters[v["itemType"]]] = tonumber(v["index"])
                    end
                end
            end 
            if ReplicatedStorage:FindFirstChild("remotes") and ReplicatedStorage.remotes:FindFirstChild("sellItemEvent") then
                 ReplicatedStorage.remotes.sellItemEvent:FireServer(args)
            end
        end

        -- Dungeon Creation (Moved logic into safer block)
        -- Only proceed if Character is valid (Spawned in Lobby)
        if Character and Character:FindFirstChild("HumanoidRootPart") and not workspace:FindFirstChild("dungeon") then
            if not JoinDebounce then
                if Settings.Dungeon.Enabled == true then
                    JoinDebounce = true
                    
                    -- REGISTER QUEUE AGAIN JUST IN CASE
                    RegisterQueue()
                    
                    local DunArgs = {[1] = {[1] = {[1] = "\1",[2] = {["\3"] = "PlaySolo",["partyData"] = {
                                        ["difficulty"] = Settings.Dungeon.Diffculty,
                                        ["mode"] = Settings.Dungeon.Mode,
                                        ["dungeonName"] = Settings.Dungeon.Name,
                                        ["tier"] = 1,
                                    }}},[2] = RemoteCodes["PartySystem"]}}
                    ReplicatedStorage.dataRemoteEvent:FireServer(unpack(DunArgs))
                    task.delay(10, function() JoinDebounce = false end)
                    
                elseif Settings.Dungeon.RaidEnabled == true then
                    JoinDebounce = true
                    
                    -- REGISTER QUEUE AGAIN JUST IN CASE
                    RegisterQueue()

                    local RaidArgs = {[1] = {[1] = {[1] = "\1",[2] = {["\3"] = "PlaySolo",["partyData"] = {
                                        ["difficulty"] = "Nightmare",
                                        ["minimumJoinLevel"] = 0,
                                        ["tier"] = Settings.Dungeon.Tier,
                                        ["dungeonName"] = Settings.Dungeon.RaidName,
                                        ["mode"] = "Raid",
                                        ["visibility"] = "Public",
                                        ["maxPlayers"] = 40
                                    }}},[2] = RemoteCodes["PartySystem"]}}
                    ReplicatedStorage.dataRemoteEvent:FireServer(unpack(RaidArgs))
                    task.delay(10, function() JoinDebounce = false end)

                elseif Settings.Dungeon.EnabledBest == true then
                    JoinDebounce = true
                    
                    -- REGISTER QUEUE AGAIN JUST IN CASE
                    RegisterQueue()

                    local DunArgs = {[1] = {[1] = {[1] = "\1",[2] = {["\3"] = "PlaySolo",["partyData"] = {
                        ["difficulty"] = BestDifficulty,
                        ["mode"] = "Normal",
                        ["dungeonName"] = BestDungeon,
                        ["tier"] = 1,
                    }}},[2] = RemoteCodes["PartySystem"]}}
                    ReplicatedStorage.dataRemoteEvent:FireServer(unpack(DunArgs))
                    task.delay(10, function() JoinDebounce = false end)
                end
            end
        else
            JoinDebounce = false
        end

        -- Auto Farm
        if not workspace:FindFirstChild("CharacterSelectScene") and Settings.AutoFarm.Enabled == true and Players.LocalPlayer.Character then
            
            -- Voting / Ready (Start Button)
            if Players.LocalPlayer.PlayerGui:FindFirstChild("HUD") and Players.LocalPlayer.PlayerGui.HUD.Main.StartButton.Visible == true then
                 -- Remote Attempt
                 ReplicatedStorage.dataRemoteEvent:FireServer({[1] = {[utf8.char(3)] = "vote",["vote"] = true},[2] = utf8.char(28)}) 
                 if ReplicatedStorage.remotes:FindFirstChild("changeStartValue") then ReplicatedStorage.remotes.changeStartValue:FireServer() end
                 ReplicatedStorage.dataRemoteEvent:FireServer(unpack({[1] = {["\3"] = "raidReady"},[2] = RemoteCodes["DungeonHandler"]}))        
                 ReplicatedStorage.Utility.AssetRequester.Remote:InvokeServer({[1] = "ui",[2] = "raidTimeLeftGui"})                  

                 -- Physical Fallback (Click)
                 local btn = Players.LocalPlayer.PlayerGui.HUD.Main.StartButton
                 local x = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
                 local y = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2)
                 VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                 task.wait(0.05)
                 VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            
            -- Secondary Check: Raid Ready Check
            elseif Players.LocalPlayer.PlayerGui:FindFirstChild("RaidReadyCheck") and Players.LocalPlayer.PlayerGui.RaidReadyCheck.Enabled == true then
                 -- Remote Attempt
                 ReplicatedStorage.dataRemoteEvent:FireServer({[1] = {[utf8.char(3)] = "vote",["vote"] = true},[2] = utf8.char(28)}) 
                 
                 -- Physical Fallback (Click Yes Button)
                 local btn = Players.LocalPlayer.PlayerGui.RaidReadyCheck:FindFirstChild("Frame") and Players.LocalPlayer.PlayerGui.RaidReadyCheck.Frame:FindFirstChild("Yes")
                 if btn then
                    local x = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
                    local y = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2)
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
                 end
            end
            
            if Character and Character:FindFirstChild("HumanoidRootPart") then
                -- Skills
                if Settings.AutoFarm.UseSkills == true then
                    Functions:DoSkills(10) 
                end
                
                -- Gregg Coin
                if Settings.Misc.GetGreggCoin == true and GreggCoin == true and RealCoin ~= nil then
                    Functions:Teleport(RealCoin:GetPivot()-Vector3.new(0,Settings.AutoFarm.Distance*2,0))
                    GreggCoin = false; RealCoin=nil
                end
                
                -- Teleport to Enemy
                local Enemy = Functions:GetClosestEnemy()
                if GreggCoin == false and Enemy ~= nil then
                    Functions:Teleport(Enemy:GetPivot())
                end
            end
        end
    end 
end)

-- Event Listeners --

workspace.ChildAdded:Connect(function(child)
    if child.Name == "Coin" then
        GreggCoin = true; RealCoin = child
    end
    -- Safe Visual Removal
    if Settings.Misc.RemovePulseVisuals == true then
        if child.Name == "pulseWavesWave" or child.Name == "groundAura" or child.Name == "pulseWavesHitbox" then
            task.delay(0, function() child:Destroy() end)
        end 
    end
end)

Players.LocalPlayer.PlayerGui.rewardGuiHolder.holder.ChildAdded:Connect(function()
    if Settings.Misc.AutoRetry == true then return end -- Check Auto Retry before leaving
    if Settings.AutoFarm.RaidFarm == true then
        RegisterQueue() -- RE-REGISTER HERE TOO
        TeleportService:Teleport(2414851778, Players.LocalPlayer)
    end
end)

if Players.LocalPlayer.PlayerGui:FindFirstChild("cutscene") then
    Players.LocalPlayer.PlayerGui.cutscene.Changed:Connect(function(change)
        if change == "Enabled" then
            ReplicatedStorage.dataRemoteEvent:FireServer({[1] = {["\3"] = "skip"},[2] = RemoteCodes["Cutscene"]})        
        end
    end)
end

-- DISABLED GENERIC ERROR HANDLER to allow 'Return to Lobby' specific handling
-- GuiService.ErrorMessageChanged:Connect(function()
--    RegisterQueue() 
--    TeleportService:Teleport(2414851778, Players.LocalPlayer)
-- end)

-- Auto Retry Listener (Robust w/ Click Fallback)
task.spawn(function()
    local retryUI = Players.LocalPlayer.PlayerGui:WaitForChild("RetryVote", 9999) 
    if retryUI then
         local function TryRetry()
            if Settings.Misc.AutoRetry == true and retryUI.Enabled then
                 ReplicatedStorage.dataRemoteEvent:FireServer({[1] = {["\3"] = "vote",["vote"] = true},[2] = RemoteCodes["DungeonRetryBridge"]})
                 if ReplicatedStorage.remotes:FindFirstChild("changeStartValue") then ReplicatedStorage.remotes.changeStartValue:FireServer() end
                 
                 task.delay(0.5, function()
                    local btn = retryUI:FindFirstChild("Frame") and retryUI.Frame:FindFirstChild("Retry")
                    if btn and btn.Visible then
                         local vim = game:GetService("VirtualInputManager")
                         local x = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
                         local y = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2)
                         vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
                         task.wait(0.05)
                         vim:SendMouseButtonEvent(x, y, 0, false, game, 1)
                    end
                 end)
            end
         end
         
         retryUI:GetPropertyChangedSignal("Enabled"):Connect(TryRetry)
         if retryUI.Enabled then TryRetry() end
    end
end)

WindUI:Notify({Title = "Loaded", Content = "Dungeon Quest Script Loaded!", Duration = 5})

-- Initial Queue (Startup)
RegisterQueue()
