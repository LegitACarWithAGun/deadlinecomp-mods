-- usage:
  -- just put this in your server autorun: require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/rulesets/default.luau")
  -- if you think you wanna edit it, just copy this entire file into your server autorun, no automatic updates then tho
-- intentionally written in a way where you can run it multiple times safely

-- load all modules
if not shared.dlcomp_all_loaded then
	require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/init.luau")
end


local geneva = shared.dlcomp_geneva
local setup_reader = shared.dlcomp_setup_reader

-- ruleset
geneva.set_banned_weapons({
	"RPG7",
	"PSRL",
	"M67",
	-- "F1",
})
geneva.set_max_grenades(1)

local KF416_problem_stocks = {
	"ar_tr2_stock",
	"hera_arms_cqr_gen1_pistol_grip_stock",
	"thordsen_frs_15_stock",
	"kf_416c_type_2_buttstock",
}
geneva.set_custom_rules({
	{
		name = "KF416 stock stacking",
		callback = function(player: player, context: geneva_context)
			for slot_name, weapon in geneva.iter_slots(player) do
				if weapon.type == "throwable" then
					continue
				end

				local client_data = weapon.client_data
				if client_data.name ~= "KF416" then
					continue
				end

				local root_node = setup_reader.parse_setup(client_data.setup)
				local stocks_found = 0
				for _, stock_name in pairs(KF416_problem_stocks) do
					if not setup_reader.find_first(root_node, stock_name) then
						continue
					end
					stocks_found += 1
				end

				if stocks_found >= 2 then
					player.set_weapon(slot_name, "nothing")
					context.feedback[slot_name] = "KF416 stock stacking"
				end
			end
		end
	}
})

-- behavior
geneva.should_announce_equipment_cleaning(true)


-- give dlcomp staff ability to run commands even if they dont own the server
local command_bot = shared.dlcomp_command_bot
local dlcomp_referees = {
	-- refs
	"LegitACarWithAGun", "klapakol", "Nescixidy", "bachancuc123",
	-- trial refs
	"Username35967", "Inhale_8632", "R_kemot1", "R0lanires", "Ryseran", "korbi3105", "ZanderFolf"
}
for _, name in pairs(dlcomp_referees) do
	command_bot.toggle_admin(name, true)
end

-- UPSTREAM BUG: the only way to read chat messages always reports them coming from the first person in the player list
-- just let everyone run chat commands until that is fixed
command_bot.toggle_command_permissions(false)


-- qol sharedvars
sharedvars.gm_team_balancing_threshold = 9999
sharedvars.chat_tips_enabled = false
sharedvars.gm_team_scrambling = false
sharedvars.plr_freecam_fov = 90


-- finish
geneva.toggle_rules(true) -- this also announces the ruleset in chat
