--!strict
-- Побег на тракторе.
--   1. Найти ключи и вставить в машину.
--   2. Найти канистру и залить солярку.
--   3. Найти аккумулятор (он разряжен), отнести в сарай, поставить на генератор,
--      завести генератор (ГРОМКО — Славик слышит), дождаться зарядки, отнести в машину.
--   4. «Завести и уехать» — кто рядом с машиной через несколько секунд, тот спасся.
--
-- Предметы можно заменить красивыми моделями: положи в ServerStorage.Items
-- деталь или модель (с PrimaryPart) с именем Keys / Fuel / Battery.
--
-- Атрибуты GameState: ObjKeys, ObjFuel, ObjBattery (true = уже в машине),
--   BatteryCharge (0..100), GeneratorRunning
-- Атрибут игрока: Carrying = "Keys" | "Fuel" | "Battery"

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MapBuilder = require(script.Parent.MapBuilder)
local Noise = require(script.Parent.Noise)

export type Callbacks = {
	onEscape: (escaped: { Player }) -> (),
}

type Item = {
	name: string,
	title: string,
	model: Instance, -- то, что лежит в мире
	handle: BasePart, -- за что берём
	prompt: ProximityPrompt,
	carrier: Player?,
	weld: WeldConstraint?,
	charged: boolean, -- только для аккумулятора
}

local ITEMS = {
	{ name = "Keys", title = "ключи", size = Vector3.new(0.8, 0.3, 1.2), color = Color3.fromRGB(220, 190, 80), material = Enum.Material.Metal },
	{ name = "Fuel", title = "канистру с соляркой", size = Vector3.new(1.4, 2, 0.9), color = Color3.fromRGB(180, 40, 30), material = Enum.Material.Metal },
	{ name = "Battery", title = "аккумулятор", size = Vector3.new(1.6, 1.2, 1), color = Color3.fromRGB(30, 30, 35), material = Enum.Material.SmoothPlastic },
}

local Objectives = {}

local map: MapBuilder.Map? = nil
local callbacks: Callbacks? = nil
local active = false
local items: { [string]: Item } = {}
local installed: { [string]: boolean } = {}
local batteryOnGenerator = false
local generatorRunning = false
local charge = 0
local escaping = false

local carPrompt: ProximityPrompt? = nil
local startPrompt: ProximityPrompt? = nil
local genPlacePrompt: ProximityPrompt? = nil
local genStartPrompt: ProximityPrompt? = nil
local genTakePrompt: ProximityPrompt? = nil
local generatorSound: Sound? = nil

local function say(player: Player?, text: string, duration: number?)
	local remote = Remotes.get("Message")
	if player then
		remote:FireClient(player, text, duration or 2.5)
	else
		remote:FireAllClients(text, duration or 3)
	end
end

local function getRoot(player: Player): BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function allParts(model: Instance): { BasePart }
	local list: { BasePart } = {}
	if model:IsA("BasePart") then
		table.insert(list, model)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function updateState()
	local state = Remotes.state()
	state:SetAttribute("ObjKeys", installed.Keys == true)
	state:SetAttribute("ObjFuel", installed.Fuel == true)
	state:SetAttribute("ObjBattery", installed.Battery == true)
	state:SetAttribute("BatteryCharge", math.floor(charge))
	state:SetAttribute("GeneratorRunning", generatorRunning)

	local allIn = installed.Keys == true and installed.Fuel == true and installed.Battery == true
	if carPrompt then
		carPrompt.Enabled = active and not allIn
	end
	if startPrompt then
		startPrompt.Enabled = active and allIn and not escaping
	end
	if genPlacePrompt then
		genPlacePrompt.Enabled = active and not batteryOnGenerator and not installed.Battery
	end
	if genStartPrompt then
		genStartPrompt.Enabled = active and batteryOnGenerator and not generatorRunning and charge < 100
	end
	if genTakePrompt then
		genTakePrompt.Enabled = active and batteryOnGenerator and not generatorRunning
	end
end

-- Положить предмет на землю в точку pos (без физики)
local function placeOnGround(item: Item, pos: Vector3)
	if item.weld then
		item.weld:Destroy()
		item.weld = nil
	end
	for _, p in allParts(item.model) do
		p.Anchored = true
		p.CanCollide = false
	end
	-- опускаем на пол под точкой
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { item.model }
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(exclude, pl.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), params)
	local ground = if hit then hit.Position else pos
	local cf = CFrame.new(ground + Vector3.new(0, item.handle.Size.Y / 2 + 0.05, 0))
	if item.model:IsA("Model") then
		item.model:PivotTo(cf)
	else
		item.handle.CFrame = cf
	end
	item.prompt.Enabled = true
end

local function drop(player: Player)
	for _, item in items do
		if item.carrier == player then
			item.carrier = nil
			local root = getRoot(player)
			placeOnGround(item, if root then root.Position else item.handle.Position)
		end
	end
	player:SetAttribute("Carrying", nil)
end

local function carriedBy(player: Player): Item?
	for _, item in items do
		if item.carrier == player then
			return item
		end
	end
	return nil
end

local function pickUp(item: Item, player: Player)
	if not active or item.carrier or player:GetAttribute("Caught") == true or player:GetAttribute("Hidden") == true then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end
	-- если в руках что-то было — кладём это сюда же (обмен)
	local current = carriedBy(player)
	if current then
		current.carrier = nil
		placeOnGround(current, item.handle.Position + Vector3.new(1.5, 0, 0))
	end
	item.carrier = player
	item.prompt.Enabled = false
	for _, p in allParts(item.model) do
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
	end
	local cf = root.CFrame * CFrame.new(1.3, -0.6, -1.3)
	if item.model:IsA("Model") then
		item.model:PivotTo(cf)
	else
		item.handle.CFrame = cf
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = item.handle
	weld.Parent = item.handle
	item.weld = weld
	player:SetAttribute("Carrying", item.name)

	if item.name == "Battery" and not item.charged then
		say(player, "Аккумулятор сел. Заряди его от генератора в сарае.", 3.5)
	else
		say(player, "Ты взял " .. item.title, 2)
	end
end

-- Предмет «использован» (вставлен в машину) — убираем из мира
local function consume(item: Item)
	if item.weld then
		item.weld:Destroy()
		item.weld = nil
	end
	local player = item.carrier
	item.carrier = nil
	if player then
		player:SetAttribute("Carrying", nil)
	end
	item.model:Destroy()
	items[item.name] = nil
end

local function makeItem(def: { name: string, title: string, size: Vector3, color: Color3, material: Enum.Material }, pos: Vector3): Item
	local model: Instance
	local handle: BasePart
	local folder = ServerStorage:FindFirstChild("Items")
	local custom = folder and folder:FindFirstChild(def.name)
	if custom and custom:IsA("BasePart") then
		local c = custom:Clone()
		model, handle = c, c
	elseif custom and custom:IsA("Model") and custom.PrimaryPart then
		local c = custom:Clone() :: Model
		model = c
		handle = c.PrimaryPart :: BasePart
	else
		local p = Instance.new("Part")
		p.Name = def.name
		p.Size = def.size
		p.Color = def.color
		p.Material = def.material
		model, handle = p, p
		-- лёгкая подсветка, чтобы предмет можно было найти в темноте
		local light = Instance.new("PointLight")
		light.Range = 6
		light.Brightness = 0.6
		light.Color = Color3.fromRGB(255, 230, 180)
		light.Parent = p
	end
	model.Name = "Item_" .. def.name

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять"
	prompt.ObjectText = def.title
	prompt.HoldDuration = Config.ItemPickupHold
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = handle

	local item: Item = {
		name = def.name,
		title = def.title,
		model = model,
		handle = handle,
		prompt = prompt,
		carrier = nil,
		weld = nil,
		charged = false,
	}
	prompt.Triggered:Connect(function(player)
		pickUp(item, player)
	end)
	model.Parent = Workspace
	placeOnGround(item, pos)
	return item
end

local function makePrompt(parent: Instance, action: string, object: string, hold: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Parent = parent
	return p
end

local function missingText(): string
	local list: { string } = {}
	if not installed.Keys then
		table.insert(list, "ключи")
	end
	if not installed.Fuel then
		table.insert(list, "солярка")
	end
	if not installed.Battery then
		table.insert(list, "заряженный аккумулятор")
	end
	return "Не хватает: " .. table.concat(list, ", ")
end

local function onCarUse(player: Player)
	local m = map
	if not active or not m then
		return
	end
	local item = carriedBy(player)
	if not item then
		say(player, missingText(), 3)
		return
	end
	if item.name == "Battery" and not item.charged then
		say(player, "Аккумулятор разряжен. Сначала заряди его на генераторе в сарае.", 3)
		return
	end
	installed[item.name] = true
	Noise.emit(m.EscapeCar.Position, Config.CarInstallNoise)
	local done = if item.name == "Keys" then "Ключи в замке"
		elseif item.name == "Fuel" then "Солярка залита"
		else "Аккумулятор на месте"
	consume(item)
	if installed.Keys and installed.Fuel and installed.Battery then
		say(nil, done .. ".\nТРАКТОР ГОТОВ! Заводи, и все к нему!", 4)
	else
		say(nil, done .. ". " .. missingText(), 3.5)
	end
	updateState()
end

local function onGeneratorPlace(player: Player)
	local m = map
	if not active or not m or batteryOnGenerator then
		return
	end
	local item = carriedBy(player)
	if not item or item.name ~= "Battery" then
		say(player, "Сюда нужен аккумулятор", 2)
		return
	end
	if item.weld then
		item.weld:Destroy()
		item.weld = nil
	end
	item.carrier = nil
	player:SetAttribute("Carrying", nil)
	for _, p in allParts(item.model) do
		p.Anchored = true
		p.CanCollide = false
	end
	local top = m.Generator.CFrame * CFrame.new(0, m.Generator.Size.Y / 2 + item.handle.Size.Y / 2, 0)
	if item.model:IsA("Model") then
		item.model:PivotTo(top)
	else
		item.handle.CFrame = top
	end
	item.prompt.Enabled = false
	batteryOnGenerator = true
	updateState()
end

local function onGeneratorStart(_player: Player)
	local m = map
	if not active or not m or not batteryOnGenerator or generatorRunning then
		return
	end
	generatorRunning = true
	say(nil, "Генератор затарахтел... Славик это слышит!", 3)
	if Config.Sounds.Generator ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = Config.Sounds.Generator
		s.Looped = true
		s.Volume = 1.5
		s.RollOffMaxDistance = 150
		s.Parent = m.Generator
		s:Play()
		generatorSound = s
	end
	updateState()
end

local function stopGenerator()
	generatorRunning = false
	if generatorSound then
		generatorSound:Destroy()
		generatorSound = nil
	end
end

local function onGeneratorTake(player: Player)
	local item = items.Battery
	if not active or not batteryOnGenerator or generatorRunning or not item then
		return
	end
	if carriedBy(player) then
		say(player, "Руки заняты", 2)
		return
	end
	batteryOnGenerator = false
	item.charged = charge >= 100
	item.prompt.Enabled = true
	pickUp(item, player)
	if item.charged then
		say(player, "Аккумулятор заряжен! Неси к трактору.", 3)
	end
	updateState()
end

local function onCarStart(player: Player)
	local m = map
	local cb = callbacks
	if not active or escaping or not m or not cb then
		return
	end
	if not (installed.Keys and installed.Fuel and installed.Battery) then
		return
	end
	escaping = true
	updateState()
	Noise.emit(m.EscapeCar.Position, Config.CarStartNoise)
	if Config.Sounds.CarStart ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = Config.Sounds.CarStart
		s.Volume = 2
		s.RollOffMaxDistance = 200
		s.Parent = m.EscapeCar
		s:Play()
	end
	task.spawn(function()
		for t = Config.EscapeCountdown, 1, -1 do
			if not active then
				return
			end
			say(nil, player.Name .. " завёл трактор! Все к трактору! " .. t, 1.1)
			Noise.emit(m.EscapeCar.Position, Config.CarStartNoise)
			task.wait(1)
		end
		if not active then
			return
		end
		local escaped: { Player } = {}
		for _, pl in Players:GetPlayers() do
			local root = getRoot(pl)
			if root and pl:GetAttribute("Caught") ~= true
				and (root.Position - m.EscapeCar.Position).Magnitude <= Config.EscapeRadius then
				table.insert(escaped, pl)
			end
		end
		if #escaped == 0 then
			escaping = false
			say(nil, "Никто не успел к трактору!", 3)
			updateState()
			return
		end
		cb.onEscape(escaped)
	end)
end

function Objectives.init(m: MapBuilder.Map)
	map = m
	local carP = makePrompt(m.EscapeCar, "Использовать", "Трактор", Config.CarInstallHold)
	carP.Triggered:Connect(onCarUse)
	carPrompt = carP
	local startP = makePrompt(m.EscapeCar, "Завести и уехать", "Трактор", Config.CarStartHold)
	startP.KeyboardKeyCode = Enum.KeyCode.F
	startP.Triggered:Connect(onCarStart)
	startPrompt = startP

	local gp = makePrompt(m.Generator, "Поставить аккумулятор", "Генератор", 0.5)
	gp.Triggered:Connect(onGeneratorPlace)
	genPlacePrompt = gp
	local gs = makePrompt(m.Generator, "Завести генератор", "Генератор", Config.GeneratorStartHold)
	gs.Triggered:Connect(onGeneratorStart)
	genStartPrompt = gs
	local gt = makePrompt(m.Generator, "Забрать аккумулятор", "Генератор", 0.5)
	gt.KeyboardKeyCode = Enum.KeyCode.R
	gt.Triggered:Connect(onGeneratorTake)
	genTakePrompt = gt

	-- Зарядка и шум генератора
	task.spawn(function()
		while true do
			task.wait(1)
			if active and generatorRunning then
				charge = math.min(100, charge + 100 / Config.GeneratorChargeTime)
				Noise.emit(m.Generator.Position, Config.GeneratorNoise)
				if charge >= 100 then
					stopGenerator()
					say(nil, "Аккумулятор заряжен! Заберите его из сарая.", 3)
				end
				updateState()
			end
		end
	end)

	Players.PlayerRemoving:Connect(drop)
	updateState()
end

-- Начало хоррора: раскладываем предметы
function Objectives.start(cb: Callbacks)
	local m = map
	if not m then
		return
	end
	Objectives.stop()
	callbacks = cb
	active = true

	local spawns = table.clone(m.ItemSpawns)
	for i = #spawns, 2, -1 do
		local j = math.random(1, i)
		spawns[i], spawns[j] = spawns[j], spawns[i]
	end
	for i, def in ITEMS do
		local spawnPart = spawns[i]
		local pos = if spawnPart then spawnPart.Position else m.EscapeCar.Position + Vector3.new(i * 4, 0, -10)
		items[def.name] = makeItem(def, pos)
	end
	updateState()
end

-- Конец раунда: всё убираем
function Objectives.stop()
	active = false
	escaping = false
	callbacks = nil
	stopGenerator()
	for _, item in items do
		item.model:Destroy()
	end
	table.clear(items)
	table.clear(installed)
	batteryOnGenerator = false
	charge = 0
	for _, pl in Players:GetPlayers() do
		pl:SetAttribute("Carrying", nil)
	end
	updateState()
end

-- Игрока поймали — он роняет то, что нёс
function Objectives.dropFor(player: Player)
	drop(player)
end

return Objectives
