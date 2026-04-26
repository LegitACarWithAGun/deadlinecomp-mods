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
    local team_scrambling_reset_value = sharedvars.gm_team_scrambling
    sharedvars.gm_team_scrambling = false

    -- offically starts the round and timer
    gamemode.force_set_gamemode(want_gamemode)
    want_gamemode = nil

    -- reset the team scrambling sharedvar to whatever it was before
    sharedvars.gm_team_scrambling = team_scrambling_reset_value
end

-- countdown ended
shared.dlcomp_countdown.finished:Connect(function()
    round_started()
end)



function filter_low_priority<T>(to_filter: {T}, filter: {T})
    local without_low_priority = shared.dlcomp_table.not_in_filter(to_filter, filter)

    -- only filter if it doesnt remove all your options
    if #without_low_priority > 0 then
        return without_low_priority
    else
        return to_filter
    end
end

-- chat command
shared.dlcomp_command_bot.add_command("round", `starts a round with a countdown. format: {ROUND_COMMAND_FORMAT}`, function(args)
    local map_name, game_mode, round_duration, countdown_duration, info
    map_name, info = shared.dlcomp_parser.get_string(args)
    game_mode, info = shared.dlcomp_parser.get_string(info.remaining_text)
    round_duration, info = shared.dlcomp_parser.get_number(info.remaining_text, sharedvars.gm_match_time_minutes, 1)
    countdown_duration, info = shared.dlcomp_parser.get_number(info.remaining_text, last_countdown_duration, 5)

    -- handle arguments
    do
        -- are all the required arguments given?
        if map_name == "" or game_mode == "" then
            return `missing required arguments, command format: {ROUND_COMMAND_FORMAT}`
        end

        -- find the map the player's searching for
        local all_maps = map.get_maps()
        local possible_maps = shared.dlcomp_string.partial_match_sections(all_maps, map_name, "_")
        possible_maps = filter_low_priority(possible_maps, low_priority_maps)

        if table.find(all_maps, map_name) then
            -- theres an exact match, just use that
        elseif #possible_maps == 0 then
            return `list of all maps: {table.concat(all_maps, ", ")}`
        elseif #possible_maps > 1 then
            return `multiple maps match the argument: {table.concat(possible_maps, ", ")}`
        else
            map_name = possible_maps[1]
        end

        -- custom short names for gamemodes, because partial-matching just wont work for the mess that team_deathmatch is
        game_mode = string.lower(game_mode)
        if gamemode_aliases[game_mode] then
            game_mode = gamemode_aliases[game_mode]
        end

        -- does the gamemode exist?
        if not gamemode.available_gamemodes[game_mode] then
            local gamemode_list = {}
            for name in pairs(gamemode.available_gamemodes) do
                table.insert(gamemode_list, name)
            end
            return `no gamemode with name [{game_mode}] found, list of gamemodes: {table.concat(gamemode_list, ", ")}`
        end
    end

    prepare_round(map_name, game_mode, round_duration, countdown_duration)
    return
end)

shared.dlcomp_round = {
    prepare_round = prepare_round,
    gamemode_aliases = gamemode_aliases,
    low_priority_maps = low_priority_maps,
}
