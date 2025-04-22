local M = {}
local utils = require("time-machine.utils")

--- Build a tree from a snapshot history
---@param snapshots TimeMachine.Snapshot The snapshot history
---@return TimeMachine.TreeNode nodes The root node
function M.build_tree(snapshots)
	local root_key = utils.find_key_with_prefix(snapshots, "root")
	local root = snapshots[root_key]
	local nodes = {}

	-- Build node map with children
	for id, snap in pairs(snapshots) do
		nodes[id] = {
			snap = snap,
			children = {},
		}
	end

	-- Build parent-child relationships
	for _, node in pairs(nodes) do
		local parent = node.snap.parent
		if parent and nodes[parent] then
			table.insert(nodes[parent].children, node)
		end
	end

	-- Sort children by timestamp
	for _, node in pairs(nodes) do
		table.sort(node.children, function(a, b)
			return a.snap.timestamp < b.snap.timestamp
		end)
	end

	return nodes[root.id]
end

--- Format snapshots like a git commit graph
---@param root TimeMachine.TreeNode Root node of the tree
---@param lines string[] The output lines
---@param id_map table<integer, string> Line number to snapshot ID
---@param current_id string The currently selected snapshot ID
function M.format_graph(root, lines, id_map, current_id)
	---@type { node: TimeMachine.TreeNode, indent: integer, parent_is_branched: boolean }[]
	local queue = {}
	table.insert(queue, { node = root, indent = 0, parent_is_branched = true })

	while #queue > 0 do
		---@type { node: TimeMachine.TreeNode, indent: integer, parent_is_branched: boolean }
		local entry = table.remove(queue, 1)
		local node = entry.node
		local current_indent = entry.indent
		local parent_is_branched = entry.parent_is_branched

		local snap = node.snap
		local short_id = utils.get_short_id(snap)
		local time_str = utils.relative_time(snap.timestamp)
		local tags = (#snap.tags > 0) and (" ◼ " .. table.concat(snap.tags, ", ")) or ""
		local marker = (snap.id == current_id) and "● " or "* "
		local prefix = string.rep("| ", current_indent)

		local line = string.format("%s%s %s%s (%s)", prefix, marker, short_id, tags, time_str)
		table.insert(lines, line)
		id_map[#lines] = snap.id

		local children = node.children or {}
		table.sort(children, function(a, b)
			return a.snap.timestamp < b.snap.timestamp
		end)

		for i = #children, 1, -1 do
			local child = children[i]
			local child_indent = current_indent

			if parent_is_branched then
				child_indent = current_indent + 1
			end

			table.insert(queue, 1, { node = child, indent = child_indent, parent_is_branched = #children > 1 })
		end
	end
end

return M
