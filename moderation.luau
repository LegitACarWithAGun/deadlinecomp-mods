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

shared.dlcomp_command_bot.add_command("ban", "ban a list players from the server. use ;unban to revert", function(args: string)
	local found, unknown = shared.dlcomp_parser.remaining_players(args)

	for _, player in found do
		table.insert(banned_players, player.name)
		player.kick()
	end

	chat.send_announcement(`banned {#found} players`)
	shared.dlcomp_parser.assert_remaining_players(found, unknown)
	return nil
end)

shared.dlcomp_command_bot.add_command("unban", "unbans a list of players from the server", function(args: string)
	local usernames = shared.dlcomp_parser.remaining_strings(args)
	
	local unbanned = {}
	local unknown = 0
	for _, username in usernames do
		local match_list = shared.dlcomp_table.partial_match(banned_players, username)
		if #match_list == 1 then
			shared.dlcomp_table.remove_value(banned_players, match_list[1])
			table.insert(unbanned, match_list[1])
		else
			warn(`found {#match_list} banned players that match arg {username}`)
			unknown += 1
		end
	end

	shared.dlcomp_string.print_array_tall("unbanned players", unbanned)
	return `unbanned {#unbanned} players; {unknown} bad args; see console`
end)

shared.dlcomp_command_bot.add_command("kick", "kick a list of people from the server", function(args: string)
	local found, unknown = shared.dlcomp_parser.remaining_players(args)

	for _, player in found do
		player.kick()
	end

	chat.send_announcement(`kicked {#found} players`)
	shared.dlcomp_parser.assert_remaining_players(found, unknown)
	return nil
end)

shared.dlcomp_command_bot.add_command("kick_except", "kicks everyone except admins and a list of players ", function(args: string)
	local found, unknown = shared.dlcomp_parser.remaining_players(args)

	-- dont allow admins to get kicked
	local exception_list = table.clone(shared.dlcomp_command_bot.admin_list)
	-- prevent user specified players from getting kicked
	for _, player in found do
		table.insert(exception_list, player.name)
	end

	-- get all players not in the exception list
	local to_kick = shared.dlcomp_table.filter(players.get_all(), function(player: player): boolean
		return not shared.dlcomp_table.contains(exception_list, player.name)
	end)

	-- kick them
	info("kick_except kicked:")
	for _, player in to_kick do
		player.kick()
		print(player.name)
	end
	print()

	chat.send_announcement(`kicked {#to_kick} players`)
	shared.dlcomp_parser.assert_remaining_players(found, unknown)
	return nil
end)

shared.dlcomp_command_bot.add_command("respawn", "spawns/respawns a list of players", function(args: string)
	local found, unknown = shared.dlcomp_parser.remaining_players(args)
	
	for _, player in found do
		player.respawn()
	end

	chat.send_announcement(`respawned {#found} players`)
	shared.dlcomp_parser.assert_remaining_players(found, unknown)
	return nil
end)

shared.dlcomp_command_bot.add_command("kill", "kills a list of players", function(args: string)
	local found, unknown = shared.dlcomp_parser.remaining_players(args)
	
	for _, player in found do
		player.kill()
	end

	chat.send_announcement(`killed {#found} players`)
	shared.dlcomp_parser.assert_remaining_players(found, unknown)
	return nil
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
