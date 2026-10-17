-- deadline does not currently provide a way to directly get the viewport's resolution
-- thankfully we can still figure it out thanks to iris clamping the size of the window when generating a new state

local ui_helper = require("./ui-helper")
local activator = require("../shared/activator").new("dlcomp-resolution")

local module = {
	resolution = Vector2.new(1920, 1080),
	activator = activator
}

-- config
local query_frequency = 1 -- in seconds

local last_query = -1
function iris_query_resolution()
	if (last_query + query_frequency) > tick() then return end
	last_query = tick()

	iris.PushConfig({
		WindowBorderSize = 0,
		IgnoreGuiInset = true,
		WindowPadding = Vector2.zero,
	})

	-- needs to be WeakState, otherwise it recognizes the previous state and doesnt create a new window widget
	local state_position = iris.WeakState(Vector2.zero)
	local state_size = iris.WeakState(Vector2.one * math.huge)
	local window = iris.Window(ui_helper.minimal_window_args(`dlcomp resolution query`), {position=state_position, size=state_size})
	iris.End()

	iris.PopConfig()

	module.resolution = window.size:get()
end

activator.OnEnable:Connect(function()
	activator.maid["iris"] = iris:Connect(iris_query_resolution)
end)

return module
