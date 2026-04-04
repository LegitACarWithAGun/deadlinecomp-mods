-- just removes whitespace from the start of a string
function trim_start(str: string): string
    return string.gsub(str, "^%s+", "", 1)
end

-- takes a list of strings and a string to match against
-- returns all the strings in the list After the first match
-- returns a empty list if it matches the last section, nil if no matches
function sections_after_match(sections: {string}, needle: string): {string}?
    for i, section in pairs( sections ) do
		-- section matches the needle, store everything after this
        if string.match(section, needle) then
			local result = {}
			return table.move(sections, i+1, #sections, 1, result)
        end
    end
	return nil
end
-- reasoning: typing the full map name is quite annoying, but a simple partial-match search is bad because theres a lot of maps with similar names, ie claustro v3 and v4
-- but those also immiedietly propose a solution; by doing multiple partial-matches on different sections of the map name,
-- you can be imprecise with long sections, and precise with small differences
-- ie to search for claustrophobic_v3, yould just type `cla_3`
function partial_match_sections(haystack: {string}, needle: string, seperator: string): {string}
    needle = string.lower(needle)

	-- turn the haystack into a useful format
    local option_sections:{ [string]: {string}? } = {}
    for _, option in pairs(haystack) do
        option = string.lower(option)
        option_sections[option] = string.split(option, seperator)
    end

    -- loop over every section of the needle
    for _, needle_section in pairs( string.split(needle, seperator) ) do
        -- loop over every option, discarding it if it doesnt have any matches
        for option, remaining_sections in pairs( option_sections ) do
            option_sections[option] = sections_after_match(remaining_sections, needle_section)
        end
    end

    -- turn the result into a useful format (list of strings)
    local output = {}
    for option, _ in pairs(option_sections) do
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

shared.dlcomp_string = {
    trim_start = trim_start,
	partial_match_sections = partial_match_sections,
    cut_prefix = cut_prefix,
}