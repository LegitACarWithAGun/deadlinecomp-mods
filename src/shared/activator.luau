-- used to enable/disable sections of code so they only run when theyre needed

local Maid = require("./maid")
local dlcomp_table = require("./table")

local Activator = {}
Activator.__index = Activator

export type Activator = typeof(Activator.new("__typing"))

function Activator.new(origin: string)
	local self = {
		OnEnable = Signal.new() :: Signal<>,
		OnDisable = Signal.new() :: Signal<>,
		maid = Maid.new(`dlcomp-activator-{origin}`),
		
		_subscribers = {} :: {string},
		_binds = {} :: {() -> ()},
		_origin = origin,
	}

	return setmetatable(self, Activator)
end

local function nilFunc() end

--- tells the activator you want to use whatever its attached to, activating it if neccesary
--- returns a function to unsubscribe
function Activator.Subscribe(self: Activator, identifier: string): () -> ()
	if dlcomp_table.contains(self._subscribers, identifier) then
		warn(`activator {self._origin} already has subscriber with id {identifier}. no-oping`)
		return nilFunc
	end

	table.insert(self._subscribers, identifier)
	if #self._subscribers == 1 then
		self:_enable()
	end

	return function()
		-- TODO: if the call is super delayed, this might unsubscribe another subscriber with the same name
		self:Remove(identifier)
	end
end

--- tells the activator you no longer want to use whatever its attached to, disabling it if you were the last thing using it
function Activator.Remove(self: Activator, identifier: string): ()
	if #self._subscribers == 0 then return end

	dlcomp_table.remove_value(self._subscribers, identifier)
	if #self._subscribers == 0  then
		self:_disable()
	end
end

--- subscribe to a different activator, will automatically unsubscribe when disabled
function Activator.Bind(self: Activator, ...: Activator): ()
	for _, other in {...} do
		table.insert(self._binds, other:Subscribe(`BIND-{self._origin}`))
	end
end

--- get the identifiers of the subscribers
function Activator.GetSubscribers(self: Activator): {string}
	return self._subscribers
end

--- force the activator to disable itself, currently used when cleaning up the bundle
function Activator.Destroy(self: Activator): ()
	if #self._subscribers > 0 then
		warn(`destroying activator {self._origin} while it still has the following subscribers: {table.concat(self._subscribers, ", ")}`)
	end
	self:_disable()
end

function Activator._enable(self: Activator)
	self.OnEnable:Fire()
end
function Activator._disable(self: Activator)
	self.OnDisable:Fire()

	self.maid:Destroy()
	-- unbind from other activators
	for _, removeCallback in self._binds do
		removeCallback()
	end
end

return Activator
