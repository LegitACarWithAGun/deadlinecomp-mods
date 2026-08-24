local command_bot = require("./command-bot")
local arg_parser = require("../shared/arg-parser")
local dlcomp_countdown = require("./countdown")
local dlcomp_table = require("../shared/table")
local dlcomp_string = require("../shared/string")

local ROUND_COMMAND_FORMAT = ";round map_name game_mode [round_duration] [countdown_duration]"

local last_countdown_duration = 30
local want_gamemode: string?

local gamemode_aliases = {
    tdm = "team_deathmatch",
    dom = "domination"
}
local low_priority_maps = {
    "test2_downtown_v2",
    "test_complex_night",
}

-- for golang style erroring
type err = string?

function prepare_round(map_name: string, mode_name: string, round_duration: number, countdown_duration: number)
    last_countdown_duration = countdown_duration
    want_gamemode = mode_name

    map.set_map(map_name)
    gamemode.force_set_gamemode("none") -- see the round_started comment
    sharedvars.gm_match_time_minutes = round_duration

    -- will eventually call round_started
    dlcomp_countdown.countdown(countdown_duration)
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
    local without_low_priority = dlcomp_table.not_in_filter(to_filter, filter)

    -- only filter if it doesnt remove all your options
    if #without_low_priority > 0 then
        return without_low_priority
    else
        return to_filter
    end
end

function autocomplete_map(input: string): (string, err)
    local all_maps = map.get_maps()

    -- just use the exact map name if it exists
    -- mainly a backup for if low_priority_maps hasnt been updated
    local exact_match = table.find(all_maps, input)
    if exact_match then
        return input, nil
    end

    local possible_maps = dlcomp_string.partial_match_sections(all_maps, input, "_")
    possible_maps = filter_low_priority(possible_maps, low_priority_maps)

    if #possible_maps == 0 then
        dlcomp_string.print_array_tall("all maps", all_maps)
        return "", `no map matches input [{input}]; see console for the map list`
    elseif #possible_maps > 1 then
        dlcomp_string.print_array_tall(`maps matching input [{input}]`, possible_maps)
        return "", `multiple maps match input [{input}]; see console`
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
        local gamemode_list = dlcomp_table.get_keys(gamemode.available_gamemodes)
        dlcomp_string.print_array_tall("available gamemodes", gamemode_list)
        return input, `no gamemode found for input [{input_unmodified}]; see console`
    end
    return input, nil
end




-- chat command
command_bot.add_command("round", `starts a round with a countdown. format: {ROUND_COMMAND_FORMAT}`, function(args)
    local map_name, game_mode, round_duration, countdown_duration, info
    map_name, info = arg_parser.get_string(args)
    game_mode, info = arg_parser.get_string(info.remaining_text)
    round_duration, info = arg_parser.get_number(info.remaining_text, sharedvars.gm_match_time_minutes, 1)
    countdown_duration, info = arg_parser.get_number(info.remaining_text, last_countdown_duration, 5)

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

command_bot.add_command("map", "loads a map", function(args)
    local want_map = arg_parser.get_string(args)

    local map_name, err = autocomplete_map(want_map)
    if err then
        return err
    end

    map.set_map(map_name)
    return `successfully loaded {map_name}`
end)

command_bot.add_command("gamemode", "starts the gamemode", function(args)
    local want_gamemode = arg_parser.get_string(args)
    
    local mode, err = autocomplete_gamemode(want_gamemode)
    if err then
        return err
    end

    gamemode.force_set_gamemode(mode)
    return `started gamemode {mode}`
end)




-- signals
-- countdown ended
dlcomp_countdown.finished:Connect(function()
    round_started()
end)




return {
    prepare_round = prepare_round,
    gamemode_aliases = gamemode_aliases,
    low_priority_maps = low_priority_maps,
}
