-- player highlights + markers
-- currently just acts as a proxy for freecam

local replicate = require("../replicate-client")
local dlcomp_avatar = require("../avatar")
local ui_helper = require("../ui-helper")
local resolution = require("../resolution")
local activator = require("../../shared/activator").new("dlcomp-esp")

local module = {
	activator = activator,
}

-- config
local fov = 95
local plr_marker_font_size = 11
local plr_marker_offset = Vector2.new(0, 4)
local highlight_colors = {
	attacker = Color3.fromHex("FF5353"),
	defender = Color3.fromHex("1E90FF")
}
local highlight_color_backup = Color3.new(0.75, 0.75, 0.75)
local highlight_fill_transparency = 0.85
local highlight_outline_transparency = 0.5

local HIGHLIGHT_INSTANCE_NAME = "dlcomp-esp-highlight"





do -- player markers
	function draw_player_marker(text: string, color: Color3, location_screenspace: Vector2)
		iris.PushConfig({
			-- disable all relevant padding
			IgnoreGuiInset = true,
			WindowPadding = Vector2.zero,
			ContentWidth = UDim.new(1, 0),
			-- ItemWidth = UDim.new(1, 0),
	
			-- style
			WindowBorderSize = 0,
			TextSize = plr_marker_font_size,
			TextTransparency = 0.15,
		})
	
			local marker_window = iris.Window( ui_helper.minimal_window_args("player marker") )--, {position = iris_position, size = iris_size})
				iris.Text({text, false, color})
			iris.End()
			
			local text_size_px = Vector2.new(ui_helper.get_text_width(text.."  ", plr_marker_font_size), plr_marker_font_size)
			marker_window.position:set(location_screenspace - text_size_px/2 + plr_marker_offset)
			marker_window.size:set(text_size_px)
	
		iris.PopConfig()
	end

	function draw_player_markers()
		for username, player_model in dlcomp_avatar.spawned_players do
			-- dont create markers for people on our own team
			local info = replicate.state.players[username]
			local self_info = replicate.self_info
			if info and self_info and (info.team == self_info.team) then
				continue
			end
	
			local torso = player_model.find_first_child("torso")
			if not torso then
				warn("no torso for player", username)
				continue
			end

			-- get position for marker
			local screenspace_location = ui_helper.world_to_viewport(framework.character.get_camera_cframe(), resolution.resolution, fov, torso.position)
			local screenspace_v2 = Vector2.new(screenspace_location.X, screenspace_location.Y)
			if screenspace_location.Z < 0 then
				continue
			end

			-- properties for the marker contents			
			local text = info and info.username or "n/a"
			local color = --[[info and highlight_colors[info.team] or]] highlight_color_backup
			draw_player_marker(text, color, screenspace_v2)
		end
	end
end





do -- player highlights
	local function create_highlight(parent: luauInstance)
		local highlight = create_instance("Highlight")
		highlight.Name = HIGHLIGHT_INSTANCE_NAME
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillTransparency = highlight_fill_transparency
		highlight.OutlineTransparency = highlight_outline_transparency

		highlight.add_tag(dlcomp_avatar.TAG_DESTROY_ON_KILL)
		highlight.Parent = parent
		return highlight
	end

	function update_highlight(username: string, model: luauInstance?)
		model = model or dlcomp_avatar.spawned_players[username]
		if not model then return end
	
		local info = replicate.state.players[username]
		if not info then
			warn(`no info found for player {username}`)
			return
		end

		local color = highlight_colors[info.team] or highlight_color_backup
		local highlight = model.find_first_child(HIGHLIGHT_INSTANCE_NAME) or create_highlight(model)
		highlight.OutlineColor = color
		highlight.FillColor = color
	end

	function remove_all_highlights()
		local models = get_chars_root()
		for _, model in models.get_children() do
			local highlight = model.find_first_child(HIGHLIGHT_INSTANCE_NAME)
			if not highlight then continue end
			highlight.destroy()
		end
	end
end





function iris_render()
	if not framework.character.is_alive() then return end

	local success, err = pcall(draw_player_markers)
	if not success then
		warn(`dlcomp-esp: draw player markers: {err}`)
		return
	end
end

activator.OnEnable:Connect(function()
	activator:Bind(replicate.activator, dlcomp_avatar.activator, resolution.activator)

	activator.maid["iris"] = iris:Connect(iris_render)

	-- player has changed teams
	activator.maid["replicate-update"] = replicate.signal_player_update:Connect(function(username: string)
		update_highlight(username)
	end)
	activator.maid["avatar-loaded"] = dlcomp_avatar.signal_model_loaded:Connect(update_highlight)
end)

activator.OnDisable:Connect(function()
	remove_all_highlights()
end)

return module