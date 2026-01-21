-- responsible for loading all of the modules, use as the default entrypoint

-- dont load twice
if shared.dlcomp_all_loaded then
    return
end


-- load command bot
if not shared.dlcomp_command_bot then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/command-bot.luau")
end

-- load arg parser module
if not shared.dlcomp_parser then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/arg-parser.luau")
end

-- load countdown module
if not shared.dlcomp_countdown then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/countdown.luau")
end

-- load geneva (equipment rules)
if not shared.dlcomp_geneva then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/geneva.luau")
end

if not shared.dlcomp_setup_reader then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/setup-reader.luau")
end

-- load round command
if not shared.dlcomp_round then
    require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/round.luau")
end

-- load team commands
require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/team.luau")

-- load moderation commands
require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/moderation.luau")

-- load misc commands
require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/misc.luau")

shared.dlcomp_all_loaded = true
