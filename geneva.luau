-- Geneva, a module for enforcing equipment rules
-- terms:
-- - equipment/weapon = everything thats equippable, slots 1-4
-- - gun = firearms and rpgs, everything thats in slots 1 and 2
-- - utility = grenades and knives, everything thats in slots 3 and 4, internally called `throwable`

-- load command bot
if not shared.dlcomp_command_bot then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/command-bot.luau")
end
-- load arg parser module
if not shared.dlcomp_parser then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/arg-parser.luau")
end
-- load common functions
if not shared.dlcomp_table then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/table.luau")
end

-- rules
local banned_weapon_list: {string} = {}
local max_equippable_grenades: number = 2
local limited_utility: {string} = {"F1", "M67"} -- these count towards max_equippable_grenades
local custom_rules: {custom_geneva_rule} = {}

-- behaviour
local enforce_rules = true -- whether the rules are active
local announce_equipment_cleaning = true -- announces in chat what equipment was removed from a player's loadout, does not affect rules themselves

-- constants
local slot_order = {"primary", "secondary", "throwable1", "throwable2"}
local known_weapon_types = {"weapon", "throwable", "healing"}

do -- human-facing command-line stuff

    -- rules:
    function set_banned_weapons(new_bans: {string})
        -- warn the user if we're not aware of all of the guns
        local unknown_list = shared.dlcomp_table.not_in_filter(new_bans, config.weapon_names)
        if #unknown_list ~= 0 then
            warn(`unknown weapons in ban list: `, table.concat(unknown_list, ", "))
        end

        banned_weapon_list = new_bans
    end

    function set_custom_rules(new_rules: {custom_geneva_rule})
        custom_rules = new_rules
    end

    function set_max_grenades(max_grenades: number)
        max_equippable_grenades = math.max(max_grenades, 0)
    end


    -- behaviour:
    function should_announce_equipment_cleaning(want: boolean)
        want = not not want -- convert to bool
        announce_equipment_cleaning = want
        print(`announce_equipment_cleaning = {want}`)
    end

    function toggle_rules(enabled: boolean?)
        if enabled == nil then
            enabled = not enforce_rules
        end
        enforce_rules = enabled

        print(`enforce_rules = {enabled}`)
        chat.send_announcement(`GENEVA rules have been {enforce_rules and "enabled" or "disabled"}`)
        if enforce_rules then
            announce_ruleset()
        end
    end


    -- info:
    function print_known_weapons()
        for _, weapon_name in config.weapon_names do
            print(weapon_name)
        end
    end

    function announce_ruleset()
        if not enforce_rules then
            chat.send_announcement("GENEVA IS DISABLED, everything goes.")
            return
        end

        local format_list = function(list: {string}): string
            return #list > 0 and table.concat(list, ", ") or "none"
        end

        chat.send_announcement("ACTIVE GENEVA RULESET:")
        chat.send_announcement(`- banned weapons: { format_list(banned_weapon_list) }`)
        chat.send_announcement(`- max equippable grenades: {max_equippable_grenades}`)

        local custom_rule_names = {}
        for _, rule in custom_rules do
            table.insert(custom_rule_names, rule.name)
        end
        chat.send_announcement(`- custom rules: { format_list(custom_rule_names) }`)
    end
end

do -- helper functions
    function clear_slot(player: player, context: geneva_context, slot: string, reason: string): ()
        context.feedback[slot] = reason
        player.set_weapon(slot, "nothing")
    end

    function get_weapon_type(weapon: weapon_data): string
        return weapon.type
    end
    -- returns true if weapon type is unknown
    function remove_if_unknown_weapon_type(player: player, context: geneva_context, slot: string, weapon: weapon_data): boolean
        local success, weapon_type = pcall(get_weapon_type, weapon)
        if not success then
            clear_slot(player, context, slot, `failed to get weapon type: {weapon_type}`)
            return
        end

        if table.find(known_weapon_types, weapon_type) then
            return false
        end

        warn("unknown weapon type:", weapon_type)
        clear_slot(player, context, slot, `unknown weapon type {weapon_type}`)
        return true
    end
    function get_weapon_name(weapon: weapon_data): string
        local weapon_type = get_weapon_type(weapon)
        if weapon_type == "weapon" then
            return weapon.client_data.name
        elseif weapon_type == "throwable" or "healing" then
            return weapon.name
        else
            error(`unknown weapon type: {weapon_type}`)
        end
    end

    --- iterate over every filled slot in the player's inventory, returning slot_name and weapon_data
    function iter_slots(player: player)
        local slot_index = 1
        return function()

            while (slot_index <= #slot_order) do
                local slot_name = slot_order[slot_index]
                local slot_data = player.get_weapon_data_from_character(slot_name)

                slot_index += 1
                if slot_data == nil then
                    continue
                end
                return slot_name, slot_data
            end
            
            return nil
        end
    end

    function collect_slots_containing(player: player, ...: flattable_strings): {string}
        local output = {}
        local search_for = shared.dlcomp_table.flat_strings(...)

        for slot, weapon in iter_slots(player) do
            local name = get_weapon_name(weapon)
            if not table.find(search_for, name) then
                continue
            end

            table.insert(output, slot)
        end
        return output
    end
end

do -- implementation
    function format_feedback(feedback: {[string]: string}): string?
        if not announce_equipment_cleaning then
            return nil
        end

        local formatted_list = {}

        -- convert the map into an array
        for _, slot_name in slot_order do
            local warning = feedback[slot_name]
            if not warning then
                continue
            end
            -- format text
            table.insert(formatted_list, `({slot_name}) {warning}`)
        end

        if #formatted_list == 0 then
            return nil
        end
        return table.concat(formatted_list, ", ")
    end

    function handle_slot(player: player, slot_name: string, slot_bans: {string}, context: geneva_context)
        local equipment = player.get_weapon_data_from_character(slot_name)
        if not equipment then
            return
        end

        if remove_if_unknown_weapon_type(player, context, slot_name, equipment) then
            return
        end
        local weapon_name = get_weapon_name(equipment)

        -- check if weapon is banned
        if table.find(slot_bans, weapon_name) then
            clear_slot(player, context, slot_name, `{weapon_name} is banned`)
            return
        end

        -- allowed to only carry a limited amount of this type of weapon
        if table.find(limited_utility, weapon_name) then
            if context.allowed_nades_left <= 0 then
                clear_slot(player, context, slot_name, `max {max_equippable_grenades} grenades`)
                return
            end
            context.allowed_nades_left -= 1
            return
        end
    end

    on_player_spawned:Connect(function(player_name: string)
        if not enforce_rules then
            return
        end

        local player = players.get(player_name)
        local context: geneva_context = {
            feedback = {},
            allowed_nades_left = max_equippable_grenades,
        }

        -- check slots
        for _, slot_name in slot_order do
            handle_slot(
                player, slot_name,
                banned_weapon_list,
                context
            )
        end

        -- apply custom rules
        for _, rule in custom_rules do
            rule.callback(player, context)
        end

        -- print feedback
        local feedback_string = format_feedback(context.feedback)
        if feedback_string then
            chat.send_announcement(`GENEVA for [{player_name}]: {feedback_string}`)
        end
    end)
end


-- chat commands
shared.dlcomp_command_bot.add_command("geneva_rules", "toggles geneva enforcing equipment rules", function(args: string)
    local toggle, _ = shared.dlcomp_parser.get_bool(args)
    toggle_rules(toggle)
end)
shared.dlcomp_command_bot.add_command("geneva_announce", "toggles whether geneva announces why a player's equipment got removed in chat", function(args: string)
    local toggle, _ = shared.dlcomp_parser.get_bool(args)
    if toggle == nil then
        toggle = not announce_equipment_cleaning
    end

    announce_equipment_cleaning = toggle
    return `geneva's equipment enforcement announcements are {toggle and "Enabled" or "Disabled"}`
end)


shared.dlcomp_geneva = {
    -- rules
    toggle_rules = toggle_rules,
    set_banned_weapons = set_banned_weapons,
    set_max_grenades = set_max_grenades,
    set_custom_rules = set_custom_rules,
    -- behavior
    should_announce_equipment_cleaning = should_announce_equipment_cleaning,
    -- information, entierly human-facing
    print_known_weapons = print_known_weapons,
    announce_ruleset = announce_ruleset,
    -- helper functions
    clear_slot = clear_slot,
    get_weapon_type = get_weapon_type,
    get_weapon_name = get_weapon_name,
    iter_slots = iter_slots,
    collect_slots_containing = collect_slots_containing,
}
