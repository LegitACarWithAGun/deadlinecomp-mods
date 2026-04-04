--!strict

-- Command Bot module
-- listens for commands written in chat and passes them to other modules
-- exists because the built-in command bot doesnt let you register custom commands

-- check if a version of the bot is already running
if shared.dlcomp_command_bot then
    return
end

-- load arg parser module
if not shared.dlcomp_parser then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/arg-parser.luau")
end
if not shared.dlcomp_table then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/table.luau")
end
if not shared.dlcomp_string then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/string.luau")
end

local prefix = ";"
local commands: {[string]: command_data} = {}
local admin_list = {} -- see bottom of script for default admins
local command_permissions = true -- whether commands are limited to admins only

type command_callback = (args: string, extra: command_call_info) -> string?
type command_data = {
    name: string,
    explanation: string,
    callback: command_callback,
}





function add_command(name: string, explanation: string, callback: command_callback)
    commands[name] = {
        name = name,
        explanation = explanation,
        callback = callback,
    }
end

-- returns (is_changed, message)
function toggle_admin(player_name: string, toggle: boolean?): (boolean, string)
    -- is the target player already a admin?
    local existing_index = table.find(admin_list, player_name)
    local is_admin = not not existing_index

    -- user wants to switch the player's admin powers
    if toggle == nil then
        toggle = not is_admin
    end

    -- returns
    if toggle == is_admin then
        return false, "no changes"
    elseif toggle then
        table.insert(admin_list, player_name)
        return true, `gave [{player_name}] admin powers`
    else
        table.remove(admin_list, existing_index)
        return true, `removed [{player_name}]'s admin powers`
    end
end

function toggle_command_permissions(toggle: boolean?)
    if toggle == nil then
        toggle = not command_permissions
    end
    local as_bool = not not toggle
    command_permissions = as_bool
    print(`command_permissions = {as_bool}`)
end

function construct_command_call_info(sender, channel, raw): command_call_info
    -- get the player object of the caller
    local caller = players.get(sender)
    if not caller then
        error(`cant get player object from username [{sender}]`)
    end

    return {
        caller = caller,
        message_channel = channel,
        raw_message = raw,
    }
end

function split_by_first_whitespace(input: string): (string, string)
    local before = string.match(input, "^%S+") or ""
    local after = string.sub(input, before:len()+2)
    return before, after
end

function can_execute_command(command: command_data, username: string): boolean
    if not command_permissions then
        return true
    end
    -- only let admins execute commands
    if not table.find(admin_list, username) then
        return false
    end
    return true
end

-- attempt to find command info from input, and return rest of input as args
function gather_command_from_string(input: string): (command_data, string)
    local command_name, command_args = split_by_first_whitespace(input)
    local command = commands[command_name]
    if not command then
        error(`no command with name [{command_name}]`)
    end
    return command, command_args
end

-- input can not have a prefix
function attempt_execute_as(input: string, extra: command_call_info): string?
    -- get command info and args from input text
    local command, command_args = gather_command_from_string(input)

    -- check if the given player can call that command
    local username = extra.caller.name
    if not can_execute_command(command, username) then
        error(`player [{username}] can not execute command [{command.name}]`)
    end

    -- execute command
    return command.callback(command_args, extra)
end

function run(...: any)
    local caller = function_caller -- function_caller seemingly gets set to nil if any other function gets called, including table.concat
    local input = table.concat({...}, " ") -- automatically calls tostring on values
    local extra = construct_command_call_info(caller, "dlcomp_command_bot.run", input)

    local result = attempt_execute_as(input, extra)
    print( tostring(result) )
end

-- listen for messages in chat
chat.player_chatted:Connect(function(sender, channel, raw_message)
    -- check for and remove prefix
    local has_prefix, content = shared.dlcomp_string.cut_prefix(raw_message, prefix)
    if not has_prefix then
        return
    end

    -- extra info
    local success_extra, extra = pcall(construct_command_call_info, sender, channel, raw_message)
    if not success_extra then
        chat.send_announcement(`constructing extra: {extra}`)
        return
    end

    -- attempt to find and call command
    local success_execute, result = pcall(attempt_execute_as, content, extra)
    if not success_execute then
        chat.send_announcement(`ERR: {result}`)
    elseif result then
        chat.send_announcement(result)
    end
end)





-- built in commands
-- TODO: page this
add_command("help", "prints this message", function(args: string)
    local results = {}
    for _, info in pairs(commands) do
        table.insert(results, `{info.name} - {info.explanation}`)
    end
    return table.concat(results, "\n")
end)

add_command("admin", "toggles a player's ability to run commands, format: ;admin player_name [toggle]", function(args: string)
    local info, want_player, toggle
    want_player, info = shared.dlcomp_parser.get_player(args)
    toggle, info = shared.dlcomp_parser.get_bool(info.remaining_text)

    -- no args given, print the name of every admin
    if not string.match(args, "%S+") then
        print( table.concat(admin_list, "; ") )
        return "printed admin list to server console"
    end

    if not want_player then
        return "unclear target player"
    end

    local success, message = toggle_admin(want_player.name, toggle)
    return `{success and "SUCCESS" or "FAIL"}: {message}`
end)





-- let other modules add/remove commands
shared.dlcomp_command_bot = {
    add_command = add_command,
    toggle_admin = toggle_admin,
    toggle_command_permissions = toggle_command_permissions,
    run = run,
    admin_list = admin_list,
}





-- add default admins
-- note that sharedvars.vip_owner currently seems to change when the host leaves or someone else joins first
-- function_caller is a better way to get the server owner's name, but is nil if ran from the autorun
local default_admin = function_caller or sharedvars.vip_owner
toggle_admin(default_admin, true)

chat.send_announcement(`loaded dlcomp_command_bot; default admin is [{default_admin}]; say {prefix}help to get a list of commands`)
