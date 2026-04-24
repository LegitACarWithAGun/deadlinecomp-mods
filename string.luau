--!strict

-- just removes whitespace from the start of a string
function trim_start(str: string): string
    local output, _ = string.gsub(str, "^%s+", "", 1)
    return output
end
function trim_end(str: string): string
    local output, _ = string.gsub(str, "s+$", "", 1)
    return output
end
function trim(str: string): string
    str = trim_start(str)
    return trim_end(str)
end

-- takes a list of strings and a string to match against
-- returns all the strings in the list After the first match
-- returns a empty list if it matches the last section, nil if no matches
function sections_after_match(sections: {string}, needle: string): {string}?
    for i, section in sections do
		-- section matches the needle, store everything after this
        if string.match(section, needle) then
			local result = {}
			return table.move(sections, i+1, #sections, 1, result)
        end
    end
	return nil
end
-- reasoning: typing the full map name is quite annoying, but a simple partial-match search is bad because theres a lot of maps with similar names, ie claustro v3 and v4
-- but those also immediately propose a solution; by doing multiple partial-matches on different sections of the map name,
-- you can be imprecise with long sections, and precise with small differences
-- ie to search for claustrophobic_v3, yould just type `cla_3`
function partial_match_sections(haystack: {string}, needle: string, seperator: string): {string}
    needle = string.lower(needle)

	-- turn the haystack into a useful format
    local option_sections:{ [string]: {string} } = {}
    for _, option in haystack do
        option = string.lower(option)
        option_sections[option] = string.split(option, seperator)
    end

    -- loop over every section of the needle
    for _, needle_section in string.split(needle, seperator) do
        -- loop over every option, discarding it if it doesnt have any matches
        for option, remaining_sections in option_sections do
            option_sections[option] = sections_after_match(remaining_sections, needle_section)
        end
    end

    -- turn the result into a useful format (list of strings)
    local output = {}
    for option, _ in option_sections do
        table.insert(output, option)
    end

    return output
end

-- does nothing if the prefix doesnt exist in the text
-- returns (found, remaining)
function cut_prefix(text: string, prefix: string): (boolean, string)
    -- check for prefix
    if text:sub(1, prefix:len()) ~= prefix then
        return false, text
    end
    -- remove the prefix
    return true, text:sub(prefix:len()+1)
end

function print_array_tall<T>(header: string?, array: {T}): ()
    if header then
        header = trim_end(header)
        info(header .. ":")
    end

    -- empty array
    if (not array or #array == 0) then
        print("==empty==")
        print()
        return
    end

    for _, v in ipairs(array) do
        print(tostring(v))
    end
    print() -- leave a empty line after contents
end

shared.dlcomp_string = {
    trim_start = trim_start,
    trim_end = trim_end,
    trim = trim,
	partial_match_sections = partial_match_sections,
    cut_prefix = cut_prefix,
    print_array_tall = print_array_tall,
}