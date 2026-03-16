local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ENABLED = false

local FOV = 150

local BeamConfig = {
Lifetime = 0.2,
BaseWidth = 0.05,
MaxWidth = 0.12,
Curved = true,
CurveAmount = 6,
Color = Color3.fromRGB(255, 60, 60),
}

local HARD_TARGET = nil
local HARD_HEAD_POS = nil
local MAX_HEAD_DELTA = 8
local ANTI_AIM_DELTA = 25
local STABLE_FRAMES = 0
local REQUIRED_STABLE = 3

local GunNames = {
"P226","MP5","M24","Draco","Glock","Sawnoff","Uzi","G3","C9",
"Hunting Rifle","Anaconda","AK47","Remington","Double Barrel"
}
local GunLookup = {}
for _,n in pairs(GunNames) do GunLookup[n] = true end

local function IsHoldingAllowedGun(args)
local ok, weapon = pcall(function() return args[3] end)
if ok and typeof(weapon) == "Instance" and GunLookup[weapon.Name] then
return true
end
if LocalPlayer.Character then
for _,c in pairs(LocalPlayer.Character:GetChildren()) do
if (c:IsA("Tool") or c:IsA("Model")) and GunLookup[c.Name] then
return true
end
end
end
return false
end

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.new(1,1,1)
fovCircle.Thickness = 2
fovCircle.NumSides = 100
fovCircle.Filled = false
fovCircle.Visible = false

local function GetClosestTarget()
local closest, shortest = nil, math.huge
local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

for _,plr in pairs(Players:GetPlayers()) do
if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
local sp, on = Camera:WorldToViewportPoint(plr.Character.Head.Position)
if on then
local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
if d < FOV and d < shortest then
shortest, closest = d, plr
end
end
end
end
return closest

end

local function GetHardHeadPos(target)
if not target.Character then return nil end
local head = target.Character:FindFirstChild("Head")
if not head then return nil end

local pos = head.Position

if HARD_TARGET ~= target then
HARD_TARGET = target
HARD_HEAD_POS = pos
STABLE_FRAMES = 0
return pos
end

if not HARD_HEAD_POS then
HARD_HEAD_POS = pos
return pos
end

local delta = (pos - HARD_HEAD_POS).Magnitude

if delta > ANTI_AIM_DELTA then
STABLE_FRAMES = 0
return HARD_HEAD_POS
end

if delta <= MAX_HEAD_DELTA then
STABLE_FRAMES += 1
if STABLE_FRAMES >= REQUIRED_STABLE then
HARD_HEAD_POS = pos
end
return HARD_HEAD_POS
end

STABLE_FRAMES = 0
return HARD_HEAD_POS

end

local function GetServerHitPart(char)
return char:FindFirstChild("HumanoidRootPart")
or char:FindFirstChild("UpperTorso")
or char:FindFirstChild("Torso")
or char:FindFirstChild("Head")
end

local LAST_BEAM = 0
local BEAM_COOLDOWN = 0.03

local function ShootBeam3D(target)
if not ENABLED then return end
if not target.Character then return end
if tick() - LAST_BEAM < BEAM_COOLDOWN then return end
LAST_BEAM = tick()

local head = target.Character:FindFirstChild("Head")
local myHead = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
if not head or not myHead then return end

local a0 = Instance.new("Attachment")
a0.Parent = myHead

local a1 = Instance.new("Attachment")
a1.Parent = head

-- MAIN BEAM
local beam = Instance.new("Beam")
beam.Attachment0 = a0
beam.Attachment1 = a1
beam.FaceCamera = true
beam.LightEmission = 1
beam.LightInfluence = 0
beam.Color = ColorSequence.new(BeamConfig.Color)
beam.Width0 = BeamConfig.BaseWidth
beam.Width1 = BeamConfig.BaseWidth
beam.Transparency = NumberSequence.new{
NumberSequenceKeypoint.new(0,0),
NumberSequenceKeypoint.new(1,0.4)
}

if BeamConfig.Curved then
beam.CurveSize0 = BeamConfig.CurveAmount
beam.CurveSize1 = -BeamConfig.CurveAmount
end

beam.Parent = myHead

-- 🔥 GLOW LAYER
local glow = beam:Clone()
glow.Width0 *= 2
glow.Width1 *= 2
glow.Transparency = NumberSequence.new(0.7)
glow.LightEmission = 2
glow.Parent = myHead

-- 💥 HIT SPARK
local spark = Instance.new("Part")
spark.Shape = Enum.PartType.Ball
spark.Material = Enum.Material.Neon
spark.Color = BeamConfig.Color
spark.Size = Vector3.new(0.25,0.25,0.25)
spark.Anchored = true
spark.CanCollide = false
spark.Position = head.Position
spark.Parent = workspace

Debris:AddItem(spark,0.08)

local destroyed = false
local conn

local function Cleanup()
if destroyed then return end
destroyed = true
if conn then conn:Disconnect() end
if beam then beam:Destroy() end
if glow then glow:Destroy() end
if a0 then a0:Destroy() end
if a1 then a1:Destroy() end
end

conn = RunService.RenderStepped:Connect(function()
if not ENABLED or not beam.Parent or not head.Parent then
Cleanup()
return
end

local dist = (myHead.Position - head.Position).Magnitude    
local w = math.clamp(dist / 300, BeamConfig.BaseWidth, BeamConfig.MaxWidth)    

beam.Width0 = w    
beam.Width1 = w    
glow.Width0 = w * 2    
glow.Width1 = w * 2    

spark.Position = head.Position

end)

task.delay(BeamConfig.Lifetime, Cleanup)

end

local send = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Send")
local oldFire
oldFire = hookfunction(send.FireServer, function(self, ...)
local args = {...}

if ENABLED and IsHoldingAllowedGun(args) then
local target = GetClosestTarget()
if target and target.Character then
local char = target.Character
local head = char:FindFirstChild("Head")
if head then
local hardPos = head.Position

args[4] = CFrame.new(math.huge, math.huge, math.huge)
args[5] = {
[1] = {
[1] = {
Instance = head,
Position = hardPos
}
}
}

if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then      
		ShootBeam3D(target)      
	end      
end

end

end

return oldFire(self, unpack(args))

end)

local tracer = Drawing.new("Line")
tracer.Color = Color3.fromRGB(255,80,80)
tracer.Thickness = 2
tracer.Visible = false

RunService.RenderStepped:Connect(function()
-- FOV
fovCircle.Visible = ENABLED
if ENABLED then
fovCircle.Position = Vector2.new(
Camera.ViewportSize.X/2,
Camera.ViewportSize.Y/2
)
fovCircle.Radius = FOV
end

if not ENABLED then
tracer.Visible = false
return
end

local target = GetClosestTarget()
if not (target and target.Character) then
tracer.Visible = false
return
end

local head = target.Character:FindFirstChild("Head")
if not head then
tracer.Visible = false
return
end

local sp, on = Camera:WorldToViewportPoint(head.Position)
if on then
local c = Camera.ViewportSize / 2
tracer.From = Vector2.new(c.X, c.Y)
tracer.To   = Vector2.new(sp.X, sp.Y)
tracer.Visible = true
else
tracer.Visible = false
end

end)

_G.InventoryViewerEnabled = false

if not _G.ViewerRunning then
    _G.ViewerRunning = true

    local function GetColorFromRarity(rarityName)
        local colors = {
            ["Common"] = Color3.fromRGB(255, 255, 255),
            ["UnCommon"] = Color3.fromRGB(99, 255, 52),
            ["Rare"] = Color3.fromRGB(51, 170, 255),
            ["Legendary"] = Color3.fromRGB(255, 150, 0),
            ["Epic"] = Color3.fromRGB(237, 44, 255),
            ["Omega"] = Color3.fromRGB(255, 20, 51)
        }
        return colors[rarityName] or Color3.fromRGB(255, 255, 255)
    end

    task.spawn(function()
        while task.wait(0.2) do
            if _G.InventoryViewerEnabled then
                pcall(function()
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            local root = player.Character.HumanoidRootPart
                            local gui = root:FindFirstChild("ItemBillboard")
                            if not gui then
                                gui = Instance.new("BillboardGui")
                                gui.Name = "ItemBillboard"
                                gui.AlwaysOnTop = true
                                gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                                gui.Size = UDim2.fromOffset(150, 40)
                                gui.StudsOffsetWorldSpace = Vector3.new(0, -14, 0)
                                gui.ExtentsOffset = Vector3.new(0, 0, 0)
                                gui.LightInfluence = 0
                                gui.MaxDistance = math.huge
                                gui.Parent = root

                                local bg = Instance.new("Frame")
                                bg.Name = "BG"
                                bg.BackgroundTransparency = 1
                                bg.Size = UDim2.fromOffset(150, 40)
                                bg.Position = UDim2.fromOffset(0, 0)
                                bg.AnchorPoint = Vector2.new(0, 0)
                                bg.Parent = gui

                                local layout = Instance.new("UIListLayout")
                                layout.FillDirection = Enum.FillDirection.Horizontal
                                layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
                                layout.VerticalAlignment = Enum.VerticalAlignment.Center
                                layout.Padding = UDim.new(0, 4)
                                layout.Parent = bg
                            end

                            local bg = gui:FindFirstChild("BG")
                            if bg then
                                local Items = {}
                                for _, child in pairs(bg:GetChildren()) do
                                    if child:IsA("Frame") then
                                        child:Destroy()
                                    end
                                end

                                for _, container in pairs({player:FindFirstChild("Backpack"), player.Character}) do
                                    if container then
                                        for _, tool in pairs(container:GetChildren()) do
                                            if tool:IsA("Tool") and not tool:GetAttribute("JobTool") and not tool:GetAttribute("Locked") then
                                                local itemFolder = tool:GetAttribute("AmmoType") and ReplicatedStorage.Items.gun or ReplicatedStorage.Items.melee
                                                for _, z in pairs(itemFolder:GetChildren()) do
                                                    if tool:GetAttribute("RarityName") == z:GetAttribute("RarityName")
                                                        and tool:GetAttribute("RarityPrice") == z:GetAttribute("RarityPrice") then

                                                        local imageId = z:GetAttribute("ImageId")
                                                        if imageId then
                                                            Items[z.Name] = true
                                                            if not bg:FindFirstChild(z.Name .. "_bg") then

                                                                local itemContainer = Instance.new("Frame")
                                                                itemContainer.Name = z.Name .. "_bg"
                                                                itemContainer.Size = UDim2.fromOffset(20, 20)
                                                                itemContainer.BackgroundTransparency = 1
                                                                itemContainer.BorderSizePixel = 0
                                                                itemContainer.Parent = bg

                                                                local iconBg = Instance.new("Frame")
                                                                iconBg.Name = "IconBg"
                                                                iconBg.Size = UDim2.fromOffset(20, 20)
                                                                iconBg.Position = UDim2.fromOffset(0, 0)
                                                                iconBg.BackgroundColor3 = GetColorFromRarity(z:GetAttribute("RarityName"))
                                                                iconBg.BackgroundTransparency = 1
                                                                iconBg.BorderSizePixel = 0
                                                                iconBg.Parent = itemContainer

                                                                local bgImage = Instance.new("ImageLabel")
                                                                bgImage.Name = "Background"
                                                                bgImage.Size = UDim2.fromScale(1, 1)
                                                                bgImage.BackgroundTransparency = 1
                                                                bgImage.Image = "rbxassetid://137066731814190"
                                                                bgImage.ImageColor3 = GetColorFromRarity(z:GetAttribute("RarityName"))
                                                                bgImage.ZIndex = 0
                                                                bgImage.Parent = iconBg

                                                                local corner = Instance.new("UICorner")
                                                                corner.CornerRadius = UDim.new(0.15, 0)
                                                                corner.Parent = iconBg

                                                                local icon = Instance.new("ImageLabel")
                                                                icon.Name = z.Name
                                                                icon.Image = imageId
                                                                icon.BackgroundTransparency = 1
                                                                icon.BorderSizePixel = 0
                                                                icon.Size = UDim2.fromOffset(16, 16)
                                                                icon.Position = UDim2.fromOffset(2, 2)
                                                                icon.Parent = iconBg

                                                                local corner2 = Instance.new("UICorner")
                                                                corner2.CornerRadius = UDim.new(0, 5)
                                                                corner2.Parent = icon
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                                gui.Enabled = _G.InventoryViewerEnabled
                                for _, child in pairs(bg:GetChildren()) do
                                    if child:IsA("Frame") then
                                        local itemName = child.Name:gsub("_bg$", "")
                                        if not Items[itemName] then
                                            child:Destroy()
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            else
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local gui = player.Character.HumanoidRootPart:FindFirstChild("ItemBillboard")
                        if gui then
                            gui:Destroy()
                        end
                    end
                end
            end
        end
    end)
end

_G.InfiniteStamina = false

task.spawn(function()
    pcall(function()
        local SprintModule = require(game:GetService("ReplicatedStorage").Modules.Game.Sprint)
        local consume_stamina = SprintModule.consume_stamina
        local SprintBar = debug.getupvalue(consume_stamina, 2).sprint_bar
        local __InfiniteStamina = SprintBar.update

        SprintBar.update = function(...)
            if _G.InfiniteStamina then
                return __InfiniteStamina(function()
                    return 0.5
                end)
            end
            return __InfiniteStamina(...)
        end
    end)
end)

repeat task.wait() until game:IsLoaded()

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
	Title = "Neverman x'Dev",
	Author = "Kiwwy",

	Icon = "rbxassetid://72830195117719",

	Theme = "Dark",
	Size = UDim2.fromOffset(450,450),
	Acrylic = true,
	HideSearchBar = true,

	OpenButton = {
		Enabled = false
	}
})

Window:Tag({
    Title = "v1.6.6",
    Icon = "github",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 0, -- from 0 to 13
})

Window:SetBackgroundTransparency(0.25)
Window:SetBackgroundImageTransparency(0.25)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "NM_Toggle"

local ICON_ID = "rbxassetid://72830195117719"

local btn = Instance.new("ImageButton")
btn.Parent = gui
btn.Size = UDim2.fromOffset(42,42)
btn.Position = UDim2.fromOffset(40,220)
btn.BackgroundColor3 = Color3.fromRGB(20,20,20)
btn.Image = ICON_ID
btn.ScaleType = Enum.ScaleType.Fit
btn.ImageTransparency = 0
btn.AutoButtonColor = false
btn.Active = true
btn.Draggable = true

btn.AnchorPoint = Vector2.new(0.5,0.5)

local corner = Instance.new("UICorner", btn)
corner.CornerRadius = UDim.new(0,10)

local stroke = Instance.new("UIStroke", btn)
stroke.Thickness = 1
stroke.Color = Color3.fromRGB(180,180,180)

local pad = Instance.new("UIPadding", btn)
pad.PaddingTop = UDim.new(0,6)
pad.PaddingBottom = UDim.new(0,6)
pad.PaddingLeft = UDim.new(0,6)
pad.PaddingRight = UDim.new(0,6)

btn.MouseButton1Click:Connect(function()
    Window:Toggle()
end)

local MainTab = Window:Tab({
    Title = "Silent Hub",
    Icon = "target"
})

Window:SelectTab(1)

local MainSection = MainTab:Section({
    Title = "MainSection"
})

MainSection:Toggle({
    Title = "Silent Aim",
    Desc = "Automatically redirects bullets to the closest enemy",
    Default = false,
    Callback = function(v)
        ENABLED = v
    end
})

MainSection:Slider({
    Title = "FOV",
    Desc = "Radius of Silent Aim",
    Step = 1,
    Value = {
        Min = 20,
        Max = 300,
        Default = 150,
    },
    Callback = function(v)
        FOV = v
    end
})

MainSection:Toggle({
    Title = "Show Weapon ESP",
    Desc = "มองของสัตรู",
    Default = false,
    Callback = function(v)
        _G.InventoryViewerEnabled = v
    end
})

MainSection:Toggle({
    Title = "Infinite Stamina",
    Desc = "วิ่งไม่หมด",
    Default = false,
    Callback = function(v)
        _G.InfiniteStamina = v
    end
})
