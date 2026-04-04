--!strict

local function is_array_section(tbl: {}, key: any): boolean
    if type(key) ~= "number" then
        return false
    end
    if key < 1 or key > #tbl then
        return false
    end
    return true
end

function get_page<T>(arr: {T}, page_length: number, want_page: number): ({T}, number)
	local max_page = math.ceil( #arr / page_length )
	local returned_page = math.clamp(want_page, 1, max_page)

	local start_index = page_length * (returned_page-1) + 1
	local end_index = math.min(start_index + page_length - 1, #arr)

	local output: {T} = {}
	return table.move(arr, start_index, end_index, 1, output), returned_page
end

function filter<T>(tbl: {T}, callback: (T) -> boolean): {T}
    local output = {}
    for i, value in tbl do
        if not callback(value) then
            continue
        end

        if is_array_section(tbl, i) then
            -- i is an array index, append to the end
            -- want to preserve the continuity of arrays
            table.insert(output, value)
        else
            -- i is a dictionary key, set value directly to the same key
            output[i] = value
        end
    end

    return output
end
function in_filter<T>(tbl: {T}, filter_with: {T}): {T}
    return filter(tbl, function(value): boolean
        return contains(filter_with, value)
    end)
end
function not_in_filter<T>(tbl: {T}, filter_with: {T}): {T}
    return filter(tbl, function(value): boolean
        return not contains(filter_with, value)
    end)
end

--- does not modify the input
function scramble<T>(arr: {T}): {T}
    local output = {}
    local copy = table.clone(arr)
    while #copy > 0 do
        local index = math.random(1, #copy)
        local chosen_value = table.remove(copy, index) :: T
        table.insert(output, chosen_value)
    end

    return output
end

-- table.find that just returns a bool
function contains<T>(tbl: {T}, value: T): boolean
    return table.find(tbl, value) ~= nil
end
function partial_match(haystack: {string}, needle: string): {string}
    local matches = {}
    for _, v in haystack do
        if not string.match(v, needle) then
            continue
        end

        table.insert(matches, v)
    end
    return matches
end

--- - matches the input exactly
--- - shifts arrays down like table.remove
--- - removes dictionary values aswell
function remove_value<T>(tbl: {T}, value: T)
    local array_indices_to_remove = {}

    for k, v in tbl do
        if v ~= value then
            continue
        end

        if is_array_section(tbl, k) then
            -- currently in a an array, deal with the key later
            table.insert(array_indices_to_remove, k)
        else
            -- dictionary key, just remove
            tbl[k] = nil
        end
    end

    -- remove matching values from the array part of the table
    -- have to do it backwards to not move the remaining indexes
    table.sort(array_indices_to_remove)
    for i=#array_indices_to_remove, 1, -1 do
        table.remove(tbl, array_indices_to_remove[i])
    end
end
-- inserts the value if an identical value isnt in the table already
function append_unique<T>(tbl: {T}, value: T)
    if contains(tbl, value) then
        return
    end
    table.insert(tbl, value)
end

-- equivalent to .map in JS
function transform_values<T, N>(tbl: {T}, callback: (value: T) -> N): {N}
    local result = {}
    for i, v in tbl do
        result[i] = callback(v)
    end
    return result
end

shared.dlcomp_table = {
	get_page = get_page,
    filter = filter,
	in_filter = in_filter,
    not_in_filter = not_in_filter,
    scramble = scramble,
    contains = contains,
    partial_match = partial_match,
    remove_value = remove_value,
    append_unique = append_unique,
    transform_values = transform_values,
}
