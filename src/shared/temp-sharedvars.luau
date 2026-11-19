-- allows setting a group of sharedvar values temporarily, and then cleaning itself up
-- the values belonging to the instance with the highest priority are used
-- TODO: better behavior on sharedvars set from elsewhere

local dlcomp_type = require("./type")
local dlcomp_table = require("./table")


local TempSharedvars = {}
TempSharedvars.__index = TempSharedvars

local sorted_instances: {TempSharedvars} = {}
local default_values: opt_sharedvars = {}

type sharedvar_keys = string
type _indexable_sv = dlcomp_type.setIndexer<typeof(sharedvars), string, any>
local sharedvars = sharedvars :: _indexable_sv
export type opt_sharedvars = dlcomp_type.set_properties_optional<_indexable_sv>

export type TempSharedvars = typeof(TempSharedvars.New("__type_info", -1, {}))
function TempSharedvars.New(identifier: string, priority: number, values: opt_sharedvars)
	local instance = setmetatable({
		priority = priority,
		values = values,
		enabled = false,
		destroyed = false,
	}, TempSharedvars)

	return instance
end

function TempSharedvars.SetValues(self: TempSharedvars, values: opt_sharedvars)
	if not self.enabled then
		self.values = values
		return
	end
	
	local index = getIndexOrInsert(self)
	local old_values = self.values

	local keys = dlcomp_table.get_keys(old_values)
	dlcomp_table.append_unique(keys, table.unpack(dlcomp_table.get_keys(values)))
	for _, k in keys do
		if hasGreater(k, index) then continue end -- a greater value is being used
		if values[k] ~= nil then
			applyValue(k, values[k])
		else
			fallFromValue(k, index, old_values[k])
		end
	end
	self.values = values
end

function TempSharedvars.Toggle(self: TempSharedvars, toggle: boolean?)
	if toggle == nil then
		toggle = not self.enabled
	end
	if toggle then
		self:Enable()
	else
		self:Disable()
	end
end
function TempSharedvars.Enable(self: TempSharedvars)
	if self.enabled then return end
	self.enabled = true

	local index = getIndexOrInsert(self)
	for k, v in self.values do
		if hasGreater(k, index) then continue end -- a greater value is being used
		applyValue(k, v)
	end
end
-- returns the index of the instance, used internally
function TempSharedvars.Disable(self: TempSharedvars): number?
	self.enabled = false
	local index = getInstanceIndex(self)
	if not index then return nil end

	for k, v in self.values do
		if hasGreater(k, index) then continue end -- a greater value is being used
		fallFromValue(k, index, v)
	end
	return index
end
function TempSharedvars.Destroy(self: TempSharedvars)
	local index = self:Disable()
	if not index then return end
	table.remove(sorted_instances, index)
end




-- update sharedvar
function applyValue(key: string, val: any): ()
	if default_values[key] == nil then
		default_values[key] = sharedvars[key]
	end
	sharedvars[key] = val
end
function fallFromValue(key: string, index: number, old_val: number): ()
	-- if sharedvars[key] ~= old_val then return end -- a 3rd party has set the value, not our responsibilty anymore
	local lesser = getGreatestBelow(key, index)
	local default = default_values[key]
	-- reset value to the next highest priority or a default
	if lesser ~= nil then
		sharedvars[key] = lesser
	elseif default ~= nil then
		sharedvars[key] = default
	end
end


-- read / push helpers for sorted_instances
function getIndexOrInsert(self: TempSharedvars): number
	self.destroyed = false
	return not self.destroyed and getInstanceIndex(self) or insertInstance(self)
end
function getInstanceIndex(self: TempSharedvars): number?
	return table.find(sorted_instances, self)
end
function insertInstance(self: TempSharedvars): number
	local index = getFirstIndexAbovePriority(self.priority)
	table.insert(sorted_instances, index, self)
	return index
end
function getFirstIndexAbovePriority(priority: number): number
	for i, v in sorted_instances do
		if v.priority > priority then
			return i
		end
	end
	return #sorted_instances+1
end



-- `Greatest`: the value belonging to the instance with the highest priority
function hasGreater(key: sharedvar_keys, index: number)
	return getGreatestAbove(key, index) ~= nil
end
function getGreatestAbove(key: sharedvar_keys, index: number)
	return getGreatestBeforeIndex(key, #sorted_instances, index+1)
end
function getGreatestBelow(key: sharedvar_keys, index: number)
	return getGreatestBeforeIndex(key, index-1, 1)
end
function getGreatestBeforeIndex(key: sharedvar_keys, index: number, min_index: number?): any
	min_index = min_index or 1
	for i=index, min_index, -1 do
		-- ignore disabled instances
		local instance = sorted_instances[i]
		if not instance.enabled then continue end

		local value = instance.values[key]
		if value then
			return value
		end
	end
	return nil
end





return TempSharedvars
