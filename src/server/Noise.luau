--!strict
-- Шум. Всё громкое (бег, генератор, удары, хлопок дверью) сообщает сюда,
-- а Славик забирает самый громкий шум, который он услышал.

local Noise = {}

export type Event = {
	position: Vector3,
	radius: number, -- на каком расстоянии слышно
	time: number,
}

local events: { Event } = {}
local LIFETIME = 1.5 -- шум «висит» полторы секунды

function Noise.emit(position: Vector3, radius: number)
	table.insert(events, { position = position, radius = radius, time = os.clock() })
end

-- Самый «сильный» шум, который слышно из точки listener (или nil)
function Noise.loudestHeardFrom(listener: Vector3): Event?
	local now = os.clock()
	local best: Event? = nil
	local bestScore = 0
	for i = #events, 1, -1 do
		local e = events[i]
		if now - e.time > LIFETIME then
			table.remove(events, i)
		else
			local dist = (e.position - listener).Magnitude
			if dist <= e.radius then
				local score = 1 - dist / e.radius -- чем ближе и громче, тем важнее
				if score > bestScore then
					bestScore = score
					best = e
				end
			end
		end
	end
	return best
end

function Noise.clear()
	table.clear(events)
end

return Noise
