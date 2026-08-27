--!strict

-- this is essentially an old version of Nevermore/Quenty Maid
-- - we dont have access to typeof, so Im slightly less sure about stuff when cleaning up
-- - added an optional _origin property so it isnt a complete nightmare to try to track down errors
-- Im hoping shibe adds the original to the globals sometime, since its already accessible through gamemodes

local Maid = {}

type MaidData = {
	[string]: any,
	_tasks: {any},
	_origin: string?,
}
export type Maid = setmetatable<MaidData, typeof(Maid)>

type err = string?

function Maid.new(origin: string?): Maid
	local self: MaidData = {
		_tasks = {},
		_origin = origin,
	}
	return setmetatable(self, Maid)
end

function Maid.GiveTask(self: Maid, task: never): ()
	table.insert(self._tasks, task)
end

function Maid.DoCleaning(self: Maid): ()
	local tasks = self._tasks
	-- next-while will visit every key even if new keys are set
	local index, task = next(tasks)
	while index ~= nil do
		local _, err = pcall(Maid.clean_arg, task)
		if err then
			-- TODO: leaves it hanging it rn..
			warn(`could not clean maid {self._origin}'s task at key {index}: {err}`)
		end

		tasks[index] = nil
		index, task = next(tasks)
	end
end
Maid.Destroy = Maid.DoCleaning

function Maid.clean_arg(task: any): err
	task = task :: never -- shut the type system up, refuses to work with me here

	if type(task) == "function" then
		task()
		return nil
	end

	if type(task) ~= "table" then
		return "task is not a function or table"
	end

	-- TODO: be more thoughtful about what you do with the object
	if task.Disconnect then
		task:Disconnect()
		return nil
	end
	if task.Destroy then
		task:Destroy()
		return nil
	end
	if task.disconnect_all_binds then
		task:disconnect_all_binds()
		return nil
	end

	return "task is a table, didnt find a key to call"
end

function Maid.__index(self: Maid, key: any)
	if Maid[key] then
		return Maid[key]
	else
		return self._tasks[key]
	end
end
function Maid.__newindex(self: Maid, key: any, new_task: any)
	if Maid[key] ~= nil then
		error(`reserved key {key}`)
	end

	local tracked = self._tasks
	local old_task = tracked[key]
	tracked[key] = new_task
	if not old_task then
		return
	end

	local _, err = pcall(Maid.clean_arg, old_task)
	if err then
		warn(`could not clean maid {self._origin}'s task at key {key}: {err}`)
	end
end

return Maid
