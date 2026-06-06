-- load command bot
if not shared.dlcomp_command_bot then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/command-bot.luau")
end
-- load countdown module
if not shared.dlcomp_countdown then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/countdown.luau")
end
-- load parser module
if not shared.dlcomp_parser then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/arg-parser.luau")
end
-- load common functions
if not shared.dlcomp_table then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/table.luau")
end
if not shared.dlcomp_string then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/string.luau")
end

local ROUND_COMMAND_FORMAT = ";round map_name game_mode [round_duration] [countdown_duration]"

local last_countdown_duration = 30
local want_gamemode: string?

local gamemode_aliases = {
    tdm = "team_deathmatch",
    dom = "domination"
}
local low_priority_maps = {
    "test2_downtown_v2",
}

function prepare_round(map_name: string, mode_name: string, round_duration: number, countdown_duration: number)
    last_countdown_duration = countdown_duration
    want_gamemode = mode_name

    map.set_map(map_name)
    gamemode.force_set_gamemode("none") -- see the round_started comment
    sharedvars.gm_match_time_minutes = round_duration

    -- will eventually call round_started
    shared.dlcomp_countdown.countdown(countdown_duration)
end

-- called when the countdown has reached 0
-- setting the gamemode here because:
-- - we have no way of pausing the round timer
-- - switchng from the "none" gamemode is instant and doesnt end the round
function round_started()
    -- did we cause the countdown?
    -- todo: this can cause unexpected behavior when manually switching maps/gamemodes
    if not want_gamemode then
        return
    end

    -- we also have to prevent the teams from getting scrambled by the game
    local previous_team_scrambling_value = sharedvars.gm_team_scrambling
    sharedvars.gm_team_scrambling = false

    -- offically starts the round and timer
    gamemode.force_set_gamemode(want_gamemode)
    want_gamemode = nil

    -- reset the team scrambling sharedvar to whatever it was before
    sharedvars.gm_team_scrambling = previous_team_scrambling_value
end

function filter_low_priority<T>(to_filter: {T}, filter: {T})
    local without_low_priority = shared.dlcomp_table.not_in_filter(to_filter, filter)

    -- only filter if it doesnt remove all your options
    if #without_low_priority > 0 then
        return without_low_priority
    else
        return to_filter
    end
end

function autocomplete_map(input: string): (string, err)
    local all_maps = map.get_maps()
    local possible_maps = shared.dlcomp_string.partial_match_sections(all_maps, input, "_")
    possible_maps = filter_low_priority(possible_maps, low_priority_maps)

    local output = ""
    if #possible_maps == 0 then
        shared.dlcomp_string.print_array_tall("all maps", all_maps)
        return output, `no map matches input [{input}]; see console for the map list`
    elseif #possible_maps > 1 then
        shared.dlcomp_string.print_array_tall(`maps matching input [{input}]`, possible_maps)
        return output, `multiple maps match input [{input}]; see console`
    else
        return possible_maps[1], nil
    end
end

function autocomplete_gamemode(input: string): (string, err)
    local input_unmodified = input
    input = string.lower(input)

    -- custom short names for gamemodes, because partial-matching just wont work for the mess that team_deathmatch is
    input = gamemode_aliases[input] or input

    -- does the gamemode exist?
    if not gamemode.available_gamemodes[input] then
        local gamemode_list = shared.dlcomp_table.get_keys(gamemode.available_gamemodes)
        shared.dlcomp_string.print_array_tall("available gamemodes", gamemode_list)
        return input, `no gamemode found for input [{input_unmodified}]; see console`
    end
    return input, nil
end




-- chat command
shared.dlcomp_command_bot.add_command("round", `starts a round with a countdown. format: {ROUND_COMMAND_FORMAT}`, function(args)
    local map_name, game_mode, round_duration, countdown_duration, info
    map_name, info = shared.dlcomp_parser.get_string(args)
    game_mode, info = shared.dlcomp_parser.get_string(info.remaining_text)
    round_duration, info = shared.dlcomp_parser.get_number(info.remaining_text, sharedvars.gm_match_time_minutes, 1)
    countdown_duration, info = shared.dlcomp_parser.get_number(info.remaining_text, last_countdown_duration, 5)

    -- handle arguments
    -- are all the required arguments given?
    if map_name == "" or game_mode == "" then
        return `missing required arguments, command format: {ROUND_COMMAND_FORMAT}`
    end

    -- get map
    local err
    map_name, err = autocomplete_map(map_name)
    if err then
        return err
    end

    -- gamemode
    game_mode, err = autocomplete_gamemode(game_mode)
    if err then
        return err
    end

    prepare_round(map_name, game_mode, round_duration, countdown_duration)
    return
end)

shared.dlcomp_command_bot.add_command("map", "loads a map", function(args)
    local want_map = shared.dlcomp_parser.get_string(args)

    local map_name, err = autocomplete_map(want_map)
    if err then
        return err
    end

    map.set_map(map_name)
    return `successfully loaded {map_name}`
end)

shared.dlcomp_command_bot.add_command("gamemode", "starts the gamemode", function(args)
    local want_gamemode = shared.dlcomp_parser.get_string(args)
    
    local mode, err = autocomplete_gamemode(want_gamemode)
    if err then
        return err
    end

    gamemode.force_set_gamemode(mode)
    return `started gamemode {mode}`
end)




-- signals
-- countdown ended
shared.dlcomp_countdown.finished:Connect(function()
    round_started()
end)




shared.dlcomp_round = {
    prepare_round = prepare_round,
    gamemode_aliases = gamemode_aliases,
    low_priority_maps = low_priority_maps,
}
