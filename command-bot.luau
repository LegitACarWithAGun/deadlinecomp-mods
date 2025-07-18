-- Command Bot module
-- listens for commands written in chat and passes them to other modules
-- exists because the built-in command bot doesnt let you register custom commands

-- check if a version of the bot is already running
if shared.dlcomp_command_bot then
    return
end

-- also import the arg-parser module so each module doesnt have to have logic to import it on its own
require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/arg-parser.luau")

local prefix = ";"
local commands: {[string]: command_data} = {}

type command_callback = (args: string) -> string?
type command_data = {
    name: string,
    explanation: string,
    callback: command_callback,
}

function add_command(name: string, explanation: string, callback: (args: string) -> string?)
    commands[name] = {
        name = name,
        explanation = explanation,
        callback = callback,
    }
end

function remove_command(name: string)
    commands[name] = nil
end

-- listen for commands in chat
chat.player_chatted:Connect(function(sender, channel, content)
    -- check if the command prefix exists, and remove it if it does
    if content:sub(1, prefix:len()) ~= prefix then
        chat.send_announcement(`missing prefix`)
        return
    end
    content = content:sub(prefix:len()+1)

    -- only let the server owner execute commands
    if sender ~= sharedvars.vip_owner then
        chat.send_announcement(`youre not the private server owner.`)
        return
    end

    -- scan until the next whitespace and treat it as the command name
    local command_name = string.match(content, "^%S+") or ""

    -- attempt to find command from name
    local command_info = commands[command_name]
    if not command_info then
        chat.send_announcement(`no command with name [{command_name}]`)
        return
    end

    -- leave the rest of the user input raw, and let the callback deal with it
    local command_args = string.sub(content, command_name:len()+2)

    -- execute command
    local result = command_info.callback(command_args)
    if (result) then
        chat.send_announcement(result)
    end
end)





-- built in commands
add_command("help", "prints this message", function(args: string)
    local results = {}
    for _, info in pairs(commands) do
        table.insert(results, `{info.name} - {info.explanation}`)
    end
    return table.concat(results, "\n")
end)


-- let other mods add/remove commands
shared.dlcomp_command_bot = {
    add_command = add_command,
    remove_command = remove_command,
}

chat.send_announcement(`loaded dlcomp-command-bot module with prefix {prefix}`)
