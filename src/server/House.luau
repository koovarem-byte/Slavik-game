--!strict
-- Дом: шкафы (тег SlavikCloset), где можно спрятаться, и проверка «игрок внутри дома».
-- Двери теперь в модуле Doors.
--
-- Атрибуты игрока:
--   Hidden      — сидит в шкафу
--   SeenHiding  — Славик видел, как он туда залез (тогда вытащит)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MapBuilder = require(script.Parent.MapBuilder)

local House = {}

local map: MapBuilder.Map? = nil
local closetOwner: { [BasePart]: Player } = {}
local hideStarted: { [Player]: number } = {}
local hideCooldownUntil: { [Player]: number } = {}
local closetPrompts: { [BasePart]: ProximityPrompt } = {}

local function getRoot(player: Player): BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function closetOf(player: Player): BasePart?
	for closet, owner in closetOwner do
		if owner == player then
			return closet
		end
	end
	return nil
end

function House.getCloset(player: Player): BasePart?
	return closetOf(player)
end

function House.unhide(player: Player)
	local closet = closetOf(player)
	if closet then
		closetOwner[closet] = nil
		local prompt = closetPrompts[closet]
		if prompt then
			prompt.ActionText = "Спрятаться"
		end
		local root = getRoot(player)
		local char = player.Character
		if root and char then
			root.Anchored = false
			-- выходим перед шкафом (со стороны его передней грани -Z)
			local front = closet.CFrame * CFrame.new(0, 0, -(closet.Size.Z / 2 + 2))
			char:PivotTo(CFrame.new(front.Position))
		end
	end
	player:SetAttribute("Hidden", nil)
	player:SetAttribute("SeenHiding", nil)
	hideStarted[player] = nil
	hideCooldownUntil[player] = os.clock() + Config.HideCooldown
end

local function hide(player: Player, closet: BasePart)
	local root = getRoot(player)
	local char = player.Character
	if not root or not char or player:GetAttribute("Caught") == true then
		return
	end
	closetOwner[closet] = player
	hideStarted[player] = os.clock()
	player:SetAttribute("Hidden", true)
	root.Anchored = true
	char:PivotTo(closet.CFrame)
	local prompt = closetPrompts[closet]
	if prompt then
		prompt.ActionText = "Выйти"
	end
end

local function onClosetTriggered(closet: BasePart, player: Player)
	local owner = closetOwner[closet]
	if owner == player then
		House.unhide(player)
		return
	end
	if owner ~= nil or player:GetAttribute("Hidden") == true then
		return -- шкаф занят
	end
	if (hideCooldownUntil[player] or 0) > os.clock() then
		Remotes.get("Message"):FireClient(player, "Отдышись... в шкаф пока нельзя", 2)
		return
	end
	hide(player, closet)
end

function House.init(m: MapBuilder.Map)
	map = m

	for _, closet in m.Closets do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "Шкаф"
		prompt.ActionText = "Спрятаться"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = closet
		closetPrompts[closet] = prompt
		prompt.Triggered:Connect(function(player)
			onClosetTriggered(closet, player)
		end)
	end

	-- Долго в шкафу не просидишь
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, started in hideStarted do
				if now - started > Config.HideMaxTime then
					Remotes.get("Message"):FireClient(player, "Душно! Пришлось вылезти из шкафа", 2)
					House.unhide(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local closet = closetOf(player)
		if closet then
			closetOwner[closet] = nil
			local prompt = closetPrompts[closet]
			if prompt then
				prompt.ActionText = "Спрятаться"
			end
		end
		hideStarted[player] = nil
		hideCooldownUntil[player] = nil
	end)
end

-- Все вылезают из шкафов
function House.reset()
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Hidden") == true then
			House.unhide(player)
		end
		hideCooldownUntil[player] = nil
	end
end

function House.isInside(pos: Vector3): boolean
	local m = map
	return m ~= nil and MapBuilder.inside(m.HouseInterior, pos)
end

return House
