--!strict

if not shared.dlcomp_command_bot then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/command-bot.luau")
end
if not shared.dlcomp_parser then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/arg-parser.luau")
end
if not shared.dlcomp_table then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/table.luau")
end
if not shared.dlcomp_string then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/string.luau")
end

local rosters: {[team_id]: {string}} = {}
local max_spawned: {[team_id]: number} = {}
local all_team_ids: {team_id} = {"attacker", "defender"}

do -- helpers
    function get_other_team(team: team_id): team_id
        return team == "attacker" and "defender" or "attacker"
    end
    
    function respawn_alive(player: player)
        if player.is_alive() then
            player.respawn()
        end
    end
    
    -- nil if team doesnt have a roster, true/false otherwise
    function is_in_roster(username: string, team: team_id): boolean?
        local roster = rosters[team]
        if not roster then
            return nil
        end
        return shared.dlcomp_table.contains(roster, username)
    end
    function is_in_any_roster(username: string): boolean
        return is_in_roster(username, "attacker") or not not is_in_roster(username, "defender")
    end

    -- errors if we arent aware of the given team id
    function assert_team(team: team_id)
        if not shared.dlcomp_table.contains(all_team_ids, team) then
            shared.dlcomp_string.print_array_tall("valid team ids", all_team_ids)
            error(`unknown team id: {team}`)
        end
    end

    function get_team_amount_spawned(team: team_id)
        local amount = 0
        for _, player in players.get_all() do
            -- dont remove the `is_in_roster` check: spawned admins that arent in a team's roster shouldnt be counted
            if player.get_team() ~= team or not is_in_roster(player.name, team) or not player.is_alive() then
                continue
            end
            amount += 1
        end

        return amount
    end

    function print_status()
        warn("TEAM/ROSTER STATUS")
        for _, team in all_team_ids do
            info(`{team}:`)
            print(`spawned limit: {max_spawned[team]}`)

            local roster = rosters[team]
            warn("roster:")
            shared.dlcomp_string.print_array_tall(nil, roster)
        end

        local in_neither_roster = shared.dlcomp_table.filter(players.get_all(), function(player: player): boolean
            return not is_in_any_roster(player.name)
        end)
        shared.dlcomp_string.print_array_tall("players not in either roster", shared.dlcomp_table.get_usernames_of_players(in_neither_roster))
    end
end

do -- roster update
    function enable_rosters()
        sharedvars.gm_team_balancing_threshold = -1
    end
    function disable_rosters()
        rosters = {}
        sharedvars.gm_team_balancing_threshold = 99
    end

    function clear_roster(team: team_id?): string
        if not team then
            disable_rosters()
            return `lifted all roster restrictions`
        end
        assert_team(team)

        -- check if other team has rosters set
        local other_team = get_other_team(team)
        if not rosters[other_team] then
            -- doesnt, just reset anything related to rosters
            disable_rosters()
            return `lifted all roster restrictions`
        end

        -- clear roster
        rosters[team] = nil
        apply_roster_rules()
        return `cleared [{team}]'s roster`
    end

    function add_to_roster(team: team_id, username: string)
        enable_rosters()

        -- remove from other team's roster
        local other_team = get_other_team(team)
        remove_from_roster(other_team, username)

        -- add to team's roster
        rosters[team] = rosters[team] or {}
        shared.dlcomp_table.append_unique(rosters[team], username)
    
        -- update the player itself, they may or may not be in the server
        local player = players.get(username)
        if player then
            player.set_team(team)
            respawn_alive(player)
        end
    end

    function remove_from_roster(team: team_id, username: string): ()
        -- do nothing if team doesnt have a roster
        local roster = rosters[team]
        if not roster then
            return
        end
    
        -- remove from roster
        local index = table.find(roster, username)
        if not index then
            return
        end
        table.remove(roster, index)

        -- remove roster if empty because of this
        if #roster == 0 then
            clear_roster(team)
        end
    end
    function remove_from_all_rosters(username: string)
        for team, _ in rosters do
            remove_from_roster(team, username)
        end
    end
end

do -- roster apply
    -- update the in-game team the specific player is in
    function update_team(player: player): ()
        local cur_team = player.get_team()
        local other_team = get_other_team(cur_team)

        -- nil if team doesnt have roster, true/false for if player is in roster
        local cur_roster = is_in_roster(player.name, cur_team)
        local other_roster = is_in_roster(player.name, other_team)

        -- despawn if neither team can take the player
        if cur_roster == false and other_roster == false then
            player.kill()
            return
        end
        -- explicitly on current team
        if cur_roster == true then
            return
        end

        local cur_priority = cur_roster and 2 or cur_roster == false and 0 or 1 --  cur_roster == nil and 0 or cur_roster and 2 or 1
        local other_priority = other_roster and 2 or other_roster == false and 0 or 1
        -- other team has priority
        if other_priority > cur_priority then
            player.set_team(other_team)
            respawn_alive(player)
            return
        end
        -- current team has priority, dont switch

        -- sanity check
        if cur_roster == false then
            player.kill()
            return
        end
    end

    function sanity_checks()
        if not rosters then
            warn("rosters was nil")
            rosters = {}
        end
        
        -- clear rosters with a length of zero, unintentional state
        for team, roster in rosters do
            if #roster == 0 then
                warn(`team {team} had a 0-length roster`)
                rosters[team] = nil
            end
        end

        local count_teams_with_roster = shared.dlcomp_table.get_size(rosters)
        if count_teams_with_roster == 0 then
            disable_rosters()
        else
            enable_rosters()
        end
    end

    -- update the in-game team of every player
    function apply_roster_rules()
        sanity_checks()
        for _, player in players.get_all() do
            update_team(player)
        end
    end
end

do -- controls
    function switch_player(username: string, want_team: team_id?)
        local player = players.get(username)
        if not player then
            error(`no player with username [{username}]`)
        end

        local previous_team = player.get_team()
        local team = want_team or get_other_team( previous_team )
        if previous_team == team then
            return team
        end

        -- remove from previous roster, might get switched back otherwise
        remove_from_roster(previous_team, player.name)
        -- add to roster if the new team has one
        if rosters[team] then
            add_to_roster(team, player.name)
        else
            player.set_team(team)
            respawn_alive(player)
        end

        return team
    end

    function team_swap()
        -- update rosters
        rosters.attacker, rosters.defender = rosters.defender, rosters.attacker

        -- update players
        for _, player in pairs( players.get_all() ) do
            local want_team = get_other_team( player.get_team() )
            player.set_team(want_team)
            respawn_alive(player)
        end
    end

    function team_scramble()
        -- no good option for what to do with rosters, just clear them
        disable_rosters()

        -- scramble all players in a random order
        local scrambled_player_list = shared.dlcomp_table.scramble( players.get_all() )

        -- loop over the scrambled list, alternating which team you place them in
        local next_team = all_team_ids[math.random(#all_team_ids)]
        for _, player in scrambled_player_list do
            -- move to team
            player.set_team(next_team)
            respawn_alive(player)

            next_team = get_other_team(next_team)
        end
    end

    function bulk_add(team: team_id, ...: flattable_strings): ()
        assert_team(team)

        for _, username in shared.dlcomp_table.flat_strings(...) do
            add_to_roster(team, username)
        end
        apply_roster_rules()
    end
    function bulk_remove(...: flattable_strings): ()
        for _, username in shared.dlcomp_table.flat_strings(...) do
            remove_from_all_rosters(username)
        end
        apply_roster_rules()
    end

    function team_lock()
        rosters = {}
        for _, player in players.get_all() do
            add_to_roster(player.get_team(), player.name)
        end
    end
end

do -- register chat commands
    shared.dlcomp_command_bot.add_command("switch", "switch the team of the specified player", function(args: string)
        local team, parsed = shared.dlcomp_parser.get_team(args)
        -- ignore the parse for a team if we didnt find anything
        local remaining_args = parsed.remaining_text
        if team == nil then
            remaining_args = args
        end

        local found, unknown = shared.dlcomp_parser.remaining_players(remaining_args)

        local updated = 0
        for _, player in found do
            local previous_team = player.get_team()
            switch_player(player.name, team)
            if previous_team ~= player.get_team() then
                updated += 1
            end
        end

        chat.send_announcement(`moved {updated} players`)
        shared.dlcomp_parser.assert_remaining_players(found, unknown)
        return nil
    end)

    shared.dlcomp_command_bot.add_command("team_swap", "swap rosters and the teams of everyone", function(args: string): string?
        team_swap()
        return "teams and rosters have been swapped"
    end)

    shared.dlcomp_command_bot.add_command("team_scramble", "scramble players into teams randomly", function(args: string)
        team_scramble()
        return "teams have been scrambled; rosters cleared"
    end)

    shared.dlcomp_command_bot.add_command("team_set", "set a roster for a specific team, format is team_set <TEAM> <PLAYER...>", function(args: string, extra: command_call_info): string?
        local team, parsed = shared.dlcomp_parser.get_team(args)
        if not team then
            return "unclear team name, try ANTO or SYNO as the first arg"
        end

        -- get usernames, I explicitly dont want to check if theyre in the server
        -- since this command is mainly for known rosters that you just paste in
        local usernames = shared.dlcomp_parser.remaining_strings(parsed.remaining_text)
        if #usernames == 0 then
            usernames = nil
        else
            -- we're setting the roster, enable rosters
            enable_rosters()
        end

        -- set roster
        rosters[team] = usernames
        apply_roster_rules()
        return "success"
    end)

    shared.dlcomp_command_bot.add_command("team_add", "add player to a specific team's roster, format is team_add <TEAM> <PLAYER...>", function(args: string, extra: command_call_info): string?
        local team, parsed = shared.dlcomp_parser.get_team(args)
        if not team then
            return "unclear team name, try ANTO or SYNO as the first arg"
        end

        -- get players from args, and get the found player's usernames
        local player_list = shared.dlcomp_parser.remaining_players_throwing(parsed.remaining_text)
        local usernames = shared.dlcomp_table.get_usernames_of_players(player_list)

        -- update rosters
        bulk_add(team, usernames)
        return `updated {#usernames} players`
    end)

    shared.dlcomp_command_bot.add_command("team_remove", "remove a player from rosters", function(args: string, extra: command_call_info): string?
        -- get players from args, and get the found player's usernames
        local player_list = shared.dlcomp_parser.remaining_players_throwing(args)
        local usernames = shared.dlcomp_table.get_usernames_of_players(player_list)

        -- update rosters
        bulk_remove(usernames)
        return `updated {#usernames} players`
    end)

    shared.dlcomp_command_bot.add_command("team_clear", "remove team restrictions from the specified team, or both", function(args: string, extra: command_call_info): string?
        local team, parsed = shared.dlcomp_parser.get_team(args)
        -- let team be nil if the arg is empty, clears both teams
        if not team and parsed.converted_from ~= "" then
            return `unclear team {parsed.converted_from}`
        end

        return clear_roster(team)
    end)

    shared.dlcomp_command_bot.add_command("team_lock", "", function(args: string, extra: command_call_info): string?
        team_lock()
        return "teams locked"
    end)

    shared.dlcomp_command_bot.add_command("team_limit", "sets how many players on a team can be spawned in at once", function(args: string, extra: command_call_info): string?
        local team, team_parsed = shared.dlcomp_parser.get_team(args)
        local limit, limit_parsed
        if not team then
            -- team is nil, two things couldve happened:
            -- 1. client mistyped the team name; the number/limit parse will fail aswell
            -- 2. client explicitily didnt specify a team; set the team limit for both teams
            limit = tonumber(team_parsed.converted_from)
            limit_parsed = team_parsed
        else
            limit, limit_parsed = shared.dlcomp_parser.get_number(team_parsed.remaining_text)
        end
        
        -- limit arg can be nil to clear the limit, but make sure thats actually what the client wanted
        if not limit and limit_parsed.converted_from ~= "" then
            error("failed to parse as number")
        end

        if limit and limit < 0 then
            limit = nil
        end

        if team then
            -- set a specific team's limit
            max_spawned[team] = limit
            return limit and `set {team} alive limit to {limit}` or `cleared {team}'s alive limit`
        else
            -- set both team's limit
            max_spawned["attacker"] = limit
            max_spawned["defender"] = limit
            return limit and `set both team's alive limit to {limit}` or `cleared alive limits`
        end
    end)

    shared.dlcomp_command_bot.add_command("team_status", "prints status for rosters", function(args: string, extra: command_call_info): string?
        print_status()
        return "printed to console"
    end)
end

do -- event listeners
    on_player_spawned:Connect(function(username: string)
        local player = players.get(username)
        if not player then
            error(`couldnt find player object for spawning player [{username}]`)
        end
        local team = player.get_team()
        
        local in_roster = is_in_roster(username, team)
        if in_roster == nil then
            -- no roster restrictions, let them spawn
            return
        end
        
        -- player is admin, notify but always let them spawn
        if not in_roster and table.find(shared.dlcomp_command_bot.admin_list, username) then
            chat.send_announcement(`letting admin [{username}] spawn despite roster restrictions`)
            return
        end
        
        -- not in roster, notify and prevent from spawning
        if not in_roster then
            player.kill()
            chat.send_announcement(`blocked [{username}]'s spawn, not in roster for {team}`)
            return
        end

        -- team's alive-limit has been reached
        local spawn_limit = max_spawned[team]
        if spawn_limit and get_team_amount_spawned(team) >= spawn_limit then
            player.kill()
            chat.send_announcement(`blocked [{username}]'s spawn, team has >={spawn_limit} players spawned`)
            return
        end

        -- passed all the guards, let them spawn
        return
    end)
    
    on_player_joined:Connect(function(username: string)
        local player = players.get(username)
        if not player then
            error(`couldnt find player object for joining player [{username}]`)
        end

        update_team(player)
    end)
end

shared.dlcomp_team = {
    rosters = rosters,
    max_spawned = max_spawned,

    disable_rosters = disable_rosters,
    apply_roster_rules = apply_roster_rules,

    clear_roster = clear_roster,
    remove_from_all_rosters = remove_from_all_rosters,
    add_to_roster = add_to_roster,
    bulk_add = bulk_add,
    bulk_remove = bulk_remove,
    
    team_lock = team_lock,
    team_scramble = team_scramble,
    team_swap = team_swap,

    is_in_roster = is_in_roster,
    print_status = print_status,
}
