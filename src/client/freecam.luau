--!strict

local ui_helper = require("./ui-helper")
local input_helper = require("./input-helper")
local Maid = require("../shared/maid")
local replicate = require("./replicate-client")
local dlcomp_avatar = require("./avatar")
local metronome = require("../shared/metronome")

--- for cleaning up the rendering and input callbacks required for the freecam class to function properly
local maid_active = Maid.new("dlcomp-freecam active")

--- for cleaning up the entire module
local maid_module = Maid.new("dlcomp-freecam module")
maid_module["maid-active"] = maid_active

local module = {
	maid = maid_module,
}

-- config
local plr_marker_font_size = 11
local plr_marker_offset = Vector2.new(0, 4)
local highlight_colors = {
	attacker = Color3.fromHex("FF5353"),
	defender = Color3.fromHex("1E90FF")
}
local highlight_color_backup = Color3.new(0.75, 0.75, 0.75)
local highlight_fill_transparency = 0.85
local highlight_outline_transparency = 0.5
local disable_delay = 3

local HIGHLIGHT_INSTANCE_NAME = "dlcomp-freecam-highlight"
local ACTIVATOR_ID = "dlcomp-freecam"

-- state
local fov = 95
local last_active_tick = -1
local freecam_active = false
local inputs = {
	sprint = false,
	select_preset = false,

	moveStraight = 0,
	moveStrafe = 0,
	moveVertical = 0,
}

local CustomFreecam = {} :: camera_controller
CustomFreecam.__index = CustomFreecam

local function v3SafeUnit(v3: Vector3): Vector3
	if v3.Magnitude == 0 then
		return Vector3.zero
	end
	return v3.Unit
end

local function draw_player_marker(text: string, color: Color3, location_screenspace: Vector2)
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
		local screenspace_location = ui_helper.world_to_viewport(framework.character.get_camera_cframe(), ui_helper.resolution, fov, torso.position)
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

function draw_camera_presets()
	if not inputs.select_preset then
		return
	end

	local padding = 2
	iris.PushConfig({
		WindowBorderSize = 0,
		IgnoreGuiInset = true,
		WindowPadding = Vector2.one * padding,
	})
		for i=1, 1 do
			local screenspace_location, visible = ui_helper.world_to_viewport(framework.character.get_camera_cframe(), ui_helper.resolution, fov, Vector3.zero)
			local screenspace_v2 = Vector2.new(screenspace_location.X, screenspace_location.Y)
			if not visible then
				continue
			end

			local image_size = Vector2.one * 20
			local args = ui_helper.minimal_window_args("camera preset")
			args[3] = false
			local window = iris.Window(args)
				iris.Image({"rbxassetid://9809316310", UDim2.new(1, 0, 1, -padding*2)})
			iris.End()
			window.size:set(image_size)
			window.position:set(screenspace_v2 - image_size/2)
		end
	iris.PopConfig()
end

local function create_highlight(parent: luauInstance)
	local obj = create_instance("Highlight")
	obj.Name = HIGHLIGHT_INSTANCE_NAME
	obj.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	obj.add_tag(dlcomp_avatar.TAG_DESTROY_ON_KILL)
	obj.Parent = parent
	return obj
end
function update_highlight(username: string, model: luauInstance?)
	model = model or dlcomp_avatar.spawned_players[username]
	if not model then
		return
	end

	local info = replicate.state.players[username]
	if not info then
		warn(`no info found for player {username}`)
		return
	end

	local highlight = model.find_first_child(HIGHLIGHT_INSTANCE_NAME) or create_highlight(model)
	highlight.FillTransparency = highlight_fill_transparency
	highlight.OutlineTransparency = highlight_outline_transparency

	local color = highlight_colors[info.team] or highlight_color_backup
	highlight.OutlineColor = color
	highlight.FillColor = color
end
function remove_all_highlights()
	local models = get_chars_root()
	for _, model in models.get_children() do
		local highlight = model.find_first_child(HIGHLIGHT_INSTANCE_NAME)
		if not highlight then
			continue
		end
		highlight.destroy()
	end
end

function update_map(code: string)

end

-- input/rendering callbacks when the freecam is active
do
	--- disables the input/rendering if we are no longer in the freecam
	local function check_is_active()
		if (last_active_tick + disable_delay) <= tick() then
			disable()
		end
	end
	--- render with iris
	local function iris_draw_markers()
		if not framework.character.is_alive() then
			return
		end
	
		local success, err
	
		-- draw player markers
		success, err = pcall(draw_player_markers)
		if not success then
			warn(err)
			-- iris_marker_destroy()
			return
		end
	
		-- draw camera preset location markers
		success, err = pcall(draw_camera_presets)
		if not success then
			warn(err)
			-- iris_marker_destroy()
			return
		end
	end
	--- poll inputs
	local function enable_client_input_group()
		local cig = ClientInputGroup.new()

		-- sprint
		input_helper.cig_bind_hold(cig, "run", function(holding: boolean)
			inputs.sprint = holding
		end)
		-- select camera location preset
		input_helper.cig_bind_hold(cig, "aim", function(pressed: boolean)
			inputs.select_preset = pressed
			if pressed then return end
			-- select the preset
		end)

		-- movement
		input_helper.cig_bind_double_axis(cig, {"move_forward"}, {"move_backward"}, function(value: number)
			inputs.moveStraight = value
		end)
		input_helper.cig_bind_double_axis(cig, {"move_left"}, {"move_right"}, function(value: number)
			inputs.moveStrafe = value
		end)
		input_helper.cig_bind_double_axis(cig, {"move_down"}, {"move_up"}, function(value: number)
			inputs.moveVertical = value
		end)

		return cig
	end

	local function on_replicator_init()
		update_map(replicate.state.map)
	end
	
	function activate()
		last_active_tick = tick()
		if freecam_active then
			return
		end
		freecam_active = true

		maid_active["activator-dlcomp_replicate"] = replicate.activator:Subscribe(ACTIVATOR_ID)
		maid_active["activator-dlcomp_avatar"] = dlcomp_avatar.activator:Subscribe(ACTIVATOR_ID)
		
		maid_active["metronome-check_is_active"] = metronome.new(1, check_is_active)
		maid_active["iris-markers"] = iris:Connect(iris_draw_markers)
		maid_active["client_input_group"] = enable_client_input_group()
		
		if replicate.is_loaded then
			on_replicator_init()
		end
		maid_active["replicate-new"] = replicate.signal_inital:Connect(on_replicator_init)

		maid_active["replicate-update"] = replicate.signal_player_update:Connect(update_highlight)
		maid_active["avatar-loaded"] = dlcomp_avatar.signal_model_loaded:Connect(update_highlight)
	end
	function disable()
		if not freecam_active then return end
		freecam_active = false
	
		remove_all_highlights()
		maid_active:DoCleaning()
	end
end

function CustomFreecam.new()
	local self = {
		camera_cframe = CFrame.new(-35.25, 135.662, 8.242),
		rot_x = 0,
		rot_y = 0,
	}

	activate()
	return setmetatable(self, CustomFreecam)
end

function CustomFreecam:update(dt: number)
	activate()

	-- rotation
	self.rot_x -= self.mouse_delta.X
	self.rot_y = math.clamp(self.rot_y - self.mouse_delta.Y, -math.pi/2, math.pi/2)
	local new_dir = CFrame.Angles(0, self.rot_x, 0) * CFrame.Angles(self.rot_y, 0, 0)

	-- movement speed
	local horizontal_speed = inputs.sprint and 90 or 45
	local vertical_speed = 90
	-- movement
	local horizontal_dir = v3SafeUnit(Vector3.new(inputs.moveStrafe, 0, inputs.moveStraight)) * horizontal_speed
	local vertical_dir = Vector3.new(0, inputs.moveVertical, 0) * vertical_speed
	local move_dir = new_dir:VectorToWorldSpace(horizontal_dir) + vertical_dir
	
	-- update
	local last_pos = math.isfinite(self.camera_cframe.Position.Magnitude) and self.camera_cframe.Position or Vector3.new()
	local new_pos = last_pos + move_dir * dt
	self.camera_cframe = new_dir + new_pos

	return nil
end

register_camera_mode("dlcomp_freecam", CustomFreecam)
return module
