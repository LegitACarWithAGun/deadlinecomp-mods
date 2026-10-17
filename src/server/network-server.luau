local maid = require("../shared/maid").new("dlcomp-network-server")
local dlcomp_table = require("../shared/table")

local module = {
	maid = maid,
}

local listeners: {[string]: listenerCallback} = {}

type listenerCallback = (player, ...any) -> ()

function module.send(player: player, message_name: string, ...)
	player.fire_client(message_name, ...)
end

function module.send_except(ignore: string?, message_name: string, ...)
	for _, player in players.get_all() do
		if ignore == player.name then continue end
		module.send(player, message_name, ...)
	end
end
function module.send_all(message_name: string, ...)
	return module.send_except(nil, message_name)
end

function module.send_username(username: string|{string}, message_name: string, ...)
	local users = type(username) == "table" and username or {username}
	for _, name in users do
		local player = players.get(name)
		if not player then continue end -- unsure what to do here
		module.send(player, message_name, ...)
	end
end

function module.listen(message_name: string, callback: (player: player, ...any) -> ())
	if listeners[message_name] then
		warn(`overriding network listener {message_name}`)
	end

	listeners[message_name] = callback
	return function()
		-- destroy listener if its the same one you set
		local existing = listeners[message_name]
		if existing ~= callback then return end
		listeners[message_name] = nil
	end
end

maid["signal-client_event"] = on_client_event:Connect(function(username: string, args: {any})
	local message_name = args[1]
	if type(message_name) ~= "string" then return end

	local listener = listeners[message_name]
	if not listener then return end

	local player = players.get(username)
	if not player then
		warn(`dlcomp-network-server on_client_event: no player object found for {username}`)
		return
	end
	listener(player, table.unpack(args, 2))
end)

-- seemingly cant disconnect on_client_event, just clear the listeners
maid["remove-listeners"] = function()
	listeners = {}
end

return module