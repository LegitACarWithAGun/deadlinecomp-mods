local module = {}

function module.cig_bind_hold(cig: ClientInputGroup, key: keybind_name, on_change: (boolean)->())
	cig:bind_user_setting(function()
		on_change(true)
	end, InputType.Began, key)
	
	cig:bind_user_setting(function()
		on_change(false)
	end, InputType.Ended, key)
end

function module.cig_bind_double_axis(cig: ClientInputGroup, negative_keys: {keybind_name}, positive_keys: {keybind_name}, on_change: (number)->()): ()
	local press_times = {}
	local value_lookup = {} -- TODO: very space inefficent

	local function hold_changed(key: keybind_name, holding: boolean)
		press_times[key] = holding and tick() or nil

		local latest_key
		local latest_time = -1
		for k, t in press_times do
			if t > latest_time then
				latest_key = k
			end
		end

		local output = latest_key and value_lookup[latest_key] or 0
		on_change(output)
	end

	-- TODO: just a single loop would be preffered
	for _, key in negative_keys do
		module.cig_bind_hold(cig, key, function(holding: boolean)
			hold_changed(key, holding)
		end)
		value_lookup[key] = -1
	end
	for _, key in positive_keys do
		module.cig_bind_hold(cig, key, function(holding: boolean)
			hold_changed(key, holding)
		end)
		value_lookup[key] = 1
	end
end

return module
