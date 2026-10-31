--!strict
-- Все двери на карте (тег SlavikDoor).
-- Дверь = деталь. Петля — левый край (локальная -X). Атрибуты (необязательно):
--   OpenAngle — угол открытия в градусах (по умолчанию -90)
--   MaxHP     — прочность (по умолчанию Config.DoorMaxHP)
-- E — открыть/закрыть, держать R — подпереть (чинит). Славик выбивает закрытые двери.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Noise = require(script.Parent.Noise)

type DoorState = {
	part: BasePart,
	closedCF: CFrame,
	openCF: CFrame,
	closed: boolean,
	broken: boolean,
	hp: number,
	maxHP: number,
	toggle: ProximityPrompt,
	repair: ProximityPrompt,
	lastRepair: { [Player]: number },
}

local Doors = {}

local doors: { DoorState } = {}
local byPart: { [BasePart]: DoorState } = {}

local function updatePrompts(d: DoorState)
	d.toggle.Enabled = not d.broken
	d.toggle.ActionText = if d.closed then "Открыть" else "Закрыть"
	d.repair.Enabled = d.closed and not d.broken and d.hp < d.maxHP
	local pct = math.floor(d.hp / d.maxHP * 100 + 0.5)
	d.toggle.ObjectText = "Дверь " .. pct .. "%"
	d.repair.ObjectText = "Дверь " .. pct .. "%"
	d.part:SetAttribute("HP", d.hp)
end

local function setClosed(d: DoorState, closed: boolean)
	if d.broken then
		return
	end
	d.closed = closed
	TweenService:Create(d.part, TweenInfo.new(0.3), { CFrame = if closed then d.closedCF else d.openCF }):Play()
	if closed then
		Noise.emit(d.part.Position, Config.DoorSlamNoise)
	end
	updatePrompts(d)
end

local function breakDoor(d: DoorState)
	d.broken = true
	d.closed = false
	d.hp = 0
	d.part.CanCollide = false
	-- выбитая дверь падает плашмя
	local fallen = d.closedCF * CFrame.new(0, -d.part.Size.Y / 2 + 0.3, 2.5) * CFrame.Angles(math.rad(90), 0, 0)
	TweenService:Create(d.part, TweenInfo.new(0.4), { CFrame = fallen, Transparency = 0.2 }):Play()
	updatePrompts(d)
end

local function setup(part: BasePart)
	local closedCF = part.CFrame
	local hinge = closedCF * CFrame.new(-part.Size.X / 2, 0, 0)
	local angleAttr = part:GetAttribute("OpenAngle")
	local angle = if typeof(angleAttr) == "number" then angleAttr else -90
	local openCF = hinge * CFrame.Angles(0, math.rad(angle), 0) * hinge:ToObjectSpace(closedCF)
	local hpAttr = part:GetAttribute("MaxHP")
	local maxHP = if typeof(hpAttr) == "number" then hpAttr else Config.DoorMaxHP

	part.Anchored = true

	local toggle = Instance.new("ProximityPrompt")
	toggle.KeyboardKeyCode = Enum.KeyCode.E
	toggle.MaxActivationDistance = 8
	toggle.RequiresLineOfSight = false
	toggle.Parent = part

	local repair = Instance.new("ProximityPrompt")
	repair.ActionText = "Подпереть"
	repair.KeyboardKeyCode = Enum.KeyCode.R
	repair.HoldDuration = Config.DoorRepairHold
	repair.MaxActivationDistance = 8
	repair.RequiresLineOfSight = false
	repair.Parent = part

	local d: DoorState = {
		part = part,
		closedCF = closedCF,
		openCF = openCF,
		closed = false,
		broken = false,
		hp = maxHP,
		maxHP = maxHP,
		toggle = toggle,
		repair = repair,
		lastRepair = {},
	}

	toggle.Triggered:Connect(function()
		setClosed(d, not d.closed)
	end)
	repair.Triggered:Connect(function(player)
		local now = os.clock()
		if (d.lastRepair[player] or 0) + 1 > now or d.broken or not d.closed then
			return
		end
		d.lastRepair[player] = now
		d.hp = math.min(d.maxHP, d.hp + Config.DoorRepairAmount)
		updatePrompts(d)
	end)

	table.insert(doors, d)
	byPart[part] = d
end

function Doors.init(list: { BasePart })
	for _, part in list do
		setup(part)
	end
	Doors.reset()
end

-- Все двери открыты и целые
function Doors.reset()
	for _, d in doors do
		d.broken = false
		d.closed = false
		d.hp = d.maxHP
		d.part.CanCollide = true
		d.part.Transparency = 0
		d.part.CFrame = d.openCF
		table.clear(d.lastRepair)
		updatePrompts(d)
	end
end

function Doors.closedDoors(): { BasePart }
	local result: { BasePart } = {}
	for _, d in doors do
		if d.closed and not d.broken then
			table.insert(result, d.part)
		end
	end
	return result
end

function Doors.isClosed(part: BasePart): boolean
	local d = byPart[part]
	return d ~= nil and d.closed and not d.broken
end

-- Ударить дверь. Возвращает true, если дверь выбита этим ударом.
function Doors.damage(part: BasePart, amount: number): boolean
	local d = byPart[part]
	if not d or not d.closed or d.broken then
		return false
	end
	d.hp -= amount
	-- (шум от ударов не нужен: бьёт сам Славик, иначе он «услышит» сам себя)
	if d.hp <= 0 then
		breakDoor(d)
		return true
	end
	updatePrompts(d)
	return false
end

-- Точка перед дверью со стороны from (куда встать, чтобы ломиться)
function Doors.approachPoint(part: BasePart, from: Vector3): Vector3
	local d = byPart[part]
	local cf = if d then d.closedCF else part.CFrame
	local normal = cf.LookVector
	local side = if (from - cf.Position):Dot(normal) >= 0 then 1 else -1
	local p = cf.Position + normal * side * 3.5
	return Vector3.new(p.X, cf.Position.Y - part.Size.Y / 2, p.Z)
end

return Doors
