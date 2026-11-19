-- qol sharedvars
sharedvars.gm_team_balancing_threshold = 9999
sharedvars.chat_tips_enabled = false
sharedvars.gm_team_scrambling = false
sharedvars.plr_freecam_fov = 90
sharedvars.gm_match_time_minutes = 8 -- round command uses this as a default

-- load modules
require("@self/command-bot")
require("@self/geneva")
require("@self/misc")
require("@self/moderation")
require("@self/round")
require("@self/team")
require("@self/disconnect-log")
require("@self/rulesets")

-- load ruleset
local geneva = require("@self/geneva")
geneva.load_ruleset("test_cup")
geneva.toggle_rules(true)

-- workaround to allow running commands through the console
shared.dlcomp_command_bot = require("@self/command-bot")
return nil