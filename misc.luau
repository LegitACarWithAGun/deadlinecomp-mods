--!strict

-- load command bot
if not shared.dlcomp_command_bot then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/command-bot.luau")
end
-- load arg parser module
if not shared.dlcomp_parser then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/arg-parser.luau")
end

shared.dlcomp_command_bot.add_command("cam", "changes the player's cam mode. format: ;cam mode [player]", function(args: string, extra: command_call_info)
	local want_mode, parsed = shared.dlcomp_parser.get_string(args)
	local player_list = shared.dlcomp_parser.remaining_players_throwing(parsed.remaining_text, {extra.caller})

	for _, player in player_list do
		player.set_camera_mode(want_mode)
	end
	return `set camera mode for {#player_list} players to {want_mode}`
end)

shared.dlcomp_command_bot.add_command("rand", "selects a random value from the argument list", function(args: string, extra: command_call_info)
	-- gather args
	local arg_list = shared.dlcomp_parser.remaining_strings(args)
	if #arg_list < 2 then
		return `please include atleast 2 arguments, seperated by whitespace`
	end

	-- choose a random arg
	local index = math.random(#arg_list)

	-- output
	return arg_list[index]
end)
