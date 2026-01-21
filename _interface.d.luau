--- used by arg-parser.luau
export type command_parse_info = {
	--- all the text After the current argument
    remaining_text: string,
    --- the string the return value value was made from, the raw argument section, useful if you wanna re-parse after a fail
    converted_from: string,
}

--- used by command-bot.luau
export type command_call_info = {
    message_channel: string,
    raw_message: string,
    caller: player,
}

--- used by geneva.luau
export type geneva_context = {
    --- warning/info about the loadout, key being the slot name
    feedback: {[string]: string},
    --- how many more grenades the player can have
    allowed_nades_left: number,
}
export type custom_geneva_rule = {
    name: string,
    callback: (player: player) -> string?
}

--- used by setup-reader.luau
export type setup_node = {
    attached: {setup_node},
    attributes: unknown,
    lerp: string | "0.000",
    name: string?,

    -- added during parse
    --- nil for the root node
    parent: setup_node?
}

declare shared: {
	[string]: any,
	dlcomp_command_bot: {
		add_command: (name: string, explanation: string, callback: (args: string, extra: command_call_info) -> string?) -> nil,
		toggle_admin: (player_name: string, toggle: boolean?) -> (boolean, string),
		toggle_command_permissions: (toggle: boolean?) -> (),
		admin_list: {string}
	},
	dlcomp_parser: {
		get_string: (args: string) -> (string, command_parse_info),
		get_number: (args: string, default: number?, min: number?, max: number?) -> (number?, command_parse_info),
		get_bool: (args: string) -> (boolean?, command_parse_info),
		get_player: (args: string, match_exact: boolean?) -> (player?, command_parse_info),
	},
	dlcomp_table: {
		get_page: <T>(list: {T}, page_length: number, want_page: number) -> ({T}, number),
		in_filter: <T>(values: {T}, filter: {T}) -> {T},
		not_in_filter: <T>(values: {T}, filter: {T}) -> {T},
	},
	dlcomp_string: {
		trim_start: (str: string) -> string,
		partial_match_sections: (haystack: {string}, needle: string, seperator: string) -> {string},
	},
	dlcomp_countdown: {
		countdown: (duration: number) -> nil,
		cancel_countdown: () -> nil,
		freeze: () -> nil,
		unfreeze: () -> nil,
	
		finished: Signal<>,
	},
	dlcomp_geneva: {
		-- rules
		toggle_rules: (enabled: boolean?) -> nil,
		set_banned_weapons: (new_bans: {string}) -> nil,
		set_max_grenades: (max_grenades: number) -> nil,
		set_custom_rules: (new_rules: {custom_geneva_rule}) -> nil,
		-- behaviour
		should_announce_equipment_cleaning: (want: boolean) -> nil,
		-- information, entierly human-facing
		print_known_weapons: () -> nil,
		announce_ruleset: () -> nil,
		--- helper functions
		iter_slots: (player: player) -> () -> (string, weapon_data),
	},
	dlcomp_round: {
		prepare_round: (map_name: string, mode_name: string, round_duration: number, countdown_duration: number) -> nil,
		gamemode_aliases: {[string]: string},
		low_priority_maps: {string},
	},
	dlcomp_setup_reader: {
		parse_setup: (setup_json: setup_json) -> setup_node,
		find_first: (entry_node: setup_node, needle: string) -> setup_node?,
	},

	-- dependencies
	rxi_json: {
		decode: (json_str: string) -> any
	}
}