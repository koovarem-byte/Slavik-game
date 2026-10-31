--!strict
-- Все цифры игры в одном месте. Меняй тут — остальной код трогать не нужно.

local Config = {
	-- ===== Игроки и лобби =====
	MinPlayers = 1, -- для теста одному = 1. Для настоящей игры поставь 2
	LobbyCountdown = 10, -- секунд до начала матча

	-- ===== Футбол =====
	FootballDuration = 300, -- сек. Если Славика так и не разбудили — он просыпается сам, когда стемнеет
	KickRange = 6, -- как близко надо стоять к мячу, чтобы ударить
	KickCooldown = 0.4, -- пауза между ударами одного игрока
	KickChargeTime = 1.0, -- сколько держать кнопку для удара на полную силу
	KickMinSpeed = 35, -- слабый удар (пас)
	KickMaxSpeed = 95, -- самый сильный удар
	KickMinLift = 6, -- насколько мяч подлетает при слабом ударе
	KickMaxLift = 38, -- ...и при сильном (сильный удар легко перелетит сетку!)
	DribbleRange = 3.2, -- если бежишь в мяч — он катится перед тобой
	DribbleBoost = 1.15,
	OutResetDelay = 2, -- через сколько секунд мяч из аута возвращается в центр
	GoalResetDelay = 2,

	-- ===== Сон Славика (0..100, на 100 он просыпается) =====
	AngerPerBallOverFence = 34, -- 3 мяча за сетку = Славик встал
	AngerNearRadius = 20, -- радиус, в котором Славик «слышит» шаги
	AngerPerSecondRunningNear = 12, -- бежишь рядом с ним
	AngerPerSecondWalkingNear = 2, -- крадёшься рядом с ним
	AngerDecayPerSecond = 0.5, -- потихоньку успокаивается
	RunningSpeedThreshold = 10, -- быстрее этого = «бежит»
	NormalSpeed = 16,
	SneakSpeed = 7, -- скорость, когда крадёшься (C / Ctrl / кнопка)

	-- ===== Хоррор =====
	SurviveDuration = 480, -- запасной вариант: продержались до рассвета (8 мин) = тоже победа
	WakeUpDelay = 4, -- сколько секунд Славик поднимается (фора, чтобы убежать)
	SlavikSpeed = 11, -- бродит / идёт на звук
	SlavikChaseSpeed = 18, -- гонится (быстрее игрока при беге 16 — нельзя просто убегать по прямой)
	SlavikAgentRadius = 1.5, -- «толщина» Славика для поиска пути (больше = не пролезет в калитку/дверь)
	CatchDistance = 4,
	PathRecompute = 0.3, -- как часто пересчитывать путь (сек)

	-- Зрение и слух Славика
	SightRange = 45, -- видит игрока без фонарика
	SightRangeFlashlight = 90, -- видит игрока с включённым фонариком
	SightAngle = 70, -- полуугол обзора в градусах (70 = конус 140°)
	SenseRange = 9, -- так близко чует даже за спиной
	LoseSightTime = 3, -- сколько секунд помнит, куда ты убежал
	SearchTime = 7, -- сколько секунд обыскивает место, где потерял
	InvestigateArriveDistance = 6, -- так близко к источнику шума = «дошёл, проверяю»
	InvestigateTimeout = 10, -- не дошёл до шума за столько секунд (и шум не повторился) = бросает и обыскивает
	NoiseRunRadius = 35, -- бег слышно на таком расстоянии
	NoiseInterval = 0.5,
	KnockInterval = 14, -- если бродит рядом с домом — стучит в окна

	-- Двери
	DoorMaxHP = 100, -- входная/задняя дверь
	InnerDoorMaxHP = 50, -- двери внутри дома / сарая
	DoorHitDamage = 12,
	DoorHitInterval = 1.4,
	DoorRepairAmount = 25,
	DoorRepairHold = 1.5, -- сколько держать R, чтобы подпереть дверь
	DoorSlamNoise = 25, -- хлопнул дверью — слышно на таком расстоянии

	-- Шкафы
	HideMaxTime = 25, -- дольше в шкафу не высидишь — душно
	HideCooldown = 8,

	-- Фонарик (Q)
	FlashlightRange = 45,
	FlashlightBrightness = 3,
	FlashlightAngle = 50,

	-- ===== Побег на Ниве =====
	ItemPickupHold = 0.6,
	CarInstallHold = 3, -- вставить ключи / залить бензин / поставить аккумулятор
	CarInstallNoise = 30,
	GeneratorStartHold = 3,
	GeneratorChargeTime = 25, -- сколько заряжается аккумулятор (генератор шумит всё это время)
	GeneratorNoise = 70, -- генератор слышно очень далеко
	CarStartHold = 4,
	CarStartNoise = 80,
	EscapeCountdown = 6, -- сколько секунд ждём остальных после «завести»
	EscapeRadius = 18, -- кто в этом радиусе от машины — уехал

	EndScreenDuration = 10,

	-- ===== Время суток (Lighting.ClockTime) =====
	EveningStart = 17.6,
	EveningEnd = 20.3,
	NightTime = 0.2,

	-- ===== Звуки =====
	-- Вставь сюда ID звуков из Creator Store (только с разрешением на использование),
	-- например "rbxassetid://1234567". Пустая строка = звука нет.
	Sounds = {
		Snore = "", -- храп Славика
		Wake = "", -- рёв, когда проснулся
		Knock = "", -- стук в окно
		DoorHit = "", -- удар в дверь
		Caught = "", -- скример
		Kick = "", -- удар по мячу
		Ambient = "", -- фон ночью (сверчки, ветер)
		Generator = "", -- тарахтение генератора (зациклено)
		CarStart = "", -- машина заводится
		Pickup = "", -- взял предмет
	},

	-- ===== Анимации Славика =====
	-- Когда появится настоящая модель (ServerStorage.SlavikModel), вставь сюда ID анимаций.
	SlavikAnimations = {
		Idle = "",
		Walk = "",
		Run = "",
		Attack = "",
	},
}

return Config
