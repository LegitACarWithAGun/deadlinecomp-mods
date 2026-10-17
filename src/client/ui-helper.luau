local module = {}

function module.minimal_window_args(title: string): {string|boolean}
	local output = table.create(10, true) :: any
	output[1] = title
	return output
end

function module.get_text_width(text: string, fontSize: number): number
	return #text * fontSize * 0.5
end

function module.world_to_viewport(camera_cframe: CFrame, resolution: Vector2, fov: number, target_pos: Vector3): (Vector3, boolean)
	local target_relative = camera_cframe:PointToObjectSpace(target_pos)
	local depth = -target_relative.Z

	local aspect_ratio = resolution.X / resolution.Y
	-- the size of the view frustum at this depth
	local half_height = depth * math.tan(math.rad(fov) / 2)
	local half_width = half_height * aspect_ratio

	-- the position of the target in (fractional) pixels in the viewport
	local pixels_x = (resolution.X / 2) * (1 + target_relative.X / half_width)
	local pixels_y = (resolution.Y / 2) * (1 - target_relative.Y / half_height)

	local on_screen = depth > 0
		and pixels_x >= 0 and pixels_x <= resolution.X
		and pixels_y >= 0 and pixels_y <= resolution.Y

	return Vector3.new(pixels_x, pixels_y, depth), on_screen
end

return module