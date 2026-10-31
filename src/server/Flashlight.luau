--!strict
-- Фонарик у каждого игрока (Q). Свет создаёт сервер, поэтому его видят все.
-- Атрибут игрока FlashlightOn = true, когда включён (Славик видит такого игрока дальше).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Flashlight = {}

local lastToggle: { [Player]: number } = {}

local function getLight(player: Player): SpotLight?
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight")
	if light and light:IsA("SpotLight") then
		return light
	end
	return nil
end

local function setOn(player: Player, on: boolean)
	local light = getLight(player)
	if light then
		light.Enabled = on
	end
	player:SetAttribute("FlashlightOn", if on then true else nil)
end

local function onCharacter(player: Player, char: Model)
	local head = char:WaitForChild("Head", 5)
	if not head then
		return
	end
	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Range = Config.FlashlightRange
	light.Brightness = Config.FlashlightBrightness
	light.Angle = Config.FlashlightAngle
	light.Face = Enum.NormalId.Front
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Shadows = true
	light.Enabled = false
	light.Parent = head
	player:SetAttribute("FlashlightOn", nil)
end

function Flashlight.init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastToggle[p] = nil
	end)

	Remotes.get("Flashlight").OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if (lastToggle[player] or 0) + 0.25 > now then
			return
		end
		lastToggle[player] = now
		if Remotes.state():GetAttribute("Phase") ~= "Horror" and player:GetAttribute("FlashlightOn") ~= true then
			return -- фонарик нужен только ночью
		end
		setOn(player, player:GetAttribute("FlashlightOn") ~= true)
	end)
end

-- Выключить у всех (конец раунда)
function Flashlight.allOff()
	for _, p in Players:GetPlayers() do
		setOn(p, false)
	end
end

return Flashlight
