local api = vim.api
local M = {}

local native_float = nil

local winborder = vim.api.nvim_get_option_value("winborder", { scope = "local" }) or "none"

---@type vim.api.keyset.win_config
local shared_win_opts = {
	relative = "editor",
	width = 0.8,
	height = 0.8,
	border = winborder,
	title_pos = "center",
	footer = "Remember to :wq to save and exit",
	footer_pos = "center",
}

--- Create a floating window for native
---@param buf integer The buffer to open
local function create_native_float(buf)
	if native_float then
		if vim.api.nvim_win_is_valid(native_float) then
			vim.api.nvim_win_set_buf(native_float, buf)
			return
		end
	end

	local win_opts = vim.tbl_deep_extend("force", shared_win_opts, {
		title = "Time Machine",
	})

	win_opts.width = math.floor(vim.o.columns * win_opts.width)
	win_opts.height = math.floor(vim.o.lines * win_opts.height)
	win_opts.row = math.floor((vim.o.lines - win_opts.height) / 2)
	win_opts.col = math.floor((vim.o.columns - win_opts.width) / 2)

	vim.api.nvim_open_win(buf, true, win_opts)
end

function M.build_child_map(history)
	local child_map = {}
	for id, snap in pairs(history.snapshots) do
		if snap.parent then
			child_map[snap.parent] = child_map[snap.parent] or {}
			table.insert(child_map[snap.parent], id)
		end
	end
	return child_map
end

function M.has_children(history, snapshot_id)
	local child_map = M.build_child_map(history)
	return child_map[snapshot_id] and #child_map[snapshot_id] > 0
end

local function find_key_with_prefix(tbl, prefix)
	for key, value in pairs(tbl) do
		if type(key) == "string" and key:sub(1, #prefix) == prefix then
			return key, value
		end
	end
end

local function build_tree(history)
	local root_key = find_key_with_prefix(history.snapshots, "root")
	local root = history.snapshots[root_key]
	local nodes = {}
	local tree = {}

	-- Build node map with children
	for id, snap in pairs(history.snapshots) do
		nodes[id] = {
			snap = snap,
			children = {},
		}
	end

	-- Build parent-child relationships
	for id, node in pairs(nodes) do
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

--- Convert a timestamp into a human-readable relative time (e.g., "16s ago", "5m ago")
local function relative_time(timestamp)
	local now = os.time()
	local diff = now - timestamp
	if diff < 60 then
		return string.format("%ds ago", diff)
	elseif diff < 3600 then
		return string.format("%dm ago", math.floor(diff / 60))
	elseif diff < 86400 then
		return string.format("%dh ago", math.floor(diff / 3600))
	else
		return string.format("%dd ago", math.floor(diff / 86400))
	end
end

--- Format tree: connectors only where siblings exist
-- node: table with .snap and .children
-- depth: current depth (root=0)
-- ancestor_has_more: boolean array per depth, true if ancestor has more siblings after it
-- is_last: boolean, true if node is last among siblings
-- lines: array to accumulate output lines
-- id_map: maps line index to snapshot ID
-- current_id: ID of the currently selected snapshot
local function format_tree(node, depth, ancestor_has_more, is_last, lines, id_map, current_id)
	-- Build prefix from ancestor levels (only up to depth-1)
	local prefix = ""
	for d = 1, depth - 1 do
		if ancestor_has_more[d] then
			prefix = prefix .. "│  "
		else
			prefix = prefix .. "   "
		end
	end

	-- Connector symbol
	local connector = ""
	if depth > 0 then
		connector = is_last and "└─ " or "├─ "
	end

	-- Format current node line
	local snap = node.snap
	local time_str = relative_time(snap.timestamp)
	local short_id = (snap.id:sub(1, 4) == "root") and snap.id or snap.id:sub(5, 8)
	local tags = (#snap.tags > 0) and (" ◼ " .. table.concat(snap.tags, ", ")) or ""
	local marker = (snap.id == current_id) and "● " or ""
	local line = prefix .. connector .. string.format("%s%s%s (%s)", marker, short_id, tags, time_str)
	table.insert(lines, line)
	id_map[#lines] = snap.id

	-- Process children
	local children = node.children or {}
	local count = #children
	for i, child in ipairs(children) do
		-- Build new ancestor_has_more for child
		local child_anc = {}
		-- Copy existing flags
		for d = 1, depth - 1 do
			child_anc[d] = ancestor_has_more[d]
		end
		-- For this node level, if node has more siblings, draw vertical line
		child_anc[depth] = not is_last
		-- Determine if child is last among siblings
		local child_is_last = (i == count)
		-- Recurse
		format_tree(child, depth + 1, child_anc, child_is_last, lines, id_map, current_id)
	end
end

function M.refresh(bufnr, buf_path)
	local history = require("time-machine.storage").load_history(buf_path)

	if not history then
		vim.notify("No history found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	local tree = build_tree(history)

	local lines = {}
	local id_map = {}

	format_tree(tree, 0, {}, true, lines, id_map, history.current.id)
	-- format_tree(tree, "", true, lines, 0, id_map, history.current.id)

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_var(bufnr, "time_machine_id_map", id_map)
end

function M.show(history, buf_path, main_bufnr)
	local tree = build_tree(history)
	local lines = {}
	local id_map = {} -- Maps line numbers to full IDs

	format_tree(tree, 0, {}, true, lines, id_map, history.current.id)
	-- format_tree(tree, "", true, lines, 0, id_map, history.current.id)

	local bufnr = api.nvim_create_buf(false, true)

	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	api.nvim_set_option_value("filetype", "time-machine-history", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("swapfile", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buflisted", false, { scope = "local", buf = bufnr })

	api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
		callback = function()
			M.preview_snapshot(history, api.nvim_win_get_cursor(0)[1], bufnr, buf_path, main_bufnr)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "<leader>r", "", {
		callback = function()
			M.handle_restore(history, api.nvim_win_get_cursor(0)[1], bufnr, buf_path, main_bufnr)
			M.refresh(bufnr, buf_path)
		end,
	})

	vim.api.nvim_open_win(bufnr, true, {
		split = "right",
	})

	vim.api.nvim_buf_set_var(bufnr, "time_machine_id_map", id_map)
end

function M.get_id_from_line(bufnr, line_num)
	local ok, id_map = pcall(vim.api.nvim_buf_get_var, bufnr, "time_machine_id_map")
	return ok and id_map[line_num] or nil
end

function M.preview_snapshot(history, line, bufnr, buf_path, main_bufnr)
	local full_id = M.get_id_from_line(bufnr, line)
	if not full_id then
		return
	end

	local content = {}

	local root_branch_id = require("time-machine").root_branch_id(buf_path)

	if full_id == root_branch_id then
		content = vim.split(history.root.content, "\n")
	else
		local current = history.snapshots[full_id]
		local chain = {}

		-- Collect chain of snapshots from selected to root
		while current do
			table.insert(chain, current)
			current = history.snapshots[current.parent]
		end

		-- Append each snapshot diff in order: newest to oldest
		for i = #chain, 1, -1 do
			local snap = chain[i]
			if snap.diff then
				local diff_lines = vim.split(snap.diff, "\n")
				for j = #diff_lines, 1, -1 do
					table.insert(content, 1, diff_lines[j])
				end
			end
		end
	end

	local preview_buf = api.nvim_create_buf(false, true)

	api.nvim_buf_set_lines(preview_buf, 0, -1, false, content)

	if full_id == root_branch_id then
		local filetype = api.nvim_get_option_value("filetype", { scope = "local", buf = main_bufnr })
		vim.api.nvim_set_option_value("filetype", filetype, { scope = "local", buf = preview_buf })
	else
		vim.api.nvim_set_option_value("filetype", "diff", { scope = "local", buf = preview_buf })
	end

	api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("swapfile", false, { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("buflisted", false, { scope = "local", buf = preview_buf })

	create_native_float(preview_buf)
end

function M.handle_restore(history, line, bufnr, buf_path, main_bufnr)
	local full_id = M.get_id_from_line(bufnr, line)
	if not full_id then
		return
	end

	require("time-machine").restore_snapshot(history.snapshots[full_id], buf_path, main_bufnr)
end

return M
