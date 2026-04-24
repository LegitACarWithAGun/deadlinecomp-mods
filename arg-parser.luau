--!strict

-- Argument Parser module
-- intended to use arguments attached to chat commands
-- in its own module and not integrated into the command-bot because I dont wanna get in the way of people doing their own thing with their arguments

if not shared.dlcomp_table then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/table.luau")
end
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

function get_player(args: string): (player?, command_parse_info, {player})
    local want_name, parsed = get_string(args)

    -- its annoying for the searching to be case sensitive
    -- turn everything lowercase
    want_name = string.lower(want_name)

    local found_players = shared.dlcomp_table.filter(players.get_all(), function(player: player): boolean
        local player_name = string.lower(player.name)

        -- does the player's name at-least partially match the input
        return string.match(player_name, want_name) ~= nil
    end)

    if #found_players == 0 or #found_players > 1 then
        return nil, parsed, found_players
    end
    return found_players[1], parsed, found_players
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

-- 2nd return value is the args we couldnt find a corresponding player for
function remaining_players(args: string): ({player}, {[string]: {player}})
    local result = {}
    local unknown = {}

    local remaining = shared.dlcomp_string.trim_end(args)
    repeat
        local player, parsed, found = get_player(remaining)
        if player then
            table.insert(result, player)
        else
            unknown[parsed.converted_from] = found
        end

        remaining = parsed.remaining_text
    until remaining == ""

    return result, unknown
end




function assert_get_player(player: player?, parsed: command_parse_info, found: {player}): (player, command_parse_info)
    if player then
        return player, parsed
    end

    if #found == 0 then
        error(`no players match the input {parsed.converted_from}`)
    else
        local usernames = shared.dlcomp_table.get_usernames_of_players(found)
        shared.dlcomp_string.print_array_tall("get_player found", usernames)
        error(`found {#found} players matching input {parsed.converted_from}; see console for a list`)
    end
end

function assert_remaining_players(found: {player}, unknown: {[string]: {player}}, default: {player}?): {player}
    if shared.dlcomp_table.is_empty(unknown) then
        if #found == 0 and default then
            return default
        else
            return found
        end
    end
    
    info("remaing_players args that matched 0 / >1 players")
    print( fmt_remaining_players_unknown(unknown) )
    print()

    local unknown_key_count = shared.dlcomp_table.get_size(unknown)
    error(`remaining_players could not find a corresponding player for {unknown_key_count} args; see console for a list`)
end




function get_player_throwing(args: string): (player, command_parse_info)
    local player, parsed, found = get_player(args)
    return assert_get_player(player, parsed, found)
end
function remaining_players_throwing(args: string, default: {player}?): {player}
    local found, unknown = remaining_players(args)
    return assert_remaining_players(found, unknown)
end




function fmt_remaining_players_unknown(unknown: {[string]: {player}}): string
    local lines = {}
    for input, found_players in unknown do
        local usernames = shared.dlcomp_table.get_usernames_of_players(found_players)
        local fmt_list = #usernames > 1 and table.concat(usernames, " ") or "== no players found =="
        table.insert(lines, `"{input}": {fmt_list}`)
    end

    return table.concat(lines, "\n")
end




shared.dlcomp_parser = {
    get_string = get_string,
    get_number = get_number,
    get_bool = get_bool,
    get_player = get_player,
    get_team = get_team,

    remaining_strings = remaining_strings,
    remaining_players = remaining_players,

    assert_get_player = assert_get_player,
    assert_remaining_players = assert_remaining_players,

    get_player_throwing = get_player_throwing,
    remaining_players_throwing = remaining_players_throwing,
}
