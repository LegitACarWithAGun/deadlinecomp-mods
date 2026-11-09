local replicate = require("./replicate-client")
local activator = require("../shared/activator").new("dlcomp-avatar")
local dlcomp_table = require("../shared/table")
local metronome = require("../shared/metronome")

local module = {
	--- key is username, value is model
	spawned_players = {} :: {[string]: luauInstance},
	--- fires with username, model
	avatar_loaded = Signal.new() :: Signal<string, luauInstance>,
	avatar_removed = Signal.new() :: Signal<string, luauInstance?>,

	TAG_DESTROY_ON_KILL = "dlcomp-avatar-autodestroy",

	activator = activator,
}

--- expected attribute values are (username: string) | true
local ATTRIBUTE_INSTANCE_TRACK = "dlcomp-avatar"

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
	module.avatar_loaded:Fire(username, avatar)

	avatar.set_attribute(ATTRIBUTE_INSTANCE_TRACK, username)
end

local function remove_player_avatar(username: string)
	if username == local_player then return end

	local model = module.spawned_players[username]

	-- update
	module.spawned_players[username] = nil
	module.avatar_removed:Fire(username, model)

	-- clean up ragdoll
	if not model then return end
	for _, instance in model.get_descendants() do
		local tags = instance.get_tags()
		if not dlcomp_table.contains(tags, module.TAG_DESTROY_ON_KILL) then continue end
		instance.destroy()
	end
end

local function scan_folder()
	-- scan for changes
	local new_avatars = {}
	local players_without_avatar = table.clone(module.spawned_players)
	for _, avatar in get_chars_root().get_children() do

		-- ignore the object if we've seen it before
		local tracker = avatar.get_attribute(ATTRIBUTE_INSTANCE_TRACK)
		-- misc object
		if tracker == true then continue end
		-- avatar, mark it as found
		if type(tracker) == "string" then
			players_without_avatar[tracker] = nil
			continue
		end
		-- unknown, report to user and default to misc object
		if tracker ~= nil then
			warn(`dlcomp-avatar.scan_folder: unknown tracker value for {avatar}: {tracker}`)
			avatar.set_attribute(ATTRIBUTE_INSTANCE_TRACK, true) -- default to ignore
			continue
		end

		-- we've not seen this object yet, handle it
		if avatar.Name == "StarterCharacter" or not avatar.find_first_child("humanoid_root_part") then
			-- not a third person avatar, ignore
			avatar.set_attribute(ATTRIBUTE_INSTANCE_TRACK, true)
			continue
		else
			-- third person avatar, add it after removing the old ones
			table.insert(new_avatars, avatar)
		end
	end

	-- the avatar for these players wasnt found in the folder, so remove them
	for username, _ in players_without_avatar do
		remove_player_avatar(username)
	end

	-- add the new avatars
	for _, avatar in new_avatars do
		add_from_avatar(avatar)
	end
end

activator.OnEnable:Connect(function()
	activator:Bind(replicate.activator)

	activator.maid["replicate-init"] = replicate.signal_inital:Connect(scan_folder)
	activator.maid["replicate-despawn"] = replicate.signal_player_despawn:Connect(remove_player_avatar)

	activator.maid["metronome-folder_scan"] = metronome.new(1, scan_folder)
end)

return module
