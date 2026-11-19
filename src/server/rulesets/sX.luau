local geneva = require("../geneva")

return geneva.register_ruleset({
	name = "sX",
	banned_weapons = {
		-- launchers
		"RPG7",
		"PSRL",
		-- explosives
		"M67",
		"Molotov",

		-- unaccessible in UI
		"Turret",
		"PlacingTool",
		"StarterCharacter", -- ?
	},
	max_grenades = 1,
	sharedvars = {
		plr_enable_mounting = false, -- disables all mounting, currently buggy and (probably) difficult enforce
	}
})
