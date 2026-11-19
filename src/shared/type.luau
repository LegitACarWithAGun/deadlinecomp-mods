export type function append_unique<T>(t: {T}, val: T): ()
	if table.find(t, val) then return end
	table.insert(t, val)
end

export type function set_properties_optional(ty, ...)
	for key, val in ty:properties() do
		ty:setproperty(key, types.optional(val.write))
	end
	return ty
end

-- wasnt needed, repurpose if needed
type function createIndexer(ty: type)
	local indexer_keys = {}
	local indexer_values = {}
	for key, val in ty:properties() do
		table.insert(indexer_keys, key)
		append_unique(indexer_values, val.read)
		append_unique(indexer_values, val.write)
	end
	return types.unionof(table.unpack(indexer_keys)),
		types.unionof(table.unpack(indexer_values))
end

export type function setIndexer(ty: type, key: type, value: type)
	ty:setindexer(key, value)
	return ty
end

return {}