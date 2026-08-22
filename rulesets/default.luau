-- usage:
  -- just put this in your server autorun: require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/rulesets/default.luau")
  -- if you think you wanna edit it, just copy this entire file into your server autorun, no automatic updates then tho
-- intentionally written in a way where you can run it multiple times safely

-- load all modules
if not shared.dlcomp_all_loaded then
	require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/init.luau")
end


local geneva = shared.dlcomp_geneva

-- ruleset
geneva.set_banned_weapons({
	-- launchers
	"RPG7",
	"PSRL",

	-- explosives
	"M67",
	-- "F1",

	-- flashes
	-- "M84",
	-- "Zarya3",

	-- smokes
	-- "M8HC",
	-- "RGD2",

	-- unaccessible in UI
	"Molotov",
	"Crayon",
	"Turret",
	"PlacingTool",
	"StarterCharacter", -- ?
})
geneva.set_max_grenades(1)
sharedvars.plr_enable_mounting = false -- disables all mounting, currently buggy and (probably) difficult enforce

-- behavior
geneva.should_announce_equipment_cleaning(true)


-- give dlcomp staff ability to run commands even if they dont own the server
local command_bot = shared.dlcomp_command_bot
local dlcomp_referees = {
	-- refs
	"LegitACarWithAGun", "areoseka", "Mango911473", "klapakol", "tezukology",
	-- trial refs
	"eifwehuy", "Inhale_8632", "killmasterpro", "korbi3105", "glory_leaves", "MeNoCare_1", "Petrumetru23224", "Thetruesaint432", "wsznmyhero", "xalwaleedx", "ZanderFolf", "Simonupd",
}
for _, name in dlcomp_referees do
	command_bot.toggle_admin(name, true)
end


-- qol sharedvars
sharedvars.gm_team_balancing_threshold = 9999
sharedvars.chat_tips_enabled = false
sharedvars.gm_team_scrambling = false
sharedvars.plr_freecam_fov = 90
sharedvars.gm_match_time_minutes = 8 -- round command uses this as a default


-- finish
geneva.toggle_rules(true) -- this also announces the ruleset in chat
