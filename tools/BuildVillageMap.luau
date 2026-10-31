-- Строитель локации «Деревня» для «Не разбуди Славика».
-- Запуск: в Roblox Studio, режим редактирования (Command Bar или через MCP execute_luau).
-- Строит Workspace.Map (имена и теги — по README «Своя локация») и террейн вокруг.
-- Меш-модели берутся из ServerStorage._MapAssetsStaging (берёзы, трактор МТЗ, кот, яблоня, бочки — бесплатные
-- из Creator Store, скрипты из них удалены). Референсы: docs/concept.png и docs/refs/*.jpg.
-- Если их нет — вместо них ставятся простые заглушки из деталей.
-- Повторный запуск удаляет старый Workspace.Map и строит заново.

local CS = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local O = Vector3.new(3000, 0, 0) -- центр поля (в стороне от остальной сцены)
local ASSETS = game:GetService("ServerStorage"):FindFirstChild("_MapAssetsStaging")
local rng = Random.new(1976)

-- ===== Цвета и материалы =====
local OLD_WOOD = Color3.fromRGB(92, 74, 58) -- потемневшие доски
local GREY_WOOD = Color3.fromRGB(118, 112, 100) -- выцветшие доски (левая половина)
local DARK_WOOD = Color3.fromRGB(58, 44, 33)
local BLUE_DOOR = Color3.fromRGB(88, 132, 140)
local BROWN_DOOR = Color3.fromRGB(96, 64, 40)
local WHITE_PAINT = Color3.fromRGB(196, 196, 186)
local ROOF = Color3.fromRGB(74, 78, 60) -- старый шифер во мху
local GREEN_SIDING = Color3.fromRGB(150, 178, 156) -- светло-зелёная обшивка левой половины (house_front.jpg)
local GLASS = Color3.fromRGB(150, 170, 175)
local LEAF = Color3.fromRGB(44, 62, 34)
local WARM = Color3.fromRGB(255, 196, 120)

local old = workspace:FindFirstChild("Map")
if old then
	old:Destroy()
end

local map = Instance.new("Model")
map.Name = "Map"
map.WorldPivot = CFrame.new(O)

local function folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or map
	return f
end

-- Деталь в локальных координатах карты (0,0,0 = центр поля на земле)
local function P(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = CFrame.new(O) * cf
	p.Color = color
	p.Material = material or Enum.Material.WoodPlanks
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function W(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(O) * cf
	p.Color = color
	p.Material = material or Enum.Material.WoodPlanks
	p.Anchored = true
	p.Parent = parent
	return p
end

-- Невидимая служебная деталь
local function marker(parent: Instance, name: string, size: Vector3, pos: Vector3, tag: string?): Part
	local p = P(parent, name, size, CFrame.new(pos), Color3.new(1, 0, 0), Enum.Material.SmoothPlastic)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if tag then
		CS:AddTag(p, tag)
	end
	return p
end

local function bulb(parent: Instance, name: string, pos: Vector3, range: number, brightness: number)
	local b = P(parent, name, Vector3.new(0.6, 0.8, 0.6), CFrame.new(pos), Color3.fromRGB(255, 220, 160), Enum.Material.Neon, Enum.PartType.Ball)
	b.CanCollide = false
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = WARM
	l.Shadows = true
	l.Parent = b
	-- провод
	P(parent, name .. "Cord", Vector3.new(0.08, 1.2, 0.08), CFrame.new(pos + Vector3.new(0, 1, 0)), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic).CanCollide = false
	return b
end

-- Стена вдоль X (от x0 до x1) на линии z, с проёмами {xc, w, yb, yt}
local function wallX(parent: Instance, x0: number, x1: number, z: number, h: number, t: number, holes: { { number } }, color: Color3, mat: Enum.Material?)
	table.sort(holes, function(a, b)
		return a[1] < b[1]
	end)
	local cur = x0
	local function seg(a: number, b: number, yb: number, yt: number)
		if b - a > 0.05 and yt - yb > 0.05 then
			P(parent, "Wall", Vector3.new(b - a, yt - yb, t), CFrame.new((a + b) / 2, (yb + yt) / 2, z), color, mat)
		end
	end
	for _, hole in holes do
		local xc, w, yb, yt = hole[1], hole[2], hole[3], hole[4]
		seg(cur, xc - w / 2, 0, h)
		seg(xc - w / 2, xc + w / 2, 0, yb)
		seg(xc - w / 2, xc + w / 2, yt, h)
		cur = xc + w / 2
	end
	seg(cur, x1, 0, h)
end

-- Стена вдоль Z (от z0 до z1) на линии x, с проёмами {zc, w, yb, yt}
local function wallZ(parent: Instance, z0: number, z1: number, x: number, h: number, t: number, holes: { { number } }, color: Color3, mat: Enum.Material?)
	table.sort(holes, function(a, b)
		return a[1] < b[1]
	end)
	local cur = z0
	local function seg(a: number, b: number, yb: number, yt: number)
		if b - a > 0.05 and yt - yb > 0.05 then
			P(parent, "Wall", Vector3.new(t, yt - yb, b - a), CFrame.new(x, (yb + yt) / 2, (a + b) / 2), color, mat)
		end
	end
	for _, hole in holes do
		local zc, w, yb, yt = hole[1], hole[2], hole[3], hole[4]
		seg(cur, zc - w / 2, 0, h)
		seg(zc - w / 2, zc + w / 2, 0, yb)
		seg(zc - w / 2, zc + w / 2, yt, h)
		cur = zc + w / 2
	end
	seg(cur, z1, 0, h)
end

-- Окно в стене вдоль X: рама + стекло (+ крестовина). broken = разбитое
local function windowX(parent: Instance, xc: number, z: number, yb: number, yt: number, w: number, frameColor: Color3, broken: boolean?)
	local h = yt - yb
	local yc = (yb + yt) / 2
	for _, dx in { -w / 2, w / 2 } do
		P(parent, "WindowFrame", Vector3.new(0.3, h + 0.3, 1.0), CFrame.new(xc + dx, yc, z), frameColor)
	end
	P(parent, "WindowFrame", Vector3.new(w + 0.6, 0.3, 1.0), CFrame.new(xc, yt, z), frameColor)
	P(parent, "WindowSill", Vector3.new(w + 1, 0.25, 1.4), CFrame.new(xc, yb, z), frameColor)
	P(parent, "WindowCross", Vector3.new(0.2, h, 0.3), CFrame.new(xc, yc, z), frameColor)
	P(parent, "WindowCross", Vector3.new(w, 0.2, 0.3), CFrame.new(xc, yc + h * 0.15, z), frameColor)
	if broken then
		-- осколки по краям, в середине дыра
		local g1 = W(parent, "GlassShard", Vector3.new(0.1, h * 0.6, w * 0.35), CFrame.new(xc - w * 0.3, yb + h * 0.3, z) * CFrame.Angles(0, math.rad(90), 0), GLASS, Enum.Material.Glass)
		g1.Transparency = 0.5
		local g2 = W(parent, "GlassShard", Vector3.new(0.1, h * 0.35, w * 0.3), CFrame.new(xc + w * 0.3, yt - h * 0.2, z) * CFrame.Angles(math.rad(180), math.rad(-90), 0), GLASS, Enum.Material.Glass)
		g2.Transparency = 0.5
	else
		local g = P(parent, "Glass", Vector3.new(w, h, 0.1), CFrame.new(xc, yc, z), GLASS, Enum.Material.Glass)
		g.Transparency = 0.55
	end
end

local function windowZ(parent: Instance, zc: number, x: number, yb: number, yt: number, w: number, frameColor: Color3)
	local h = yt - yb
	local yc = (yb + yt) / 2
	for _, dz in { -w / 2, w / 2 } do
		P(parent, "WindowFrame", Vector3.new(1.0, h + 0.3, 0.3), CFrame.new(x, yc, zc + dz), frameColor)
	end
	P(parent, "WindowFrame", Vector3.new(1.0, 0.3, w + 0.6), CFrame.new(x, yt, zc), frameColor)
	P(parent, "WindowSill", Vector3.new(1.4, 0.25, w + 1), CFrame.new(x, yb, zc), frameColor)
	P(parent, "WindowCross", Vector3.new(0.3, h, 0.2), CFrame.new(x, yc, zc), frameColor)
	local g = P(parent, "Glass", Vector3.new(0.1, h, w), CFrame.new(x, yc, zc), GLASS, Enum.Material.Glass)
	g.Transparency = 0.55
end

-- Дверь с тегом SlavikDoor (петля — левый край, открывается в локальную +Z)
local function door(parent: Instance, name: string, cf: CFrame, color: Color3, maxHP: number)
	local d = P(parent, name, Vector3.new(4.9, 7.9, 0.35), cf, color, Enum.Material.WoodPlanks)
	d:SetAttribute("OpenAngle", -90)
	d:SetAttribute("MaxHP", maxHP)
	CS:AddTag(d, "SlavikDoor")
	return d
end

-- Габариты модели в мировых осях (GetBoundingBox меряет в осях самой модели)
local function worldBox(m: Instance): (Vector3, Vector3)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local c = d.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
						mn = mn:Min(c)
						mx = mx:Max(c)
					end
				end
			end
		end
	end
	return mn, mx
end

-- Повернуть модель вокруг мировой точки
local function rotateAround(m: Model, center: Vector3, rot: CFrame)
	m:PivotTo(CFrame.new(center) * rot * CFrame.new(-center) * m:GetPivot())
end

-- Поставить модель низом на землю в точку pos (по мировым габаритам)
local function settle(m: Model, pos: Vector3)
	local mn, mx = worldBox(m)
	local c = (mn + mx) / 2
	m:PivotTo(m:GetPivot() + (O + pos - Vector3.new(c.X, mn.Y, c.Z)))
end

-- Модель из ServerStorage._MapAssetsStaging: клон, встать «на ноги», низом на землю, в точку
local function placeAsset(assetName: string, parent: Instance, pos: Vector3, yaw: number, scale: number?): Model?
	local src = ASSETS and ASSETS:FindFirstChild(assetName)
	if not src then
		return nil
	end
	local m = src:Clone() :: Model
	if not m:IsA("Model") then
		return nil
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy() -- никаких чужих скриптов на карте
		end
	end
	if scale and scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	local mn, mx = worldBox(m)
	rotateAround(m, (mn + mx) / 2, CFrame.Angles(0, math.rad(yaw), 0))
	settle(m, pos)
	m.Parent = parent
	return m
end

-- ===================================================================
-- 1) ТЕРРЕЙН
-- ===================================================================
local T = workspace.Terrain
pcall(function()
	T:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(62, 78, 44))
	T:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(52, 70, 38))
	T:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(88, 74, 58))
	T:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(66, 54, 42))
end)
local function fill(center: Vector3, size: Vector3, mat: Enum.Material)
	T:FillBlock(CFrame.new(O + center), size, mat)
end
-- Террейн округляет по сетке 4 стада: чтобы поверхность была ровно на y = 0,
-- верх заливки ставим на y = -2 (половина воксела -4..0 заполнена).
-- Сначала очищаем всё выше y = -4 (на случай повторного запуска).
fill(Vector3.new(3, 26, 3), Vector3.new(470, 60, 470), Enum.Material.Air)
fill(Vector3.new(3, -8, 3), Vector3.new(460, 12, 460), Enum.Material.Grass)
task.wait()
-- поле: вытоптанная земля
fill(Vector3.new(0, -3, 0), Vector3.new(62, 2, 106), Enum.Material.Ground)
-- тропинки к дому, сараю и машине
fill(Vector3.new(-13, -3, 59), Vector3.new(5, 2, 12), Enum.Material.Mud)
fill(Vector3.new(10, -3, 59), Vector3.new(5, 2, 12), Enum.Material.Mud)
fill(Vector3.new(30, -3, 62), Vector3.new(30, 2, 5), Enum.Material.Mud)
fill(Vector3.new(-18, -3, 90), Vector3.new(6, 2, 18), Enum.Material.Mud)
-- заросли у левой половины дома и вдоль заборов
fill(Vector3.new(-20, -3, 58), Vector3.new(16, 2, 6), Enum.Material.LeafyGrass)
fill(Vector3.new(-40, -3, 70), Vector3.new(20, 2, 40), Enum.Material.LeafyGrass)
fill(Vector3.new(0, -3, -78), Vector3.new(76, 2, 32), Enum.Material.LeafyGrass)
fill(Vector3.new(-15, -3, 96), Vector3.new(74, 2, 19), Enum.Material.LeafyGrass) -- огород
fill(Vector3.new(67, -3, 10), Vector3.new(9, 2, 250), Enum.Material.Mud) -- дорога за правым забором
fill(Vector3.new(52, -3, 92), Vector3.new(16, 2, 18), Enum.Material.Mud) -- у ворот и трактора
fill(Vector3.new(0, -3, 125), Vector3.new(110, 2, 30), Enum.Material.LeafyGrass) -- соседская сторона
-- холмы за забором (лес вдали)
for i = 1, 14 do
	local a = (i / 14) * math.pi * 2
	local r = rng:NextNumber(150, 190)
	if math.sin(a) < 0.35 then -- на соседской стороне (за огородом) холмов нет
		T:FillBall(O + Vector3.new(math.cos(a) * r, -18, math.sin(a) * r), rng:NextNumber(30, 45), Enum.Material.Grass)
	end
end
pcall(function()
	T.Decoration = true -- шевелящаяся трава
end)
task.wait()

-- ===================================================================
-- 2) ПОЛЕ: ворота из ящиков, сетка-рабица, лежбище Славика
-- ===================================================================
local field = folder("Field")
local function crate(pos: Vector3, rot: number)
	local c = P(field, "Crate", Vector3.new(2.2, 2.2, 2.2), CFrame.new(pos) * CFrame.Angles(0, math.rad(rot), 0), Color3.fromRGB(128, 98, 62), Enum.Material.WoodPlanks)
	return c
end
for _, z in { 50, -50 } do
	for _, x in { -5.5, 5.5 } do
		crate(Vector3.new(x, 1.1, z), rng:NextNumber(-8, 8))
		crate(Vector3.new(x + rng:NextNumber(-0.2, 0.2), 3.3, z), rng:NextNumber(-15, 15))
	end
end
marker(field, "GoalHouse", Vector3.new(9, 5, 2), Vector3.new(0, 2.5, 51.5))
marker(field, "GoalFence", Vector3.new(9, 5, 2), Vector3.new(0, 2.5, -51.5))
marker(field, "BallSpawn", Vector3.new(1, 1, 1), Vector3.new(0, 2, 0))
marker(field, "SpawnHouse", Vector3.new(1, 1, 1), Vector3.new(0, 3, 35))
marker(field, "SpawnFence", Vector3.new(1, 1, 1), Vector3.new(0, 3, -35))
-- старые покрышки по углам поля
for _, pos in { Vector3.new(-31, 0.45, 53), Vector3.new(31, 0.45, -53), Vector3.new(-31, 0.45, -53) } do
	local tire = P(field, "Tire", Vector3.new(0.9, 2.6, 2.6), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(28, 28, 28), Enum.Material.Rubber, Enum.PartType.Cylinder)
	tire.CanCollide = false
end

-- Сетка-рабица: z = -58 (калитка x 28..34), бока x = ±40, зад z = -95
local chain = folder("ChainLinkFence")
local FENCE_H = 8
local function chainPanel(size: Vector3, pos: Vector3)
	local p = P(chain, "ChainLink", size, CFrame.new(pos), Color3.fromRGB(120, 110, 100), Enum.Material.Metal)
	p.Transparency = 1
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local t = Instance.new("Texture")
		t.Texture = "rbxassetid://22215675"
		t.StudsPerTileU = 4
		t.StudsPerTileV = 4
		t.Face = face
		t.Parent = p
	end
end
local function pipe(pos: Vector3, h: number)
	P(chain, "FencePost", Vector3.new(h, 0.4, 0.4), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 84, 78), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
end
chainPanel(Vector3.new(68, FENCE_H, 0.2), Vector3.new(-6, FENCE_H / 2, -58))
chainPanel(Vector3.new(6, FENCE_H, 0.2), Vector3.new(37, FENCE_H / 2, -58))
chainPanel(Vector3.new(0.2, FENCE_H, 37), Vector3.new(-40, FENCE_H / 2, -76.5))
chainPanel(Vector3.new(0.2, FENCE_H, 37), Vector3.new(40, FENCE_H / 2, -76.5))
chainPanel(Vector3.new(80, FENCE_H, 0.2), Vector3.new(0, FENCE_H / 2, -95))
for x = -40, 40, 6 do
	if x < 27 or x > 35 then
		pipe(Vector3.new(x, 0, -58), FENCE_H + 0.3)
		pipe(Vector3.new(x, 0, -95), FENCE_H + 0.3)
	end
end
for z = -64, -94, -6 do
	pipe(Vector3.new(-40, 0, z), FENCE_H + 0.3)
	pipe(Vector3.new(40, 0, z), FENCE_H + 0.3)
end
pipe(Vector3.new(28, 0, -58), FENCE_H + 0.3)
pipe(Vector3.new(34, 0, -58), FENCE_H + 0.3)
-- приоткрытая калитка (стоит вдоль бока, не мешает пройти)
local gate = P(chain, "GateLeaf", Vector3.new(0.2, FENCE_H - 1, 5.5), CFrame.new(27.6, (FENCE_H - 1) / 2 + 0.3, -61) * CFrame.Angles(0, math.rad(-20), 0), Color3.fromRGB(120, 110, 100), Enum.Material.Metal)
gate.Transparency = 1
for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
	local t = Instance.new("Texture")
	t.Texture = "rbxassetid://22215675"
	t.StudsPerTileU = 4
	t.StudsPerTileV = 4
	t.Face = face
	t.Parent = gate
end
marker(chain, "FenceZone", Vector3.new(80, 40, 36.5), Vector3.new(0, 20, -76.75))

-- Лежбище Славика
local den = folder("SlavikDen")
P(den, "Mattress", Vector3.new(4.2, 0.6, 7), CFrame.new(0, 0.3, -75) * CFrame.Angles(0, math.rad(8), 0), Color3.fromRGB(112, 100, 76), Enum.Material.Fabric)
P(den, "Blanket", Vector3.new(3.6, 0.15, 3.2), CFrame.new(0.3, 0.68, -76.5) * CFrame.Angles(0, math.rad(14), math.rad(2)), Color3.fromRGB(70, 58, 52), Enum.Material.Fabric)
P(den, "Box", Vector3.new(3, 2.5, 3), CFrame.new(5, 1.25, -78) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(140, 112, 76), Enum.Material.Cardboard)
P(den, "Box", Vector3.new(2, 2, 2), CFrame.new(-4.5, 1, -72) * CFrame.Angles(0, -0.3, 0), Color3.fromRGB(140, 112, 76), Enum.Material.Cardboard)
P(den, "Bottle", Vector3.new(1, 0.35, 0.35), CFrame.new(-2.6, 0.18, -79) * CFrame.Angles(0, 0.7, 0), Color3.fromRGB(40, 70, 40), Enum.Material.Glass, Enum.PartType.Cylinder)
marker(den, "SlavikSpot", Vector3.new(1, 1, 1), Vector3.new(0, 0, -75))
task.wait()

-- ===================================================================
-- 3) ДОМ на две семьи: x -26..26, z 64..80. Левая половина — голубая дверь, заросли.
--    Правая — коричневая дверь, фонарь, разбитое окно. Перегородка x = 0 с дверью.
-- ===================================================================
local house = folder("House")
local WALL_H, T_W = 10, 0.8
local DOOR = { 0, 8.2 } -- низ/верх дверного проёма (без порога — Славик не умеет прыгать)
local WIN = { 3.4, 7.4 }
-- передняя стена: левая половина (выцветшая), правая (тёмная)
wallX(house, -26, 0, 64, WALL_H, T_W, {
	{ -21, 4, WIN[1], WIN[2] },
	{ -13, 5, DOOR[1], DOOR[2] },
	{ -5, 4, WIN[1], WIN[2] },
}, GREEN_SIDING)
wallX(house, 0, 26, 64, WALL_H, T_W, {
	{ 10, 5, DOOR[1], DOOR[2] },
	{ 19, 4, WIN[1], WIN[2] },
}, OLD_WOOD)
-- задняя стена
wallX(house, -26, 0, 80, WALL_H, T_W, {
	{ -18, 5, DOOR[1], DOOR[2] },
	{ -6, 4, WIN[1], WIN[2] },
}, GREEN_SIDING)
wallX(house, 0, 26, 80, WALL_H, T_W, {
	{ 16, 4, WIN[1], WIN[2] },
}, OLD_WOOD)
-- торцы
wallZ(house, 64.4, 79.6, -26, WALL_H, T_W, { { 72, 4, WIN[1], WIN[2] } }, GREEN_SIDING)
wallZ(house, 64.4, 79.6, 26, WALL_H, T_W, { { 72, 4, WIN[1], WIN[2] } }, OLD_WOOD)
-- перегородка между семьями
wallZ(house, 64.4, 79.6, 0, WALL_H, 0.5, { { 72, 5, DOOR[1], DOOR[2] } }, Color3.fromRGB(120, 100, 80))
-- окна
windowX(house, -21, 64, WIN[1], WIN[2], 4, WHITE_PAINT)
windowX(house, -5, 64, WIN[1], WIN[2], 4, WHITE_PAINT)
windowX(house, 19, 64, WIN[1], WIN[2], 4, Color3.fromRGB(150, 140, 120), true) -- разбитое
windowX(house, -6, 80, WIN[1], WIN[2], 4, WHITE_PAINT)
windowX(house, 16, 80, WIN[1], WIN[2], 4, Color3.fromRGB(150, 140, 120))
windowZ(house, 72, -26, WIN[1], WIN[2], 4, WHITE_PAINT)
windowZ(house, 72, 26, WIN[1], WIN[2], 4, Color3.fromRGB(150, 140, 120))
-- одно окно слева заколочено досками
for i = 0, 2 do
	P(house, "Board", Vector3.new(5, 0.6, 0.2), CFrame.new(-5, WIN[1] + 0.8 + i * 1.3, 63.45) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12))), OLD_WOOD)
end
-- пол, потолок (пол чердака), фундамент
P(house, "Floor", Vector3.new(52, 0.4, 16), CFrame.new(0, 0.2, 72), DARK_WOOD, Enum.Material.WoodPlanks)
P(house, "Ceiling", Vector3.new(52, 0.4, 16), CFrame.new(0, WALL_H + 0.2, 72), Color3.fromRGB(80, 66, 52), Enum.Material.WoodPlanks)
P(house, "Plinth", Vector3.new(53, 0.8, 17), CFrame.new(0, -0.3, 72), Color3.fromRGB(90, 88, 84), Enum.Material.Cobblestone)
-- угловые доски
for _, x in { -26, 0, 26 } do
	for _, z in { 64, 80 } do
		P(house, "CornerBoard", Vector3.new(1.1, WALL_H, 1.1), CFrame.new(x, WALL_H / 2, z), DARK_WOOD)
	end
end
-- двускатная крыша (конёк вдоль X на z = 72)
local rise, run = 5, 8
local ang = math.atan(rise / run)
local over = 1.4
local slabLen = (run + over) / math.cos(ang)
local midRun = (run + over) / 2
for _, s in { -1, 1 } do
	local zc = 72 + s * midRun
	local yc = WALL_H + 0.4 + rise - math.tan(ang) * midRun
	local r = P(house, "Roof", Vector3.new(55, 0.6, slabLen), CFrame.new(0, yc, zc) * CFrame.Angles(s * ang, 0, 0), ROOF, Enum.Material.Slate)
	r.Name = "Roof"
end
P(house, "RoofRidge", Vector3.new(55.5, 0.6, 0.9), CFrame.new(0, WALL_H + 0.4 + rise + 0.2, 72), DARK_WOOD)
-- фронтоны
for _, x in { -26, 26 } do
	W(house, "Gable", Vector3.new(0.8, rise, run), CFrame.new(x, WALL_H + 0.4 + rise / 2, 72 - run / 2), x < 0 and GREEN_SIDING or OLD_WOOD)
	W(house, "Gable", Vector3.new(0.8, rise, run), CFrame.new(x, WALL_H + 0.4 + rise / 2, 72 + run / 2) * CFrame.Angles(0, math.rad(180), 0), x < 0 and GREEN_SIDING or OLD_WOOD)
end
-- труба печи
P(house, "Chimney", Vector3.new(2.2, 6, 2.2), CFrame.new(-3, WALL_H + 4, 75), Color3.fromRGB(120, 70, 55), Enum.Material.Brick)

-- Двери (в закрытом положении; в игре стартуют открытыми)
door(house, "FrontDoorBlue", CFrame.new(-13, 4.3, 64), BLUE_DOOR, 100)
door(house, "FrontDoorBrown", CFrame.new(10, 4.3, 64), Color3.fromRGB(168, 120, 70), 100) -- светлая филёнчатая
door(house, "InnerDoor", CFrame.new(0, 4.3, 72) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(104, 38, 34), 50) -- тёмно-красная (kitchen.jpg)
door(house, "BackDoor", CFrame.new(-18, 4.3, 80), Color3.fromRGB(80, 60, 44), 100)
-- наличники дверей
for _, xc in { -13, 10 } do
	local c = if xc < 0 then WHITE_PAINT else DARK_WOOD
	P(house, "DoorFrame", Vector3.new(0.4, 8.4, 1.0), CFrame.new(xc - 2.7, 4.2, 64), c)
	P(house, "DoorFrame", Vector3.new(0.4, 8.4, 1.0), CFrame.new(xc + 2.7, 4.2, 64), c)
	P(house, "DoorFrame", Vector3.new(5.8, 0.4, 1.0), CFrame.new(xc, 8.4, 64), c)
	if xc < 0 then
		P(house, "Step", Vector3.new(6, 0.4, 2), CFrame.new(xc, 0.2, 62.6), Color3.fromRGB(100, 96, 90), Enum.Material.Concrete)
	else
		P(house, "Step", Vector3.new(4.4, 0.35, 1.4), CFrame.new(xc, 0.18, 62.9), Color3.fromRGB(120, 92, 62), Enum.Material.Wood)
		-- тротуарная плитка у порога (cat_porch.jpg), вровень с землёй
		for ix = -2, 2 do
			for iz = 0, 2 do
				local tile = P(house, "PavingTile", Vector3.new(1.4, 0.1, 0.9), CFrame.new(xc + ix * 1.5 + (iz % 2) * 0.5, 0.05, 61.6 - iz * 1.0) * CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), 0), Color3.fromRGB(120, 116, 104):Lerp(Color3.fromRGB(90, 100, 80), rng:NextNumber(0, 0.5)), Enum.Material.Pavement)
				tile.CanCollide = false
			end
		end
	end
end
-- занавеска в разбитом окне
local curtain = P(house, "Curtain", Vector3.new(3.6, 3.2, 0.08), CFrame.new(19, 5.6, 64.6), Color3.fromRGB(235, 235, 228), Enum.Material.Fabric)
curtain.Transparency = 0.15
curtain.CanCollide = false
-- веранда левой половины: навес на столбах и белые резные доски-«фестоны» (house_front.jpg)
local veranda = folder("Veranda", house)
P(veranda, "VerandaRoof", Vector3.new(26, 0.4, 5), CFrame.new(-13.5, 9.6, 61.8) * CFrame.Angles(math.rad(-8), 0, 0), ROOF, Enum.Material.Slate)
P(veranda, "VerandaBeam", Vector3.new(26, 0.6, 0.5), CFrame.new(-13.5, 8.9, 59.8), WHITE_PAINT, Enum.Material.WoodPlanks)
for _, x in { -25.6, -17.4, -8.6, -1.2 } do
	P(veranda, "VerandaPost", Vector3.new(0.5, 8.9, 0.5), CFrame.new(x, 4.45, 59.8), WHITE_PAINT, Enum.Material.Wood)
end
do
	local x = -26.2
	local i = 0
	while x < -0.8 do
		local len = if i % 2 == 0 then 1.9 else 1.3
		local f = P(veranda, "Festoon", Vector3.new(0.75, len, 0.12), CFrame.new(x, 8.6 - len / 2, 59.65), WHITE_PAINT, Enum.Material.WoodPlanks)
		f.CanCollide = false
		x += 0.95
		i += 1
	end
end
P(veranda, "Railing", Vector3.new(7, 0.25, 0.25), CFrame.new(-21.5, 3.1, 59.8), WHITE_PAINT, Enum.Material.Wood)
-- фонарь над коричневой дверью
local lampBox = P(house, "DoorLamp", Vector3.new(0.9, 1.1, 0.9), CFrame.new(13.4, 8.6, 63.2), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
lampBox.CanCollide = false
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Bottom
spot.Angle = 120
spot.Range = 22
spot.Brightness = 2.2
spot.Color = WARM
spot.Shadows = true
spot.Parent = lampBox
local glow = Instance.new("PointLight")
glow.Range = 7
glow.Brightness = 0.8
glow.Color = WARM
glow.Parent = lampBox
P(house, "LampCap", Vector3.new(1.3, 0.25, 1.3), CFrame.new(13.4, 9.25, 63.2), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
-- стул у двери (как на концепте)
local chair = folder("Chair", house)
P(chair, "Seat", Vector3.new(2, 0.25, 2), CFrame.new(20, 1.8, 60.5) * CFrame.Angles(0, math.rad(-15), 0), Color3.fromRGB(180, 178, 168), Enum.Material.Metal)
P(chair, "Back", Vector3.new(2, 2, 0.2), CFrame.new(20.25, 2.9, 61.4) * CFrame.Angles(0, math.rad(-15), 0), Color3.fromRGB(180, 178, 168), Enum.Material.Metal)
for _, off in { Vector3.new(-0.9, 0, -0.9), Vector3.new(0.9, 0, -0.9), Vector3.new(-0.9, 0, 0.9), Vector3.new(0.9, 0, 0.9) } do
	P(chair, "Leg", Vector3.new(0.15, 1.8, 0.15), CFrame.new(Vector3.new(20, 0.9, 60.5) + off), Color3.fromRGB(150, 148, 140), Enum.Material.Metal)
end

-- Интерьер: левая семья
local inside = folder("Interior", house)
P(inside, "Bed", Vector3.new(4, 1.6, 7), CFrame.new(-23.5, 1.2, 68.5), Color3.fromRGB(120, 108, 92), Enum.Material.Fabric)
P(inside, "BedFrame", Vector3.new(4.3, 0.6, 7.3), CFrame.new(-23.5, 0.7, 68.5), DARK_WOOD, Enum.Material.Wood)
P(inside, "Table", Vector3.new(4, 0.3, 2.6), CFrame.new(-8, 3, 68), Color3.fromRGB(110, 80, 52), Enum.Material.Wood)
for _, off in { Vector3.new(-1.7, 0, -1), Vector3.new(1.7, 0, -1), Vector3.new(-1.7, 0, 1), Vector3.new(1.7, 0, 1) } do
	P(inside, "TableLeg", Vector3.new(0.3, 2.6, 0.3), CFrame.new(Vector3.new(-8, 1.7, 68) + off), DARK_WOOD, Enum.Material.Wood)
end
P(inside, "Stove", Vector3.new(4, 7, 4), CFrame.new(-3, 3.9, 77), Color3.fromRGB(210, 205, 195), Enum.Material.Brick) -- русская печь
P(inside, "Rug", Vector3.new(6, 0.1, 4), CFrame.new(-14, 0.45, 72), Color3.fromRGB(110, 40, 36), Enum.Material.Fabric)
-- правая семья
P(inside, "Table", Vector3.new(4, 0.3, 2.6), CFrame.new(8, 3, 68), Color3.fromRGB(100, 72, 48), Enum.Material.Wood)
for _, off in { Vector3.new(-1.7, 0, -1), Vector3.new(1.7, 0, -1), Vector3.new(-1.7, 0, 1), Vector3.new(1.7, 0, 1) } do
	P(inside, "TableLeg", Vector3.new(0.3, 2.6, 0.3), CFrame.new(Vector3.new(8, 1.7, 68) + off), DARK_WOOD, Enum.Material.Wood)
end
P(inside, "Sofa", Vector3.new(7, 2, 3), CFrame.new(18, 1.4, 66.3), Color3.fromRGB(80, 66, 50), Enum.Material.Fabric)
P(inside, "Shelf", Vector3.new(5, 6, 1.2), CFrame.new(7, 3.4, 79), DARK_WOOD, Enum.Material.Wood)
-- кухня (kitchen.jpg): белая газовая плита с полотенцем, кастрюли, клеёнка в горошек, оранжевый таз, табурет
local kitchen = folder("Kitchen", inside)
P(kitchen, "GasStove", Vector3.new(2.6, 3, 2.3), CFrame.new(24.4, 1.9, 75.3), Color3.fromRGB(232, 232, 226), Enum.Material.SmoothPlastic)
P(kitchen, "OvenGlass", Vector3.new(1.8, 1.2, 0.05), CFrame.new(24.4, 1.6, 74.12), Color3.fromRGB(30, 30, 32), Enum.Material.Glass)
local towel = P(kitchen, "Towel", Vector3.new(0.7, 1.3, 0.06), CFrame.new(23.9, 2.3, 74.08), Color3.fromRGB(210, 120, 150), Enum.Material.Fabric)
towel.CanCollide = false
for i, off in { Vector3.new(-0.6, 0, -0.4), Vector3.new(0.6, 0, 0.4) } do
	P(kitchen, "Pot", Vector3.new(0.9, 1.1, 1.1), CFrame.new(Vector3.new(24.4, 3.85, 75.3) + off) * CFrame.Angles(0, 0, math.rad(90)), if i == 1 then Color3.fromRGB(170, 160, 140) else Color3.fromRGB(40, 40, 42), Enum.Material.Metal, Enum.PartType.Cylinder)
end
local cloth = P(kitchen, "TableCloth", Vector3.new(4.4, 0.08, 3), CFrame.new(8, 3.2, 68), Color3.fromRGB(176, 170, 128), Enum.Material.Fabric)
for ix = -2, 2 do
	for iz = -1, 1 do
		local dot = P(kitchen, "PolkaDot", Vector3.new(0.05, 0.35, 0.35), CFrame.new(8 + ix * 0.85, 3.25, 68 + iz * 0.9) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(226, 222, 196), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		dot.CanCollide = false
	end
end
P(kitchen, "Basin", Vector3.new(0.7, 2, 2), CFrame.new(6.4, 3.6, 68.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(235, 120, 40), Enum.Material.Plastic, Enum.PartType.Cylinder)
P(kitchen, "Stool", Vector3.new(1.6, 0.25, 1.6), CFrame.new(21.5, 2, 72.5), Color3.fromRGB(150, 90, 50), Enum.Material.Wood)
for _, off in { Vector3.new(-0.6, 0, -0.6), Vector3.new(0.6, 0, -0.6), Vector3.new(-0.6, 0, 0.6), Vector3.new(0.6, 0, 0.6) } do
	P(kitchen, "StoolLeg", Vector3.new(0.18, 1.9, 0.18), CFrame.new(Vector3.new(21.5, 0.95, 72.5) + off), Color3.fromRGB(150, 90, 50), Enum.Material.Wood)
end
for i = 0, 1 do
	P(kitchen, "Socket", Vector3.new(0.5, 0.5, 0.1), CFrame.new(16 + i * 0.6, 3.6, 79.55), Color3.fromRGB(235, 235, 230), Enum.Material.SmoothPlastic)
end
-- шкафы, где можно спрятаться (выход — передняя грань, -Z)
local c1 = P(inside, "ClosetLeft", Vector3.new(4, 7, 2.5), CFrame.new(-10, 3.9, 78.35), Color3.fromRGB(74, 54, 38), Enum.Material.Wood)
CS:AddTag(c1, "SlavikCloset")
local c2 = P(inside, "ClosetRight", Vector3.new(4, 7, 2.5), CFrame.new(21, 3.9, 78.35), Color3.fromRGB(70, 50, 36), Enum.Material.Wood)
CS:AddTag(c2, "SlavikCloset")
-- лампочки (HouseLight мигает)
bulb(house, "HouseLight", Vector3.new(12, 8.7, 72), 22, 1.4)
bulb(house, "HouseLight2", Vector3.new(-13, 8.7, 72), 20, 1.1)
marker(house, "HouseInterior", Vector3.new(51, 9.5, 15), Vector3.new(0, 5, 72))
task.wait()

-- Заросли у левой половины: кусты и плющ
local bushes = folder("Overgrowth")
local function bush(pos: Vector3, r: number)
	local b = P(bushes, "Bush", Vector3.new(r * 2, r * 1.4, r * 2), CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), LEAF:Lerp(Color3.fromRGB(70, 84, 44), rng:NextNumber(0, 0.5)), Enum.Material.LeafyGrass, Enum.PartType.Ball)
	b.CanCollide = false
	return b
end
for i = 1, 14 do
	local x = rng:NextNumber(-27, -2)
	if math.abs(x + 13) > 3.5 then -- не загораживать голубую дверь
		bush(Vector3.new(x, rng:NextNumber(0.6, 1.6), rng:NextNumber(60.5, 62.8)), rng:NextNumber(1.4, 2.6))
	end
end
for i = 1, 10 do
	bush(Vector3.new(rng:NextNumber(-34, -27.5), rng:NextNumber(0.8, 2), rng:NextNumber(62, 82)), rng:NextNumber(1.6, 3))
end
-- плющ на стене слева
for i = 1, 12 do
	local x = rng:NextNumber(-25.5, -1)
	if math.abs(x + 13) > 3.2 then
		local h = rng:NextNumber(3, 9)
		local ivy = P(bushes, "Ivy", Vector3.new(rng:NextNumber(0.8, 2), h, 0.25), CFrame.new(x, h / 2, 63.45) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-10, 10))), LEAF, Enum.Material.LeafyGrass)
		ivy.CanCollide = false
	end
end
task.wait()

-- ===================================================================
-- 4) САРАЙ справа: x 36..48, z 66..78. Дверь спереди, поленница под навесом, генератор внутри
-- ===================================================================
local shed = folder("Shed")
local SH = 9
wallX(shed, 36, 48, 66, SH, 0.6, { { 44, 5, DOOR[1], DOOR[2] } }, Color3.fromRGB(78, 64, 50))
wallX(shed, 36, 48, 78, SH, 0.6, {}, Color3.fromRGB(78, 64, 50))
wallZ(shed, 66.3, 77.7, 36, SH, 0.6, {}, Color3.fromRGB(78, 64, 50))
wallZ(shed, 66.3, 77.7, 48, SH, 0.6, {}, Color3.fromRGB(78, 64, 50))
P(shed, "ShedFloor", Vector3.new(12, 0.3, 12), CFrame.new(42, 0.15, 72), Color3.fromRGB(70, 60, 48), Enum.Material.WoodPlanks)
P(shed, "ShedRoof", Vector3.new(14, 0.5, 14.5), CFrame.new(42, SH + 0.6, 72) * CFrame.Angles(0, 0, math.rad(-6)), Color3.fromRGB(88, 76, 66), Enum.Material.CorrodedMetal)
door(shed, "ShedDoor", CFrame.new(44, 4.3, 66), Color3.fromRGB(86, 70, 52), 50)
-- навес для дров перед сараем
P(shed, "WoodRoof", Vector3.new(7, 0.4, 5), CFrame.new(38.8, 6.8, 63.4) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(88, 76, 66), Enum.Material.CorrodedMetal)
for _, x in { 35.6, 42 } do
	P(shed, "WoodPost", Vector3.new(0.5, 6.6, 0.5), CFrame.new(x, 3.3, 61.3), DARK_WOOD, Enum.Material.Wood)
end
-- поленница: торцы брёвен смотрят на поле
local logs = folder("Firewood", shed)
for row = 0, 6 do
	for col = 0, 7 do
		local r = rng:NextNumber(0.34, 0.44)
		local x = 36.4 + col * 0.82 + (row % 2) * 0.4 + rng:NextNumber(-0.05, 0.05)
		if x < 42 then
			local log = P(logs, "Log", Vector3.new(3.2, r * 2, r * 2), CFrame.new(x, 0.45 + row * 0.78, 63.6 + rng:NextNumber(-0.25, 0.25)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(rng:NextNumber(0, 6.28), 0, 0), Color3.fromRGB(150, 112, 72):Lerp(Color3.fromRGB(110, 80, 50), rng:NextNumber()), Enum.Material.Wood, Enum.PartType.Cylinder)
			log.Name = "Log"
		end
	end
end
-- одна невидимая стенка, чтобы через поленницу не проваливаться и Славик обходил её целиком
local woodBlock = P(logs, "FirewoodCollider", Vector3.new(6, 5.6, 3.4), CFrame.new(39.2, 2.8, 63.6), Color3.new(), Enum.Material.SmoothPlastic)
woodBlock.Transparency = 1
for _, l in logs:GetChildren() do
	if l.Name == "Log" then
		(l :: BasePart).CanCollide = false
	end
end
-- генератор
local gen = P(shed, "Generator", Vector3.new(3, 2.2, 2), CFrame.new(45, 1.4, 75.5), Color3.fromRGB(150, 44, 34), Enum.Material.Metal)
P(shed, "GeneratorFrame", Vector3.new(3.4, 0.3, 2.4), CFrame.new(45, 0.45, 75.5), Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
P(shed, "GeneratorTank", Vector3.new(2, 0.7, 1.4), CFrame.new(45, 2.85, 75.5), Color3.fromRGB(160, 50, 40), Enum.Material.Metal)
P(shed, "Exhaust", Vector3.new(1, 0.35, 0.35), CFrame.new(46.8, 1.6, 75.5), Color3.fromRGB(60, 60, 60), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
P(shed, "Workbench", Vector3.new(5, 3, 2), CFrame.new(39.5, 1.65, 76.5), Color3.fromRGB(96, 72, 50), Enum.Material.Wood)
bulb(shed, "ShedLight", Vector3.new(42, 7.2, 72), 14, 0.9)
task.wait()

-- ===================================================================
-- 5) ДЕРЕВЯННЫЙ ЗАБОР по периметру двора (старый, кривой, местами без досок)
-- ===================================================================
local fence = folder("WoodFence")
-- gaps = { {от, до} } — проёмы (в стадах от начала линии), h = высота досок
local function fenceLine(a: Vector3, b: Vector3, gaps: { { number } }?, h: number?)
	local H = h or 5
	local dir = (b - a)
	local len = dir.Magnitude
	local unit = dir.Unit
	local yaw = math.atan2(-unit.Z, unit.X)
	-- куски забора между проёмами
	local pieces: { { number } } = {}
	local cur = 0
	local sorted = table.clone(gaps or {})
	table.sort(sorted, function(x, y)
		return x[1] < y[1]
	end)
	for _, g in sorted do
		if g[1] > cur then
			table.insert(pieces, { cur, g[1] })
		end
		cur = g[2]
	end
	if cur < len then
		table.insert(pieces, { cur, len })
	end
	for _, piece in pieces do
		local s0, s1 = piece[1], piece[2]
		local plen = s1 - s0
		local mid = a + unit * ((s0 + s1) / 2)
		for _, y in { H * 0.24, H * 0.76 } do
			P(fence, "Rail", Vector3.new(plen, 0.35, 0.3), CFrame.new(mid.X, y, mid.Z) * CFrame.Angles(0, yaw, 0), DARK_WOOD, Enum.Material.Wood)
		end
		local n = math.max(1, math.floor(plen / 8))
		for i = 0, n do
			local p = a + unit * (s0 + i * plen / n)
			P(fence, "Post", Vector3.new(0.6, H + 0.6, 0.6), CFrame.new(p.X, (H + 0.6) / 2, p.Z) * CFrame.Angles(0, yaw, 0), DARK_WOOD, Enum.Material.Wood)
		end
		local d = s0 + 0.6
		while d < s1 - 0.4 do
			if rng:NextNumber() > 0.06 then -- иногда доски нет
				local p = a + unit * d
				local ph = rng:NextNumber(H * 0.88, H * 1.08)
				local tilt = if rng:NextNumber() < 0.08 then rng:NextNumber(-14, 14) else rng:NextNumber(-2, 2)
				P(fence, "Plank", Vector3.new(0.9, ph, 0.15), CFrame.new(p.X, ph / 2, p.Z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 0.25) * CFrame.Angles(0, 0, math.rad(tilt)), GREY_WOOD:Lerp(OLD_WOOD, rng:NextNumber()), Enum.Material.WoodPlanks)
			end
			d += 1.25
		end
	end
end
fenceLine(Vector3.new(-52, 0, -100), Vector3.new(-52, 0, 106))
task.wait()
-- правый забор: ворота к дороге у трактора (z 84..100)
fenceLine(Vector3.new(58, 0, -100), Vector3.new(58, 0, 106), { { 184, 200 } })
task.wait()
-- задний забор: дыра на соседскую сторону (x -41..-35)
fenceLine(Vector3.new(-52, 0, 106), Vector3.new(58, 0, 106), { { 11, 17 } })
task.wait()
fenceLine(Vector3.new(-52, 0, -100), Vector3.new(58, 0, -100))
task.wait()
-- распахнутые створки ворот (наружу, к дороге)
for _, info in { { 84, 10 }, { 100, -10 } } do -- створки вдоль дороги, проезд свободен
	local z = info[1]
	local leaf = P(fence, "GateLeaf", Vector3.new(7.6, 4.6, 0.3), CFrame.new(58, 2.6, z) * CFrame.Angles(0, math.rad(info[2]), 0) * CFrame.new(3.8, 0, 0), GREY_WOOD, Enum.Material.WoodPlanks)
	leaf.Name = "GateLeaf"
end

-- ===================================================================
-- 6) МЕШ-МОДЕЛИ: берёзы, трактор, огород, соседи, кот, бочки
-- ===================================================================
local nature = folder("Trees")
local birchPack = ASSETS and ASSETS:FindFirstChild("BirchPack")
local birchTemplates: { Model } = {}
if birchPack then
	local inner = birchPack:FindFirstChildWhichIsA("Model")
	if inner then
		for _, t in inner:GetChildren() do
			if t:IsA("Model") then
				table.insert(birchTemplates, t)
			end
		end
	end
end
local function birch(idx: number, pos: Vector3, yaw: number, scale: number)
	local tpl = birchTemplates[((idx - 1) % #birchTemplates) + 1]
	if not tpl then
		-- запасная берёза из деталей
		P(nature, "BirchTrunk", Vector3.new(30 * scale, 1.6 * scale, 1.6 * scale), CFrame.new(pos + Vector3.new(0, 15 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 220, 210), Enum.Material.Wood, Enum.PartType.Cylinder)
		return
	end
	local m = tpl:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	-- в паке деревья лежат на боку — ставим вертикально (по самой длинной мировой оси)
	local mn, mx = worldBox(m)
	local size = mx - mn
	local center = (mn + mx) / 2
	if size.Z > size.Y and size.Z >= size.X then
		rotateAround(m, center, CFrame.Angles(math.rad(-90), 0, 0))
	elseif size.X > size.Y and size.X > size.Z then
		rotateAround(m, center, CFrame.Angles(0, 0, math.rad(90)))
	end
	-- крона (самая «толстая» деталь: у ствола средний размер маленький) должна быть сверху
	local crown: BasePart? = nil
	local crownWidth = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local dims = { d.Size.X, d.Size.Y, d.Size.Z }
			table.sort(dims)
			if dims[2] > crownWidth then
				crown, crownWidth = d, dims[2]
			end
		end
	end
	mn, mx = worldBox(m)
	center = (mn + mx) / 2
	if crown and crown.Position.Y < center.Y then
		rotateAround(m, center, CFrame.Angles(math.rad(180), 0, 0))
	end
	if scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	mn, mx = worldBox(m)
	rotateAround(m, (mn + mx) / 2, CFrame.Angles(0, math.rad(yaw), 0))
	settle(m, pos)
	m.Parent = nature
	return m
end
-- огромная берёза между домом и сараем
local bigBirch = birch(6, Vector3.new(31, -0.3, 58), 30, 2.0)
if bigBirch then
	bigBirch.Name = "BigBirch"
	local trunk = P(nature, "BigBirchCollider", Vector3.new(2.6, 20, 2.6), CFrame.new(31, 10, 58), Color3.new(), Enum.Material.SmoothPlastic)
	trunk.Transparency = 1
end
-- берёзы и лес за забором
local spots = {
	{ -47, 82 }, { -44, 40 }, { -47, -20 }, { -46, -70 }, { 53, 30 }, { 52, -40 },
	{ -70, 20 }, { -75, 80 }, { -68, -60 }, { 80, 60 }, { 82, -20 }, { 72, -85 }, { 0, -120 }, { -40, -118 }, { 40, -125 },
	{ -62, 128 }, { 55, 130 }, { -90, -10 }, { 95, 20 },
}
for i, s in spots do
	birch(i, Vector3.new(s[1], -0.3, s[2]), rng:NextNumber(0, 360), rng:NextNumber(1.1, 1.6))
	if i % 6 == 0 then
		task.wait()
	end
end

-- Трактор МТЗ сбоку участка, у ворот рядом с сараем (носом к воротам)
local tractorFolder = folder("Tractor")
local escapeCar: BasePart
local tractor = placeAsset("Tractor", tractorFolder, Vector3.new(46, 0, 92), 0, 0.7)
if tractor then
	tractor.Name = "MTZ"
	local body = tractor:FindFirstChild("MTZ82", true)
	-- плуг сзади: направление «плуг -> кабина» = вперёд; разворачиваем вперёд к воротам (+X)
	local sum, n = Vector3.zero, 0
	for _, d in tractor:GetDescendants() do
		if d:IsA("BasePart") and (d.Name:find("Skiba") or d.Name:find("Resor")) then
			sum += d.Position
			n += 1
		end
	end
	if body and body:IsA("BasePart") and n > 0 then
		local f = body.Position - sum / n
		local mn, mx = worldBox(tractor)
		rotateAround(tractor, (mn + mx) / 2, CFrame.Angles(0, math.atan2(f.Z, f.X), 0))
		settle(tractor, Vector3.new(46, 0, 92))
	end
	for _, d in tractor:GetDescendants() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			d.Disabled = true
		end
	end
	if body and body:IsA("BasePart") then
		escapeCar = body
	else
		local best: BasePart? = nil
		for _, d in tractor:GetDescendants() do
			if d:IsA("BasePart") and (not best or d.Size.Magnitude > best.Size.Magnitude) then
				best = d
			end
		end
		escapeCar = best :: BasePart
	end
else
	escapeCar = P(tractorFolder, "EscapeCar", Vector3.new(12, 7, 7), CFrame.new(46, 3.5, 92), Color3.fromRGB(40, 70, 140), Enum.Material.Metal)
end
escapeCar.Name = "EscapeCar"

-- ===== ОГОРОД за домом (garden.jpg): x -52..22, z 87..106 =====
local garden = folder("Garden")
local GARDEN_FENCE_H = 3.6
-- низкий забор: калитка напротив задней двери (x -22..-14), пролом сбоку (z 95..100)
fenceLine(Vector3.new(-52, 0, 87), Vector3.new(22, 0, 87), { { 30, 38 } }, GARDEN_FENCE_H)
fenceLine(Vector3.new(22, 0, 87), Vector3.new(22, 0, 106), { { 8, 13 } }, GARDEN_FENCE_H)
-- приоткрытая калитка
P(garden, "Wicket", Vector3.new(3.6, 3.2, 0.25), CFrame.new(-22, 1.7, 87) * CFrame.Angles(0, math.rad(60), 0) * CFrame.new(1.8, 0, 0), GREY_WOOD, Enum.Material.WoodPlanks)
-- грядки (земля, рядами ботва/капуста)
for _, z in { 91, 95, 99 } do
	P(garden, "Bed", Vector3.new(17, 0.45, 2.4), CFrame.new(-37, 0.2, z), Color3.fromRGB(62, 48, 36), Enum.Material.Mud)
	for x = -44.5, -29.5, 1.5 do
		local leafy = P(garden, "Plant", Vector3.new(0.9, 0.7, 0.9), CFrame.new(x + rng:NextNumber(-0.2, 0.2), 0.75, z + rng:NextNumber(-0.5, 0.5)), Color3.fromRGB(70, 104, 52):Lerp(Color3.fromRGB(120, 140, 70), rng:NextNumber(0, 0.4)), Enum.Material.LeafyGrass, Enum.PartType.Ball)
		leafy.CanCollide = false
	end
end
-- высокая трава кочками
local function grassClump(pos: Vector3)
	for i = 1, 3 do
		local h = rng:NextNumber(2.2, 4.2)
		local blade = P(garden, "TallGrass", Vector3.new(0.9, h, 0.15), CFrame.new(pos + Vector3.new(rng:NextNumber(-0.5, 0.5), h / 2, rng:NextNumber(-0.5, 0.5))) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-12, 12))), Color3.fromRGB(78, 104, 50):Lerp(Color3.fromRGB(128, 132, 70), rng:NextNumber()), Enum.Material.Grass)
		blade.CanCollide = false
		blade.CastShadow = false
	end
end
local placed = 0
while placed < 55 do
	local x, z = rng:NextNumber(-50, 20), rng:NextNumber(88.5, 104.5)
	local onBed = x > -46.5 and x < -27.5 and z > 89 and z < 101
	local onPath = x > -22 and x < -14
	if not onBed and not onPath then
		grassClump(Vector3.new(x, 0, z))
		placed += 1
	end
end
-- кусты смородины/малины с ягодами
local function berryBush(pos: Vector3, berry: Color3)
	local r = rng:NextNumber(1.6, 2.3)
	local b = P(garden, "BerryBush", Vector3.new(r * 2, r * 1.5, r * 2), CFrame.new(pos + Vector3.new(0, r * 0.6, 0)), LEAF:Lerp(Color3.fromRGB(64, 92, 40), rng:NextNumber()), Enum.Material.LeafyGrass, Enum.PartType.Ball)
	b.CanCollide = false
	for i = 1, 9 do
		local a = rng:NextNumber(0, 6.28)
		local y = rng:NextNumber(0.2, r * 1.1)
		local berryPart = P(garden, "Berry", Vector3.new(0.32, 0.32, 0.32), CFrame.new(pos + Vector3.new(math.cos(a) * r * 0.95, y, math.sin(a) * r * 0.95)), berry, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		berryPart.CanCollide = false
	end
end
for i, pos in { Vector3.new(-49, 0, 90), Vector3.new(-49, 0, 97), Vector3.new(-49, 0, 103), Vector3.new(19, 0, 90), Vector3.new(16, 0, 103), Vector3.new(-26, 0, 103.5) } do
	berryBush(pos, if i % 2 == 0 then Color3.fromRGB(170, 20, 30) else Color3.fromRGB(40, 16, 40))
end
-- яблони
local appleSrc = ASSETS and ASSETS:FindFirstChild("AppleTree")
for _, info in { { -4, 95, 20 }, { 10, 100, 140 }, { -10, 103, 260 } } do
	local pos = Vector3.new(info[1], 0, info[2])
	local tree = placeAsset("AppleTree", garden, pos, info[3], 0.45)
	if tree then
		tree.Name = "AppleTree"
		for _, d in tree:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	else
		P(garden, "AppleCrown", Vector3.new(9, 7, 9), CFrame.new(pos + Vector3.new(0, 8, 0)), LEAF, Enum.Material.LeafyGrass, Enum.PartType.Ball).CanCollide = false
	end
	local trunk = P(garden, "AppleTrunk", Vector3.new(1.1, 6, 1.1), CFrame.new(pos + Vector3.new(0, 3, 0)), Color3.fromRGB(70, 56, 44), Enum.Material.Wood)
	trunk.Transparency = if appleSrc then 1 else 0
end
-- старые доски и ведро в огороде
P(garden, "PlankPile", Vector3.new(7, 0.6, 2), CFrame.new(-8, 0.3, 90) * CFrame.Angles(0, 0.3, 0), OLD_WOOD)
P(garden, "Bucket", Vector3.new(1.2, 1.4, 1.4), CFrame.new(-25, 0.6, 92) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(110, 110, 105), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)

-- ===== СОСЕДИ за задним забором: дома с красной и зелёной металлической крышей, серый сарай =====
local neighbors = folder("Neighbors")
local function neighborHouse(c: Vector3, w: number, d: number, wallColor: Color3, roofColor: Color3, wallH: number)
	P(neighbors, "NWall", Vector3.new(w, wallH, d), CFrame.new(c + Vector3.new(0, wallH / 2, 0)), wallColor, Enum.Material.WoodPlanks)
	local rise = d * 0.35
	local ang = math.atan(rise / (d / 2))
	local slab = (d / 2 + 1) / math.cos(ang)
	for _, sgn in { -1, 1 } do
		local mid = (d / 2 + 1) / 2
		P(neighbors, "NRoof", Vector3.new(w + 2, 0.3, slab), CFrame.new(c + Vector3.new(0, wallH + rise - math.tan(ang) * mid, sgn * mid)) * CFrame.Angles(sgn * ang, 0, 0), roofColor, Enum.Material.CorrodedMetal)
	end
	for _, sx in { -1, 1 } do
		W(neighbors, "NGable", Vector3.new(0.4, rise, d / 2), CFrame.new(c + Vector3.new(sx * w / 2, wallH + rise / 2, -d / 4)), wallColor, Enum.Material.WoodPlanks)
		W(neighbors, "NGable", Vector3.new(0.4, rise, d / 2), CFrame.new(c + Vector3.new(sx * w / 2, wallH + rise / 2, d / 4)) * CFrame.Angles(0, math.rad(180), 0), wallColor, Enum.Material.WoodPlanks)
	end
	for i = -1, 1 do
		local win = P(neighbors, "NWindow", Vector3.new(2.4, 2.8, 0.2), CFrame.new(c + Vector3.new(i * w / 3.2, wallH * 0.55, -d / 2 - 0.05)), Color3.fromRGB(28, 30, 34), Enum.Material.Glass)
		win.CanCollide = false
	end
end
neighborHouse(Vector3.new(-26, 0, 132), 22, 13, Color3.fromRGB(140, 130, 112), Color3.fromRGB(150, 40, 36), 9) -- красная крыша
neighborHouse(Vector3.new(18, 0, 136), 20, 12, Color3.fromRGB(110, 100, 88), Color3.fromRGB(40, 110, 82), 8.5) -- зелёная крыша
neighborHouse(Vector3.new(44, 0, 124), 12, 9, Color3.fromRGB(120, 118, 112), Color3.fromRGB(96, 96, 96), 7) -- серый сарай

-- Чёрный кот у крыльца (cat_porch.jpg), рядом с голубой дверью
local catModel = placeAsset("Cat", house, Vector3.new(-9.3, 0, 62.4), 200, 0.45)
if catModel then
	catModel.Name = "Cat"
	for _, d in catModel:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
end
task.wait()

-- Бочки (у сарая и у дома)
local props = folder("Props")
local barrelSrc = ASSETS and ASSETS:FindFirstChild("Barrels")
local function barrel(pos: Vector3)
	if barrelSrc then
		local b = barrelSrc:FindFirstChildWhichIsA("BasePart")
		if b then
			local c = b:Clone()
			c.Anchored = true
			c.CFrame = CFrame.new(O + pos + Vector3.new(0, c.Size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			c.Parent = props
			return
		end
	end
	P(props, "Barrel", Vector3.new(3.4, 2.4, 2.4), CFrame.new(pos + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 60, 50), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
end
barrel(Vector3.new(34.3, 0, 62.5))
barrel(Vector3.new(49.5, 0, 64.5))
barrel(Vector3.new(27.8, 0, 66))
barrel(Vector3.new(-28.5, 0, 82.5))
barrel(Vector3.new(55, 0, 80.5))
-- старая скамейка у поля, ведро, доски
P(props, "Bench", Vector3.new(6, 0.4, 1.4), CFrame.new(-36, 1.6, 10), Color3.fromRGB(100, 80, 60), Enum.Material.Wood)
for _, x in { -38.4, -33.6 } do
	P(props, "BenchLeg", Vector3.new(0.4, 1.4, 1.2), CFrame.new(x, 0.7, 10), DARK_WOOD, Enum.Material.Wood)
end
P(props, "Bucket", Vector3.new(1.2, 1.4, 1.4), CFrame.new(51, 0.6, 62) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(110, 110, 105), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
task.wait()

-- Деревянный столб с фонарём у поля (единственный свет на поле)
local function poleLamp(pos: Vector3)
	P(props, "LampPole", Vector3.new(0.8, 16, 0.8), CFrame.new(pos + Vector3.new(0, 8, 0)), DARK_WOOD, Enum.Material.Wood)
	P(props, "LampArm", Vector3.new(3, 0.3, 0.3), CFrame.new(pos + Vector3.new(1.4, 15.2, 0)), DARK_WOOD, Enum.Material.Wood)
	local head = P(props, "LampHead", Vector3.new(1, 0.6, 1), CFrame.new(pos + Vector3.new(2.6, 14.8, 0)), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
	head.CanCollide = false
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Bottom
	l.Angle = 110
	l.Range = 45
	l.Brightness = 2.4
	l.Color = WARM
	l.Shadows = true
	l.Parent = head
end
poleLamp(Vector3.new(-36, 0, 0))
poleLamp(Vector3.new(36, 0, -32))

-- ===================================================================
-- 7) СЛУЖЕБНОЕ: точки предметов, патруль, спавн, комната пойманных
-- ===================================================================
local svc = folder("Gameplay")
for i, pos in {
	Vector3.new(-23.5, 2.6, 68.5), -- на кровати
	Vector3.new(-8, 3.7, 68), -- стол слева
	Vector3.new(9, 3.7, 67.8), -- стол справа (рядом с тазом)
	Vector3.new(24, 1, 70), -- угол справа
	Vector3.new(-20, 1, 77), -- у задней двери
	Vector3.new(40, 1, 72), -- сарай
	Vector3.new(39.5, 3.7, 76.5), -- верстак
	Vector3.new(-37, 1, 93), -- огород, между грядками
	Vector3.new(4, 1, 91), -- огород, у яблони
	Vector3.new(-14, 1, 103), -- огород, дальний угол
	Vector3.new(-42, 1, 30), -- двор слева
	Vector3.new(48, 1, 30), -- двор справа
	Vector3.new(15, 1, -85), -- за сеткой у Славика
	Vector3.new(30, 1, 100), -- у трактора, за сараем
	Vector3.new(-36, 2.4, 10), -- на скамейке
} do
	marker(svc, "ItemSpawn" .. i, Vector3.new(1, 1, 1), pos, "SlavikItemSpawn")
end
for i, pos in {
	Vector3.new(-32, 0, 72), Vector3.new(32, 0, 72), Vector3.new(0, 0, 92), Vector3.new(-13, 0, 54),
	Vector3.new(10, 0, 58), Vector3.new(46, 0, 58), Vector3.new(-16, 0, 102), Vector3.new(0, 0, 0),
	Vector3.new(31, 0, -50), Vector3.new(-12, 0, 72), Vector3.new(14, 0, 72), Vector3.new(42, 0, 72),
	Vector3.new(-40, 0, -30), Vector3.new(48, 0, 10),
	Vector3.new(-24, 0, 97), Vector3.new(8, 0, 94), Vector3.new(-38, 0, 116), -- огород и за дырой в заборе
	Vector3.new(30, 0, 92),
} do
	marker(svc, "Patrol" .. i, Vector3.new(1, 1, 1), pos, "SlavikPatrol")
end
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Size = Vector3.new(6, 0.4, 6)
spawn.CFrame = CFrame.new(O + Vector3.new(24, 0.2, 40))
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Duration = 0
spawn.Neutral = true
spawn.Parent = svc
-- комната для пойманных (высоко над картой)
local spec = P(svc, "Spectator", Vector3.new(30, 1, 30), CFrame.new(0, 150, 0), Color3.fromRGB(200, 220, 255), Enum.Material.Glass)
spec.Transparency = 0.7
for _, info in {
	{ Vector3.new(30, 8, 1), Vector3.new(0, 154, 15) },
	{ Vector3.new(30, 8, 1), Vector3.new(0, 154, -15) },
	{ Vector3.new(1, 8, 30), Vector3.new(15, 154, 0) },
	{ Vector3.new(1, 8, 30), Vector3.new(-15, 154, 0) },
} do
	local w = P(svc, "SpectatorWall", info[1], CFrame.new(info[2]), Color3.new(1, 1, 1), Enum.Material.Glass)
	w.Transparency = 0.85
end

map.Parent = workspace

-- ===================================================================
-- 8) СВЕТ: ночь, луна, туман (Technology = Future включается вручную в Lighting)
-- ===================================================================
local lightOk, lightErr = pcall(function()
Lighting.ClockTime = 0.2
Lighting.Brightness = 0.6
Lighting.Ambient = Color3.fromRGB(16, 16, 24)
Lighting.OutdoorAmbient = Color3.fromRGB(42, 46, 62)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atm.Density = 0.45
atm.Offset = 0.1
atm.Color = Color3.fromRGB(80, 88, 110)
atm.Decay = Color3.fromRGB(40, 44, 60)
atm.Glare = 0.2
atm.Haze = 2.2
atm.Parent = Lighting
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
cc.Saturation = -0.25
cc.Contrast = 0.12
cc.Brightness = 0
cc.TintColor = Color3.fromRGB(225, 232, 255)
cc.Enabled = true
cc.Parent = Lighting
local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.6
bloom.Enabled = true
bloom.Parent = Lighting
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof.FarIntensity = 0.15
	dof.FocusDistance = 40
	dof.InFocusRadius = 60
	dof.NearIntensity = 0
end
local sky = Lighting:FindFirstChildOfClass("Sky")
if sky then
	sky.MoonAngularSize = 14
	sky.StarCount = 1500
end
end)
if not lightOk then
	warn("[BuildVillageMap] Свет настроен не полностью: " .. tostring(lightErr))
end

local parts, lights = 0, 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Light") then
		lights += 1
	end
end
print(string.format("[BuildVillageMap] Готово: деталей %d, источников света %d", parts, lights))
return string.format("parts=%d lights=%d", parts, lights)
