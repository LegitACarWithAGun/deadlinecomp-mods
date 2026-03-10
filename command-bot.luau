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

function construct_command_call_info(sender, channel, raw): command_call_info?
    -- get the player object of the caller
    local caller = players.get(sender)
    if not caller then
        chat.send_announcement(`cant get player object from username [{sender}]`)
        return nil
    end

    return {
        caller = caller,
        message_channel = channel,
        raw_message = raw,
    }
end

-- listen for messages in chat
chat.player_chatted:Connect(function(sender, channel, content)
    local raw_message = content

    -- check if the message has the command prefix
    if content:sub(1, prefix:len()) ~= prefix then
        return
    end
    -- remove the command prefix
    content = content:sub(prefix:len()+1)

    -- only let admins execute commands
    if command_permissions and not table.find(admin_list, sender) then
        chat.send_announcement(`only admins can execute commands. you are [{sender}]`)
        print(`admins: {table.concat(admin_list, "; ")}`)
        return
    end

    -- treat everything before the next whitespace as the command name
    local command_name = string.match(content, "^%S+") or ""

    -- attempt to find command from name
    local command_info = commands[command_name]
    if not command_info then
        chat.send_announcement(`no command with name [{command_name}]`)
        return
    end

    -- leave the rest of the user input raw, and let the callback deal with it
    local command_args = string.sub(content, command_name:len()+2)

    -- get the player object of the caller
    local caller = players.get(sender)
    if not caller then
        chat.send_announcement(`cant get player object from username [{sender}]`)
        return
    end

    -- generate extra info
    local extra = construct_command_call_info(sender, channel, raw_message)
    if not extra then
        return
    end

    -- execute command
    local success, result = pcall(command_info.callback, command_args, extra)
    if not success then
        chat.send_announcement(`ERROR: {result}`)
        warn(`error on command-bot command [{command_info.name}]: {result}`)
        return
    end
    if result ~= nil then
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
        local admin_list_string = table.concat(admin_list, "; ")
        print(admin_list_string)
        return admin_list_string
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
    admin_list = admin_list,
}





-- add default admins
-- note that sharedvars.vip_owner currently seems to change when the host leaves or someone else joins first
-- function_caller is a better way to get the server owner's name, but is nil if ran from the autorun
local default_admin = function_caller or sharedvars.vip_owner
toggle_admin(default_admin, true)

chat.send_announcement(`loaded dlcomp_command_bot; default admin is [{default_admin}]; say {prefix}help to get a list of commands`)
