local M = {}
local utils = require("time-machine.utils")

--- Build a tree from a snapshot history
---@param snapshots TimeMachine.Snapshot The snapshot history
---@return TimeMachine.TreeNode nodes The root node
function M.build_tree(snapshots)
	-- 1) Build a map: id → TreeNode
	local nodes = {}
	for _, snap in ipairs(snapshots) do
		nodes[snap.id] = {
			snap = snap,
			children = {},
		}
	end

	-- 2) Wire up parent → children, and detect the root
	local root
	for _, node in pairs(nodes) do
		local pid = node.snap.parent
		if pid and nodes[pid] then
			table.insert(nodes[pid].children, node)
		else
			-- no parent means this is (one of) the root(s)
			-- if you expect exactly one root, you could assert root == nil here
			root = node
		end
	end

	-- 3) Recursively sort each node’s children by timestamp
	---@param n TimeMachine.TreeNode
	---@return TimeMachine.TreeNode
	local function sort_subtree(n)
		table.sort(n.children, function(a, b)
			return a.snap.timestamp < b.snap.timestamp
		end)
		for _, child in ipairs(n.children) do
			sort_subtree(child)
		end
	end

	if root then
		sort_subtree(root)
	end

	return root
end

--- Format snapshots like a git commit graph
---@param root TimeMachine.TreeNode Root node of the tree
---@param lines string[] The output lines
---@param id_map table<integer, string> Line number to snapshot ID
---@param current_id string The currently selected snapshot ID
function M.format_graph(root, lines, id_map, current_id)
	local formatted = {}
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
		local short_id = snap.id
		local time_str = utils.relative_time(snap.timestamp)
		-- local tags = (#snap.tags > 0) and (" ◼ " .. table.concat(snap.tags, ", ")) or ""
		local marker = (snap.id == current_id) and "● " or "* "
		local prefix = string.rep("| ", current_indent)

		local line = string.format("%s%s %s (%s)", prefix, marker, short_id, time_str)
		table.insert(formatted, { text = line, id = snap.id })

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

	-- reverse and insert into the lines
	for i = #formatted, 1, -1 do
		table.insert(lines, formatted[i].text)
		id_map[#lines] = formatted[i].id
	end
end

local function format_time(timestamp)
	return os.date("%H:%M:%S", timestamp)
end

function M.render_git_style_graph(graph, lines)
	local node_map = {}
	for _, node in ipairs(graph) do
		node_map[node.seq] = node
	end

	-- Build connections
	for _, node in ipairs(graph) do
		if node.parent then
			local parent = node_map[node.parent]
			if parent then
				table.insert(parent.children, node.seq)
			end
		end
	end

	local function render_node(node, prefix, is_last, parent_pos)
		local branch_char = is_last and "└─" or "├─"
		local commit_hash = string.sub(tostring(node.save), 1, 7)
		local newhead_marker = node.is_newhead and " (branch)" or ""

		local line =
			string.format("%s%s %s | %s%s", prefix, branch_char, commit_hash, format_time(node.time), newhead_marker)

		table.insert(lines, line)

		-- Draw vertical lines
		if #node.children > 0 then
			local vertical_line = prefix .. (is_last and "  " or "│ ")
			table.insert(lines, vertical_line)
		end

		local new_prefix = prefix .. (is_last and "  " or "│ ")
		for i, child_seq in ipairs(node.children) do
			local child = node_map[child_seq]
			if child then
				render_node(child, new_prefix, i == #node.children)
			end
		end
	end

	-- Find root nodes
	for _, node in ipairs(graph) do
		if not node.parent then
			render_node(node, "", true)
			break
		end
	end
end

return M
