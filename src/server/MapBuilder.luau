--!strict
-- Карта-заглушка («серая коробка»).
-- Если в Workspace уже есть папка "Map" (твоя настоящая локация) — ничего не строим,
-- просто находим в ней нужные объекты по именам (список имён — в README.md).

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

export type Map = {
	Folder: Instance,
	BallSpawn: BasePart,
	GoalHouse: BasePart, -- ворота у дома
	GoalFence: BasePart, -- ворота у сетки
	FenceZone: BasePart, -- зона за сеткой (там спит Славик)
	SlavikSpot: BasePart,
	SpawnHouse: BasePart, -- откуда стартует команда «Дом»
	SpawnFence: BasePart, -- откуда стартует команда «Сетка»
	HouseInterior: BasePart, -- невидимая зона «внутри дома»
	HouseLight: BasePart?,
	EscapeCar: BasePart, -- трактор (имя оставлено EscapeCar)
	Generator: BasePart, -- генератор в сарае
	Doors: { BasePart }, -- тег SlavikDoor
	Closets: { BasePart }, -- тег SlavikCloset
	ItemSpawns: { BasePart }, -- тег SlavikItemSpawn
	PatrolPoints: { BasePart }, -- тег SlavikPatrol
	Spectator: BasePart, -- куда попадают пойманные
	FieldCenter: Vector3,
	FieldHalfSize: Vector3, -- за этими границами мяч считается в ауте
}

local MapBuilder = {}

-- Теги (CollectionService). На своей карте просто повесь эти теги на нужные детали.
MapBuilder.Tags = {
	Door = "SlavikDoor",
	Closet = "SlavikCloset",
	ItemSpawn = "SlavikItemSpawn",
	Patrol = "SlavikPatrol",
}

local GRASS = Color3.fromRGB(70, 92, 52)
local DIRT = Color3.fromRGB(110, 88, 60)
local WOOD = Color3.fromRGB(105, 74, 46)
local DARK_WOOD = Color3.fromRGB(70, 50, 32)
local METAL = Color3.fromRGB(150, 150, 150)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Невидимая служебная деталь (триггер, точка)
local function marker(parent: Instance, name: string, size: Vector3, pos: Vector3): Part
	local p = part(parent, name, size, CFrame.new(pos), Color3.new(1, 0, 0))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function lamp(parent: Instance, pos: Vector3, range: number)
	part(parent, "LampPole", Vector3.new(0.6, 14, 0.6), CFrame.new(pos + Vector3.new(0, 7, 0)), DARK_WOOD, Enum.Material.Wood)
	local head = part(
		parent,
		"LampHead",
		Vector3.new(1.4, 0.8, 1.4),
		CFrame.new(pos + Vector3.new(0, 14.2, 0)),
		Color3.fromRGB(255, 214, 150),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 200, 130)
	light.Shadows = true
	light.Parent = head
end

-- Заглушка строится далеко от центра мира и чуть выше,
-- чтобы не налезать на твою сцену/террейн в Workspace
local GRAYBOX_ORIGIN = Vector3.new(3000, 60, 0)

local function build(): Instance
	local map = Instance.new("Model")
	map.Name = "Map"

	-- Земля и поле
	part(map, "Ground", Vector3.new(400, 1, 400), CFrame.new(0, -0.5, 0), GRASS, Enum.Material.Grass)
	part(map, "Field", Vector3.new(64, 0.2, 110), CFrame.new(0, 0.1, 0), DIRT, Enum.Material.Ground)

	-- Боковые бортики (низкие доски)
	for _, x in { -34, 34 } do
		part(map, "SideBoard", Vector3.new(0.5, 2.5, 118), CFrame.new(x, 1.25, 1), WOOD, Enum.Material.WoodPlanks)
	end

	-- Импровизированные ворота: ящики вместо штанг
	local function goal(name: string, z: number, triggerZ: number)
		for _, x in { -5.5, 5.5 } do
			part(map, name .. "Post", Vector3.new(2, 5, 2), CFrame.new(x, 2.5, z), WOOD, Enum.Material.WoodPlanks)
		end
		marker(map, name, Vector3.new(9, 5, 2), Vector3.new(0, 2.5, triggerZ))
	end
	goal("GoalHouse", 50, 51.5)
	goal("GoalFence", -50, -51.5)

	-- Сетка-рабица за воротами, с калиткой (дыра x 28..34)
	local fenceH = 12
	local function fenceSegment(size: Vector3, pos: Vector3)
		local f = part(map, "Fence", size, CFrame.new(pos), METAL, Enum.Material.DiamondPlate)
		f.Transparency = 0.45
	end
	fenceSegment(Vector3.new(68, fenceH, 0.3), Vector3.new(-6, fenceH / 2, -58)) -- x -40..28
	fenceSegment(Vector3.new(6, fenceH, 0.3), Vector3.new(37, fenceH / 2, -58)) -- x 34..40
	fenceSegment(Vector3.new(0.3, fenceH, 37), Vector3.new(-40, fenceH / 2, -76.5))
	fenceSegment(Vector3.new(0.3, fenceH, 37), Vector3.new(40, fenceH / 2, -76.5))
	fenceSegment(Vector3.new(80, fenceH, 0.3), Vector3.new(0, fenceH / 2, -95))
	for x = -40, 40, 10 do
		-- в проёме калитки (x 28..34) столба нет, иначе Славик не пролезет
		if x < 28 or x > 34 then
			part(map, "FencePole", Vector3.new(0.5, fenceH + 0.5, 0.5), CFrame.new(x, (fenceH + 0.5) / 2, -58), DARK_WOOD)
		end
	end
	marker(map, "FenceZone", Vector3.new(80, 40, 36.5), Vector3.new(0, 20, -76.75))

	-- Лежбище Славика: матрас и коробки
	part(map, "Mattress", Vector3.new(4, 0.6, 7), CFrame.new(0, 0.3, -75), Color3.fromRGB(120, 110, 80), Enum.Material.Fabric)
	part(map, "Box", Vector3.new(3, 2.5, 3), CFrame.new(5, 1.25, -78) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(150, 120, 80), Enum.Material.Cardboard)
	part(map, "Box", Vector3.new(2, 2, 2), CFrame.new(-4.5, 1, -72) * CFrame.Angles(0, -0.3, 0), Color3.fromRGB(150, 120, 80), Enum.Material.Cardboard)
	marker(map, "SlavikSpot", Vector3.new(1, 1, 1), Vector3.new(0, 0, -75))

	-- ===== Дом (x -15..15, z 62..86): две половины, передняя и задняя дверь =====
	local house = Instance.new("Folder")
	house.Name = "House"
	house.Parent = map
	local wallH = 12
	local function wall(size: Vector3, pos: Vector3)
		part(house, "Wall", size, CFrame.new(pos), Color3.fromRGB(140, 110, 80), Enum.Material.WoodPlanks)
	end
	-- Передняя стена (к полю) с проёмом x -2.5..2.5, высота 8
	wall(Vector3.new(12.5, wallH, 1), Vector3.new(-8.75, wallH / 2, 62))
	wall(Vector3.new(12.5, wallH, 1), Vector3.new(8.75, wallH / 2, 62))
	wall(Vector3.new(5, 4, 1), Vector3.new(0, 10, 62))
	-- Задняя стена с задней дверью x -7..-3
	wall(Vector3.new(8, wallH, 1), Vector3.new(-11, wallH / 2, 86))
	wall(Vector3.new(18, wallH, 1), Vector3.new(6, wallH / 2, 86))
	wall(Vector3.new(4, 4, 1), Vector3.new(-5, 10, 86))
	-- Перегородка между половинами (z = 78) с проёмом x -2..2
	wall(Vector3.new(12.5, wallH, 0.6), Vector3.new(-8.25, wallH / 2, 78))
	wall(Vector3.new(12.5, wallH, 0.6), Vector3.new(8.25, wallH / 2, 78))
	wall(Vector3.new(4, 4, 0.6), Vector3.new(0, 10, 78))
	-- Боковые стены с окном (z 72..76, y 4..8)
	for _, x in { -15, 15 } do
		wall(Vector3.new(1, 4, 24), Vector3.new(x, 2, 74))
		wall(Vector3.new(1, 4, 24), Vector3.new(x, 10, 74))
		wall(Vector3.new(1, 4, 10), Vector3.new(x, 6, 67))
		wall(Vector3.new(1, 4, 10), Vector3.new(x, 6, 81))
		local glass = part(house, "Window", Vector3.new(0.3, 4, 4), CFrame.new(x, 6, 74), Color3.fromRGB(180, 200, 210), Enum.Material.Glass)
		glass.Transparency = 0.6
	end
	part(house, "Floor", Vector3.new(30, 0.4, 24), CFrame.new(0, 0.2, 74), DARK_WOOD, Enum.Material.WoodPlanks)
	part(house, "Roof", Vector3.new(32, 1, 26), CFrame.new(0, 12.5, 74), Color3.fromRGB(80, 60, 50), Enum.Material.Slate)

	-- Мебель
	part(house, "Bed", Vector3.new(5, 2, 8), CFrame.new(-10, 1.2, 70), Color3.fromRGB(150, 140, 120), Enum.Material.Fabric)
	part(house, "Table", Vector3.new(5, 3, 3), CFrame.new(8, 1.7, 68), WOOD, Enum.Material.Wood)

	-- Шкафы, где можно спрятаться (в задней половине)
	for i, x in { -11.5, 11.5 } do
		local c = part(house, "Closet" .. i, Vector3.new(4, 7, 3), CFrame.new(x, 3.9, 83.5), DARK_WOOD, Enum.Material.Wood)
		CollectionService:AddTag(c, MapBuilder.Tags.Closet)
	end

	-- Лампочки (первая мигает)
	for i, z in { 70, 82 } do
		local bulb = part(house, if i == 1 then "HouseLight" else "HouseLight2", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 11.3, z), Color3.fromRGB(255, 220, 160), Enum.Material.Neon)
		local bulbLight = Instance.new("PointLight")
		bulbLight.Range = 20
		bulbLight.Brightness = 1.3
		bulbLight.Color = Color3.fromRGB(255, 210, 150)
		bulbLight.Shadows = true
		bulbLight.Parent = bulb
	end
	marker(house, "HouseInterior", Vector3.new(29, 11, 23), Vector3.new(0, 6, 74))

	-- Двери. Петля — левый край двери (локальная -X). OpenAngle — куда открывается.
	local function door(parent: Instance, name: string, size: Vector3, cf: CFrame, maxHP: number)
		local d = part(parent, name, size, cf, Color3.fromRGB(90, 60, 40), Enum.Material.WoodPlanks)
		d:SetAttribute("OpenAngle", -90)
		d:SetAttribute("MaxHP", maxHP)
		CollectionService:AddTag(d, MapBuilder.Tags.Door)
	end
	door(house, "FrontDoor", Vector3.new(5, 8, 0.5), CFrame.new(0, 4.2, 62), 100)
	door(house, "InnerDoor", Vector3.new(4, 8, 0.4), CFrame.new(0, 4.2, 78), 50)
	door(house, "BackDoor", Vector3.new(4, 8, 0.5), CFrame.new(-5, 4.2, 86), 100)

	-- ===== Сарай (x 28..40, z 66..80) с генератором и дровами =====
	local shed = Instance.new("Folder")
	shed.Name = "Shed"
	shed.Parent = map
	local shedColor = Color3.fromRGB(95, 75, 55)
	local function shedWall(size: Vector3, pos: Vector3)
		part(shed, "ShedWall", size, CFrame.new(pos), shedColor, Enum.Material.WoodPlanks)
	end
	shedWall(Vector3.new(1, 9, 5), Vector3.new(28, 4.5, 68.5))
	shedWall(Vector3.new(1, 9, 5), Vector3.new(28, 4.5, 77.5))
	shedWall(Vector3.new(1, 1, 4), Vector3.new(28, 8.5, 73))
	shedWall(Vector3.new(1, 9, 14), Vector3.new(40, 4.5, 73))
	shedWall(Vector3.new(12, 9, 1), Vector3.new(34, 4.5, 66))
	shedWall(Vector3.new(12, 9, 1), Vector3.new(34, 4.5, 80))
	part(shed, "ShedRoof", Vector3.new(13, 0.6, 15), CFrame.new(34, 9.3, 73), Color3.fromRGB(70, 60, 50), Enum.Material.CorrodedMetal)
	door(shed, "ShedDoor", Vector3.new(4, 8, 0.4), CFrame.new(28, 4.2, 73) * CFrame.Angles(0, math.rad(90), 0), 50)
	part(shed, "Generator", Vector3.new(3, 3, 2), CFrame.new(37, 1.5, 70), Color3.fromRGB(160, 50, 40), Enum.Material.Metal)
	part(shed, "Firewood", Vector3.new(8, 4, 2), CFrame.new(34, 2, 78), Color3.fromRGB(120, 85, 50), Enum.Material.Wood)

	-- ===== Транспорт для побега (в заглушке — коробка) =====
	local car = Instance.new("Folder")
	car.Name = "Car"
	car.Parent = map
	part(car, "EscapeCar", Vector3.new(6, 3.5, 11), CFrame.new(-35, 2.3, 96), Color3.fromRGB(70, 90, 60), Enum.Material.Metal)
	part(car, "CarCabin", Vector3.new(5.6, 2.5, 6), CFrame.new(-35, 5.3, 97), Color3.fromRGB(60, 80, 55), Enum.Material.Metal)
	for _, off in { Vector3.new(-3, 0, -3.5), Vector3.new(3, 0, -3.5), Vector3.new(-3, 0, 3.5), Vector3.new(3, 0, 3.5) } do
		part(car, "Wheel", Vector3.new(1, 2.2, 2.2), CFrame.new(Vector3.new(-35, 1.1, 96) + off), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber)
	end

	-- ===== Где могут лежать предметы (каждый раунд случайно) =====
	for i, pos in {
		Vector3.new(-10, 2.6, 70), -- на кровати
		Vector3.new(8, 3.6, 68), -- на столе
		Vector3.new(12, 1, 64), -- угол у входа
		Vector3.new(0, 1, 82), -- задняя половина
		Vector3.new(31, 1, 68), -- сарай
		Vector3.new(34, 4.6, 78), -- на дровах
		Vector3.new(-25, 1, 40), -- двор
		Vector3.new(25, 1, -10), -- край поля
		Vector3.new(15, 1, -85), -- за сеткой, у лежбища Славика
	} do
		local m = marker(map, "ItemSpawn" .. i, Vector3.new(1, 1, 1), pos)
		CollectionService:AddTag(m, MapBuilder.Tags.ItemSpawn)
	end

	-- Точки, вокруг которых бродит Славик
	for i, pos in {
		Vector3.new(-20, 0, 74),
		Vector3.new(20, 0, 74),
		Vector3.new(0, 0, 92),
		Vector3.new(-8, 0, 57),
		Vector3.new(8, 0, 57),
		Vector3.new(24, 0, 73),
		Vector3.new(-28, 0, 90),
		Vector3.new(0, 0, 0),
		Vector3.new(31, 0, -50),
	} do
		local m = marker(map, "Patrol" .. i, Vector3.new(1, 1, 1), pos)
		CollectionService:AddTag(m, MapBuilder.Tags.Patrol)
	end

	-- Фонари (один на всю улицу + у дома)
	lamp(map, Vector3.new(32, 0, -20), 45)
	lamp(map, Vector3.new(-20, 0, 58), 30)

	-- Старт и спавны
	marker(map, "BallSpawn", Vector3.new(1, 1, 1), Vector3.new(0, 2, 0))
	marker(map, "SpawnHouse", Vector3.new(1, 1, 1), Vector3.new(0, 3, 35))
	marker(map, "SpawnFence", Vector3.new(1, 1, 1), Vector3.new(0, 3, -35))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(24, 0.5, 40)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = map

	-- Комната для пойманных (высоко над картой, со стеклянным полом)
	local spec = part(map, "Spectator", Vector3.new(30, 1, 30), CFrame.new(0, 150, 0), Color3.fromRGB(200, 220, 255), Enum.Material.Glass)
	spec.Transparency = 0.7
	for _, info in {
		{ Vector3.new(30, 8, 1), Vector3.new(0, 154, 15) },
		{ Vector3.new(30, 8, 1), Vector3.new(0, 154, -15) },
		{ Vector3.new(1, 8, 30), Vector3.new(15, 154, 0) },
		{ Vector3.new(1, 8, 30), Vector3.new(-15, 154, 0) },
	} do
		local w = part(map, "SpectatorWall", info[1], CFrame.new(info[2]), Color3.new(1, 1, 1), Enum.Material.Glass)
		w.Transparency = 0.85
	end

	-- Строили вокруг (0,0,0), теперь переносим всё целиком в GRAYBOX_ORIGIN
	map.WorldPivot = CFrame.new()
	map:PivotTo(CFrame.new(GRAYBOX_ORIGIN))
	map.Parent = Workspace
	return map
end

local function find(folder: Instance, name: string): BasePart
	local obj = folder:FindFirstChild(name, true)
	assert(obj and obj:IsA("BasePart"), "[MapBuilder] В папке Map не найдена деталь: " .. name)
	return obj :: BasePart
end

-- Все детали с тегом + (для совместимости) детали из папки с таким именем
local function collect(folder: Instance, tag: string, folderName: string): { BasePart }
	local result: { BasePart } = {}
	local seen: { [Instance]: boolean } = {}
	for _, obj in CollectionService:GetTagged(tag) do
		if obj:IsA("BasePart") and obj:IsDescendantOf(Workspace) and not seen[obj] then
			seen[obj] = true
			table.insert(result, obj)
		end
	end
	local holder = folder:FindFirstChild(folderName, true)
	if holder then
		for _, c in holder:GetChildren() do
			if c:IsA("BasePart") and not seen[c] then
				seen[c] = true
				table.insert(result, c)
			end
		end
	end
	return result
end

function MapBuilder.load(): Map
	local folder = Workspace:FindFirstChild("Map")
	if not folder then
		folder = build()
		print("[MapBuilder] Построена карта-заглушка")
	else
		print("[MapBuilder] Используется готовая карта Workspace.Map")
	end
	assert(folder)

	local light = folder:FindFirstChild("HouseLight", true)

	local map: Map = {
		Folder = folder,
		BallSpawn = find(folder, "BallSpawn"),
		GoalHouse = find(folder, "GoalHouse"),
		GoalFence = find(folder, "GoalFence"),
		FenceZone = find(folder, "FenceZone"),
		SlavikSpot = find(folder, "SlavikSpot"),
		SpawnHouse = find(folder, "SpawnHouse"),
		SpawnFence = find(folder, "SpawnFence"),
		HouseInterior = find(folder, "HouseInterior"),
		HouseLight = if light and light:IsA("BasePart") then light else nil,
		EscapeCar = find(folder, "EscapeCar"),
		Generator = find(folder, "Generator"),
		Doors = collect(folder, MapBuilder.Tags.Door, "Doors"),
		Closets = collect(folder, MapBuilder.Tags.Closet, "Closets"),
		ItemSpawns = collect(folder, MapBuilder.Tags.ItemSpawn, "ItemSpawns"),
		PatrolPoints = collect(folder, MapBuilder.Tags.Patrol, "PatrolPoints"),
		Spectator = find(folder, "Spectator"),
		FieldCenter = find(folder, "BallSpawn").Position,
		FieldHalfSize = Vector3.new(35, 0, 98),
	}
	if #map.ItemSpawns < 3 then
		warn("[MapBuilder] Мало точек для предметов (тег SlavikItemSpawn): нужно минимум 3, есть " .. #map.ItemSpawns)
	end
	print(string.format("[MapBuilder] Дверей: %d, шкафов: %d, точек предметов: %d, точек патруля: %d",
		#map.Doors, #map.Closets, #map.ItemSpawns, #map.PatrolPoints))
	return map
end

-- Точка внутри детали? (для ворот, зоны за сеткой, дома)
function MapBuilder.inside(p: BasePart, pos: Vector3): boolean
	local rel = p.CFrame:PointToObjectSpace(pos)
	local h = p.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
end

return MapBuilder
