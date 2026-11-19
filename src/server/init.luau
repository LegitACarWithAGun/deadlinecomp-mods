local maid = require("./shared/maid").new("dlcomp-init")

maid["sharedvars-qol"] = require("./shared/temp-sharedvars").New("dlcomp-init", 0, {
	-- team / roster
	gm_team_balancing_threshold = 9999,
	gm_team_scrambling = false,
	-- ref
	plr_freecam_fov = 90,
	gm_match_time_minutes = 8, -- round command uses this as a default
	-- small obstructions
	chat_tips_enabled = false,
	dbg_editor_disable_tutorial = true,
}):Enable()

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

-- load staff
local command_bot = require("@self/command-bot")
command_bot.add_admin(
	-- refs
	"LegitACarWithAGun", "areoseka", "Mango911473", "tezukology",
	-- trial refs
	"eifwehuy", "Inhale_8632", "killmasterpro", "korbi3105", "glory_leaves", "MeNoCare_1", "Petrumetru23224", "Thetruesaint432", "wsznmyhero", "xalwaleedx", "ZanderFolf", "Simonupd"
)

-- workaround to allow running commands through the console
shared.dlcomp_command_bot = require("@self/command-bot")
return {
	maid = maid
}