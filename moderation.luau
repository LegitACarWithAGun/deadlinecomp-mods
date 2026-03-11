--!strict

-- load command bot
if not shared.dlcomp_command_bot then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/command-bot.luau")
end
-- load arg parser module
if not shared.dlcomp_parser then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/arg-parser.luau")
end

local banned_players: {string} = {}

shared.dlcomp_command_bot.add_command("ban", "bans a player from the server", function(args: string)
	local player, _ = shared.dlcomp_parser.get_player(args)
	if not player then
		return "unclear target player"
	end

	table.insert(banned_players, player.name)
	player.kick()
	return `banned {player.name}`
end)

shared.dlcomp_command_bot.add_command("unban", "unbans a player from the server", function(args: string)
	local username_input, _ = shared.dlcomp_parser.get_string(args)

	local match_list = shared.dlcomp_table.partial_match(banned_players, username_input)
	if #match_list ~= 1 then
		return `unclear target player [{username_input}]`
	end
	local selected = match_list[1]

	shared.dlcomp_table.remove_value(banned_players, selected)
	return `unbanned [{selected}]`
end)

shared.dlcomp_command_bot.add_command("kick", "kicks a person from the server", function(args: string)
	local player, info = shared.dlcomp_parser.get_player(args)
	if not player then
		return `unclear target player [{info.converted_from}]`
	end
	player.kick()
	return `kicked {player.name}`
end)

shared.dlcomp_command_bot.add_command("kick_except", "kicks everyone except admins and a list of players ", function(args: string)
	-- dont allow admins to get kicked
	local exception_list = table.clone(shared.dlcomp_command_bot.admin_list)

	-- collect user-specified exceptions
	while true do
		local player, info = shared.dlcomp_parser.get_player(args)

		if info.converted_from == "" then
			-- no more inputs
			break
		end
		if player == nil then
			-- dont know who theyre reffering to
			chat.send_announcement(`unclear player: [{info.converted_from}]`)
			continue
		end

		table.insert(exception_list, player.name)
		args = info.remaining_text
	end

	-- get all players not in the exception list
	local to_kick = shared.dlcomp_table.filter(players.get_all(), function(player: player): boolean
		return not shared.dlcomp_table.contains(exception_list, player.name)
	end)

	-- kick them
	info("kicking players:")
	for _, player in to_kick do
		player.kick()
		print(`- {player.name}`)
	end

	return `kicked {#to_kick} players`
end)

shared.dlcomp_command_bot.add_command("respawn", "respawns a player if theyre alive", function(args: string)
	local player, _ = shared.dlcomp_parser.get_player(args)
	if not player then
		return "unclear target player"
	end

	if player.is_alive() then
		player.respawn()
		return `respawned [{player.name}]`
	else
		return `[{player.name}] isnt spawned`
	end
end)

shared.dlcomp_command_bot.add_command("kill", "kills a specific player", function(args: string)
	local player, _ = shared.dlcomp_parser.get_player(args)
	if not player then
		return "unclear target player"
	end

	player.kill()
	return `killed [{player.name}]`
end)

-- kick any banned players that try to rejoin
on_player_joined:Connect(function(username: string)
	if not table.find(banned_players, username) then
		return
	end

	local player = players.get(username)
	if not player then
		error(`failed to get the player object of a rejoining banned player [{username}]`)
		return
	end

	player.kick()
end)
