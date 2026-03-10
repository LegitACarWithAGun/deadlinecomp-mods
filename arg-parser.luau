--!strict

-- Argument Parser module
-- intended to use arguments attached to chat commands
-- in its own module and not integrated into the command-bot because I dont wanna get in the way of people doing their own thing with their arguments
-- honestly not super confident in this

if not shared.dlcomp_string then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/string.luau")
end

-- text that will get coereced into a boolean if passed to get_bool
-- keep entries lowercase
local true_text = {"true", "t", "on", "enable", "1"}
local false_text = {"false", "f", "off", "disable", "0"}

-- text that will get coerced into a team id ("attacker" | "defender") if passed to get_team
-- keep entries lowercase
local anto_text = {"anto", "attacker"}
local syno_text = {"syno", "defender"}

-- creates a new parse_info instance, just for convenience
-- see _interface.d.luau for the command_parse_info interface
function new_info(): command_parse_info
    return {
        remaining_text = "",
        converted_from = "",
    }
end

-- treats the next argument as a string
-- cant fail
function get_string(args: string): (string, command_parse_info)
    local info = new_info()

    -- remove whitespace from start
    args = shared.dlcomp_string.trim_start(args)

    -- scan until next whitespace
    local current_arg = string.match(args, "^%S*") or ""

    -- see parse_info's comments
    info.converted_from = current_arg
    info.remaining_text = string.sub(args, current_arg:len()+1) -- 99% sure +1 is correct here 

    return current_arg, info
end

-- treats the next argument as a number,
-- will return nil if it cant be turned into a number, but the returned info will still remove the section
function get_number(args: string, default: number?, min: number?, max: number?): (number?, command_parse_info)
    local arg, info = get_string(args)

    -- process arg
    local result = tonumber(arg) or default
    if result and min then
        result = math.max(result, min)
    end
    if result and max then
        result = math.min(result, max)
    end

    return result, info
end

-- treats the next argument as a boolean
-- will return nil if it cant be turned into a boolean, but the returned info will still remove the section
function get_bool(args: string): (boolean?, command_parse_info)
    local arg, info = get_string(args)

    local text = string.lower(arg)
    if table.find(true_text, text) then
        return true, info
    elseif table.find(false_text, text) then
        return false, info
    else
        return nil, info
    end
end

-- treats the next argument as a player name,
-- will return nil if no such player exists, but the returned info will still remove the section
function get_player(args: string, match_exact: boolean?): (player?, command_parse_info)
    local want_name, info = get_string(args)

    -- the user wants the name to be an exact match
    if match_exact then
        return players.get(want_name), info
    end

    -- its annoying for the searching to be case sensitive
    -- turn everything lowercase
    want_name = string.lower(want_name)

    local matched_player: player?
    for _, player in pairs( players.get_all() ) do
        -- we turned the search arg all lowercase above, do the same with the name
        local player_name = string.lower(player.name)

        -- does the player's name match the search arg?
        if not string.match(player_name, want_name) then
            continue
        end

        -- multiple players match the search arg, cant be sure which they mean, return none of them
        if matched_player then
            return nil, info
        end

        -- first time we've matched, store for the above case
        matched_player = player
    end

    return matched_player, info
end

-- treats the next argument as a team id,
-- will return nil if it cant find the team, but the returned info will still remove the section
function get_team(args: string): (team_id?, command_parse_info)
    local want_team, info = get_string(args)
    want_team = string.lower(want_team)

    if table.find(anto_text, want_team) then
        return "attacker", info
    end
    if table.find(syno_text, want_team) then
        return "defender", info
    end

    return nil, info
end

function remaining_strings(args: string): {string}
    local output = {}
    local remaining = args
    while remaining ~= "" do
        local section, info = get_string(remaining)
        table.insert(output, section)
        remaining = info.remaining_text
    end
    
    return output
end

shared.dlcomp_parser = {
    get_string = get_string,
    get_number = get_number,
    get_bool = get_bool,
    get_player = get_player,
    get_team = get_team,

    remaining_strings = remaining_strings,
}
