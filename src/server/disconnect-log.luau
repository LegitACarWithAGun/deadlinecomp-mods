
local maid = require("../shared/maid").new("dlcomp-disconnect-log")
local command_bot = require("./command-bot")
local arg_parser = require("../shared/arg-parser")

local module = {
	enabled = true,
}

maid["signal-joined"] = on_player_joined:Connect(function(username: string)
	if not module.enabled then return end
	local message = `{username} joined the server`
	chat.send_announcement(message)
	print(message)
end)

maid["signal-left"] = on_player_left:Connect(function(username: string)
	if not module.enabled then return end
	local message = `{username} left the server`
	chat.send_announcement(message)
	print(message)
end)

maid["cmd-toggle"] = command_bot.add_command("toggle_disconnect", "enable/disable join/disconnect logs", function(args: string, extra: command_bot.command_call_info): string?
	local input = arg_parser.get_bool(args)
	local toggle
	if input == nil then
		toggle = not toggle
	else
		toggle = input
	end

	module.enabled = toggle
	return (toggle and "enabled" or "disabled") .. " join+disconnect logging"
end)

return module
