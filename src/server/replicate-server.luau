-- see comment in src/shared/replicate-shared.luau

local maid = require("../shared/maid").new("dlcomp-replicate-server")
local replicate = require("../shared/replicate-shared")
local network = require("./network-server")
local activator = require("../shared/activator").new("dlcomp-replicate-server")
local metronome = require("../shared/metronome")

local module = {
	maid = maid,
}
maid["activator-players"] = activator

-- config
local team_change_scan_frequency = 4 -- in seconds

local state = replicate.generate_state()

local function network_subscribed(message_name: string, ...: any)
	network.send_username(activator:GetSubscribers(), message_name, ...)
end

local function set_player_state(username: string, value: replicate.player_info?)
	state.players[username] = value
	network_subscribed(replicate.NETWORK_UPDATE, username, value)
end
local function send_spawn(username: string)
	network_subscribed(replicate.NETWORK_SPAWN, username)
end
local function send_despawn(username: string)
	network_subscribed(replicate.NETWORK_DESPAWN, username)
end
local function set_map(map: string)
	state.map = map
	network_subscribed(replicate.NETWORK_MAP, map)
end


local function player_init(player: player)
	network.send(player, replicate.NETWORK_INITAL, state)
end

local function create_info(player: player): replicate.player_info
	return {
		id = player.player_id,
		username = player.name,
		team = player.get_team(),
	}
end

local function add_player(username: string)
	local player = players.get(username)
	if not player then
		warn(`dlcomp-replicate.add_player no player found with username {username}`)
		return
	end

	set_player_state(username, create_info(player))
end

-- check if the player has changed teams, update them if they have
local function update_team_maybe(username: string): boolean
	local existing = state.players[username]
	if not existing then
		add_player(username)	
		return true
	end

	local player = players.get(username)
	if not player then
		warn(`dlcomp-replicate.update_team_maybe: username does not have player object: {username}`)
		return false
	end

	if existing.team == player.get_team() then
		return false
	end
	existing.team = player.get_team()
	set_player_state(username, existing)
	return true
end

activator.OnEnable:Connect(function()
	state = replicate.generate_state()

	-- add existing players
	for _, plr in players.get_all() do
		add_player(plr.name)
	end

	-- player joined/left
	activator.maid["signal-joined"] = on_player_joined:Connect(add_player)
	activator.maid["signal-left"] = on_player_left:Connect(function(username: string)
		activator:Remove(username) -- unsubscribe
		set_player_state(username, nil) -- remove from state
	end)

	-- player spawned/died
	activator.maid["signal-spawned"] = on_player_spawned:Connect(function(username: string)
		update_team_maybe(username)
		send_spawn(username)
	end)
	activator.maid["signal-died"] = on_player_died:Connect(function(username: string)
		send_despawn(username)
	end)

	-- check for team changes
	activator.maid["metronome-team_changes"] = metronome.new(team_change_scan_frequency, function()
		for _, player in players.get_all() do
			update_team_maybe(player.name)
		end
	end)

	-- map changed
	activator.maid["signal-map_changed"] = game_data.map_code.changed:Connect(set_map)
end)

-- subscribe/unsubscribe requests
maid["network-subscribe"] = network.listen(replicate.NETWORK_SUBSCRIBE, function(player: player, ...)
	activator:Subscribe(player.name)
	player_init(player)
end)
maid["network-unsubscribe"] = network.listen(replicate.NETWORK_UNSUBSCRIBE, function(player: player, ...)
	activator:Remove(player.name)
end)

return module
