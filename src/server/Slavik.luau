--!strict
-- Славик: спит за сеткой, потом встаёт и охотится.
--
-- Как он думает (каждые Config.PathRecompute сек):
--   ВИДИТ игрока (конус зрения + нет стены между) -> ПОГОНЯ
--   потерял из виду -> бежит туда, где видел последний раз -> ОБЫСК вокруг
--   СЛЫШИТ шум (бег, генератор, дверь, машина) -> идёт ПРОВЕРИТЬ
--   иначе -> БРОДИТ по точкам патруля, стучит в окна дома
-- Если путь закрыт дверью — идёт к двери и выбивает её.
-- Если видел, как игрок залез в шкаф, — вытащит его оттуда.
--
-- Настоящая модель: положи в ServerStorage модель "SlavikModel"
-- (с Humanoid и HumanoidRootPart, например R15). Анимации — в Config.SlavikAnimations.
-- Если модели нет — собирается временный Славик из блоков.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local Noise = require(script.Parent.Noise)
local Doors = require(script.Parent.Doors)

export type Context = {
	onCatch: (player: Player) -> (),
	onDoorHit: (door: BasePart, broke: boolean) -> (),
	onKnock: () -> (),
	isInsideHouse: (pos: Vector3) -> boolean,
}

local Slavik = {}

local model: Model? = nil
local root: BasePart? = nil
local humanoid: Humanoid? = nil
local running = false
local snore: Sound? = nil
local tracks: { [string]: AnimationTrack } = {}
local currentTrack: string? = nil

local BLOCK_HIP_HEIGHT = 2.5

-- ===== Модель =====

local function weldPart(parent: Model, rootPart: BasePart, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = rootPart.CFrame * CFrame.new(offset)
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.CanCollide = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local w = Instance.new("WeldConstraint")
	w.Part0 = rootPart
	w.Part1 = p
	w.Parent = p
	p.Parent = parent
	return p
end

-- Временный Славик из блоков (по концепту: лысый, борода, тёмная рубашка, протез слева)
local function buildBlocky(): Model
	local m = Instance.new("Model")
	m.Name = "Slavik"

	local r = Instance.new("Part")
	r.Name = "HumanoidRootPart"
	r.Size = Vector3.new(2, 2, 1)
	r.Transparency = 1
	r.CanCollide = true
	r.Anchored = true
	r.CFrame = CFrame.new(0, 100, 0)
	r.Parent = m
	m.PrimaryPart = r

	local shirt = Color3.fromRGB(55, 50, 45)
	local skin = Color3.fromRGB(165, 130, 105)
	local pants = Color3.fromRGB(40, 38, 36)
	weldPart(m, r, "Torso", Vector3.new(2, 2, 1), Vector3.zero, shirt)
	local head = weldPart(m, r, "Head", Vector3.new(1.2, 1.3, 1.2), Vector3.new(0, 1.65, 0), skin, Enum.Material.SmoothPlastic)
	weldPart(m, r, "Beard", Vector3.new(1.1, 0.6, 0.3), Vector3.new(0, 1.2, -0.55), Color3.fromRGB(45, 35, 30))
	weldPart(m, r, "Blood", Vector3.new(0.05, 0.5, 0.35), Vector3.new(-0.61, 1.6, -0.3), Color3.fromRGB(110, 15, 15), Enum.Material.SmoothPlastic)
	for _, x in { -0.27, 0.27 } do
		local eye = weldPart(m, r, "Eye", Vector3.new(0.22, 0.14, 0.05), Vector3.new(x, 1.8, -0.62), Color3.fromRGB(255, 40, 30), Enum.Material.Neon)
		eye.Transparency = 1 -- глаза загораются, когда проснётся
	end
	weldPart(m, r, "LeftArm", Vector3.new(0.8, 2, 0.8), Vector3.new(-1.4, 0, 0), shirt)
	weldPart(m, r, "RightArm", Vector3.new(0.8, 2, 0.8), Vector3.new(1.4, 0, 0), shirt)
	weldPart(m, r, "RightLeg", Vector3.new(0.9, 2.5, 0.9), Vector3.new(0.5, -2.25, 0), pants)
	-- левая нога — протез
	weldPart(m, r, "LeftThigh", Vector3.new(0.9, 0.9, 0.9), Vector3.new(-0.5, -1.45, 0), pants)
	weldPart(m, r, "Prosthesis", Vector3.new(0.3, 1.6, 0.3), Vector3.new(-0.5, -2.7, 0), Color3.fromRGB(150, 150, 155), Enum.Material.Metal)

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15 -- чтобы HipHeight работал для самодельной модели
	hum.HipHeight = BLOCK_HIP_HEIGHT
	hum.Parent = m
	return m
end

local function build(): (Model, BasePart, Humanoid)
	local m: Model
	local custom = ServerStorage:FindFirstChild("SlavikModel")
	if custom and custom:IsA("Model") and custom:FindFirstChildOfClass("Humanoid") and custom:FindFirstChild("HumanoidRootPart") then
		m = custom:Clone()
		m.Name = "Slavik"
	else
		m = buildBlocky()
	end
	local r = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	m.PrimaryPart = r
	r.Anchored = true
	hum.WalkSpeed = Config.SlavikSpeed
	hum.MaxHealth = 1e9
	hum.Health = 1e9
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	-- Красное свечение глаз (включится при пробуждении)
	local head = m:FindFirstChild("Head")
	if head and not head:FindFirstChild("EyeGlow") then
		local glow = Instance.new("PointLight")
		glow.Name = "EyeGlow"
		glow.Color = Color3.fromRGB(255, 30, 20)
		glow.Range = 10
		glow.Brightness = 0
		glow.Parent = head
	end
	return m, r, hum
end

local function loadAnimations(hum: Humanoid)
	table.clear(tracks)
	currentTrack = nil
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = hum
		animator = a
	end
	assert(animator)
	for name, id in Config.SlavikAnimations do
		if id ~= "" then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				track.Looped = name ~= "Attack"
				tracks[name] = track
			end
		end
	end
end

local function playTrack(name: string)
	if currentTrack == name then
		return
	end
	local track = tracks[name]
	if not track then
		return
	end
	if currentTrack then
		local old = tracks[currentTrack]
		if old then
			old:Stop(0.2)
		end
	end
	track:Play(0.2)
	currentTrack = name
end

local function playAttack()
	local t = tracks.Attack
	if t then
		t:Play(0.1)
	end
end

local function playSound(parent: Instance, id: string, looped: boolean, volume: number): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
	s.RollOffMaxDistance = 80
	s.Parent = parent
	s:Play()
	if not looped then
		task.delay(6, function()
			s:Destroy()
		end)
	end
	return s
end

function Slavik.despawn()
	running = false
	if model then
		model:Destroy()
	end
	model, root, humanoid, snore = nil, nil, nil, nil
	table.clear(tracks)
	currentTrack = nil
end

-- Спит на матрасе за сеткой
function Slavik.spawnSleeping(map: MapBuilder.Map)
	Slavik.despawn()
	local m, r, hum = build()
	model, root, humanoid = m, r, hum
	m:PivotTo(CFrame.new(map.SlavikSpot.Position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(math.rad(-90), 0, 0))
	m.Parent = Workspace
	loadAnimations(hum)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Zzz"
	gui.Size = UDim2.fromOffset(80, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Zzz..."
	label.TextScaled = true
	label.Font = Enum.Font.Cartoon
	label.TextColor3 = Color3.fromRGB(220, 220, 255)
	label.Parent = gui
	gui.Parent = r

	snore = playSound(r, Config.Sounds.Snore, true, 0.8)
end

-- ===== Восприятие =====

local function charRoot(player: Player): BasePart?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp and hrp:IsA("BasePart") and hum and hum.Health > 0 then
		return hrp
	end
	return nil
end

local function lineOfSight(from: Vector3, target: BasePart): boolean
	local m = model
	if not m then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { m }
	local targetModel = target.Parent
	if targetModel then
		table.insert(exclude, targetModel)
	end
	params.FilterDescendantsInstances = exclude
	local result = Workspace:Raycast(from, target.Position - from, params)
	return result == nil
end

-- Видит ли Славик игрока прямо сейчас
local function canSee(r: BasePart, player: Player, hrp: BasePart): boolean
	if player:GetAttribute("Hidden") == true then
		return false
	end
	local eye = r.Position + Vector3.new(0, 2, 0)
	local offset = hrp.Position - eye
	local dist = offset.Magnitude
	if dist < Config.SenseRange then
		return lineOfSight(eye, hrp)
	end
	local range = if player:GetAttribute("FlashlightOn") == true then Config.SightRangeFlashlight else Config.SightRange
	if dist > range then
		return false
	end
	local look = r.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local flatDir = Vector3.new(offset.X, 0, offset.Z)
	if flatLook.Magnitude > 0.01 and flatDir.Magnitude > 0.01 then
		local cos = flatLook.Unit:Dot(flatDir.Unit)
		-- фонарик в лицо видно и со спины
		if cos < math.cos(math.rad(Config.SightAngle)) and player:GetAttribute("FlashlightOn") ~= true then
			return false
		end
	end
	return lineOfSight(eye, hrp)
end

-- ===== Передвижение =====

local function computePath(from: Vector3, to: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath({
		AgentRadius = Config.SlavikAgentRadius,
		AgentHeight = 6,
		AgentCanJump = false,
	})
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

local function moveAlong(hum: Humanoid, r: BasePart, waypoints: { PathWaypoint })
	for i = 2, #waypoints do
		local wp = waypoints[i].Position
		if (Vector3.new(wp.X, r.Position.Y, wp.Z) - r.Position).Magnitude > 1.5 then
			hum:MoveTo(wp)
			return
		end
	end
	hum:MoveTo(waypoints[#waypoints].Position)
end

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Просыпается и начинает охоту
function Slavik.wake(map: MapBuilder.Map, ctx: Context)
	if not model or not root or not humanoid then
		Slavik.spawnSleeping(map)
	end
	assert(model and root and humanoid, "Славик не создан")
	local m: Model, r: BasePart, hum: Humanoid = model, root, humanoid

	local zzz = r:FindFirstChild("Zzz")
	if zzz then
		zzz:Destroy()
	end
	if snore then
		snore:Destroy()
		snore = nil
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Eye" then
			p.Transparency = 0
		end
	end
	local head = m:FindFirstChild("Head")
	local glow = head and head:FindFirstChild("EyeGlow")
	if glow and glow:IsA("PointLight") then
		glow.Brightness = 3
	end
	playSound(r, Config.Sounds.Wake, false, 2)

	-- Встаёт (пока поднимается — фора игрокам)
	local spot = map.SlavikSpot.Position
	local standY = hum.HipHeight + r.Size.Y / 2
	m:PivotTo(CFrame.lookAt(spot + Vector3.new(0, standY, 0), spot + Vector3.new(0, standY, 10)))
	running = true

	task.spawn(function()
		local base = r.CFrame
		local t0 = os.clock()
		while running and os.clock() - t0 < Config.WakeUpDelay do
			r.CFrame = base * CFrame.new((math.random() - 0.5) * 0.3, 0, (math.random() - 0.5) * 0.3)
			task.wait(0.05)
		end
		if not running then
			return
		end
		r.CFrame = base
		r.Anchored = false
		r:SetNetworkOwner(nil)

		local state = "Patrol"
		local chaseTarget: Player? = nil
		local lastSeenPos: Vector3? = nil
		local lastSeenTime = -math.huge
		local searchUntil = 0
		local searchPoint: Vector3? = nil
		local investigatePos: Vector3? = nil
		local patrolTarget: Vector3? = nil
		local lastDoorHit = 0
		local lastKnock = os.clock()
		local lastPos = r.Position
		local stuckSince = os.clock()

		-- Идти к точке; если путь закрыт дверью — ломать дверь
		local function goTo(goal: Vector3)
			local waypoints = computePath(r.Position, goal)
			if waypoints then
				moveAlong(hum, r, waypoints)
				return
			end
			-- Пути нет: ищем закрытую дверь, через которую короче всего
			local bestDoor: BasePart? = nil
			local bestCost = math.huge
			for _, door in Doors.closedDoors() do
				local cost = (door.Position - r.Position).Magnitude + (door.Position - goal).Magnitude
				if cost < bestCost then
					bestCost = cost
					bestDoor = door
				end
			end
			-- ломать дверь есть смысл, только если она примерно по пути
			local direct = (goal - r.Position).Magnitude
			if not bestDoor or bestCost > direct * 1.8 + 30 then
				hum:MoveTo(goal)
				return
			end
			local approach = Doors.approachPoint(bestDoor, r.Position)
			if flatDist(approach, r.Position) > 3.5 then
				local toDoor = computePath(r.Position, approach)
				if toDoor then
					moveAlong(hum, r, toDoor)
				else
					hum:MoveTo(approach)
				end
			else
				-- стоит у двери: поворачивается и бьёт
				hum:MoveTo(r.Position)
				local now = os.clock()
				if now - lastDoorHit > Config.DoorHitInterval then
					lastDoorHit = now
					playAttack()
					playSound(r, Config.Sounds.DoorHit, false, 1.5)
					local broke = Doors.damage(bestDoor, Config.DoorHitDamage)
					ctx.onDoorHit(bestDoor, broke)
				end
			end
		end

		while running and m.Parent do
			local now = os.clock()

			-- 1) Поймал?
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("Caught") ~= true then
					local hrp = charRoot(player)
					local hidden = player:GetAttribute("Hidden") == true
					local exposed = not hidden or player:GetAttribute("SeenHiding") == true
					if hrp and exposed and (hrp.Position - r.Position).Magnitude < Config.CatchDistance + (if hidden then 2 else 0) then
						playAttack()
						ctx.onCatch(player)
					end
				end
			end

			-- 2) Кого видит
			local seen: Player? = nil
			local seenRoot: BasePart? = nil
			local seenDist = math.huge
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("Caught") ~= true then
					local hrp = charRoot(player)
					if hrp then
						local visible = canSee(r, player, hrp)
						-- видел, как залез в шкаф — «видит» и в шкафу
						if player:GetAttribute("SeenHiding") == true then
							visible = true
						end
						local d = (hrp.Position - r.Position).Magnitude
						if visible and d < seenDist then
							seen, seenRoot, seenDist = player, hrp, d
						end
					end
				end
			end

			-- Цель погони только что залезла в шкаф у него на глазах?
			local target = chaseTarget
			if target and target:GetAttribute("Hidden") == true and target:GetAttribute("SeenHiding") ~= true
				and now - lastSeenTime < 1.2 then
				target:SetAttribute("SeenHiding", true)
			end

			if seen and seenRoot then
				state = "Chase"
				chaseTarget = seen
				lastSeenPos = seenRoot.Position
				lastSeenTime = now
				investigatePos = nil
			elseif state == "Chase" and now - lastSeenTime > Config.LoseSightTime then
				-- потерял: идёт туда, где видел, и обыскивает
				state = "Search"
				searchUntil = now + Config.SearchTime
				searchPoint = lastSeenPos
				chaseTarget = nil
			end

			-- 3) Слух (если не гонится)
			if state ~= "Chase" then
				local noise = Noise.loudestHeardFrom(r.Position)
				if noise then
					state = "Investigate"
					investigatePos = noise.position
				end
			end

			-- 4) Действие
			if state == "Chase" then
				hum.WalkSpeed = Config.SlavikChaseSpeed
				local goal = if seenRoot then seenRoot.Position else lastSeenPos
				-- если цель в шкафу — идём к точке перед шкафом (внутрь шкафа путь не строится)
				if goal and seen and seen:GetAttribute("Hidden") == true then
					local away = r.Position - goal
					local flat = Vector3.new(away.X, 0, away.Z)
					if flat.Magnitude > 0.1 then
						goal = goal + flat.Unit * 3
					end
				end
				if goal then
					if seenRoot and seenDist < 12 and seen and seen:GetAttribute("Hidden") ~= true then
						hum:MoveTo(goal) -- рядом и видит — прямо на тебя
					else
						goTo(goal)
					end
				end
			elseif state == "Investigate" and investigatePos then
				hum.WalkSpeed = Config.SlavikSpeed + 3
				if flatDist(investigatePos, r.Position) < 4 then
					state = "Search"
					searchUntil = now + Config.SearchTime
					searchPoint = investigatePos
					investigatePos = nil
				else
					goTo(investigatePos)
				end
			elseif state == "Search" then
				hum.WalkSpeed = Config.SlavikSpeed
				if now > searchUntil or not searchPoint then
					state = "Patrol"
					patrolTarget = nil
				else
					local sp = searchPoint :: Vector3
					if flatDist(sp, r.Position) < 3 or now - lastSeenTime > Config.LoseSightTime + 1 then
						-- осматривается: случайная точка рядом
						if math.random() < 0.3 then
							searchPoint = sp + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
						end
					end
					goTo(searchPoint :: Vector3)
				end
			else
				-- Патруль
				hum.WalkSpeed = Config.SlavikSpeed
				if not patrolTarget or flatDist(patrolTarget, r.Position) < 3 then
					local points = map.PatrolPoints
					if #points > 0 then
						patrolTarget = points[math.random(1, #points)].Position
					end
				end
				if patrolTarget then
					goTo(patrolTarget)
				end
				-- бродит рядом с домом — стучит в окна
				if now - lastKnock > Config.KnockInterval
					and flatDist(map.HouseInterior.Position, r.Position) < 30 then
					lastKnock = now
					playSound(r, Config.Sounds.Knock, false, 1.5)
					ctx.onKnock()
				end
			end

			-- 5) Застрял? Шаг в случайную сторону
			if (r.Position - lastPos).Magnitude > 1 then
				lastPos = r.Position
				stuckSince = now
			elseif now - stuckSince > 2.5 and (now - lastDoorHit) > 3 then
				hum:MoveTo(r.Position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)))
				stuckSince = now
				patrolTarget = nil
			end

			-- 6) Анимация
			local speed = Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z).Magnitude
			if speed < 1 then
				playTrack("Idle")
			elseif speed > Config.SlavikSpeed + 2 then
				playTrack(if tracks.Run then "Run" else "Walk")
			else
				playTrack("Walk")
			end

			task.wait(Config.PathRecompute)
		end
	end)
end

-- Для GameLoop: где Славик сейчас
function Slavik.getPosition(): Vector3?
	return if root then root.Position else nil
end

return Slavik
