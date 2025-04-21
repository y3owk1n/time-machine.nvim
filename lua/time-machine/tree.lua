local M = {}
local utils = require("time-machine.utils")

--- Build a tree from a snapshot history
---@param history TimeMachine.History The snapshot history
---@return TimeMachine.TreeNode[] nodes The list of tree nodes
function M.build_tree(history)
	local root_key = utils.find_key_with_prefix(history.snapshots, "root")
	local root = history.snapshots[root_key]
	local nodes = {}

	-- Build node map with children
	for id, snap in pairs(history.snapshots) do
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

--- Format a tree node
---@param node TimeMachine.TreeNode The tree node
---@param depth integer The current depth
---@param ancestor_has_more boolean[] The ancestor has more siblings after it
---@param is_last boolean Whether the node is the last among siblings
---@param lines string[] The output lines
---@param id_map table<integer, string> The map of line numbers to snapshot IDs
---@param current_id string The ID of the currently selected snapshot
---@return nil
function M.format_tree(node, depth, ancestor_has_more, is_last, lines, id_map, current_id)
	-- only draw prefixes for *branching* ancestors
	local prefix = ""
	for d = 1, depth - 1 do
		if ancestor_has_more[d] then
			prefix = prefix .. "│  "
		end
	end

	local connector = ""
	if depth > 0 then
		connector = is_last and "└─ " or "├─ "
	end

	local snap = node.snap
	local time_str = utils.relative_time(snap.timestamp)
	local short_id = (snap.id:sub(1, 4) == "root") and snap.id or snap.id:sub(5, 8)
	local tags = (#snap.tags > 0) and (" ◼ " .. table.concat(snap.tags, ", ")) or ""
	local marker = (snap.id == current_id) and "● " or ""
	local line = prefix .. connector .. string.format("%s%s%s (%s)", marker, short_id, tags, time_str)

	table.insert(lines, line)
	id_map[#lines] = snap.id

	local children = node.children or {}
	local count = #children
	for i, child in ipairs(children) do
		local child_anc = {}
		for d = 1, depth - 1 do
			child_anc[d] = ancestor_has_more[d]
		end
		-- only mark “has more” if this parent actually has >1 child
		child_anc[depth] = (count > 1) and (i ~= count) or not is_last
		M.format_tree(child, depth + 1, child_anc, i == count, lines, id_map, current_id)
	end
end

return M
