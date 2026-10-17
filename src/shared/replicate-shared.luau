-- very basic implementation, all I need for freecam, I dont doubt most of it will change
-- however I dont really know what future requirements will be, and I need freecam out fairly soon

local module = {}

export type state = {
	players: {[string]: player_info},
	map: string,
}

export type player_id = number
export type player_info = {
	id: player_id,
	username: string,
	team: team_id,
}

module.NETWORK_SUBSCRIBE = "dlcomp-replicate-subscribe"
module.NETWORK_UNSUBSCRIBE = "dlcomp-replicate-unsubscribe"
module.NETWORK_INITAL = "dlcomp-replicate-initial"
module.NETWORK_UPDATE = "dlcomp-replicate-update"
module.NETWORK_SPAWN = "dlcomp-replicate-spawn"
module.NETWORK_DESPAWN = "dlcomp-replicate-despawn"
module.NETWORK_MAP = "dlcomp-replicate-map"

function module.generate_state(): state
	return {
		players = {},
		map = "",
	}
end

return module