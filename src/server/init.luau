
-- TODO: bundler workaround
local _ = {
    require("@self/command-bot"),
    require("@self/geneva"),
    require("@self/misc"),
    require("@self/moderation"),
    require("@self/round"),
    require("@self/team"),
    require("@self/disconnect-log"),
}

-- workaround to allow running commands through the console
shared.dlcomp_command_bot = require("@self/command-bot")

return nil