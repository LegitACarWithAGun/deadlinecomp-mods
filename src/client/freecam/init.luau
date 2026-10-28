local input_helper = require("./input-helper")
local esp = require("@self/esp")
local Maid = require("../shared/maid")

local module = {}

-- config
--- name to register the camera mode as, 
--- using exactly `Freecam` prevents the user's weapons from being equippable
local CAMERA_MODE_NAME = "Freecam"
--- heartbeats (frames) to wait before disabling itself, 
--- since deadline doesnt let us read or listen to the active camera mode
local disable_after = 15

-- state
local active_freecam: dlcomp_freecam?
local module_destroyed = false




local dlcomp_freecam = {}
dlcomp_freecam.__index = dlcomp_freecam
type dlcomp_freecam = typeof(dlcomp_freecam.new())
type dlcomp_freecam_full = dlcomp_freecam & camera_controller_provided

function dlcomp_freecam.new()
	if active_freecam then
		active_freecam:destroy()
	end

	local self = {
		maid = Maid.new("dlcomp-freecam-instance"),

		camera_cframe = CFrame.new(-35.25, 135.662, 8.242),
		rot_x = 0,
		rot_y = 0,

		--- not to be confused with the .input field that is added automatically
		controls = {
			sprint = false,
			select_preset = false,
			pitch_movement_toggle = false, -- if true, forward/back movement goes towards where your camera is pointed
		
			moveStraight = 0,
			moveStrafe = 0,
			moveVertical = 0,
		},

		frames_without_update = 0,
		destroyed = false,
	}

	local instance = setmetatable(self, dlcomp_freecam)
	instance:enable()
	return instance
end
-- camera controls
function dlcomp_freecam.update(self: dlcomp_freecam_full, dt: number)
	if self:is_destroyed() then return end
	self:enable()

	local controls = self.controls

	-- rotation
	self.rot_x -= self.mouse_delta.X
	self.rot_y = math.clamp(self.rot_y - self.mouse_delta.Y, -math.pi/2, math.pi/2)
	local new_dir_yaw = CFrame.Angles(0, self.rot_x, 0)
	local new_dir = new_dir_yaw * CFrame.Angles(self.rot_y, 0, 0)

	-- movement speed
	local horizontal_speed = controls.sprint and 90 or 45
	local vertical_speed = controls.sprint and 90 or 45
	local horizontal_dir = v3SafeUnit(Vector3.new(controls.moveStrafe, 0, controls.moveStraight)) * horizontal_speed
	local vertical_dir = Vector3.new(0, controls.moveVertical, 0) * vertical_speed
	-- movement
	local move_dir = controls.pitch_movement_toggle and new_dir or new_dir_yaw
	move_dir = move_dir:VectorToWorldSpace(horizontal_dir) + vertical_dir
	
	-- update
	local last_pos = math.isfinite(self.camera_cframe.Position.Magnitude) and self.camera_cframe.Position or Vector3.new()
	local new_pos = last_pos + move_dir * dt
	self.camera_cframe = new_dir + new_pos
end

--- listen to user inputs and map them to the `.controls` table
function dlcomp_freecam.bind_inputs(self: dlcomp_freecam, cig: ClientInputGroup)
	local controls = self.controls

	-- sprint
	input_helper.cig_bind_hold(cig, "run", function(holding: boolean)
		controls.sprint = holding
	end)

	-- movement
	input_helper.cig_bind_double_axis(cig, {"move_forward"}, {"move_backward"}, function(value: number)
		controls.moveStraight = value
	end)
	input_helper.cig_bind_double_axis(cig, {"move_left"}, {"move_right"}, function(value: number)
		controls.moveStrafe = value
	end)
	input_helper.cig_bind_double_axis(cig, {"move_down", "crouch", "prone"}, {"move_up", "space"}, function(value: number)
		controls.moveVertical = value
	end)

	-- toggles
	cig:bind_user_setting(function()
		controls.pitch_movement_toggle = not controls.pitch_movement_toggle
	end, InputType.Began, "laser_toggle")
end


--- call every time the freecam updates, since deadline doesnt let us read or listen to the active camera mode
function dlcomp_freecam.enable(self: dlcomp_freecam)
	self.frames_without_update = 0
	if active_freecam or self:is_destroyed() then return end
	active_freecam = self

	-- dependencies
	self.maid["activator-dlcomp_esp"] = esp.activator:Subscribe("dlcomp-freecam")

	-- inputs
	local cig = ClientInputGroup.new()
	self.maid["client_input_group"] = cig
	self:bind_inputs(cig)

	-- continously check if we're still in the freecam
	self.maid["heartbeat-is_active"] = time.heartbeat("dlcomp-freecam-is_active", function()
		self.frames_without_update += 1
		if disable_after > self.frames_without_update then return end
		self:disable()
	end)
end
function dlcomp_freecam.disable(self: dlcomp_freecam)
	self.maid:DoCleaning()
	if active_freecam == self then
		active_freecam = nil
	end
end
function dlcomp_freecam.destroy(self: dlcomp_freecam)
	self.destroyed = true
	self:disable()
end
function dlcomp_freecam.is_destroyed(self: dlcomp_freecam)
	return self.destroyed or module_destroyed
end




function v3SafeUnit(v3: Vector3): Vector3
	return v3.Magnitude == 0 and Vector3.zero or v3.Unit
end




function module.destroy()
	module_destroyed = true
	if active_freecam then
		active_freecam:destroy()
	end
	register_camera_mode(CAMERA_MODE_NAME, nil)
end

register_camera_mode(CAMERA_MODE_NAME, dlcomp_freecam)
return module
