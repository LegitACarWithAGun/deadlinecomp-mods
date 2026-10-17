local replicate = require("./replicate-client")
local activator = require("../shared/activator").new("dlcomp-avatar")
local dlcomp_table = require("../shared/table")
local metronome = require("../shared/metronome")

local module = {
	--- key is username, value is model
	spawned_players = {} :: {[string]: luauInstance},
	--- fires with username, model
	signal_model_loaded = Signal.new() :: Signal<string, luauInstance>,
	signal_avatar_removed = Signal.new() :: Signal<string, luauInstance>,

	TAG_DESTROY_ON_KILL = "dlcomp-avatar-autodestroy",

	activator = activator,
}

local function add_from_avatar(avatar: luauInstance)
	local id = tonumber(avatar.Name)
	if not id then
		warn(`dlcomp-avatar failed to parse model name as number {avatar.Name}`)
		return
	end

	local info = dlcomp_table.find_first_value_callback(replicate.state.players, function(info: replicate.player_info): boolean
		return info.id == id
	end)
	if not info then
		warn(`cant find player from id {id}`)
		return
	end

	local username = info.username
	module.spawned_players[username] = avatar
	module.signal_model_loaded:Fire(username, avatar)
end

local function remove_player_model(username: string)
	if username == local_player then return end

	local model = module.spawned_players[username]
	if not model then
		warn("despawning player, but they didnt have a model set?")
	end

	-- update
	module.spawned_players[username] = nil
	module.signal_avatar_removed:Fire(username, model)

	-- clean up ragdoll
	for _, instance in model.get_descendants() do
		local tags = instance.get_tags()
		if not dlcomp_table.contains(tags, module.TAG_DESTROY_ON_KILL) then
			continue
		end
		instance.destroy()
	end
end

-- TODO: really inefficent
local function scan_folder()
	-- scan for changes
	local new_avatars = {}
	local players_list = dlcomp_table.get_keys(module.spawned_players)
	for _, avatar in get_chars_root().get_children() do
		if avatar.Name == "StarterCharacter" then continue end

		local username = dlcomp_table.find_first_callback(module.spawned_players, function(existing: luauInstance): boolean
			return existing.Name == avatar.Name
		end)
		if not username then
			-- new avatar, make sure new avatars only get added after the old one is removed
			table.insert(new_avatars, avatar)
			continue
		end
		
		dlcomp_table.remove_value(players_list, username)
	end

	-- remove avatars not used
	for _, username in players_list do
		remove_player_model(username)
	end

	-- add new avatars
	for _, avatar in new_avatars do
		add_from_avatar(avatar)
	end
end

activator.OnEnable:Connect(function()
	activator:Bind(replicate.activator)

	activator.maid["replicate-init"] = replicate.signal_inital:Connect(scan_folder)
	activator.maid["replicate-despawn"] = replicate.signal_player_despawn:Connect(remove_player_model)

	activator.maid["metronome-folder_scan"] = metronome.new(1, scan_folder)
end)

return module
