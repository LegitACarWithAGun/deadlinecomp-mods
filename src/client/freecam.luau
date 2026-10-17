--!strict

local input_helper = require("./input-helper")
local Maid = require("../shared/maid")
local esp = require("./esp")
local maid = Maid.new("dlcomp-freecam active")

local module = {
	maid = maid,
}

-- config
--- heartbeats (frames) to wait before disabling itself, 
--- since deadline doesnt let us read or listen to the active camera mode
local disable_after = 15

-- state
local frames_without_update = 0
local freecam_active = false
local inputs = {
	sprint = false,
	select_preset = false,

	moveStraight = 0,
	moveStrafe = 0,
	moveVertical = 0,
}
local module_destroyed = false




local dlcomp_freecam = {} :: camera_controller
dlcomp_freecam.__index = dlcomp_freecam

function dlcomp_freecam.new()
	local self = {
		camera_cframe = CFrame.new(-35.25, 135.662, 8.242),
		rot_x = 0,
		rot_y = 0,
	}

	activate()
	return setmetatable(self, dlcomp_freecam)
end
-- camera controls
function dlcomp_freecam:update(dt: number)
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





--- listen to inputs and map them to the `inputs` object
local function map_inputs(): ClientInputGroup
	local cig = ClientInputGroup.new()

	-- sprint
	input_helper.cig_bind_hold(cig, "run", function(holding: boolean)
		inputs.sprint = holding
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




--- call every time the freecam updates, since deadline doesnt let us read or listen to the active camera mode
function activate()
	frames_without_update = 0
	if freecam_active or module_destroyed then return end
	freecam_active = true
	
	maid["activator-dlcomp_esp"] = esp.activator:Subscribe("dlcomp-freecam")
	maid["client_input_group"] = map_inputs()

	-- check if we're still in the freecam
	maid["heartbeat-is_active"] = time.heartbeat("dlcomp-freecam-is_active", function()
		frames_without_update += 1
		if disable_after > frames_without_update then return end
		disable()
	end)
end
function disable()
	if not freecam_active then return end
	freecam_active = false
	
	maid:DoCleaning()
end




function v3SafeUnit(v3: Vector3): Vector3
	return v3.Magnitude == 0 and Vector3.zero or v3.Unit
end




function module.destroy()
	disable()
	maid:DoCleaning()
	module_destroyed = true
end

register_camera_mode("dlcomp_freecam", dlcomp_freecam)
return module
