-- calls a callback once every n seconds
-- used for: fixed timestep, rare updates, prolly countdown soon

local maid = require("./maid").new("dlcomp-metronome")
local dlcomp_table = require("./table")

local module = {
	maid = maid
}

local instances: {[number]: metronome_data} = {}
local _cur_id = 0

type metronome_data = {
	callback: () -> (),
	delay: number,
	timer: number,
}

-- TODO: dlcomp-bundler currently keeps all global functions in the namespace at the same time
-- turn this into a normal global function once thats fixed
local enable: () -> ()

function module.new(delay_seconds: number, callback: () -> ())
	-- enable heartbeat if it wasnt already
	if dlcomp_table.is_empty(instances) then
		enable()
	end
	
	-- create object
	_cur_id += 1
	local id = _cur_id
	instances[id] = {
		callback = callback,
		delay = delay_seconds,
		timer = 0,
	}

	-- callback to destroy the object
	return function()
		instances[id] = nil
		if dlcomp_table.is_empty(instances) then
			maid:DoCleaning()
		end
	end
end

local function tick_instance(instance: metronome_data, dt: number)
	instance.timer += dt
	if instance.timer >= instance.delay then
		instance.callback()
		instance.timer %= instance.delay -- only let the instance be ticked at most once a frame
	end
end

enable = function()
	local last_tick = tick()
	maid["signal-hearbeat"] = time.heartbeat("dlcomp-metronome", function()
		local cur_time = tick()
		local dt = cur_time - last_tick
		last_tick = cur_time
	
		for _, data in instances do
			tick_instance(data, dt)
		end
	end)
end

return module
