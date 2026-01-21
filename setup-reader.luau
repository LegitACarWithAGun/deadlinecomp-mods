-- load json decoder
if not shared.rxi_json then
	require("https://raw.githubusercontent.com/LegitACarWithAGun/deadlinecomp-mods/refs/heads/main/dependencies/rxi-json.lua")
end

--- breadth first
function iter_descendants(node: setup_node, include_self: boolean): () -> setup_node?
	local cur_nodes = include_self and {node} or node.attached
	local next_nodes = {}
	local i = 1

	return function()
		-- nothing more in the current depth, descend if we can
		if i > #cur_nodes then
			if #next_nodes == 0 then
				return nil
			end
			cur_nodes = next_nodes
			next_nodes = {}
			i = 1
		end

		-- add nodes from the next depth
		local node = cur_nodes[i]
		for _, child in pairs(node.attached) do
			table.insert(next_nodes, child)
		end

		i += 1
		return node
	end
end

function update_parents(node: setup_node)
	for _, child in pairs(node.attached) do
		child.parent = node
		update_parents(child)
	end
end

function parse_setup(setup_json: setup_json): setup_node
	local root_node = shared.rxi_json.decode(setup_json) :: setup_node

	if not root_node.attached then
		root_node = root_node[1]
	end

	-- set parents for all descendants
	root_node.parent = nil
	update_parents(root_node)

	return root_node
end

--- breadth-first searches for the first node that exactly matches the search value, including the input node
function find_first(entry_node: setup_node, needle: string): setup_node?
	for node in iter_descendants(entry_node, true) do
		if node.name == needle then
			return node
		end
	end
	return nil
end

--- prints all the attachments of the equipped weapon
function print_equipped_attachments(want_player: string?, slot_name: string?)
	want_player = want_player or function_caller
	local player = players.get(want_player :: string) --- TODO: this errors without overriding the type
	slot_name = slot_name or player.get_active_slot()

	local weapon = player.get_weapon_data_from_character(slot_name)
	if weapon.type == "throwable" then
		info(`{weapon.name} in slot {slot_name} is throwable`)
		return
	end

	local client_data = weapon.client_data
	info(`attachments for {client_data.name} in slot {slot_name}:`)

	-- prints the setup tree as a... tree
	local function print_node(node: setup_node, depth: number)
		print(`{string.rep("	", depth-1)}{depth}: {node.name}`)
		for _, child in pairs(node.attached) do
			print_node(child, depth+1)
		end
	end

	local root_node = parse_setup(client_data.setup)
	print_node(root_node, 1)
end

shared.dlcomp_setup_reader = {
	parse_setup = parse_setup,
	find_first = find_first,
	print_equipped_attachments = print_equipped_attachments
}
