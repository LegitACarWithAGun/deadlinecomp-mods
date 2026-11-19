local geneva = require("../geneva")

return geneva.register_ruleset({
	name = "test_cup",
	banned_weapons = {
		-- launchers
		"RPG7",
		"PSRL",
		-- throwables
		"M67",
		"M84",
		"Zarya3",
		"Molotov",
		-- unaccessible in UI
		"Turret",
		"PlacingTool",
		"StarterCharacter",
	},
	max_grenades = 1,
	sharedvars = {
		plr_enable_mounting = false, -- disables all mounting, currently buggy and (probably) difficult enforce
	},
	custom_rules = {
		["ban >40r mags"] = function(player: player, context: geneva.context)
			for slot, weapon in geneva.iter_slots(player) do
				if weapon.type ~= "weapon" then return end

				local mag_capacity
				if weapon.ammo.type == "detachable_magazine" then
					mag_capacity = weapon.ammo.metadata.magazine_capacity
				elseif weapon.ammo.type == "internal_magazine" then
					-- off by 1 on the 870 and launchers because of a inaccessible animation variable, not relevant rn
					mag_capacity = weapon.ammo.rounds_in_magazine
				else
					geneva.clear_slot(player, context, slot, `unknown ammo type {weapon.ammo.type}`)
					return
				end

				if mag_capacity <= 40 then return end
				geneva.clear_slot(player, context, slot, `{mag_capacity}/40r mag`)
			end
		end
	}
})