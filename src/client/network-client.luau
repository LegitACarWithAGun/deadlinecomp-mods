local maid = require("../shared/maid").new("dlcomp-network-client")

local module = {
	maid = maid,
}

local listeners = {} :: {[string]: listenerCallback}

type nilFunc = () -> ()
type listenerCallback = (...any) -> ()

function module.listen(message_name: string, callback: listenerCallback): nilFunc
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

function module.send(message_name: string, ...)
	fire_server(message_name, ...)
end

maid["signal-server_event"] = on_server_event:Connect(function(args: {any})
	local message_name = args[1]
	if type(message_name) ~= "string" then return end

	local listener = listeners[message_name]
	if not listener then return end
	listener( table.unpack(args, 2) )
end)

-- seemingly cant disconnect on_client_event, doubt its different on client, just clear the listeners
maid["remove-listeners"] = function()
	listeners = {}
end

return module