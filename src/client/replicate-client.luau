-- see comment in src/shared/replicate-shared.luau

local replicate = require("../shared/replicate-shared")
local network = require("./network-client")
local activator = require("../shared/activator").new("dlcomp-replicate-client")

local module = {
	state = replicate.generate_state(),
	self_info = nil :: replicate.player_info?,
	is_loaded = false,
	
	signal_inital = Signal.new(),
	signal_player_update = Signal.new() :: Signal<string>,
	signal_player_spawn = Signal.new() :: Signal<string>,
	signal_player_despawn = Signal.new() :: Signal<string>,
	signal_map = Signal.new() :: Signal<string>,

	activator = activator,
}

export type player_info = replicate.player_info

activator.OnEnable:Connect(function()
	network.send(replicate.NETWORK_SUBSCRIBE)

	activator.maid["network-init"] = network.listen(replicate.NETWORK_INITAL, function(new_state: replicate.state)
		module.state = new_state
		module.self_info = new_state.players[local_player]
		module.signal_inital:Fire()
	end)

	activator.maid["network-update"] = network.listen(replicate.NETWORK_UPDATE, function(username: string, info: replicate.player_info?)
		module.state.players[username] = info
		if username == local_player then
			module.self_info = info
		end
		module.signal_player_update:Fire(username)
	end)

	activator.maid["network-spawn"] = network.listen(replicate.NETWORK_SPAWN, function(username: string)
		module.signal_player_spawn:Fire(username)
	end)
	activator.maid["network-despawn"] = network.listen(replicate.NETWORK_DESPAWN, function(username: string)
		module.signal_player_despawn:Fire(username)
	end)

	activator.maid["network-map"] = network.listen(replicate.NETWORK_MAP, function(map_name: string)
		module.signal_map:Fire(map_name)
	end)
end)

activator.OnDisable:Connect(function()
	module.is_loaded = false
	network.send(replicate.NETWORK_UNSUBSCRIBE)

	module.state = replicate.generate_state()
	module.self_info = nil
end)

return module
